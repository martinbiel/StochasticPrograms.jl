"""
    SerialExecution

Functor object for using serial execution in a progressive-hedging algorithm. Create by supplying a [`Serial`](@ref) object through `execution` in the `ProgressiveHedgingSolver` factory function and then pass to a `StochasticPrograms.jl` model.

"""
struct SerialExecution{T <: AbstractFloat,
                       A <: AbstractVector,
                       PT <: AbstractPenaltyterm} <: AbstractProgressiveHedgingExecution
    subproblems::Vector{SubProblem{T,A,PT}}

    function SerialExecution(::Type{T}, ::Type{A}, ::Type{PT}) where {T <: AbstractFloat, A <: AbstractVector, PT <: AbstractPenaltyterm}
        return new{T,A,PT}(Vector{SubProblem{T,A,PT}}())
    end
end

function initialize_subproblems!(ph::AbstractProgressiveHedging,
                                 execution::SerialExecution{T},
                                 scenarioproblems::ScenarioProblems,
                                 penaltyterm::AbstractPenaltyterm) where T <: AbstractFloat
    # Create subproblems
    for i = 1:num_subproblems(scenarioproblems)
        push!(execution.subproblems, SubProblem(
            subproblem(scenarioproblems, i),
            i,
            T(probability(scenarioproblems, i)),
            copy(penaltyterm)))
    end
    # Initial reductions
    update_iterate!(ph)
    update_dual_gap!(ph)
    return nothing
end

function finish_initilization!(execution::SerialExecution, penalty::AbstractFloat)
    for subproblem in execution.subproblems
        initialize!(subproblem, penalty)
    end
    return nothing
end

function restore_subproblems!(ph::AbstractProgressiveHedging, execution::SerialExecution)
    for subproblem in execution.subproblems
        restore_subproblem!(subproblem)
    end
    return nothing
end

function resolve_subproblems!(ph::AbstractProgressiveHedging, execution::SerialExecution)
    Qs = Vector{SubproblemSolution}(undef, length(execution.subproblems))
    # Reformulate and solve sub problems
    for (i, subproblem) in enumerate(execution.subproblems)
        reformulate_subproblem!(subproblem, ph.ξ, penalty(ph))
        Qs[i] = subproblem(ph.ξ)
    end
    # Return current objective value
    return sum(Qs)
end

function update_iterate!(ph::AbstractProgressiveHedging, execution::SerialExecution)
    # Update the estimate
    ξ_prev = copy(ph.ξ)
    ph.ξ .= mapreduce(+, execution.subproblems, init = zero(ph.ξ)) do subproblem
        π = subproblem.probability
        x = subproblem.x
        π * x
    end
    # Update δ₁
    ph.data.δ₁ = norm(ph.ξ - ξ_prev, 2) ^ 2
    return nothing
end

function update_subproblems!(ph::AbstractProgressiveHedging, execution::SerialExecution)
    # Update dual prices
    update_subproblems!(execution.subproblems, ph.ξ, penalty(ph))
    return nothing
end

function update_dual_gap!(ph::AbstractProgressiveHedging, execution::SerialExecution{T}) where T <: AbstractFloat
    # Update δ₂
    ph.data.δ₂ = mapreduce(+, execution.subproblems, init = zero(T)) do subproblem
        π = subproblem.probability
        x = subproblem.x
        π * norm(x - ph.ξ, 2) ^ 2
    end
    return nothing
end

function calculate_objective_value(ph::AbstractProgressiveHedging, execution::SerialExecution{T}) where T <: AbstractFloat
    return mapreduce(+, execution.subproblems, init = zero(T)) do subproblem
        _objective_value(subproblem)
    end
end

# API
# ------------------------------------------------------------
function (execution::Serial)(::Type{T}, ::Type{A}, ::Type{PT}) where {T <: AbstractFloat, A <: AbstractVector, PT <: AbstractPenaltyterm}
    return SerialExecution(T, A, PT)
end

function str(::Serial)
    return ""
end
