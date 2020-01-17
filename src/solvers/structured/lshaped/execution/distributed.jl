SubWorker{F,T,A,S} = RemoteChannel{Channel{Vector{SubProblem{F,T,A,S}}}}
ScenarioProblemChannel{S} = RemoteChannel{Channel{StochasticPrograms.ScenarioProblems{S}}}
Work = RemoteChannel{Channel{Int}}

function load_subproblems!(subworkers::Vector{SubWorker{F,T,A,S}},
                           scenarioproblems::AbstractScenarioProblems,
                           x::AbstractVector,
                           subsolver::SubSolver) where {F <: AbstractFeasibility,
                                                        T <: AbstractFloat,
                                                        A <: AbstractVector,
                                                        S <: LQSolver}
    # Create subproblems on worker processes
    @sync begin
        for w in workers()
            subworkers[w-1] = RemoteChannel(() -> Channel{Vector{SubProblem{F,T,A,S}}}(1), w)
            @async load_worker!(scenarioproblems, w, subworkers[w-1], x, subsolver)
        end
    end
end

function load_worker!(sp::ScenarioProblems,
                      w::Integer,
                      worker::SubWorker,
                      x::AbstractVector,
                      subsolver::SubSolver)
    n = StochasticPrograms.nscenarios(sp)
    (nscen, extra) = divrem(n, nworkers())
    prev = [nscen + (extra + 2 - p > 0) for p in 2:(w-1)]
    start = isempty(prev) ? 1 : sum(prev) + 1
    stop = min(start + nscen + (extra + 2 - w > 0) - 1, n)
    prev = [begin
            jobsize = nscen + (extra + 2 - p > 0)
            ceil(Int, jobsize)
            end for p in 2:(w-1)]
    start_id = isempty(prev) ? 0 : sum(prev)
    πs = [probability(sp.scenarios[i]) for i = start:stop]
    return remotecall_fetch(init_subworker!,
                            w,
                            worker,
                            sp.parent,
                            sp.problems[start:stop],
                            πs,
                            x,
                            subsolver,
                            start_id)
end

function load_worker!(sp::DScenarioProblems,
                      w::Integer,
                      worker::SubWorker,
                      x::AbstractVector,
                      subsolver::SubSolver)
    prev = [sp.scenario_distribution[p-1] for p in 2:(w-1)]
    start_id = isempty(prev) ? 0 : sum(prev)
    return remotecall_fetch(init_subworker!,
                            w,
                            worker,
                            sp[w-1],
                            x,
                            subsolver,
                            start_id)
end

function init_subworker!(subworker::SubWorker{F,T,A,S},
                         parent::JuMP.Model,
                         submodels::Vector{JuMP.Model},
                         πs::A,
                         x::A,
                         subsolver::SubSolver,
                         start_id::Integer) where {F, T <: AbstractFloat, A <: AbstractArray, S <: LQSolver}
    subproblems = Vector{SubProblem{F,T,A,S}}(undef, length(submodels))
    for (i,submodel) = enumerate(submodels)
        y₀ = convert(A, rand(submodel.numCols))
        subproblems[i] = SubProblem(submodel, parent, start_id + i, πs[i], x, y₀, get_solver(subsolver), F)
    end
    put!(subworker, subproblems)
    return nothing
end

function init_subworker!(subworker::SubWorker{F,T,A,S},
                         scenarioproblems::ScenarioProblemChannel,
                         x::A,
                         subsolver::SubSolver,
                         start_id::Integer) where {F, T <: AbstractFloat, A <: AbstractArray, S <: LQSolver}
    sp = fetch(scenarioproblems)
    subproblems = Vector{SubProblem{F,T,A,S}}(undef, StochasticPrograms.nsubproblems(sp))
    for (i,submodel) = enumerate(sp.problems)
        y₀ = convert(A, rand(sp.problems[i].numCols))
        subproblems[i] = SubProblem(submodel, sp.parent, start_id + i, probability(sp.scenarios[i]), x, y₀, get_solver(subsolver), F)
    end
    put!(subworker, subproblems)
    return nothing
end

function resolve_subproblems!(subworker::SubWorker{F,T,A,S}, x::AbstractVector, cutqueue::CutQueue{T}, aggregator::AbstractAggregator, t::Integer, metadata::MetaData) where {F <: AbstractFeasibility, T <: AbstractFloat, A <: AbstractArray, S <: LQSolver}
    # Fetch all subproblems stored in worker
    subproblems::Vector{SubProblem{F,T,A,S}} = fetch(subworker)
    if isempty(subproblems)
        # Workers has nothing do to, return.
        return nothing
    end
    # Aggregation policy
    aggregation::AbstractAggregation = aggregator(length(subproblems), T)
    # Solve subproblems
    for subproblem ∈ subproblems
        update_subproblem!(subproblem, x)
        cut = subproblem()
        aggregate_cut!(cutqueue, aggregation, metadata, t, cut, x)
    end
    flush!(cutqueue, aggregation, metadata, t, x)
    return nothing
end

function work_on_subproblems!(subworker::SubWorker{F,T,A,S},
                              work::Work,
                              finalize::Work,
                              cutqueue::CutQueue{T},
                              decisions::Decisions{A},
                              metadata::MetaData,
                              aggregator::AbstractAggregator) where {F, T <: AbstractFloat, A <: AbstractArray, S <: LQSolver}
    subproblems::Vector{SubProblem{F,T,A,S}} = fetch(subworker)
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
        x::A = fetch(decisions,t)
        for subproblem in subproblems
            update_subproblem!(subproblem, x)
            cut = subproblem()
            !quit && aggregate_cut!(cutqueue, aggregation, metadata, t, cut, x)
        end
        !quit && flush!(cutqueue, aggregation, metadata, t, x)
        if quit
            # Worker finished
            return nothing
        end
    end
end

function eval_second_stage(subworkers::Vector{<:SubWorker}, x::AbstractVector)
    partial_objectives = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_objectives[i] = remotecall_fetch(calculate_subobjective, w, subworkers[w-1], x)
        end
    end
    return sum(partial_objectives)
end

function calculate_subobjective(subworker::SubWorker{F,T,A,S}, x::A) where {F, T <: AbstractFloat, A <: AbstractArray, S <: LQSolver}
    subproblems::Vector{SubProblem{F,T,A,S}} = fetch(subworker)
    if length(subproblems) > 0
        return sum([subproblem.π*subproblem(x) for subproblem in subproblems])
    else
        return zero(T)
    end
end

function fill_submodels!(subworkers::Vector{<:SubWorker}, x::AbstractVector, scenarioproblems::ScenarioProblems)
    j = 0
    @sync begin
        for w in workers()
            n = remotecall_fetch((sw)->length(fetch(sw)), w, subworkers[w-1])
            for i = 1:n
                k = i+j
                @async fill_submodel!(scenarioproblems.problems[k],remotecall_fetch((sw,i,x)->begin
                    sp = fetch(sw)[i]
                    sp(x)
                    get_solution(sp)
                end,
                w,
                subworkers[w-1],
                i,
                x)...)
            end
            j += n
        end
    end
    return nothing
end

function fill_submodels!(subworkers::Vector{<:SubWorker}, x::AbstractVector, scenarioproblems::DScenarioProblems)
    @sync begin
        for w in workers()
            @async remotecall_fetch(fill_submodels!,
                                    w,
                                    subworkers[w-1],
                                    x,
                                    scenarioproblems[w-1])
        end
    end
    return nothing
end

function fill_submodels!(subworker::SubWorker{F,T,A,S},
                         x::A,
                         scenarioproblems::ScenarioProblemChannel) where {F <: AbstractFeasibility, T <: AbstractFloat, A <: AbstractArray, S <: LQSolver}
    sp = fetch(scenarioproblems)
    subproblems::Vector{SubProblem{F,T,A,S}} = fetch(subworker)
    for (i, submodel) in enumerate(sp.problems)
        subproblems[i](x)
        fill_submodel!(submodel, subproblems[i])
    end
    return nothing
end
