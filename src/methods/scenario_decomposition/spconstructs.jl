# Scenario-decomposition spconstructs #
# =================================== #
function EWS(stochasticprogram::StochasticProgram, structure::ScenarioDecompositionStructure)
    # Restore structure if optimization has been run before
    restore_structure!(optimizer(stochasticprogram))
    # Dispatch on scenarioproblems
    return EWS_horizontal(scenarioproblems(structure))
end
function EWS_horizontal(scenarioproblems::ScenarioProblems)
    return outcome_mean(subproblems(scenarioproblems), probability.(scenarios(scenarioproblems)))
end
function EWS_horizontal(scenarioproblems::DistributedScenarioProblems)
    partial_ews = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_ews[i] = remotecall_fetch(
                w,
                scenarioproblems[w-1]) do sp
                    scenarioproblems = fetch(sp)
                    num_scenarios(scenarioproblems) == 0 && return 0.0
                    return outcome_mean(subproblems(scenarioproblems),
                                        probability.(scenarios(scenarioproblems)))
                end
        end
    end
    return sum(partial_ews)
end

function statistical_EWS(::StochasticProgram, structure::ScenarioDecompositionStructure)
    return statistical_EWS_horizontal(scenarioproblems(structure))
end
function statistical_EWS_horizontal(scenarioproblems::ScenarioProblems)
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
                    scenarioproblems = fetch(sp)
                    num_scenarios(scenarioproblems) == 0 && return 0.0, 0.0, 0.0, 0
                    return welford(subproblems(scenarioproblems),
                                   probability.(scenarios(scenarioproblems)))
                end
        end
    end
    𝔼WS, σ², _ = reduce(aggregate_welford, partial_welfords)
    return 𝔼WS, sqrt(σ²)
end
