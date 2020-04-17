# Checkers #
# ========================== #
_check_generators(stochasticprogram::StochasticProgram{N}) where N = _check_generators(stochasticprogram, Val(N))
function _check_generators(stochasticprogram::StochasticProgram, ::Val{N}) where N
    return _check_stage_generator(stochasticprogram, N) && _check_generators(stochasticprogram, Val(N-1))
end
function _check_generators(stochasticprogram::StochasticProgram, ::Val{1})
    return has_generator(stochasticprogram, :stage_1)
end
function _check_stage_generator(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    stage_key = Symbol(:stage_, s)
    return has_generator(stochasticprogram, stage_key)
end
# Decision variable generation #
# ========================== #
function generate_decision_variables!(stochasticprogram::StochasticProgram{N}) where N
    # Auxiliary JuMP model to hold all decisions
    aux_model = Model()
    # Generate all stages
    for stage in 1:N
        clear_decision_variables!(decision_variables(stochasticprogram, stage))
        decision_key = Symbol(:stage_, stage, :_decisions)
        has_generator(stochasticprogram, decision_key) || error("No decision variables defined in stage $stage.")
        aux_model.ext[:decisionvariables] = decision_variables(stochasticprogram, stage)
        generator(stochasticprogram, decision_key)(aux_model, stage_parameters(stochasticprogram, stage))
    end
    return stochasticprogram
end
# Model generation #
# ========================== #
"""
    stage_one_model(stochasticprogram::StochasticProgram; optimizer = nothing)

Return a generated copy of the first stage model in `stochasticprogram`. Optionally, supply a capable `optimizer` to the stage model.
"""
function stage_one_model(stochasticprogram::StochasticProgram; optimizer = nothing)
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    model = optimizer == nothing ? Model() : Model(optimizer)
    generator(stochasticprogram, :stage_1)(model, stage_parameters(stochasticprogram, 1))
    return model
end
"""
    stage_model(stochasticprogram::StochasticProgram, stage::Integer, scenario::AbstractScenario; optimizer = nothing)

Return a generated stage model corresponding to `scenario`, in `stochasticprogram`. Optionally, supply a capable `optimizer` to the stage model.
"""
function stage_model(stochasticprogram::StochasticProgram{N},
                     stage::Integer,
                     scenario::AbstractScenario;
                     optimizer = nothing) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N")
    stage == 1 && return stage_one_model(stochasticprogram, optimizer)
    stage_key = Symbol(:stage_, stage)
    decision_key = Symbol(:stage_, stage - 1, :_decisions)
    has_generator(stochasticprogram, stage_key) || error("Stage problem $stage not defined in stochastic program. Consider @stage $stage")
    has_generator(stochasticprogram, decision_key) || error("No decision variables defined in stage problem $(stage-1).")
    return _stage_model(generator(stochasticprogram, decision_key),
                        stage_parameters(stochasticprogram, stage - 1),
                        generator(stochasticprogram, stage_key),
                        stage_parameters(stochasticprogram, stage),
                        scenario,
                        copy(decision_variables(stochasticprogram, stage)),
                        optimizer)
end
function _stage_model(decision_generator::Function,
                      generator::Function,
                      decision_params::Any,
                      stage_params,
                      scenario::AbstractScenario,
                      decision_variables::DecisionVariables,
                      optimizer_constructor)
    stage_model = optimizer_constructor == nothing ? Model() : Model(optimizer_constructor)
    stage_model.ext[:decisionvariables] = decision_variables
    decision_generator(stage_model, decision_params)
    generator(stage_model, stage_params, scenario)
    return stage_model
end
function generate_stage_one!(stochasticprogram::StochasticProgram)
    haskey(stochasticprogram.problemcache, :stage_1) && return nothing
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    stochasticprogram.problemcache[:stage_1] = JuMP.Model()
    generator(stochasticprogram, :stage_1)(stochasticprogram.problemcache[:stage_1], stage_parameters(stochasticprogram, 1))
    return nothing
end

"""
    clear!(stochasticprogram::StochasticProgram)

Clear the `stochasticprogram`, removing all model definitions.
"""
function clear!(stochasticprogram::StochasticProgram{N}) where N
    # Clearing invalidates the cache
    invalidate_cache!(stochasticprogram)
    # Dispatch clearup on stochastic structure
    clear!(stochasticprogram, structure(stochasticprogram))
    return nothing
end
"""
    generate!(stochasticprogram::StochasticProgram)

Generate the `stochasticprogram` using the model definitions from @stage and available data.
"""
function generate!(stochasticprogram::StochasticProgram{N}) where N
    if !deferred(stochasticprogram)
        # Clear stochasticprogram before re-generation
        clear!(stochasticprogram)
    end
    # Dispatch generation on stochastic structure
    generate!(stochasticprogram, structure(stochasticprogram))
    return stochasticprogram
end
# Outcome model generation #
# ========================== #
function _outcome_model!(outcome_model::JuMP.Model,
                         decision_generator::Function,
                         generator::Function,
                         decision_params::Any,
                         stage_params::Any,
                         decision_variables::DecisionVariables,
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
                  decision::Union{AbstractVector, DecisionVariables},
                  scenario::AbstractScenario;
                  optimizer = nothing)

Return the resulting second stage model if `decision` is the first-stage decision in the provided `scenario`, in `stochasticprogram`. The supplied `decision` must be of type `AbstractVector` or `DecisionVariables`, and must match the defined decision variables in `stochasticprogram`. Optionally, supply a capable `optimizer` to the outcome model.
"""
function outcome_model(stochasticprogram::TwoStageStochasticProgram,
                       decision::DecisionVariables,
                       scenario::AbstractScenario;
                       optimizer = nothing)
    # Sanity checks on given decision vector
    decision_names(decision_variables(stochasticprogram)) == decision_names(decision) || error("Given decision does not match decision variables in stochastic program.")
    return outcome_model(stochasticprogram, decisions(decision), scenario; optimizer = optimizer)
end
function outcome_model(stochasticprogram::TwoStageStochasticProgram,
                       decision::AbstractVector,
                       scenario::AbstractScenario;
                       optimizer = nothing)
    has_generator(stochasticprogram,:stage_1_decisions) || error("First-stage not defined in stochastic program. Consider @first_stage or @stage 1.")
    has_generator(stochasticprogram,:stage_2) || error("Second-stage problem not defined in stochastic program. Consider @second_stage.")
    outcome_model = optimizer == nothing ? Model() : Model(optimizer)
    _outcome_model!(outcome_model,
                    generator(stochasticprogram,:stage_1_decisions),
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
