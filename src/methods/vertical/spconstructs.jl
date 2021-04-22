function EWS(stochasticprogram::StochasticProgram,
             structure::VerticalStructure{2,1,Tuple{SP}}) where SP <: DistributedScenarioProblems
    partial_ews = Vector{Float64}(undef, nworkers())
    return get_from_scenarioproblems(
        scenarioproblems(structure),
        +,
        partial_ews,
        stochasticprogram.generator[:stage_1],
        stochasticprogram.generator[:stage_2],
        stage_parameters(stochasticprogram, 1),
        stage_parameters(stochasticprogram, 2),
        subproblem_optimizer(stochasticprogram)) do sp, gen_one, gen_two, one_params, two_params, opt
            scenarioproblems = fetch(sp)
            num_scenarios(scenarioproblems) == 0 && return 0.0
            subproblems = map(scenarios(scenarioproblems)) do scenario
                ws = _WS(gen_one,
                         gen_two,
                         one_params,
                         two_params,
                         scenario,
                         Decisions(),
                         Decisions(),
                         opt)
                return ws
            end
            return outcome_mean(subproblems, probability.(scenarios(scenarioproblems)))
        end
end

function statistical_EWS(stochasticprogram::StochasticProgram,
                         structure::VerticalStructure{2,1,Tuple{SP}}) where SP <: DistributedScenarioProblems
    partial_welfords = Vector{Tuple{Float64,Float64,Float64,Int}}(undef, nworkers())
    𝔼WS, σ², wₖ, N = get_from_scenarioproblems(
        scenarioproblems(structure),
        aggregate_welford,
        partial_welfords,
        stochasticprogram.generator[:stage_1],
        stochasticprogram.generator[:stage_2],
        stage_parameters(stochasticprogram, 1),
        stage_parameters(stochasticprogram, 2),
        subproblem_optimizer(stochasticprogram)) do sp, gen_one, gen_two, one_params, two_params, opt
            scenarioproblems = fetch(sp)
            num_scenarios(scenarioproblems) == 0 && return 0.0, 0.0, 0.0, 0
            ws_models = map(scenarios(scenarioproblems)) do scenario
                ws = _WS(gen_one,
                         gen_two,
                         one_params,
                         two_params,
                         scenario,
                         Decisions(),
                         Decisions(),
                         opt)
                return ws
            end
            return welford(ws_models, probability.(scenarios(scenarioproblems)))
        end
    return 𝔼WS, sqrt(σ²)
end
