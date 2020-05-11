"""
    SerialExecution

Functor object for using serial execution in a progressive-hedging algorithm. Create by supplying a [`Serial`](@ref) object through `execution` in the `ProgressiveHedgingSolver` factory function and then pass to a `StochasticPrograms.jl` model.

"""
struct SerialExecution{T <: AbstractFloat,
                       A <: AbstractVector,
                       S <: MOI.AbstractOptimizer,
                       PT <: PenaltyTerm} <: AbstractExecution
    subproblems::Vector{SubProblem{T,A,S,PT}}

    function SerialExecution(::Type{T}, ::Type{A}, ::Type{S}, ::Type{PT}) where {T <: AbstractFloat, A <: AbstractVector, S <: MOI.AbstractOptimizer, PT <: PenaltyTerm}
        return new{T,A,S,PT}(Vector{SubProblem{T,A,S,PT}}())
    end
end

function initialize_subproblems!(execution::SerialExecution{T},
                                 scenarioproblems::ScenarioProblems,
                                 penaltyterm::PenaltyTerm) where T <: AbstractFloat
    for i = 1:num_subproblems(scenarioproblems)
        push!(execution.subproblems, SubProblem(
            subproblem(scenarioproblems, i),
            i,
            T(probability(scenarioproblems, i)),
            copy(penaltyterm)))
    end
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
    ph.ξ .= mapreduce(+, execution.subproblems) do subproblem
        π = subproblem.probability
        x = subproblem.x
        π * x
    end
    # Update δ₁
    ph.data.δ₁ = norm(ph.ξ - ξ_prev, 2)^2
    return nothing
end

function update_subproblems!(ph::AbstractProgressiveHedging, execution::SerialExecution)
    # Update dual prices
    update_subproblems!(execution.subproblems, ph.ξ, penalty(ph))
    return nothing
end

function update_dual_gap!(ph::AbstractProgressiveHedging, execution::SerialExecution)
    # Update δ₂
    ph.data.δ₂ = mapreduce(+, execution.subproblems) do subproblem
        π = subproblem.probability
        x = subproblem.x
        π * norm(x - ph.ξ, 2)^2
    end
    return nothing
end

function calculate_objective_value(ph::AbstractProgressiveHedging, execution::SerialExecution)
    return mapreduce(+, execution.subproblems) do subproblem
        _objective_value(subproblem)
    end
end

# API
# ------------------------------------------------------------
function (execution::Serial)(::Type{T}, ::Type{A}, ::Type{S}, ::Type{PT}) where {T <: AbstractFloat, A <: AbstractVector, S <: MOI.AbstractOptimizer, PT <: PenaltyTerm}
    return SerialExecution(T,A,S,PT)
end

function str(::Serial)
    return ""
end
