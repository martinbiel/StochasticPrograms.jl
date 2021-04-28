# Horizontal generation #
# ========================== #
function generate!(stochasticprogram::StochasticProgram{N}, structure::HorizontalStructure{N}) where N
    # Generate all stages
    for stage in 2:N
        generate!(stochasticprogram, structure, stage)
    end
    return nothing
end

function generate!(stochasticprogram::TwoStageStochasticProgram, structure::HorizontalStructure{2}, stage::Integer)
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
                         structure.decisions[stage-1],
                         subproblem_optimizer(stochasticprogram))
    # Generate constraint map
    first_stage_constraints = CI[]
    # Do not need to map any first-stage decision constraints
    for (F,S) in MOI.get(proxy(stochasticprogram, 1), MOI.ListOfConstraints())
        if is_decision_type(F)
            append!(first_stage_constraints, MOI.get(proxy(stochasticprogram, 1), MOI.ListOfConstraintIndices{F,S}()))
        end
    end
    # Create a temporary WS model
    proxy_ = proxy(stochasticprogram, 2)
    ws = WS(stochasticprogram, scenario(stochasticprogram, 1))
    for (F,S) in MOI.get(proxy_, MOI.ListOfConstraints())
        if is_decision_type(F)
            constraints =  filter(MOI.get(ws, MOI.ListOfConstraintIndices{F,S}())) do ci
                !(ci in first_stage_constraints)
            end
            proxy_constraints = MOI.get(proxy_, MOI.ListOfConstraintIndices{F,S}())
            for (proxy,ci) in zip(proxy_constraints, constraints)
                for scenario_index in 1:num_scenarios(stochasticprogram, 2)
                    structure.constraint_map[(proxy, scenario_index)] = typeof(ci)(ci.value)
                end
            end
        end
    end
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
                                             Decisions(),
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
                optimizer) do sp, gen_one, gen_two, one_params, two_params, decisions, opt
                    generate_horizontal!(fetch(sp),
                                         gen_one,
                                         gen_two,
                                         one_params,
                                         two_params,
                                         fetch(decisions),
                                         opt)
                end
        end
    end
    return nothing
end

function clear!(structure::HorizontalStructure{N}) where N
    # Clear decisions
    map(clear!, structure.decisions)
    # Clear all stages
    for stage in 2:N
        clear_stage!(structure, stage)
    end
    return nothing
end

function clear_stage!(structure::HorizontalStructure{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    clear!(scenarioproblems(structure, s))
    return nothing
end
