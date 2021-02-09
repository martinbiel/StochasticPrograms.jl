struct SubProblem{H <: AbstractFeasibilityHandler, T <: AbstractFloat}
    id::Int
    probability::T
    optimizer::MOI.AbstractOptimizer
    feasibility_handler::H
    linking_constraints::Vector{MOI.ConstraintIndex}
    masterterms::Vector{Vector{Tuple{Int, Int, T}}}

    function SubProblem(model::JuMP.Model,
                        id::Integer,
                        π::AbstractFloat,
                        master_indices::Vector{MOI.VariableIndex},
                        ::Type{H}) where H <: AbstractFeasibilityHandler
        T = typeof(π)
        # Get optimizer backend
        optimizer = backend(model)
        # Instantiate feasibility handler if requested
        feasibility_handler = H(optimizer)
        # Collect all constraints with known decision occurances
        constraints, terms =
            collect_linking_constraints(model,
                                        master_indices,
                                        T)
        return new{H,T}(id,
                        π,
                        optimizer,
                        feasibility_handler,
                        constraints,
                        terms)
    end
end

# Feasibility handlers #
# ========================== #
struct FeasibilityIgnorer <: AbstractFeasibilityHandler end
FeasibilityIgnorer(::MOI.ModelLike) = FeasibilityIgnorer()

restore!(::MOI.ModelLike, ::FeasibilityIgnorer) = nothing


mutable struct FeasibilityHandler <: AbstractFeasibilityHandler
    objective::MOI.AbstractScalarFunction
    feasibility_variables::Vector{MOI.VariableIndex}
end

HandlerType(::Type{IgnoreFeasibility}) = FeasibilityIgnorer
HandlerType(::Type{<:HandleFeasibility}) = FeasibilityHandler

function FeasibilityHandler(model::MOI.ModelLike)
    # Cache objective
    func_type = MOI.get(model, MOI.ObjectiveFunctionType())
    obj = MOI.get(model, MOI.ObjectiveFunction{func_type}())
    return FeasibilityHandler(obj, Vector{MOI.VariableIndex}())
end

prepared(handler::FeasibilityHandler) = length(handler.feasibility_variables) > 0

function prepare!(model::MOI.ModelLike, handler::FeasibilityHandler)
    # Set objective to zero
    G = MOI.ScalarAffineFunction{Float64}
    MOI.set(model, MOI.ObjectiveFunction{G}(), zero(MOI.ScalarAffineFunction{Float64}))
    i = 1
    # Create auxiliary feasibility variables
    for (F, S) in MOI.get(model, MOI.ListOfConstraints())
        i = add_auxilliary_variables!(model, handler, F, S, i)
    end
    return nothing
end

function add_auxilliary_variables!(model::MOI.ModelLike,
                                   handler::FeasibilityHandler,
                                   F::Type{<:MOI.AbstractFunction},
                                   S::Type{<:MOI.AbstractSet},
                                   idx::Integer)
    # Nothing to do for most most constraints
    return idx
end

function add_auxilliary_variables!(model::MOI.ModelLike,
                                   handler::FeasibilityHandler,
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
        push!(handler.feasibility_variables, pos_aux_var)
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
        push!(handler.feasibility_variables, neg_aux_var)
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

function add_auxilliary_variables!(model::MOI.ModelLike,
                                   handler::FeasibilityHandler,
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
            push!(handler.feasibility_variables, pos_aux_var)
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
            push!(handler.feasibility_variables, neg_aux_var)
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

function restore!(model::MOI.ModelLike, handler::FeasibilityHandler)
    # Delete any feasibility variables
    if !isempty(handler.feasibility_variables)
        MOI.delete(model, handler.feasibility_variables)
    end
    empty!(handler.feasibility_variables)
    # Restore objective
    F = typeof(handler.objective)
    MOI.set(model, MOI.ObjectiveFunction{F}(), handler.objective)
    return nothing
end

# Subproblem methods #
# ========================== #
function collect_linking_constraints(model::JuMP.Model,
                                     master_indices::Vector{MOI.VariableIndex},
                                     ::Type{T}) where T <: AbstractFloat
    linking_constraints = Vector{MOI.ConstraintIndex}()
    masterterms = Vector{Vector{Tuple{Int, Int, T}}}()
    # Parse single rows
    F = DecisionAffExpr{Float64}
    for S in [MOI.EqualTo{Float64}, MOI.LessThan{Float64}, MOI.GreaterThan{Float64}]
        for cref in all_constraints(model, F, S)
            coeffs = Vector{Tuple{Int, Int, T}}()
            aff = JuMP.jump_function(model, MOI.get(model, MOI.ConstraintFunction(), cref))::DecisionAffExpr
            for (coef, kvar) in linear_terms(aff.decisions)
                # Map known decisions to master decision,
                # assuming sorted order
                if state(kvar) == Known
                    col = master_indices[index(kvar).value].value
                    push!(coeffs, (1, col, T(coef)))
                end
            end
            if !isempty(coeffs)
                push!(masterterms, coeffs)
                push!(linking_constraints, cref.index)
            end
        end
    end
    # Parse vector rows
    F = Vector{DecisionAffExpr{Float64}}
    for S in [MOI.Zeros, MOI.Nonpositives, MOI.Nonnegatives]
        for cref in all_constraints(model, F, S)
            coeffs = Vector{Tuple{Int, Int, T}}()
            affs = JuMP.jump_function(model, MOI.get(model, MOI.ConstraintFunction(), cref))::Vector{DecisionAffExpr{T}}
            for (row, aff) in enumerate(affs)
                for (coef, kvar) in linear_terms(aff.decisions)
                    # Map known decisions to master decision,
                    # assuming sorted order
                    if state(kvar) == Known
                        col = master_indices[index(kvar).value].value
                        push!(coeffs, (row, col, T(coef)))
                    end
                end
            end
            if !isempty(coeffs)
                push!(masterterms, coeffs)
                push!(linking_constraints, cref.index)
            end
        end
    end
    return linking_constraints, masterterms
end

function update_subproblem!(subproblem::SubProblem)
    update_known_decisions!(subproblem.optimizer)
    return nothing
end

function restore_subproblem!(subproblem::SubProblem)
    restore!(subproblem.optimizer, subproblem.feasibility_handler)
end

function solve(subproblem::SubProblem, x::AbstractVector)
    MOI.optimize!(subproblem.optimizer)
    status = MOI.get(subproblem.optimizer, MOI.TerminationStatus())
    if status ∈ AcceptableTermination
        return OptimalityCut(subproblem, x)
    elseif status == MOI.INFEASIBLE
        return Infeasible(subproblem)
    elseif status == MOI.DUAL_INFEASIBLE
        return Unbounded(subproblem)
    else
        error("Subproblem $(subproblem.id) was not solved properly, returned status code: $status")
    end
end

function (subproblem::SubProblem{FeasibilityHandler})(x::AbstractVector)
    model = subproblem.optimizer
    if !prepared(subproblem.feasibility_handler)
        prepare!(model, subproblem.feasibility_handler)
    end
    # Optimize auxiliary problem
    MOI.optimize!(model)
    # Sanity check that aux problem could be solved
    status = MOI.get(subproblem.optimizer, MOI.TerminationStatus())
    if !(status ∈ AcceptableTermination)
        error("Subproblem $(subproblem.id) was not solved properly during feasibility check, returned status code: $status")
    end
    obj_sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
    w = MOI.get(model, MOI.ObjectiveValue())
    w *= obj_sense == MOI.MAX_SENSE ? -1.0 : 1.0
    if w > sqrt(eps())
        # Subproblem is infeasible, create feasibility cut
        return FeasibilityCut(subproblem, x)
    end
    # Restore subproblem
    restore_subproblem!(subproblem)
    return solve(subproblem, x)
end
function (subproblem::SubProblem{FeasibilityIgnorer})(x::AbstractVector)
    return solve(subproblem, x)
end

# Cuts #
# ========================== #
function OptimalityCut(subproblem::SubProblem{H, T}, x::AbstractVector) where {H, T}
    π = subproblem.probability
    nterms = if isempty(subproblem.masterterms)
        nterms = 0
    else
        nterms = mapreduce(+, subproblem.masterterms) do terms
            length(terms)
        end
    end
    cols = zeros(Int, nterms)
    vals = zeros(T, nterms)
    j = 1
    for (i, ci) in enumerate(subproblem.linking_constraints)
        λ = MOI.get(subproblem.optimizer, MOI.ConstraintDual(), ci)
        for (row, col, coeff) in subproblem.masterterms[i]
            cols[j] = col
            vals[j] = π * λ[row] * coeff
            j += 1
        end
    end
    # Get sense
    sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    # Create sense-corrected optimality cut
    δQ = sparsevec(cols, vals, length(x))
    q = correction * π * MOI.get(subproblem.optimizer, MOI.ObjectiveValue()) + δQ⋅x
    return OptimalityCut(δQ, q, subproblem.id)
end

function FeasibilityCut(subproblem::SubProblem{H, T}, x::AbstractVector) where {H, T}
    nterms = mapreduce(+, subproblem.masterterms) do terms
        length(terms)
    end
    cols = zeros(Int, nterms)
    vals = zeros(T, nterms)
    j = 1
    for (i, ci) in enumerate(subproblem.linking_constraints)
        λ = MOI.get(subproblem.optimizer, MOI.ConstraintDual(), ci)
        for (row, col, coeff) in subproblem.masterterms[i]
            cols[j] = col
            vals[j] = λ[row] * coeff
            j += 1
        end
    end
    # Get sense
    sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    # Create sense-corrected optimality cut
    G = sparsevec(cols, vals, length(x))
    g = correction * MOI.get(subproblem.optimizer, MOI.ObjectiveValue()) + G⋅x
    return FeasibilityCut(G, g, subproblem.id)
end

Infeasible(subprob::SubProblem) = Infeasible(subprob.id)
Unbounded(subprob::SubProblem) = Unbounded(subprob.id)
