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

struct SubProblem{T <: AbstractFloat, F <: AbstractFeasibilityAlgorithm, I <: AbstractIntegerAlgorithm}
    id::Int
    probability::T
    model::JuMP.Model
    optimizer::MOI.AbstractOptimizer
    feasibility_algorithm::F
    integer_algorithm::I
    linking_constraints::Vector{MOI.ConstraintIndex}
    masterterms::Vector{Vector{Tuple{Int, Int, T}}}

    function SubProblem(model::JuMP.Model,
                        id::Integer,
                        π::AbstractFloat,
                        feasibility_strategy::AbstractFeasibilityStrategy,
                        integer_strategy::AbstractIntegerStrategy)
        T = typeof(π)
        # Get optimizer backend
        optimizer = backend(model)
        # Instantiate feasibility algorithm
        feasibility_algorithm = worker(feasibility_strategy, optimizer)
        F = typeof(feasibility_algorithm)
        # Instantiate integer algorithm
        integer_algorithm = worker(integer_strategy, T)
        I = typeof(integer_algorithm)
        # Collect all constraints with known decision occurances
        constraints, terms =
            collect_linking_constraints(model,
                                        T)
        subproblem =  new{T,F,I}(id,
                                 π,
                                 model,
                                 optimizer,
                                 feasibility_algorithm,
                                 integer_algorithm,
                                 constraints,
                                 terms)
        # Initialize integer algorithm
        initialize_integer_algorithm!(subproblem)
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
                        push!(coeffs, (row, col, T(coef)))
                    end
                end
            end
            if !isempty(coeffs)
                push!(masterterms, coeffs)
                push!(linking_constraints, ci)
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
    restore!(subproblem.optimizer, subproblem.integer_algorithm)
    restore!(subproblem.optimizer, subproblem.feasibility_algorithm)
    return nothing
end

function (subproblem::SubProblem)(x::AbstractVector, metadata)
    return solve_subproblem(subproblem,
                            metadata,
                            subproblem.feasibility_algorithm,
                            subproblem.integer_algorithm,
                            x)
end

function solve_subproblem(subproblem::SubProblem, x::AbstractVector)
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

# Cuts #
# ========================== #
function OptimalityCut(subproblem::SubProblem{T}, x::AbstractVector) where T <: AbstractFloat
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

function FeasibilityCut(subproblem::SubProblem{T}, x::AbstractVector) where T <: AbstractFloat
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

function Infeasible(subproblem::SubProblem)
    # Get sense
    sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    return Infeasible(correction * Inf, subproblem.id)
end

function Unbounded(subproblem::SubProblem)
    # Get sense
    sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    return Unbounded(correction * -Inf, subproblem.id)
end
