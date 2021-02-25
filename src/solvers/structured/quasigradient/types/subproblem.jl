abstract type AbstractSubProblem{T <: AbstractFloat} end
abstract type AbstractSubProblemState end

struct Gradient{T <: AbstractFloat, A <: AbstractVector}
    δQ::A
    Q::T
    id::Int

    function Gradient(δQ::AbstractVector, Q::AbstractFloat, id::Int)
        T = promote_type(eltype(δQ), Float32)
        δQ_ = convert(AbstractVector{T}, δQ)
        new{T, typeof(δQ_)}(δQ_, Q, id)
    end
end
SparseGradient{T <: AbstractFloat} = Gradient{T, SparseVector{T,Int64}}
DenseGradient{T <: AbstractFloat} = Gradient{T, Vector{T}}

struct SubProblem{T <: AbstractFloat} <: AbstractSubProblem{T}
    id::Int
    probability::T
    model::JuMP.Model
    optimizer::MOI.AbstractOptimizer
    linking_constraints::Vector{MOI.ConstraintIndex}
    masterterms::Vector{Vector{Tuple{Int, Int, T}}}

    function SubProblem(model::JuMP.Model,
                        id::Integer,
                        π::AbstractFloat)
        T = typeof(π)
        # Get optimizer backend
        optimizer = backend(model)
        # Collect all constraints with known decision occurances
        constraints, terms =
            collect_linking_constraints(model,
                                        T)
        subproblem =  new{T}(id,
                             π,
                             model,
                             optimizer,
                             constraints,
                             terms)
        return subproblem
    end
end

function collect_linking_constraints(model::JuMP.Model,
                                     ::Type{T}) where T <: AbstractFloat
    linking_constraints = Vector{MOI.ConstraintIndex}()
    masterterms = Vector{Vector{Tuple{Int, Int, T}}}()
    master_indices = index.(all_known_decision_variables(model, 1))
    # Parse single rows
    F = AffineDecisionFunction{T}
    for S in [MOI.EqualTo{Float64}, MOI.LessThan{Float64}, MOI.GreaterThan{Float64}]
        for ci in MOI.get(backend(model), MOI.ListOfConstraintIndices{F,S}())
            coeffs = Vector{Tuple{Int, Int, T}}()
            f = MOI.get(backend(model), MOI.ConstraintFunction(), ci)::AffineDecisionFunction{T}
            aff = JuMP.jump_function(model, f)::DecisionAffExpr{T}
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
                push!(linking_constraints, ci)
            end
        end
    end
    # Parse vector rows
    F = VectorAffineDecisionFunction{T}
    for S in [MOI.Zeros, MOI.Nonpositives, MOI.Nonnegatives]
        for ci in MOI.get(backend(model), MOI.ListOfConstraintIndices{F,S}())
            coeffs = Vector{Tuple{Int, Int, T}}()
            f = MOI.get(backend(model), MOI.ConstraintFunction(), ci)::VectorAffineDecisionFunction{T}
            affs = JuMP.jump_function(model, f)::Vector{DecisionAffExpr{T}}
            for (row, aff) in enumerate(affs)
                for (coef, kvar) in linear_terms(aff.decisions)
                    # Map known decisions to master decision,
                    # assuming sorted order
                    if state(kvar) == Known
                        col = master_indices[index(kvar).value].value
                        push!(coeffs, (1, col, T(coef)))
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

function update_subproblem!(subproblem::AbstractSubProblem)
    update_known_decisions!(subproblem.optimizer)
    return nothing
end

function (subproblem::SubProblem)(x::AbstractVector)
    return solve_subproblem(subproblem, x)
end

function solve_subproblem(subproblem::SubProblem, x::AbstractVector)
    MOI.optimize!(subproblem.optimizer)
    status = MOI.get(subproblem.optimizer, MOI.TerminationStatus())
    if status ∈ AcceptableTermination
        return Subgradient(subproblem, x)
    elseif status == MOI.INFEASIBLE
        return Infeasible(subproblem)
    elseif status == MOI.DUAL_INFEASIBLE
        return Unbounded(subproblem)
    else
        error("Subproblem $(subproblem.id) was not solved properly, returned status code: $status")
    end
end

# Smooth #
# ========================== #
@with_kw mutable struct SmoothingData{T <: AbstractFloat}
    objective::AffineDecisionFunction{T} = zero(AffineDecisionFunction{T})
end

@with_kw mutable struct SmoothingParameters{T <: AbstractFloat}
    μ::T = 1.0
    objective_correction::Bool = false
end

"""
    SmoothSubProblem

Subproblem smoothed using a Moreau envelope.

...
# Parameters
- `μ::AbstractFloat = 1.0`: Moreau smoothing parameter. Controls the smoothing approximation accuracy.
...
"""
struct SmoothSubProblem{T <: AbstractFloat} <: AbstractSubProblem{T}
    data::SmoothingData{T}
    parameters::SmoothingParameters{T}

    id::Int
    probability::T
    model::JuMP.Model
    optimizer::MOI.AbstractOptimizer

    projection_targets::Vector{MOI.VariableIndex}
    penaltyterm::Quadratic

    function SmoothSubProblem(model::JuMP.Model,
                              id::Integer,
                              π::AbstractFloat,
                              ξ::AbstractVector;
                              kw...)
        T = typeof(π)
        # Get optimizer backend
        optimizer = backend(model)
        # Initialize data and params
        data = SmoothingData{T}()
        params = SmoothingParameters{T}(; kw...)
        @unpack μ = params
        # Cache objective
        F = MOI.get(backend(model), MOI.ObjectiveFunctionType())
        data.objective = MOI.get(backend(model), MOI.ObjectiveFunction{F}())
        # Create and return smoothed subproblem
        subproblem = new{T}(data,
                            params,
                            id,
                            π,
                            model,
                            optimizer,
                            Vector{MOI.VariableIndex}(),
                            Quadratic())
        # Setup Moreau envelope
        add_projection_targets!(subproblem, ξ)
        return subproblem
    end
end

function (subproblem::SmoothSubProblem)(x::AbstractVector)
    return solve_subproblem(subproblem, x)
end

function solve_subproblem(subproblem::SmoothSubProblem, x::AbstractVector)
    MOI.optimize!(subproblem.optimizer)
    status = MOI.get(subproblem.optimizer, MOI.TerminationStatus())
    if status ∈ AcceptableTermination
        return Gradient(subproblem, x)
    elseif status == MOI.INFEASIBLE
        return Infeasible(subproblem)
    elseif status == MOI.DUAL_INFEASIBLE
        return Unbounded(subproblem)
    else
        error("Subproblem $(subproblem.id) was not solved properly, returned status code: $status")
    end
end

function add_projection_targets!(subproblem::SmoothSubProblem{T}, ξ::AbstractVector) where T <: AbstractFloat
    @unpack μ = subproblem.parameters
    n = num_decisions(subproblem.model, 1)
    resize!(subproblem.projection_targets, n)
    for i in eachindex(ξ)
        name = add_subscript(:ξ, i)
        set = SingleDecisionSet(1, KnownDecision(ξ[i], T), NoSpecifiedConstraint(), false)
        empty = ScalarVariable(VariableInfo(false, NaN, false, NaN, false, NaN, false, NaN, false, false))
        dref = add_variable(subproblem.model, VariableConstrainedOnCreation(empty, set), name)
        subproblem.projection_targets[i] = index(dref)
    end
    # Initialize quadratic penalty
    x = index.(all_decision_variables(subproblem.model, 1))
    initialize_penaltyterm!(subproblem.penaltyterm,
                            subproblem.optimizer,
                            1 / (2 * μ),
                            x,
                            subproblem.projection_targets)
    return nothing
end

function restore_subproblem!(subproblem::SmoothSubProblem)
    MOI.optimize!(subproblem.optimizer)
    # Delete penalty-term
    remove_penalty!(subproblem.penaltyterm, subproblem.optimizer)
    # Delete projection targets
    for var in subproblem.projection_targets
        MOI.delete(subproblem.optimizer, var)
    end
    empty!(subproblem.projection_targets)
    return nothing
end

# Gradient #
# ========================== #
function Subgradient(subproblem::SubProblem{T}, x::AbstractVector) where T <: AbstractFloat
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
    # Create sense-corrected subgradient
    δQ = sparsevec(cols, vals, length(x))
    Q = correction * π * MOI.get(subproblem.optimizer, MOI.ObjectiveValue())
    return Gradient(δQ, Q, subproblem.id)
end

function Gradient(subproblem::SmoothSubProblem{T}, x::AbstractVector) where T <: AbstractFloat
    @unpack μ, objective_correction = subproblem.parameters
    π = subproblem.probability
    # Get sense
    sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    # Get solution
    u = value.(all_decision_variables(subproblem.model, 1))
    # Sense corrected gradient
    δQ = π * (1/μ) * (x - u)
    # Sense corrected objective
    decisions = index.(all_decision_variables(subproblem.model, 1))
    if objective_correction
        fix.(all_decision_variables(subproblem.model, 1), x)
        StochasticPrograms.disable_penalty!(subproblem.penaltyterm,
                         subproblem.optimizer,
                         decisions,
                         subproblem.projection_targets)
        MOI.optimize!(subproblem.optimizer)
        status = MOI.get(subproblem.optimizer, MOI.TerminationStatus())
        if !(status ∈ AcceptableTermination)
            if status == MOI.INFEASIBLE
                return Infeasible(subproblem)
            elseif status == MOI.DUAL_INFEASIBLE
                return Unbounded(subproblem)
            end
        end
    end
    Q = correction * π * MOIU.eval_variables(subproblem.data.objective) do vi
        MOI.get(subproblem.optimizer, MOI.VariablePrimal(), vi)
    end
    if objective_correction
        unfix.(all_decision_variables(subproblem.model, 1))
        StochasticPrograms.enable_penalty!(subproblem.penaltyterm,
                                           subproblem.optimizer,
                                           1 / (2 * μ),
                                           decisions,
                                           subproblem.projection_targets)
    end
    return Gradient(δQ, Q, subproblem.id)
end

function Infeasible(subproblem::AbstractSubProblem)
    # Get sense
    sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    return Gradient(sparsevec(Float64[]), correction * Inf, subproblem.id)
end

function Unbounded(subproblem::AbstractSubProblem)
    # Get sense
    sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    return Gradient(sparsevec(Float64[]), correction * -Inf, subproblem.id)
end

# API
# ------------------------------------------------------------
"""
    Unaltered

Factory object for using regular [`SubProblem`](@ref) in the quasi-gradient algorithm. Passed by default to `subproblems` to `QuasiGradient.Optimizer`.

"""
struct Unaltered <: AbstractSubProblemState end
"""
    Smoothed

Factory object for using [`SmoothSubProblem`](@ref) through Moreau envelopes in the quasi-gradient algorithm. Pass to `subproblems ` in `QuasiGradient.Optimizer` or by setting the [`SubProblems`](@ref) attribute. See [`SmoothSubProblem`](@ref) for parameter descriptions.

"""
struct Smoothed <: AbstractSubProblemState
    parameters::SmoothingParameters{Float64}
end
Smoothed(; kw...) = Smoothed(SmoothingParameters(; kw...))
