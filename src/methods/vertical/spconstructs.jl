function EWS(stochasticprogram::StochasticProgram,
             structure::VerticalBlockStructure{2,1,Tuple{SP}}) where SP <: DistributedScenarioProblems
    partial_ews = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_ews[i] = remotecall_fetch(
                w,
                scenarioproblems(stochasticprogram)[w-1],
                stochasticprogram.generator[:stage_1],
                stochasticprogram.generator[:stage_2],
                stage_parameters(stochasticprogram, 1),
                stage_parameters(stochasticprogram, 2),
                sub_optimizer(stochasticprogram)) do (sp,gen_one,gen_two,one_params,two_params,opt)
                    scenarioproblems = fetch(sp)
                    num_scenarios(scenarioproblems) == 0 && return zero(T)
                    return mapreduce(+, scenarios(scenarioproblems)) do scenario
                        ws = _WS(gen_one,
                                 gen_two,
                                 one_params,
                                 two_params,
                                 scenario,
                                 Decisions(),
                                 opt)
                        optimize!(ws)
                        probability(scenario)*objective_value(ws)
                    end
                end
        end
    end
    return sum(partial_ews)
end

function statistical_EWS(stochasticprogram::StochasticProgram,
                         structure::VerticalBlockStructure{2,1,Tuple{SP}}) where SP <: DistributedScenarioProblems
    partial_welfords = Vector{Tuple{Float64,Float64,Float64,Int}}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_ews[i] = remotecall_fetch(
                w,
                scenarioproblems(stochasticprogram)[w-1],
                stochasticprogram.generator[:stage_1],
                stochasticprogram.generator[:stage_2],
                stage_parameters(stochasticprogram, 1),
                stage_parameters(stochasticprogram, 2),
                sub_optimizer(stochasticprogram)) do (sp,gen_one,gen_two,one_params,two_params,opt)
                    scenarioproblems = fetch(sp)
                    num_scenarios(scenarioproblems) == 0 && return 0.0, 0.0, 0.0, 0
                    ws_models = map(scenarios(scenarioproblems)) do scenario
                        ws = _WS(gen_one,
                                 gen_two,
                                 one_params,
                                 two_params,
                                 scenario,
                                 Decisions(),
                                 opt)
                    end
                    return welford(ws_models, probability.(scenarios(scenarioproblems)))
                end
        end
    end
    𝔼WS, σ², _ = reduce(aggregate_welford, partial_welfords)
    return 𝔼WS, sqrt(σ²)
end
