"""
    SynchronousExecution

Functor object for using synchronous execution in a progressive-hedging algorithm (assuming multiple Julia cores are available). Create by supplying a [`Synchronous`](@ref) object through `execution` in the `ProgressiveHedgingSolver` factory function and then pass to a `StochasticPrograms.jl` model.

"""
struct SynchronousExecution{T <: AbstractFloat,
                            A <: AbstractVector,
                            S <: MOI.AbstractOptimizer,
                            PT <: AbstractPenaltyterm} <: AbstractProgressiveHedgingExecution
    subworkers::Vector{SubWorker{T,A,S,PT}}

    function SynchronousExecution(::Type{T}, ::Type{A},
                                  ::Type{S}, ::Type{PT}) where {T <: AbstractFloat,
                                                                A <: AbstractVector,
                                                                S <: MOI.AbstractOptimizer,
                                                                PT <: AbstractPenaltyterm}
        return new{T,A,S,PT}(Vector{SubWorker{T,A,S,PT}}(undef, nworkers()))
    end
end

function initialize_subproblems!(ph::AbstractProgressiveHedging,
                                 execution::SynchronousExecution,
                                 scenarioproblems::DistributedScenarioProblems,
                                 penaltyterm::AbstractPenaltyterm)
    # Create subproblems on worker processes
    initialize_subproblems!(ph,
                            execution.subworkers,
                            scenarioproblems,
                            penaltyterm)
    # Initial reductions
    update_iterate!(ph)
    update_dual_gap!(ph)
    return nothing
end

function restore_subproblems!(::AbstractProgressiveHedging, execution::SynchronousExecution)
    restore_subproblems!(execution.subworkers)
    return nothing
end

function resolve_subproblems!(ph::AbstractProgressiveHedging, execution::SynchronousExecution{T}) where T <: AbstractFloat
    partial_solutions = Vector{SubproblemSolution{T}}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_solutions[i] = remotecall_fetch(resolve_subproblems!,
                                                           w,
                                                           execution.subworkers[w-1],
                                                           ph.ξ,
                                                           penalty(ph))
        end
    end
    return sum(partial_solutions)
end

function update_iterate!(ph::AbstractProgressiveHedging, execution::SynchronousExecution{T,A}) where {T <: AbstractFloat, A <: AbstractVector}
    partial_primals = Vector{A}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_primals[i] = remotecall_fetch(collect_primals,
                                                         w,
                                                         execution.subworkers[w-1],
                                                         length(ph.ξ))
        end
    end
    ξ_prev = copy(ph.ξ)
    ph.ξ .= sum(partial_primals)
    # Update δ₁
    ph.data.δ₁ = norm(ph.ξ - ξ_prev, 2) ^ 2
    return nothing
end

function update_subproblems!(ph::AbstractProgressiveHedging, execution::SynchronousExecution)
    # Update dual prices
    @sync begin
        for w in workers()
            @async remotecall_fetch(
                w,
                execution.subworkers[w-1],
                ph.ξ,
                penalty(ph)) do sw, ξ, r
                    subproblems = fetch(sw)
                    if length(subproblems) > 0
                        update_subproblems!(subproblems, ξ, r)
                    end
                end
        end
    end
    return nothing
end

function update_dual_gap!(ph::AbstractProgressiveHedging, execution::SynchronousExecution)
    return update_dual_gap!(ph, execution.subworkers)
end

function calculate_objective_value(ph::AbstractProgressiveHedging, execution::SynchronousExecution)
    return calculate_objective_value(execution.subworkers)
end

# API
# ------------------------------------------------------------
function (execution::Synchronous)(::Type{T}, ::Type{A},
                                  ::Type{S}, ::Type{PT}) where {T <: AbstractFloat,
                                                                A <: AbstractVector,
                                                                S <: MOI.AbstractOptimizer,
                                                                PT <: AbstractPenaltyterm}
    return SynchronousExecution(T,A,S,PT)
end

function str(::Synchronous)
    return "Synchronous "
end
