# Stage generation #
# ========================== #
"""
    stage_one_model(stochasticprogram::StochasticProgram)

Return a generated copy of the first stage model in `stochasticprogram`.
"""
function stage_one_model(stochasticprogram::StochasticProgram, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    model = optimizer_factory == nothing ? Model() : Model(optimizer_factory)
    generator(stochasticprogram, :stage_1)(model, stage_parameters(stochasticprogram, 1))
    return model
end
"""
    stage_model(stochasticprogram::StochasticProgram, stage::Integer, scenario::AbstractScenario)

Return a generated stage model corresponding to `scenario`, in `stochasticprogram`.
"""
function stage_model(stochasticprogram::StochasticProgram{N}, stage::Integer, scenario::AbstractScenario, optimizer_factory::Union{Nothing, OptimizerFactory}) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N")
    stage == 1 && return stage_one_model(stochasticprogram, optimizer_factory)
    stage_key = Symbol(:stage_, stage)
    decision_key = Symbol(:stage_, stage - 1, :_decisions)
    has_generator(stochasticprogram, stage_key) || error("Stage problem $stage not defined in stochastic program. Consider @stage $stage")
    has_generator(stochasticprogram, decision_key) || error("Decision variables for stage problem $(stage-1) not defined in stochastic program. Consider @stage $(stage-1)")
    return _stage_model(generator(stochasticprogram, decision_key),
                        stage_parameters(stochasticprogram, stage - 1),
                        generator(stochasticprogram, stage_key),
                        stage_parameters(stochasticprogram, stage),
                        scenario,
                        decision_variables(stochasticprogram, stage),
                        optimizer_factory)
end
function _stage_model(decision_generator::Function,
                      generator::Function,
                      decision_params::Any,
                      stage_params,
                      scenario::AbstractScenario,
                      decision_variables::DecisionVariables,
                      optimizer_factory::Union{Nothing, OptimizerFactory})
    stage_model = optimizer_factory == nothing ? Model() : Model(optimizer_factory)
    stage_model.ext[:decisionvariables] = decision_variables
    decision_generator(stage_model, decision_params)
    generator(stage_model, stage_params, scenario)
    return stage_model
end
function generate_stage_one!(stochasticprogram::StochasticProgram)
    haskey(stochasticprogram.problemcache, :stage_1) && return nothing
    has_generator(stochasticprogram, :stage) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    stochasticprogram.problemcache[:stage_1] = JuMP.Model()
    generator(stochasticprogram, :stage_1)(stochasticprogram.problemcache[:stage_1], stage_parameters(stochasticprogram, 1))
    return nothing
end
function generate!(scenarioproblems::ScenarioProblems{S},
                   decision_generator::Function,
                   generator::Function,
                   decision_params::Any,
                   stage_params::Any,
                   optimizer_factory::Union{Nothing, OptimizerFactory}) where S <: AbstractScenario
    for i in nsubproblems(scenarioproblems)+1:nscenarios(scenarioproblems)
        push!(scenarioproblems.problems, _stage_model(decision_generator,
                                                      generator,
                                                      decision_params,
                                                      stage_params,
                                                      scenario(scenarioproblems,i),
                                                      decision_variables(scenarioproblems),
                                                      optimizer_factory))
    end
    return nothing
end
function generate!(scenarioproblems::DScenarioProblems{S},
                   decision_generator::Function,
                   generator::Function,
                   decision_params::Any,
                   stage_params::Any,
                   optimizer_factory::Union{Nothing, OptimizerFactory}) where S <: AbstractScenario
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
function generate_stage!(stochasticprogram::StochasticProgram{N}, stage::Integer) where N
    1 <= stage <= N || error("Stage $s not in range 1 to $N")
    if stage == 1
        if haskey(stochasticprogram.problemcache, :stage_1)
            remove_stages!(stochasticprogram, 1)
            invalidate_cache!(stochasticprogram)
        end
        generate_stage_one!(stochasticprogram)
    else
        if nsubproblems(stochasticprogram, stage) > 0
            remove_stages!(stochasticprogram, stage)
            invalidate_cache!(stochasticprogram)
        end
        stage_key = Symbol(:stage_, stage)
        decision_key = Symbol(:stage_, stage - 1, :_decisions)
        has_generator(stochasticprogram, stage_key) || error("Stage problem $stage not defined in stochastic program. Consider @stage $stage.")
        has_generator(stochasticprogram, decision_key) || error("Decision variables for stage problem $(stage-1) not defined in stochastic program. Consider @stage $(stage-1)")
        if nscenarios(stochasticprogram, stage) > 0
            p = stage_probability(stochasticprogram, stage)
            abs(p - 1.0) <= 1e-6 || @warn "Scenario probabilities do not add up to one. The probability sum is given by $p"
        end
        generate!(scenarioproblems(stochasticprogram, stage),
                  generator(stochasticprogram, decision_key),
                  generator(stochasticprogram, stage_key),
                  stage_parameters(stochasticprogram, stage - 1),
                  stage_parameters(stochasticprogram, stage),
                  sp_optimizer_factory(stochasticprogram))
    end
    return nothing
end
"""
    generate!(stochasticprogram::StochasticProgram)

Generate the `stochasticprogram` using the model definitions from @stage and available data.
"""
function generate!(stochasticprogram::StochasticProgram{N}) where N
    for stage in 1:N
        generate_stage!(stochasticprogram, stage)
    end
    return stochasticprogram
end
# Deterministic equivalent generation #
# ========================== #
function generate_deterministic_equivalent(stochasticprogram::StochasticProgram{2})
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    # Check that the required generators have been defined
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Consider @stage 2.")
    # Create model
    dep_model = Model(moi_optimizer(stochasticprogram))
    # Define first-stage problem
    generator(stochasticprogram, :stage_1)(dep_model, stage_parameters(stochasticprogram, 1))
    dep_obj = objective_function(dep_model)
    # Define second-stage problems, renaming variables according to scenario.
    stage_two_params = stage_parameters(stochasticprogram, 2)
    visited_objs = collect(keys(object_dictionary(dep_model)))
    for (i, scenario) in enumerate(scenarios(stochasticprogram))
        generator(stochasticprogram,:stage_2)(dep_model, stage_two_params, scenario, dep_model)
        dep_obj += probability(scenario)*objective_function(dep_model)
        for (objkey,obj) ∈ filter(kv->kv.first ∉ visited_objs, object_dictionary(dep_model))
            newkey = if isa(obj, VariableRef)
                varname = add_subscript(name(obj), i)
                set_name(obj, varname)
                newkey = Symbol(varname)
            elseif isa(obj, AbstractArray{<:VariableRef})
                arrayname = add_subscript(objkey, i)
                for var in obj
                    splitname = split(name(var), "[")
                    varname = @sprintf("%s[%s", add_subscript(splitname[1],i), splitname[2])
                    set_name(var, varname)
                end
                newkey = Symbol(arrayname)
            elseif isa(obj,JuMP.ConstraintRef)
                arrayname = add_subscript(objkey, i)
                newkey = Symbol(arrayname)
            elseif isa(obj, AbstractArray{<:ConstraintRef})
                arrayname = add_subscript(objkey, i)
                newkey = Symbol(arrayname)
            else
                continue
            end
            dep_model.obj_dict[newkey] = obj
            delete!(dep_model.obj_dict, objkey)
            push!(visited_objs, newkey)
        end
    end
    set_objective_function(dep_model, dep_obj)
    return dep_model
end
# Outcome model generation #
# ========================== #
function _outcome_model!(outcome_model::JuMP.Model,
                         decision_generator::Function,
                         generator::Function,
                         decision_params::Any,
                         stage_params::Any,
                         decision_variables::DecisionVariables
                         decision::AbstractVector,
                         scenario::AbstractScenario)
    outcome_model.ext[:decisionvariables] = copy(decision_variables)
    update_decision_variables!(outcome_model, decision)
    decision_generator(outcome_model, decision_params)
    generator(outcome_model, stage_params, scenario)
    return outcome_model
end
"""
    outcome_model(stochasticprogram::TwoStageStochasticProgram,
                  decision::AbstractVector,
                  scenario::AbstractScenario;
                  optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)

Return the resulting second stage model if `decision` is the first-stage decision in scenario `i`, in `stochasticprogram`. Optionally, supply a capable `solver` to the outcome model.
"""
function outcome_model(stochasticprogram::StochasticProgram{2},
                       decision::AbstractVector,
                       scenario::AbstractScenario,
                       optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    has_generator(stochasticprogram,:stage_1_vars) || error("First-stage not defined in stochastic program. Consider @first_stage or @stage 1.")
    has_generator(stochasticprogram,:stage_2) || error("Second-stage problem not defined in stochastic program. Consider @second_stage.")
    outcome_model = optimizer_factory == nothing ? Model() : Model(optimizer_factory)
    _outcome_model!(outcome_model,
                    generator(stochasticprogram,:stage_1_vars),
                    generator(stochasticprogram,:stage_2),
                    stage_parameters(stochasticprogram, 1),
                    stage_parameters(stochasticprogram, 2),
                    decision_variables(stochasticprogram, 1),
                    decision,
                    scenario)
    return outcome_model
end
"""
    outcome_model(stochasticprogram::StochasticProgram{N},
                  decisions::NTuple{N-1,AbstractVector}
                  scenario_path::NTuple{N-1,AbstractScenario},
                  solver::MOI.AbstractOptimizer)

Return the resulting `N`:th stage model if `decisions` are the decisions taken in the previous stages and `scenario_path` are the realized scenarios up to stage `N` in `stochasticprogram`. Optionally, supply a capable `solver` to the outcome model.
"""
function outcome_model(stochasticprogram::StochasticProgram{N},
                       decisions::NTuple{M,AbstractVector},
                       scenario_path::NTuple{M,AbstractScenario};
                       solver::MOI.AbstractOptimizer = UnsetSolver()) where {N,M}
    N == M - 1 || error("Inconsistent number of stages $N and number of decisions and scenarios $M")
    # TODO
end
# ========================== #
