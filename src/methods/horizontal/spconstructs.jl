function EWS(stochasticprogram::StochasticProgram, structure::HorizontalStructure)
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
    return get_from_scenarioproblems(scenarioproblems, +, partial_ews) do sp
        scenarioproblems = fetch(sp)
        num_scenarios(scenarioproblems) == 0 && return 0.0
        return outcome_mean(subproblems(scenarioproblems),
                            probability.(scenarios(scenarioproblems)))
    end
    return sum(partial_ews)
end

function statistical_EWS(::StochasticProgram, structure::HorizontalStructure)
    return statistical_EWS_horizontal(scenarioproblems(structure))
end
function statistical_EWS_horizontal(scenarioproblems::ScenarioProblems)
    # Welford algorithm on WS subproblems
    return welford(subproblems(scenarioproblems),
                   probability.(scenarios(scenarioproblems)))
end
function statistical_EWS_horizontal(scenarioproblems::DistributedScenarioProblems)
    partial_welfords = Vector{Tuple{Float64,Float64,Float64,Int}}(undef, nworkers())
    𝔼WS, σ², _ = return get_from_scenarioproblems(scenarioproblems, aggregate_welford, partial_welfords) do sp
        scenarioproblems = fetch(sp)
        num_scenarios(scenarioproblems) == 0 && return 0.0, 0.0, 0.0, 0
        return welford(subproblems(scenarioproblems),
                       probability.(scenarios(scenarioproblems)))
    end
    return 𝔼WS, sqrt(σ²)
end
