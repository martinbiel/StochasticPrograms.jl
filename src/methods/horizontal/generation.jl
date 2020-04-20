# Block-horizontal generation #
# ========================== #
function generate!(stochasticprogram::StochasticProgram{N}, structure::HorizontalBlockStructure{N}) where N
    # Generate all stages
    for stage in 1:N
        generate!(stochasticprogram, structure, stage)
    end
    return nothing
end

function generate!(stochasticprogram::TwoStageStochasticProgram, structure::HorizontalBlockStructure{2}, stage::Integer)
    stage == 1 && return nothing
    stage == 2 || error("Stage $stage not available in two-stage model.")
    # Check generators
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Consider @stage 2.")
    # Sanity check on scenario probabilities
    if num_scenarios(structure, stage) > 0
        p = stage_probability(structure, stage)
        abs(p - 1.0) <= 1e-6 || @warn "Scenario probabilities do not add up to one. The probability sum is given by $p"
    end
    # Generate
    generate_horizontal!(scenarioproblems(structure, stage),
                         generator(stochasticprogram, :stage_1),
                         generator(stochasticprogram, :stage_2),
                         stage_parameters(stochasticprogram, 1),
                         stage_parameters(stochasticprogram, 2),
                         structure.decisions[stage - 1],
                         moi_optimizer(stochasticprogram))
    return nothing
end

function generate_horizontal!(scenarioproblems::ScenarioProblems,
                              stage_one_generator::Function,
                              stage_two_generator::Function,
                              stage_one_params::Any,
                              stage_two_params::Any,
                              decisions::Decisions,
                              optimizer)
    for i in num_subproblems(scenarioproblems)+1:num_scenarios(scenarioproblems)
        push!(scenarioproblems.problems, _WS(stage_one_generator,
                                             stage_two_generator,
                                             stage_one_params,
                                             stage_two_params,
                                             scenario(scenarioproblems,i),
                                             decisions,
                                             optimizer))
    end
    return nothing
end
function generate_horizontal!(scenarioproblems::DistributedScenarioProblems,
                              stage_one_generator::Function,
                              stage_two_generator::Function,
                              stage_one_params::Any,
                              stage_two_params::Any,
                              decisions::Decisions,
                              optimizer)
    @sync begin
        for w in workers()
            @async remotecall_fetch(
                w,
                scenarioproblems[w-1],
                stage_one_generator,
                stage_two_generator,
                stage_one_params,
                stage_two_params,
                scenarioproblems.decisions[w-1],
                optimizer) do (sp,gen_one,gen_two,one_params,two_params,decisions,opt)
                    generate!(fetch(sp),
                              gen_one,
                              gen_two,
                              one_params,
                              two_params,
                              decisions,
                              opt)
                end
        end
    end
    return nothing
end

function clear(structure::HorizontalBlockStructure{N}) where N
    # Clear all stages
    for stage in 1:N
        clear_stage!(structure, stage)
    end
    return nothing
end

function clear_stage!(structure::HorizontalBlockStructure{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    if s == 1
        empty!(first_stage(stochasticprogram))
    else
        clear!(scenarioproblems(structure, s))
    end
    return nothing
end
