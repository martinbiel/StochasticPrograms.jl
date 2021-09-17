# MIT License
#
# Copyright (c) 2018 Martin Biel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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
    linking_constraints::Vector{MOI.ConstraintIndex}
    feasibility_variables::Vector{MOI.VariableIndex}
    prepared::Bool

    function FeasibilityCutsWorker(objective::MOI.AbstractScalarFunction,
                                   linking_constraints::Vector{MOI.ConstraintIndex},
                                   feasibility_variables::Vector{MOI.VariableIndex})
        return new(objective, linking_constraints, feasibility_variables, false)
    end
end

handle_feasibility(::FeasibilityCutsWorker) = true
num_cuts(::FeasibilityCutsWorker) = 0

function prepare!(model::MOI.ModelLike, worker::FeasibilityCutsWorker)
    # Set objective to zero
    G = MOI.ScalarAffineFunction{Float64}
    MOI.set(model, MOI.ObjectiveFunction{G}(), zero(MOI.ScalarAffineFunction{Float64}))
    i = 1
    # Create auxiliary feasibility variables
    for ci in worker.linking_constraints
        i = add_auxiliary_variables!(model, worker, ci, i)
    end
    worker.prepared = true
    return nothing
end
function prepared(worker::FeasibilityCutsWorker)
    return worker.prepared
end

function add_auxiliary_variables!(model::MOI.ModelLike,
                                  worker::FeasibilityCutsWorker,
                                  ci::CI{F,S},
                                  idx::Integer) where {F <: MOI.AbstractFunction, S <: MOI.AbstractSet}
    # Nothing to do for most most constraints
    return idx
end

function add_auxiliary_variables!(model::MOI.ModelLike,
                                  worker::FeasibilityCutsWorker,
                                  ci::CI{F,S},
                                  idx::Integer) where {F <: AffineDecisionFunction, S <: MOI.AbstractScalarSet}
    G = MOI.ScalarAffineFunction{Float64}
    obj_sense = MOI.get(model, MOI.ObjectiveSense())
    # Positive feasibility variable
    pos_aux_var = MOI.add_variable(model)
    name = add_subscript(:v⁺, idx)
    MOI.set(model, MOI.VariableName(), pos_aux_var, name)
    worker.feasibility_variables[idx] = pos_aux_var
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
    worker.feasibility_variables[idx] = neg_aux_var
    # Nonnegativity constraint
    MOI.add_constraint(model, MOI.SingleVariable(neg_aux_var),
                       MOI.GreaterThan{Float64}(0.0))
    # Add to objective
    MOI.modify(model, MOI.ObjectiveFunction{G}(),
               MOI.ScalarCoefficientChange(neg_aux_var, obj_sense == MOI.MAX_SENSE ? -1.0 : 1.0))
    # Add to constraint
    MOI.modify(model, ci, MOI.ScalarCoefficientChange(neg_aux_var, -1.0))
    # Return updated identification index
    return idx + 1
end

function add_auxiliary_variables!(model::MOI.ModelLike,
                                  worker::FeasibilityCutsWorker,
                                  ci::CI{F,S},
                                  idx::Integer) where {F <: VectorAffineDecisionFunction, S <: MOI.AbstractVectorSet}
    G = MOI.ScalarAffineFunction{Float64}
    obj_sense = MOI.get(model, MOI.ObjectiveSense())
    n = MOI.dimension(MOI.get(model, MOI.ConstraintSet(), ci))
    for (i, id) in enumerate(idx:(idx + n - 1))
        # Positive feasibility variable
        pos_aux_var = MOI.add_variable(model)
        name = add_subscript(:v⁺, id)
        MOI.set(model, MOI.VariableName(), pos_aux_var, name)
        worker.feasibility_variables[id] = pos_aux_var
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
        worker.feasibility_variables[id] = neg_aux_var
        # Nonnegativity constraint
        MOI.add_constraint(model, MOI.SingleVariable(neg_aux_var),
                           MOI.GreaterThan{Float64}(0.0))
        # Add to objective
        MOI.modify(model, MOI.ObjectiveFunction{G}(),
                   MOI.ScalarCoefficientChange(neg_aux_var, obj_sense == MOI.MAX_SENSE ? -1.0 : 1.0))
        # Add to constraint
        MOI.modify(model, ci, MOI.MultirowChange(neg_aux_var, [(i, -1.0)]))
    end
    # Return updated identification index
    return idx + n + 1
end

function restore!(model::MOI.ModelLike, worker::FeasibilityCutsWorker)
    # Delete any feasibility variables
    if prepared(worker)
        MOI.delete(model, worker.feasibility_variables)
    end
    # Restore objective
    F = typeof(worker.objective)
    MOI.set(model, MOI.ObjectiveFunction{F}(), worker.objective)
    # Switch status flag
    worker.prepared = false
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

function worker(::IgnoreFeasibility, ::Vector{MOI.ConstraintIndex}, ::MOI.ModelLike)
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

function worker(::FeasibilityCuts, linking_constraints::Vector{MOI.ConstraintIndex}, model::MOI.ModelLike)
    # Cache objective
    func_type = MOI.get(model, MOI.ObjectiveFunctionType())
    obj = MOI.get(model, MOI.ObjectiveFunction{func_type}())
    num_constraints = mapreduce(+, linking_constraints) do ci
        return MOI.dimension(MOI.get(model, MOI.ConstraintSet(), ci))
    end
    return FeasibilityCutsWorker(obj, linking_constraints, Vector{MOI.VariableIndex}(undef, num_constraints))
end
function worker_type(::FeasibilityCuts)
    return FeasibilityCutsWorker
end
