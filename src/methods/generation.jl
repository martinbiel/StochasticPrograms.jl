# Problem generation #
# ========================== #
"""
    stage_one_model(stochasticprogram::StochasticProgram)

Return a generated copy of the first stage model in `stochasticprogram`.
"""
function stage_one_model(stochasticprogram::StochasticProgram; solver = UnsetSolver())
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    stage_one_model = Model()
    generator(stochasticprogram, :stage_1)(stage_one_model, stage_parameters(stochasticprogram, 1))
    return stage_one_model
end
function _stage_model(generator::Function, stage_params::Any, scenario::AbstractScenario, parent::JuMP.Model)
    stage_model = Model()
    generator(stage_model, stage_params, scenario, parent)
    return stage_model
end
"""
    stage_two_model(stochasticprogram::StochasticProgram)

Return a generated second stage model corresponding to `scenario`, in `stochasticprogram`.
"""
function stage_model(stochasticprogram::StochasticProgram{N}, stage::Integer, scenario::AbstractScenario; solver = UnsetSolver()) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N")
    stage == 1 && return stage_one_model(stochasticprogram; solver = solver)
    stage_key = Symbol(:stage_, stage)
    has_generator(stochasticprogram, stage_key) || error("Stage problem $stage not defined in stochastic program. Consider @stage $stage")
    return _stage_model(generator(stochasticprogram, stage_key),
                        stage_parameters(stochasticprogram, stage),
                        scenario,
                        parentmodel(stochasticprogram, stage))
end
function generate_parent!(scenarioproblems::ScenarioProblems, generator::Function, parent_params::Any)
    generator(parentmodel(scenarioproblems), parent_params)
    return nothing
end
function generate_parent!(scenarioproblems::DScenarioProblems, generator::Function, parent_params::Any)
    generator(parentmodel(scenarioproblems), parent_params)
    @sync begin
        for w in workers()
            @async remotecall_fetch((sp,generator,params)->generate_parent!(fetch(sp),generator,params),
                                    w,
                                    scenarioproblems[w-1],
                                    generator,
                                    parent_params)
        end
    end
    return nothing
end
function generate_parent!(stochasticprogram::StochasticProgram, stage::Integer)
    if stage == 1
        @warn "The first stage has no predecessors."
        return nothing
    end
    parent_key = Symbol(:stage_, stage - 1, :_vars)
    has_generator(stochasticprogram, parent_key) || error("Stage problem $(stage - 1) not defined in stochastic program. Consider @stage $(stage - 1).")
    generate_parent!(scenarioproblems(stochasticprogram, stage), generator(stochasticprogram, parent_key), stage_parameters(stochasticprogram, stage - 1))
    return nothing
end
function generate_stage_one!(stochasticprogram::StochasticProgram)
    haskey(stochasticprogram.problemcache, :stage_1) && return nothing
    has_generator(stochasticprogram, :stage_1) && has_generator(stochasticprogram, :stage_1_vars) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    stochasticprogram.problemcache[:stage_1] = JuMP.Model()
    generator(stochasticprogram, :stage_1)(stochasticprogram.problemcache[:stage_1], stage_parameters(stochasticprogram, 1))
    return nothing
end
function generate!(scenarioproblems::ScenarioProblems{S}, stage_params::Any, generator::Function) where S <: AbstractScenario
    for i in nsubproblems(scenarioproblems)+1:nscenarios(scenarioproblems)
        push!(scenarioproblems.problems, _stage_model(generator, stage_params, scenario(scenarioproblems,i), parentmodel(scenarioproblems)))
    end
    return nothing
end
function generate!(scenarioproblems::DScenarioProblems{S}, stage_params::Any, generator::Function) where S <: AbstractScenario
    @sync begin
        for w in workers()
            @async remotecall_fetch((sp,params,generator)->generate!(fetch(sp), params, generator), w, scenarioproblems[w-1], stage_params, generator)
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
        generate_parent!(stochasticprogram, 2)
    else
        if nsubproblems(stochasticprogram, stage) > 0
            remove_stages!(stochasticprogram, stage)
            invalidate_cache!(stochasticprogram)
        end
        stage_key = Symbol(:stage_, stage)
        has_generator(stochasticprogram, stage_key) || error("Stage problem $stage not defined in stochastic program. Consider @stage $stage.")
        if nscenarios(stochasticprogram, stage) > 0
            p = stage_probability(stochasticprogram, stage)
            abs(p - 1.0) <= 1e-6 || @warn "Scenario probabilities do not add up to one. The probability sum is given by $p"
        end
        stage < N && generate_parent!(stochasticprogram, stage + 1)
        generate!(scenarioproblems(stochasticprogram, stage),
                  stage_parameters(stochasticprogram, stage),
                  generator(stochasticprogram, stage_key))
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

function _outcome_model!(outcome_model::JuMP.Model,
                         stage_one_generator::Function,
                         stage_two_generator::Function,
                         stage_one_params::Any,
                         stage_two_params::Any,
                         decision::AbstractVector,
                         scenario::AbstractScenario)
    stage_one_generator(outcome_model, stage_one_params)
    for obj in values(outcome_model.obj_dict)
        if isa(obj, VariableRef)
            val = decision[index(obj).value]
            fix(obj, val, force = true)
        elseif isa(obj, AbstractArray{<:VariableRef})
            for var in obj
                val = decision[index(var).value]
                fix(var, val, force = true)
            end
        else
            continue
        end
    end
    stage_two_generator(outcome_model, stage_two_params, scenario, outcome_model)
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
