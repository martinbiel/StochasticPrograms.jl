"""
    SynchronousExecution

Functor object for using synchronous execution in an L-shaped algorithm (assuming multiple Julia cores are available). Create by supplying a [`Synchronous`](@ref) object through `execution` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

"""
struct SynchronousExecution{T <: AbstractFloat,
                            A <: AbstractVector,
                            F <: AbstractFeasibilityAlgorithm,
                            I <: AbstractIntegerAlgorithm} <: AbstractLShapedExecution
    subworkers::Vector{SubWorker{T,F,I}}
    decisions::Vector{DecisionChannel}
    subobjectives::A
    model_objectives::A
    metadata::MetaDataChannel
    remote_metadata::Vector{MetaDataChannel}
    cutqueue::CutQueue{T}

    function SynchronousExecution(structure::VerticalStructure{2, 1, <:Tuple{DistributedScenarioProblems}},
                                  feasibility_strategy::AbstractFeasibilityStrategy,
                                  integer_strategy::AbstractIntegerStrategy,
                                  ::Type{T},
                                  ::Type{A}) where {T <: AbstractFloat,
                                                    A <: AbstractVector}
        F = worker_type(feasibility_strategy)
        I = worker_type(integer_strategy)
        execution =  new{T,A,F,I}(Vector{SubWorker{H,T}}(undef, nworkers()),
                                  scenarioproblems(structure).decisions,
                                  A(),
                                  A(),
                                  RemoteChannel(() -> MetaChannel()),
                                  Vector{MetaDataChannel}(undef, nworkers()),
                                  RemoteChannel(() -> Channel{QCut{T}}(4 * nworkers() * num_scenarios(structure))),
                                  Vector{Future}(undef, nworkers()))
        # Start loading subproblems
        load_subproblems!(execution.subworkers,
                          scenarioproblems,
                          execution.decisions,
                          feasibility_strategy,
                          integer_strategy)
        return execution
    end
end

function finish_initilization!(lshaped::AbstractLShaped, execution::SynchronousExecution)
    append!(execution.subobjectives, fill(1e10, num_thetas(lshaped)))
    append!(execution.model_objectives, fill(-1e10, num_thetas(lshaped)))
    for w in workers()
        execution.remote_metadata[w-1] = RemoteChannel(() -> MetaChannel(), w)
    end
    return lshaped
end

function restore_subproblems!(::AbstractLShaped, execution::SynchronousExecution)
    restore_subproblems!(execution.subworkers)
    return nothing
end

function resolve_subproblems!(lshaped::AbstractLShaped, execution::SynchronousExecution{T}) where T <: AbstractFloat
    # Update metadata
    for w in workers()
        put!(execution.metadata[w-1], timestamp(lshaped), :gap, gap(lshaped))
    end
    @sync begin
        for (i,w) in enumerate(workers())
            worker_aggregator = remote_aggregator(lshaped.aggregation, scenarioproblems(lshaped.structure), w)
            @async remotecall_fetch(resolve_subproblems!,
                                    w,
                                    execution.subworkers[w-1],
                                    execution.decisions[w-1],
                                    lshaped.x,
                                    execution.cutqueue,
                                    worker_aggregator,
                                    timestamp(lshaped),
                                    execution.metadata[w-1])
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

# API
# ------------------------------------------------------------
function (execution::Synchronous)(structure::VerticalStructure{2, 1, <:Tuple{DistributedScenarioProblems}},
                                  feasibility_strategy::AbstractFeasibilityStrategy,
                                  integer_strategy::AbstractIntegerStrategy,
                                  ::Type{T},
                                  ::Type{A}) where {T <: AbstractFloat,
                                                    A <: AbstractVector}
    return SynchronousExecution(structure,
                                feasibility_strategy,
                                integer_strategy,
                                T,
                                A)
end

function str(::Synchronous)
    return "Synchronous "
end
