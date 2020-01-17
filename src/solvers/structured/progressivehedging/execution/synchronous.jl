"""
    SynchronousExecution

Functor object for using synchronous execution in a progressive-hedging algorithm (assuming multiple Julia cores are available). Create by supplying a [`Synchronous`](@ref) object through `execution` in the `ProgressiveHedgingSolver` factory function and then pass to a `StochasticPrograms.jl` model.

"""
struct SynchronousExecution{T <: AbstractFloat,
                            A <: AbstractVector,
                            S <: LQSolver} <: AbstractExecution
    subworkers::Vector{SubWorker{T,A,S}}

    function SynchronousExecution(::Type{T}, ::Type{A}, ::Type{S}) where {T <: AbstractFloat, A <: AbstractVector, S <: LQSolver}
        return new{T,A,S}(Vector{SubWorker{T,A,S}}(undef, nworkers()))
    end
end

function init_subproblems!(ph::AbstractProgressiveHedgingSolver, subsolver::QPSolver, execution::SynchronousExecution)
    return init_subproblems!(ph, subsolver, execution.subworkers)
end

function resolve_subproblems!(ph::AbstractProgressiveHedgingSolver, execution::SynchronousExecution{T}) where T <: AbstractFloat
    partial_objectives = Vector{T}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_objectives[i] = remotecall_fetch(resolve_subproblems!, w, execution.subworkers[w-1], ph.ξ, penalty(ph))
        end
    end
    return sum(partial_objectives)
end

function update_iterate!(ph::AbstractProgressiveHedgingSolver, execution::SynchronousExecution{T,A}) where {T <: AbstractFloat, A <: AbstractVector}
    partial_primals = Vector{A}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_primals[i] = remotecall_fetch(collect_primals, w, execution.subworkers[w-1], length(ph.ξ))
        end
    end
    ξ_prev = copy(ph.ξ)
    ph.ξ .= sum(partial_primals)
    # Update δ₁
    ph.data.δ₁ = norm(ph.ξ-ξ_prev, 2)^2
    return nothing
end

function update_subproblems!(ph::AbstractProgressiveHedgingSolver, execution::SynchronousExecution)
    # Update dual prices
    @sync begin
        for w in workers()
            @async remotecall_fetch((sw,ξ,r)->begin
                subproblems = fetch(sw)
                if length(subproblems) > 0
                    update_subproblems!(subproblems, ξ, r)
                end
                end,
                w,
                execution.subworkers[w-1],
                ph.ξ,
                penalty(ph))
        end
    end
    return nothing
end

function update_dual_gap!(ph::AbstractProgressiveHedgingSolver, execution::SynchronousExecution)
    return update_dual_gap!(ph, execution.subworkers)
end

function calculate_objective_value(ph::AbstractProgressiveHedgingSolver, execution::SynchronousExecution)
    return calculate_objective_value(ph, execution.subworkers)
end

function fill_submodels!(ph::AbstractProgressiveHedgingSolver, scenarioproblems, execution::SynchronousExecution)
    return fill_submodels!(ph, scenarioproblems, execution.subworkers)
end
# API
# ------------------------------------------------------------
function (execution::Synchronous)(::Type{T}, ::Type{A}, ::Type{S}) where {T <: AbstractFloat, A <: AbstractVector, S <: LQSolver}
    return SynchronousExecution(T,A,S)
end

function str(::Synchronous)
    return "synchronous execution"
end
