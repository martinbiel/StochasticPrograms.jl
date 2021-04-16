SubWorker{T,F,I} = RemoteChannel{Channel{Vector{SubProblem{T,F,I}}}}
ScenarioProblemChannel{S} = RemoteChannel{Channel{ScenarioProblems{S}}}
Work = RemoteChannel{Channel{Int}}

function load_subproblems!(subworkers::Vector{SubWorker{T,F,I}},
                           scenarioproblems::DistributedScenarioProblems,
                           decisions::Vector{DecisionChannel},
                           feasibility_strategy::AbstractFeasibilityStrategy,
                           integer_strategy::AbstractIntegerStrategy) where {T <: AbstractFloat,
                                                                             F <: AbstractFeasibilityAlgorithm,
                                                                             I <: AbstractIntegerAlgorithm}
    # Create subproblems on worker processes
    @sync begin
        for w in workers()
            subworkers[w-1] = RemoteChannel(() -> Channel{Vector{SubProblem{T,F,I}}}(1), w)
            prev = map(2:(w-1)) do p
                scenarioproblems.scenario_distribution[p-1]
            end
            start_id = isempty(prev) ? 0 : sum(prev)
            @async remotecall_fetch(initialize_subworker!,
                                    w,
                                    subworkers[w-1],
                                    scenarioproblems[w-1],
                                    feasibility_strategy,
                                    integer_strategy,
                                    start_id)
        end
    end
end

function initialize_subworker!(subworker::SubWorker{T,F,I},
                               scenarioproblems::ScenarioProblemChannel,
                               feasibility_strategy::AbstractFeasibilityStrategy,
                               integer_strategy::AbstractIntegerStrategy,
                               start_id::Integer) where {T <: AbstractFloat,
                                                         F <: AbstractFeasibilityAlgorithm,
                                                         I <: AbstractIntegerAlgorithm}
    sp = fetch(scenarioproblems)
    subproblems = Vector{SubProblem{T,F,I}}(undef, num_subproblems(sp))
    for i in 1:num_subproblems(sp)
        subproblems[i] = SubProblem(
            subproblem(sp, i),
            start_id + i,
            T(probability(scenario(sp, i))),
            feasibility_strategy,
            integer_strategy)
    end
    put!(subworker, subproblems)
    return nothing
end

function mutate_subproblems!(mutator::Function, subworkers::Vector{<:SubWorker})
    @sync begin
        for w in workers()
            @async remotecall_fetch(w, mutator, subworkers[w-1]) do mutator, sw
                for subproblem in fetch(sw)
                    mutator(subproblem)
                end
            end
        end
    end
    return nothing
end

function restore_subproblems!(subworkers::Vector{<:SubWorker})
     @sync begin
        for w in workers()
            @async remotecall_fetch(w, subworkers[w-1]) do sw
                for subproblem in fetch(sw)
                    restore_subproblem!(subproblem)
                end
            end
        end
    end
    return nothing
end

function resolve_subproblems!(subworker::SubWorker{T,F,I},
                              decisions::DecisionChannel,
                              x::AbstractVector,
                              cutqueue::CutQueue{T},
                              aggregator::AbstractAggregator,
                              t::Integer,
                              metadata::MetaDataChannel,
                              worker_metadata::MetaDataChannel) where {T <: AbstractFloat,
                                                                F <: AbstractFeasibilityAlgorithm,
                                                                I <: AbstractIntegerAlgorithm}
    # Fetch all subproblems stored in worker
    subproblems::Vector{SubProblem{T,F,I}} = fetch(subworker)
    if isempty(subproblems)
        # Workers has nothing do to, return.
        return nothing
    end
    # Update subproblems
    update_known_decisions!(fetch(decisions), x)
    # Aggregation policy
    aggregation::AbstractAggregation = aggregator(length(subproblems), T)
    # Solve subproblems
    for subproblem in subproblems
        update_subproblem!(subproblem)
        cut::SparseHyperPlane{T} = subproblem(x, metadata)
        aggregate_cut!(cutqueue, aggregation, worker_metadata, t, cut, x)
    end
    flush!(cutqueue, aggregation, worker_metadata, t, x)
    return nothing
end

function work_on_subproblems!(subworker::SubWorker{T,F,I},
                              decisions::DecisionChannel,
                              work::Work,
                              finalize::Work,
                              cutqueue::CutQueue{T},
                              iterates::RemoteIterates{A},
                              metadata::MetaDataChannel,
                              worker_metadata::MetaDataChannel,
                              aggregator::AbstractAggregator) where {T <: AbstractFloat,
                                                                     A <: AbstractVector,
                                                                     F <: AbstractFeasibilityAlgorithm,
                                                                     I <: AbstractIntegerAlgorithm}
    subproblems::Vector{SubProblem{T,F,I}} = fetch(subworker)
    if isempty(subproblems)
       # Workers has nothing do to, return.
       return nothing
    end
    aggregation::AbstractAggregation = aggregator(length(subproblems), T)
    quit = false
    while true
        t::Int = try
            if isready(finalize)
                quit = true
                take!(finalize)
            else
                wait(work)
                take!(work)
            end
        catch err
            if err isa InvalidStateException
                # Master closed the work/finalize channel. Worker finished
                return nothing
            end
        end
        t == -1 && continue
        x::A = fetch(iterates, t)
        # Update subproblems
        update_known_decisions!(fetch(decisions), x)
        for subproblem in subproblems
            update_subproblem!(subproblem)
            cut::SparseHyperPlane{T} = subproblem(x, metadata)
            !quit && aggregate_cut!(cutqueue, aggregation, worker_metadata, t, cut, x)
        end
        !quit && flush!(cutqueue, aggregation, worker_metadata, t, x)
        if quit
            # Worker finished
            return nothing
        end
    end
end
