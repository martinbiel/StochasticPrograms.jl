"""
    SynchronousExecution

Functor object for using synchronous execution in an L-shaped algorithm (assuming multiple Julia cores are available). Create by supplying a [`Synchronous`](@ref) object through `execution` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

"""
struct SynchronousExecution{F <: AbstractFeasibility,
                            T <: AbstractFloat,
                            A <: AbstractVector,
                            S <: LQSolver} <: AbstractExecution
    subworkers::Vector{SubWorker{F,T,A,S}}
    subobjectives::A
    model_objectives::A
    metadata::Vector{MetaData}
    cutqueue::CutQueue{T}

    function SynchronousExecution(nscenarios::Integer, ::Type{F}, ::Type{T}, ::Type{A}, ::Type{S}) where {F <: AbstractFeasibility, T <: AbstractFloat, A <: AbstractVector, S <: LQSolver}
        return new{F,T,A,S}(Vector{SubWorker{F,T,A,S}}(undef, nworkers()),
                            A(),
                            A(),
                            Vector{MetaData}(undef,nworkers()),
                            RemoteChannel(() -> Channel{QCut{T}}(4*nworkers()*nscenarios)))
    end
end

function initialize_subproblems!(execution::SynchronousExecution,
                                 scenarioproblems::AbstractScenarioProblems,
                                 x::AbstractVector,
                                 subsolver::MPB.AbstractMathProgSolver)
    load_subproblems!(execution.subworkers, scenarioproblems, x, subsolver)
    return nothing
end

function finish_initilization!(lshaped::AbstractLShapedSolver, execution::SynchronousExecution)
    append!(execution.subobjectives, fill(1e10, nthetas(lshaped)))
    append!(execution.model_objectives, fill(-1e10, nthetas(lshaped)))
    for w in workers()
        execution.metadata[w-1] = RemoteChannel(() -> MetaChannel(), w)
    end
    return lshaped
end

function resolve_subproblems!(lshaped::AbstractLShapedSolver, execution::SynchronousExecution{F,T}) where {F <: AbstractFeasibility, T <: AbstractFloat}
    # Update metadata
    for w in workers()
        put!(execution.metadata[w-1], timestamp(lshaped), :gap, gap(lshaped))
    end
    @sync begin
        for (i,w) in enumerate(workers())
            worker_aggregator = remote_aggregator(lshaped.aggregation, scenarioproblems(lshaped.stochasticprogram), w)
            remotecall_fetch(resolve_subproblems!, w, execution.subworkers[w-1], lshaped.x, execution.cutqueue, worker_aggregator, timestamp(lshaped), execution.metadata[w-1])
        end
    end
    # Assume no cuts are added
    added = false
    # Collect incoming cuts
    while isready(execution.cutqueue)
        _, cut::SparseHyperPlane{T} = take!(execution.cutqueue)
        added |= add_cut!(lshaped, cut)
    end
    # Return current objective value and cut_added flag
    return current_objective_value(lshaped), added
end

function calculate_objective_value(lshaped::AbstractLShapedSolver, execution::SynchronousExecution)
    return lshaped.c⋅decision(lshaped) + eval_second_stage(execution.subworkers, decision(lshaped))
end

function fill_submodels!(lshaped::AbstractLShapedSolver, scenarioproblems, execution::SynchronousExecution)
    return fill_submodels!(execution.subworkers, decision(lshaped), scenarioproblems)
end

# API
# ------------------------------------------------------------
function (execution::Synchronous)(nscenarios::Integer, ::Type{F}, ::Type{T}, ::Type{A}, ::Type{S}) where {F <: AbstractFeasibility, T <: AbstractFloat, A <: AbstractVector, S <: LQSolver}
    return SynchronousExecution(nscenarios, F, T, A, S)
end

function str(::Synchronous)
    return "Synchronous "
end
