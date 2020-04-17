# Block-vertical generation #
# ========================== #
function generate!(stochasticprogram::StochasticProgram{N}, structure::VerticalBlockStructure{N}, stage::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    if stage == 1
        # Check generators
        has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
        # Generate first stage
        generator(stochasticprogram, :stage_1)(structure.first_stage, stage_parameters(stochasticprogram, 1))
    else
        # Check generators
        stage_key = Symbol(:stage_, stage)
        decision_key = Symbol(:stage_, stage - 1, :_decisions)
        has_generator(stochasticprogram, stage_key) || error("Stage problem $stage not defined in stochastic program. Consider @stage $stage.")
        has_generator(stochasticprogram, decision_key) || error("No decision variables defined in stage problem $(stage-1).")
        # Sanity check on scenario probabilities
        if nscenarios(stochasticprogram, stage) > 0
            p = stage_probability(stochasticprogram, stage)
            abs(p - 1.0) <= 1e-6 || @warn "Scenario probabilities do not add up to one. The probability sum is given by $p"
        end
        # Generate
        generate!(scenarioproblems(structure, stage),
                  generator(stochasticprogram, decision_key),
                  generator(stochasticprogram, stage_key),
                  stage_parameters(stochasticprogram, stage - 1),
                  stage_parameters(stochasticprogram, stage),
                  moi_optimizer(stochasticprogram))
    end
    return nothing
end

function generate!(scenarioproblems::ScenarioProblems,
                   decision_generator::Function,
                   generator::Function,
                   decision_params::Any,
                   stage_params::Any,
                   optimizer)
    for i in nsubproblems(scenarioproblems)+1:nscenarios(scenarioproblems)
        push!(scenarioproblems.problems, _stage_model(decision_generator,
                                                      generator,
                                                      decision_params,
                                                      stage_params,
                                                      scenario(scenarioproblems,i),
                                                      decision_variables(scenarioproblems),
                                                      optimizer))
    end
    return nothing
end
function generate!(scenarioproblems::DScenarioProblems,
                   decision_generator::Function,
                   generator::Function,
                   decision_params::Any,
                   stage_params::Any,
                   optimizer)
    @sync begin
        for w in workers()
            @async remotecall_fetch((sp,decision_generator,generator,decision_params,params,optimizer)->
                                    generate!(fetch(sp),
                                              decision_generator,
                                              generator,
                                              decision_params,
                                              params,
                                              optimizer),
                                    w,
                                    scenarioproblems[w-1],
                                    decision_generator,
                                    generator,
                                    decision_params,
                                    stage_params,
                                    optimizer)
        end
    end
    return nothing
end

function clear_stage!(structure::VerticalBlockStructure{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    if s == 1
        empty!(first_stage(stochasticprogram))
    else
        clear!(scenarioproblems(structure, s))
    end
    return nothing
end
