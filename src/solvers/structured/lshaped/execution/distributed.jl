SubWorker{H,T,S} = RemoteChannel{Channel{Vector{SubProblem{H,T,S}}}}
ScenarioProblemChannel{S} = RemoteChannel{Channel{ScenarioProblems{S}}}
Work = RemoteChannel{Channel{Int}}

function load_subproblems!(subworkers::Vector{SubWorker{H,T,S}},
                           scenarioproblems::DistributedScenarioProblems,
                           decisions::Vector{DecisionChannel},
                           tolerance::AbstractFloat) where {H <: AbstractFeasibilityHandler,
                                                            T <: AbstractFloat,
                                                            S <: MOI.AbstractOptimizer}
    # Create subproblems on worker processes
    @sync begin
        for w in workers()
            subworkers[w-1] = RemoteChannel(() -> Channel{Vector{SubProblem{H,T,S}}}(1), w)
            prev = map(2:(w-1)) do p
                scenarioproblems.scenario_distribution[p-1]
            end
            start_id = isempty(prev) ? 0 : sum(prev)
            @async remotecall_fetch(initialize_subworker!,
                                    w,
                                    subworkers[w-1],
                                    scenarioproblems[w-1],
                                    decisions[w-1],
                                    tolerance,
                                    start_id)
        end
    end
end

function initialize_subworker!(subworker::SubWorker{H,T,S},
                               scenarioproblems::ScenarioProblemChannel,
                               decisions::DecisionChannel,
                               tolerance::AbstractFloat,
                               start_id::Integer) where {H <: AbstractFeasibilityHandler, T <: AbstractFloat, S <: MOI.AbstractOptimizer}
    sp = fetch(scenarioproblems)
    subproblems = Vector{SubProblem{H,T,S}}(undef, num_subproblems(sp))
    for i in 1:num_subproblems(sp)
        subproblems[i] = SubProblem(
            subproblem(sp, i),
            start_id + i,
            T(probability(scenario(sp, i))),
            T(tolerance),
            fetch(decisions).knowns,
            H)
    end
    put!(subworker, subproblems)
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

function resolve_subproblems!(subworker::SubWorker{H,T,S},
                              decisions::DecisionChannel,
                              x::AbstractVector,
                              cutqueue::CutQueue{T},
                              aggregator::AbstractAggregator,
                              t::Integer,
                              metadata::MetaData) where {H <: AbstractFeasibilityHandler, T <: AbstractFloat, S <: MOI.AbstractOptimizer}
    # Fetch all subproblems stored in worker
    subproblems::Vector{SubProblem{H,T,S}} = fetch(subworker)
    if isempty(subproblems)
        # Workers has nothing do to, return.
        return nothing
    end
    # Update subproblems
    update_known_decisions!(fetch(decisions), x)
    change = KnownValuesChange()
    # Aggregation policy
    aggregation::AbstractAggregation = aggregator(length(subproblems), T)
    # Solve subproblems
    for subproblem in subproblems
        update_subproblem!(subproblem, change)
        cut::SparseHyperPlane{T} = subproblem(x)
        aggregate_cut!(cutqueue, aggregation, metadata, t, cut, x)
    end
    flush!(cutqueue, aggregation, metadata, t, x)
    return nothing
end

function work_on_subproblems!(subworker::SubWorker{H,T,S},
                              decisions::DecisionChannel,
                              work::Work,
                              finalize::Work,
                              cutqueue::CutQueue{T},
                              iterates::RemoteIterates{A},
                              metadata::MetaData,
                              aggregator::AbstractAggregator) where {H <: AbstractFeasibilityHandler,
                                                                     T <: AbstractFloat,
                                                                     A <: AbstractVector,
                                                                     S <: MOI.AbstractOptimizer}
    subproblems::Vector{SubProblem{H,T,S}} = fetch(subworker)
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
        change = KnownValuesChange()
        for subproblem in subproblems
            update_subproblem!(subproblem, change)
            cut::SparseHyperPlane{T} = subproblem(x)
            !quit && aggregate_cut!(cutqueue, aggregation, metadata, t, cut, x)
        end
        !quit && flush!(cutqueue, aggregation, metadata, t, x)
        if quit
            # Worker finished
            return nothing
        end
    end
end
