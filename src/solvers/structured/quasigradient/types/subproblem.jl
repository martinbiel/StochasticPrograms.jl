struct Subgradient{T <: AbstractFloat, A <: AbstractVector}
    δQ::A
    Q::T
    id::Int

    function Subgradient(δQ::AbstractVector, Q::AbstractFloat, id::Int)
        T = promote_type(eltype(δQ), Float32)
        δQ_ = convert(AbstractVector{T}, δQ)
        new{T, typeof(δQ_)}(δQ_, Q, id)
    end
end
SparseSubgradient{T <: AbstractFloat} = Subgradient{T, SparseVector{T,Int64}}
QGradient{T} = Tuple{Int,SparseSubgradient{T}}
GradientQueue{T} = RemoteChannel{Channel{QGradient{T}}}

struct SubProblem{T <: AbstractFloat}
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

# Subproblem methods #
# ========================== #
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

function update_subproblem!(subproblem::SubProblem)
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

# Cuts #
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
    return Subgradient(δQ, Q, subproblem.id)
end

function Infeasible(subproblem::SubProblem)
    # Get sense
    sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    return Subgradient(sparsevec(Float64[]), correction * Inf, subproblem.id)
end

function Unbounded(subproblem::SubProblem)
    # Get sense
    sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    return Subgradient(sparsevec(Float64[]), correction * -Inf, subproblem.id)
end
