SubWorker{T} = RemoteChannel{Channel{Vector{SubProblem{T}}}}
ScenarioProblemChannel{S} = RemoteChannel{Channel{ScenarioProblems{S}}}
Work = RemoteChannel{Channel{Int}}

function load_subproblems!(subworkers::Vector{SubWorker{T}},
                           scenarioproblems::DistributedScenarioProblems,
                           decisions::Vector{DecisionChannel}) where T <: AbstractFloat
    # Create subproblems on worker processes
    @sync begin
        for w in workers()
            subworkers[w-1] = RemoteChannel(() -> Channel{Vector{SubProblem{T}}}(1), w)
            prev = map(2:(w-1)) do p
                scenarioproblems.scenario_distribution[p-1]
            end
            start_id = isempty(prev) ? 0 : sum(prev)
            @async remotecall_fetch(initialize_subworker!,
                                    w,
                                    subworkers[w-1],
                                    scenarioproblems[w-1],
                                    decisions[w-1],
                                    start_id)
        end
    end
end

function initialize_subworker!(subworker::SubWorker{T},
                               scenarioproblems::ScenarioProblemChannel,
                               decisions::DecisionChannel,
                               start_id::Integer) where T <: AbstractFloat
    sp = fetch(scenarioproblems)
    subproblems = Vector{SubProblem{T}}(undef, num_subproblems(sp))
    for i in 1:num_subproblems(sp)
        subproblems[i] = SubProblem(
            subproblem(sp, i),
            start_id + i,
            T(probability(scenario(sp, i))))
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
