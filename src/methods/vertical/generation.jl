# Vertical generation #
# ========================== #
function generate!(stochasticprogram::StochasticProgram{N}, structure::VerticalStructure{N}) where N
    # Generate all stages
    for stage in 1:N
        generate!(stochasticprogram, structure, stage)
    end
    return nothing
end

function generate!(stochasticprogram::StochasticProgram{N}, structure::VerticalStructure{N}, stage::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    if stage == 1
        # Check generators
        has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
        # Set the optimizer (if any)
        if has_provided_optimizer(stochasticprogram.optimizer)
            master_opt = master_optimizer(stochasticprogram)
            if master_opt != nothing
                set_optimizer(structure.first_stage, master_opt)
            end
        end
        # Prepare decisions
        structure.first_stage.ext[:decisions] = Decisions((structure.decisions[1],))
        add_decision_bridges!(structure.first_stage)
        # Generate first stage
        generator(stochasticprogram, :stage_1)(structure.first_stage, stage_parameters(stochasticprogram, 1))
    else
        # Check generators
        stage_key = Symbol(:stage_, stage)
        decision_key = Symbol(:stage_, stage - 1, :_decisions)
        has_generator(stochasticprogram, stage_key) || error("Stage problem $stage not defined in stochastic program. Consider @stage $stage.")
        has_generator(stochasticprogram, decision_key) || error("No decision variables defined in stage problem $(stage-1).")
        # Sanity check on scenario probabilities
        if num_scenarios(stochasticprogram, stage) > 0
            p = stage_probability(stochasticprogram, stage)
            abs(p - 1.0) <= 1e-6 || @warn "Scenario probabilities do not add up to one. The probability sum is given by $p"
        end
        # Generate
        generate_vertical!(scenarioproblems(structure, stage),
                           stage,
                           generator(stochasticprogram, decision_key),
                           generator(stochasticprogram, stage_key),
                           stage_parameters(stochasticprogram, stage - 1),
                           stage_parameters(stochasticprogram, stage),
                           structure.decisions[stage],
                           subproblem_optimizer(stochasticprogram))
    end
    return nothing
end

function generate_vertical!(scenarioproblems::ScenarioProblems,
                            stage::Integer,
                            decision_generator::Function,
                            generator::Function,
                            decision_params::Any,
                            stage_params::Any,
                            decision_map::DecisionMap,
                            optimizer)
    for i in num_subproblems(scenarioproblems)+1:num_scenarios(scenarioproblems)
        # Create subproblem
        subproblem = optimizer == nothing ? Model() : Model(optimizer)
        # Prepare decisions
        decisions = ntuple(Val{stage}()) do s
            if s == stage - 1
                # Known decisions from the previous stages are
                # the same everywhere.
                decision_map
            else
                # Remaining decisions are unique to each subproblem
                DecisionMap()
            end
        end
        subproblem.ext[:decisions] = Decisions(decisions; is_node = true)
        add_decision_bridges!(subproblem)
        # Generate and return the stage model
        decision_generator(subproblem, decision_params)
        generator(subproblem, stage_params, scenario(scenarioproblems, i))
        push!(scenarioproblems.problems, subproblem)
    end
    return nothing
end
function generate_vertical!(scenarioproblems::DistributedScenarioProblems,
                            stage::Integer,
                            decision_generator::Function,
                            generator::Function,
                            decision_params::Any,
                            stage_params::Any,
                            ::DecisionMap,
                            optimizer)
    @sync begin
        for w in workers()
            @async remotecall_fetch(
                w,
                scenarioproblems[w-1],
                stage,
                decision_generator,
                generator,
                decision_params,
                stage_params,
                scenarioproblems.decisions[w-1],
                optimizer) do sp, stage, dgenerator, generator, dparams, params, decisions, opt
                    generate_vertical!(fetch(sp),
                                       stage,
                                       dgenerator,
                                       generator,
                                       dparams,
                                       params,
                                       fetch(decisions),
                                       opt)
                end
        end
    end
    return nothing
end

function clear!(structure::VerticalStructure{N}) where N
    # Clear decisions
    clear!(structure.decisions)
    # Clear all stages
    for stage in 1:N
        clear_stage!(structure, stage)
    end
    return nothing
end

function clear_stage!(structure::VerticalStructure{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    if s == 1
        empty!(structure.first_stage)
    else
        clear!(scenarioproblems(structure, s))
    end
    return nothing
end

# Getters #
# ========================== #
function first_stage(stochasticprogram::StochasticProgram, structure::VerticalStructure; optimizer = nothing)
    if optimizer == nothing
        return structure.first_stage
    end
    stage_one = copy(structure.first_stage)
    set_optimizer(stage_one, optimizer)
    return stage_one
end
