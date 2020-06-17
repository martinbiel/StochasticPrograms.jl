SubWorker{T,A,PT} = RemoteChannel{Channel{Vector{SubProblem{T,A,PT}}}}
ScenarioProblemChannel{S} = RemoteChannel{Channel{ScenarioProblems{S}}}
Work = RemoteChannel{Channel{Int}}
Progress{T <: AbstractFloat} = Tuple{Int,Int,SubproblemSolution{T}}
ProgressQueue{T <: AbstractFloat} = RemoteChannel{Channel{Progress{T}}}

function initialize_subproblems!(ph::AbstractProgressiveHedging,
                                 subworkers::Vector{SubWorker{T,A,PT}},
                                 scenarioproblems::DistributedScenarioProblems,
                                 penaltyterm::AbstractPenaltyterm) where {T <: AbstractFloat,
                                                                          A <: AbstractVector,
                                                                          PT <: AbstractPenaltyterm}
    # Create subproblems on worker processes
    @sync begin
        for w in workers()
            subworkers[w-1] = RemoteChannel(() -> Channel{Vector{SubProblem{T,A,PT}}}(1), w)
            prev = map(2:(w-1)) do p
                scenarioproblems.scenario_distribution[p-1]
            end
            start_id = isempty(prev) ? 0 : sum(prev)
            @async remotecall_fetch(initialize_subworker!,
                                    w,
                                    subworkers[w-1],
                                    scenarioproblems[w-1],
                                    penaltyterm,
                                    start_id)
        end
    end
    return nothing
end

function update_dual_gap!(ph::AbstractProgressiveHedging,
                          subworkers::Vector{<:SubWorker{T}}) where T <: AbstractFloat
    # Update δ₂
    partial_δs = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_δs[i] = remotecall_fetch(
                w,
                subworkers[w-1],
                ph.ξ) do sw, ξ
                    subproblems = fetch(sw)
                    return mapreduce(+, subproblems, init = zero(T)) do subproblem
                        π = subproblem.probability
                        x = subproblem.x
                        π * norm(x - ph.ξ, 2) ^ 2
                    end
                end
        end
    end
    ph.data.δ₂ = sum(partial_δs)
    return nothing
end

function initialize_subworker!(subworker::SubWorker{T,A,PT},
                               scenarioproblems::ScenarioProblemChannel,
                               penaltyterm::AbstractPenaltyterm,
                               start_id::Integer) where {T <: AbstractFloat,
                                                         A <: AbstractArray,
                                                         PT <: AbstractPenaltyterm}
    sp = fetch(scenarioproblems)
    subproblems = Vector{SubProblem{T,A,PT}}(undef, num_subproblems(sp))
    for i = 1:num_subproblems(sp)
        subproblems[i] = SubProblem(
            subproblem(sp, i),
            start_id + i,
            T(probability(sp, i)),
            copy(penaltyterm))
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

function resolve_subproblems!(subworker::SubWorker{T,A,PT},
                              ξ::AbstractVector,
                              r::AbstractFloat) where {T <: AbstractFloat,
                                                       A <: AbstractArray,
                                                       PT <: AbstractPenaltyterm}
    subproblems::Vector{SubProblem{T,A,PT}} = fetch(subworker)
    Qs = Vector{SubproblemSolution{T}}(undef, length(subproblems))
    # Reformulate and solve sub problems
    for (i,subproblem) in enumerate(subproblems)
        reformulate_subproblem!(subproblem, ξ, r)
        Qs[i] = subproblem(ξ)
    end
    # Return current objective value
    return sum(Qs)
end

function collect_primals(subworker::SubWorker{T,A,PT}, n::Integer) where {T <: AbstractFloat,
                                                                          A <: AbstractArray,
                                                                          PT <: AbstractPenaltyterm}
    subproblems::Vector{SubProblem{T,A,PT}} = fetch(subworker)
    return mapreduce(+, subproblems, init = zeros(T, n)) do subproblem
        π = subproblem.probability
        x = subproblem.x
        π * x
    end
end

function calculate_objective_value(subworkers::Vector{<:SubWorker{T}}) where T <: AbstractFloat
    partial_objectives = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i, w) in enumerate(workers())
            @async partial_objectives[i] = remotecall_fetch(w, subworkers[w-1]) do sw
                return mapreduce(+, fetch(sw), init = zero(T)) do subproblem
                    _objective_value(subproblem)
                end
            end
        end
    end
    return sum(partial_objectives)
end

function work_on_subproblems!(subworker::SubWorker{T,A,PT},
                              work::Work,
                              finalize::Work,
                              progress::ProgressQueue{T},
                              x̄::RemoteRunningAverage{A},
                              δ::RemoteRunningAverage{T},
                              iterates::RemoteIterates{A},
                              r::IteratedValue{T}) where {T <: AbstractFloat,
                                                          A <: AbstractArray,
                                                          PT <: AbstractPenaltyterm}
    subproblems::Vector{SubProblem{T,A,PT}} = fetch(subworker)
    if isempty(subproblems)
       # Workers has nothing do to, return.
       return nothing
    end
    x̄ = fetch(x̄)
    δ = fetch(δ)
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
        ξ::A = fetch(iterates, t)
        if t > 1
            update_subproblems!(subproblems, ξ, fetch(r,t-1))
        end
        for (i,subproblem) in enumerate(subproblems)
            !quit && subtract!(δ, i)
            !quit && subtract!(x̄, i)
            x = subproblem.x
            π = subproblem.probability
            !quit && add!(δ, i, norm(x - ξ, 2) ^ 2, π)
            reformulate_subproblem!(subproblem, ξ, fetch(r, t))
            Q::SubproblemSolution{T} = subproblem(ξ)
            !quit && add!(x̄, i, π)
            !quit && put!(progress, (t, subproblem.id, Q))
        end
        if quit
            # Worker finished
            return nothing
        end
    end
end
