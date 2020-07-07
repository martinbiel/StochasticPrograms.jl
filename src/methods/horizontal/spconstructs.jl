function EWS(::StochasticProgram, structure::HorizontalStructure)
    return EWS_horizontal(scenarioproblems(structure))
end
function EWS_horizontal(scenarioproblems::ScenarioProblems)
    num_subproblems(scenarioproblems) == 0 && return 0.0
    return mapreduce(+, 1:length(num_subproblems(scenarioproblems))) do i
        subprob = subproblem(scenarioproblems, i)
        # Ensure that no decisions are fixed
        untake_decisions!(subprob)
        # Solve subproblem
        optimize!(subprob)
        probability(scenarioproblems, i)*objective_value(subprob)
    end
end
function EWS_horizontal(scenarioproblems::DistributedScenarioProblems)
    partial_ews = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_ews[i] = remotecall_fetch(
                w,
                scenarioproblems[w-1]) do sp
                    EWS_horizontal(fetch(sp))
                end
        end
    end
    return sum(partial_ews)
end

function statistical_EWS(::StochasticProgram, structure::HorizontalStructure)
    return statistical_EWS_horizontal(scenarioproblems(structure))
end
function statistical_EWS_horizontal(scenarioproblems::ScenarioProblems)
    # Ensure that no decisions are fixed
    map(subprob -> untake_decisions!(subprob), subproblems(scenarioproblems))
    # Welford algorithm on WS subproblems
    return welford(subproblems(scenarioproblems),
                   probability.(scenarios(scenarioproblems)))
end
function statistical_EWS_horizontal(scenarioproblems::DistributedScenarioProblems)
    partial_welfords = Vector{Tuple{Float64,Float64,Float64,Int}}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_welfords[i] = remotecall_fetch(
                w,
                scenarioproblems[w-1]) do sp
                    statistical_EWS_horizontal(fetch(sp))
                end
        end
    end
    𝔼WS, σ², _ = reduce(aggregate_welford, partial_welfords)
    return 𝔼WS, sqrt(σ²)
end
