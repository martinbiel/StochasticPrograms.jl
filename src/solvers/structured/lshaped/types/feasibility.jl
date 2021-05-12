abstract type AbstractFeasibilityAlgorithm end
abstract type AbstractFeasibilityStrategy end

"""
    NoFeasibilityAlgorithm

Empty functor object for running an L-shaped algorithm without dealing with second-stage feasibility.
"""
struct NoFeasibilityAlgorithm <: AbstractFeasibilityAlgorithm end

handle_feasibility(::NoFeasibilityAlgorithm) = false
num_cuts(::NoFeasibilityAlgorithm) = 0
restore!(::MOI.ModelLike, ::NoFeasibilityAlgorithm) = nothing

"""
    FeasibilityCutsMaster

Master functor object for using feasibility cuts in an L-shaped algorithm. Create by supplying a [`FeasibilityCuts`](@ref) object through `feasibility_strategy` in `LShaped.Optimizer` or set the [`FeasibilityStrategy`](@ref) attribute.
"""
struct FeasibilityCutsMaster{T <: AbstractFloat} <: AbstractFeasibilityAlgorithm
    cuts::Vector{SparseFeasibilityCut{T}}

    function FeasibilityCutsMaster(::Type{T}) where T <: AbstractFloat
        return new{T}(Vector{SparseFeasibilityCut{T}}())
    end
end

handle_feasibility(::FeasibilityCutsMaster) = true
worker_type(::FeasibilityCutsMaster) = FeasibilityCutsWorker
num_cuts(feasibility::FeasibilityCutsMaster) = length(feasibility.cuts)
restore!(::MOI.ModelLike, ::FeasibilityCutsMaster) = nothing

"""
    FeasibilityCutsWorker

Worker functor object for using feasibility cuts in an L-shaped algorithm. Create by supplying a [`FeasibilityCuts`](@ref) object through `feasibility_strategy` in `LShaped.Optimizer` or set the [`FeasibilityStrategy`](@ref) attribute.
"""
mutable struct FeasibilityCutsWorker <: AbstractFeasibilityAlgorithm
    objective::MOI.AbstractScalarFunction
    feasibility_variables::Vector{MOI.VariableIndex}
end

handle_feasibility(::FeasibilityCutsWorker) = true
num_cuts(::FeasibilityCutsWorker) = 0

function prepare!(model::MOI.ModelLike, worker::FeasibilityCutsWorker)
    # Set objective to zero
    G = MOI.ScalarAffineFunction{Float64}
    MOI.set(model, MOI.ObjectiveFunction{G}(), zero(MOI.ScalarAffineFunction{Float64}))
    i = 1
    # Create auxiliary feasibility variables
    for (F, S) in MOI.get(model, MOI.ListOfConstraints())
        i = add_auxiliary_variables!(model, worker, F, S, i)
    end
    return nothing
end
function prepared(worker::FeasibilityCutsWorker)
    return length(worker.feasibility_variables) > 0
end

function add_auxiliary_variables!(model::MOI.ModelLike,
                                  worker::FeasibilityCutsWorker,
                                  F::Type{<:MOI.AbstractFunction},
                                  S::Type{<:MOI.AbstractSet},
                                  idx::Integer)
    # Nothing to do for most most constraints
    return idx
end

function add_auxiliary_variables!(model::MOI.ModelLike,
                                  worker::FeasibilityCutsWorker,
                                  F::Type{<:AffineDecisionFunction},
                                  S::Type{<:MOI.AbstractScalarSet},
                                  idx::Integer)
    G = MOI.ScalarAffineFunction{Float64}
    obj_sense = MOI.get(model, MOI.ObjectiveSense())
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
        # Positive feasibility variable
        pos_aux_var = MOI.add_variable(model)
        name = add_subscript(:v⁺, idx)
        MOI.set(model, MOI.VariableName(), pos_aux_var, name)
        push!(worker.feasibility_variables, pos_aux_var)
        # Nonnegativity constraint
        MOI.add_constraint(model, MOI.SingleVariable(pos_aux_var),
                           MOI.GreaterThan{Float64}(0.0))
        # Add to objective
        MOI.modify(model, MOI.ObjectiveFunction{G}(),
                   MOI.ScalarCoefficientChange(pos_aux_var, obj_sense == MOI.MAX_SENSE ? -1.0 : 1.0))
        # Add to constraint
        MOI.modify(model, ci, MOI.ScalarCoefficientChange(pos_aux_var, 1.0))
        # Negative feasibility variable
        neg_aux_var = MOI.add_variable(model)
        name = add_subscript(:v⁻, idx)
        MOI.set(model, MOI.VariableName(), neg_aux_var, name)
        push!(worker.feasibility_variables, neg_aux_var)
        # Nonnegativity constraint
        MOI.add_constraint(model, MOI.SingleVariable(neg_aux_var),
                           MOI.GreaterThan{Float64}(0.0))
        # Add to objective
        MOI.modify(model, MOI.ObjectiveFunction{G}(),
                   MOI.ScalarCoefficientChange(neg_aux_var, obj_sense == MOI.MAX_SENSE ? -1.0 : 1.0))
        # Add to constraint
        MOI.modify(model, ci, MOI.ScalarCoefficientChange(neg_aux_var, -1.0))
        # Update identification index
        idx += 1
    end
    return idx + 1
end

function add_auxiliary_variables!(model::MOI.ModelLike,
                                  worker::FeasibilityCutsWorker,
                                  F::Type{<:VectorAffineDecisionFunction},
                                  S::Type{<:MOI.AbstractVectorSet},
                                  idx::Integer)
    G = MOI.ScalarAffineFunction{Float64}
    obj_sense = MOI.get(model, MOI.ObjectiveSense())
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{F, S}())
        n = MOI.dimension(MOI.get(model, MOI.ConstraintSet(), ci))
        for (i, id) in enumerate(idx:(idx + n - 1))
            # Positive feasibility variable
            pos_aux_var = MOI.add_variable(model)
            name = add_subscript(:v⁺, id)
            MOI.set(model, MOI.VariableName(), pos_aux_var, name)
            push!(worker.feasibility_variables, pos_aux_var)
            # Nonnegativity constraint
            MOI.add_constraint(model, MOI.SingleVariable(pos_aux_var),
                               MOI.GreaterThan{Float64}(0.0))
            # Add to objective
            MOI.modify(model, MOI.ObjectiveFunction{G}(),
                       MOI.ScalarCoefficientChange(pos_aux_var, obj_sense == MOI.MAX_SENSE ? -1.0 : 1.0))
            # Add to constraint
            MOI.modify(model, ci, MOI.MultirowChange(pos_aux_var, [(i, 1.0)]))
        end
        for (i, id) in enumerate(idx:(idx + n - 1))
            # Negative feasibility variable
            neg_aux_var = MOI.add_variable(model)
            name = add_subscript(:v⁻, id)
            MOI.set(model, MOI.VariableName(), neg_aux_var, name)
            push!(worker.feasibility_variables, neg_aux_var)
            # Nonnegativity constraint
            MOI.add_constraint(model, MOI.SingleVariable(neg_aux_var),
                               MOI.GreaterThan{Float64}(0.0))
            # Add to objective
            MOI.modify(model, MOI.ObjectiveFunction{G}(),
                       MOI.ScalarCoefficientChange(neg_aux_var, obj_sense == MOI.MAX_SENSE ? -1.0 : 1.0))
            # Add to constraint
            MOI.modify(model, ci, MOI.MultirowChange(neg_aux_var, [(i, -1.0)]))
        end
        # Update identification index
        idx += n
    end
    return idx + 1
end

function restore!(model::MOI.ModelLike, worker::FeasibilityCutsWorker)
    # Delete any feasibility variables
    if !isempty(worker.feasibility_variables)
        MOI.delete(model, worker.feasibility_variables)
    end
    empty!(worker.feasibility_variables)
    # Restore objective
    F = typeof(worker.objective)
    MOI.set(model, MOI.ObjectiveFunction{F}(), worker.objective)
    return nothing
end

# API
# ------------------------------------------------------------
"""
    IgnoreFeasibility

Factory object for [`NoFeasibilityAlgorithm`](@ref). Passed by default to `feasibility_strategy` in `LShaped.Optimizer`.

"""
struct IgnoreFeasibility <: AbstractFeasibilityStrategy end

function master(::IgnoreFeasibility, ::Type{T}) where T <: AbstractFloat
    return NoFeasibilityAlgorithm()
end

function worker(::IgnoreFeasibility, ::MOI.ModelLike)
    return NoFeasibilityAlgorithm()
end
function worker_type(::IgnoreFeasibility)
    return NoFeasibilityAlgorithm
end

"""
    IgnoreFeasibility

Factory object for using feasibility cuts in an L-shaped algorithm.

"""
struct FeasibilityCuts <: AbstractFeasibilityStrategy end

function master(::FeasibilityCuts, ::Type{T}) where T <: AbstractFloat
    return FeasibilityCutsMaster(T)
end

function worker(::FeasibilityCuts, model::MOI.ModelLike)
    # Cache objective
    func_type = MOI.get(model, MOI.ObjectiveFunctionType())
    obj = MOI.get(model, MOI.ObjectiveFunction{func_type}())
    return FeasibilityCutsWorker(obj, Vector{MOI.VariableIndex}())
end
function worker_type(::FeasibilityCuts)
    return FeasibilityCutsWorker
end
