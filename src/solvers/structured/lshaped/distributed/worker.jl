SubWorker{F,T,A,S} = RemoteChannel{Channel{Vector{SubProblem{F,T,A,S}}}}
ScenarioProblemChannel{S} = RemoteChannel{Channel{StochasticPrograms.ScenarioProblems{S}}}
Work = RemoteChannel{Channel{Int}}

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

function work_on_subproblems!(subworker::SubWorker{F,T,A,S},
                              work::Work,
                              cutqueue::CutQueue{T},
                              decisions::Decisions{A},
                              metadata::MetaData,
                              aggregator::AbstractAggregator) where {F, T <: AbstractFloat, A <: AbstractArray, S <: LQSolver}
    subproblems::Vector{SubProblem{F,T,A,S}} = fetch(subworker)
    if isempty(subproblems)
       # Workers has nothing do to, return.
       return
    end
    aggregation::AbstractAggregation = aggregator(length(subproblems), T)
    while true
        t::Int = try
            wait(work)
            take!(work)
        catch err
            if err isa InvalidStateException
                # Master closed the work channel. Worker finished
                return nothing
            end
        end
        if t == -1
            # Worker finished
            return nothing
        end
        x::A = fetch(decisions,t)
        for subproblem in subproblems
            update_subproblem!(subproblem, x)
            cut = subproblem()
            aggregate_cut!(cutqueue, aggregation, metadata, t, cut, x)
        end
        flush!(cutqueue, aggregation, metadata, t, x)
    end
end

function calculate_subobjective(subworker::SubWorker{F,T,A,S}, x::A) where {F, T <: AbstractFloat, A <: AbstractArray, S <: LQSolver}
    subproblems::Vector{SubProblem{F,T,A,S}} = fetch(subworker)
    if length(subproblems) > 0
        return sum([subproblem.π*subproblem(x) for subproblem in subproblems])
    else
        return zero(T)
    end
end

function fill_submodels!(subworker::SubWorker{F,T,A,S},
                         x::A,
                         scenarioproblems::ScenarioProblemChannel) where {F, T <: AbstractFloat, A <: AbstractArray, S <: LQSolver}
    sp = fetch(scenarioproblems)
    subproblems::Vector{SubProblem{F,T,A,S}} = fetch(subworker)
    for (i, submodel) in enumerate(sp.problems)
        subproblems[i](x)
        fill_submodel!(submodel, subproblems[i])
    end
    return nothing
end
