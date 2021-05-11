# Checkers #
# ========================== #
check_generators(stochasticprogram::StochasticProgram{N}) where N = _check_generators(stochasticprogram, Val(N))
function _check_generators(stochasticprogram::StochasticProgram, ::Val{N}) where N
    _check_stage_generator(stochasticprogram, N)
    _check_generators(stochasticprogram, Val(N-1))
    return nothing
end
function _check_generators(stochasticprogram::StochasticProgram, ::Val{1})
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    return nothing
end
function _check_stage_generator(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    stage_key = Symbol(:stage_, s)
    has_generator(stochasticprogram, stage_key) || error("Stage problem $stage not defined in stochastic program. Consider @stage $stage.")
    return nothing
end
# Model generation #
# ========================== #
"""
    stage_one_model(stochasticprogram::StochasticProgram; optimizer = nothing)

Return a generated copy of the first stage model in `stochasticprogram`. Optionally, supply a capable `optimizer` to the stage model.
"""
function stage_one_model(stochasticprogram::StochasticProgram; optimizer = nothing)
    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache, :stage_1)
        m = cache[:stage_1]
        optimizer != nothing && set_optimizer(m, optimizer)
        return m
    end
    # Check that the required generators have been defined
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    model = optimizer == nothing ? Model() : Model(optimizer)
    # Prepare decisions
    model.ext[:decisions] = Decisions(Val{1}())
    add_decision_bridges!(model)
    # Generate and cache first-stage model
    generator(stochasticprogram, :stage_1)(model, stage_parameters(stochasticprogram, 1))
    cache[:stage_1] = model
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
    # Check generators
    stage_key = Symbol(:stage_, stage)
    decision_key = Symbol(:stage_, stage - 1, :_decisions)
    has_generator(stochasticprogram, stage_key) || error("Stage problem $stage not defined in stochastic program. Consider @stage $stage")
    has_generator(stochasticprogram, decision_key) || error("No decision variables defined in stage problem $(stage-1).")
    # Create stage model
    stage_model = optimizer == nothing ? Model() : Model(optimizer)
    # Prepare decisions
    stage_model.ext[:decisions] = Decisions(stage)
    add_decision_bridges!(stage_model)
    # Generate and return the stage model
    generator(stochasticprogram, decision_key)(stage_model, decision_params)
    generator(stochasticprogram, stage_key)(stage_model, stage_params, scenario)
    return stage_model
end
function generate_stage_one!(stochasticprogram::StochasticProgram)
    haskey(stochasticprogram.problemcache, :stage_1) && return nothing
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    stochasticprogram.problemcache[:stage_1] = JuMP.Model()
    generator(stochasticprogram, :stage_1)(stochasticprogram.problemcache[:stage_1], stage_parameters(stochasticprogram, 1))
    return nothing
end

function generate_proxy!(stochasticprogram::StochasticProgram{N}) where N
    # First-stage decisions are unique (reuse)
    proxy(stochasticprogram, 1).ext[:decisions] = Decisions((stochasticprogram.decisions[1],))
    # Generate first stage
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    generator(stochasticprogram, :stage_1)(proxy(stochasticprogram, 1), stage_parameters(stochasticprogram, 1))
    # Generate remaining stages
    for s in 2:N
        # Initialize decisions
        decisions = ntuple(Val{s}()) do i
            if i == s - 1
                # Known decisions from the previous stages are
                # the same everywhere.
                return stochasticprogram.decisions[s]
            end
            return DecisionMap()
        end
        proxy(stochasticprogram, s).ext[:decisions] = Decisions(decisions)
        # Check generator
        stage_key = Symbol(:stage_, s)
        decision_key = Symbol(:stage_, s - 1, :_decisions)
        has_generator(stochasticprogram, stage_key) || error("Stage problem $stage not defined in stochastic program. Consider @stage $stage.")
        has_generator(stochasticprogram, decision_key) || error("No decision variables defined in stage problem $(stage-1).")
        # Generate
        generator(stochasticprogram, decision_key)(proxy(stochasticprogram, s), stage_parameters(stochasticprogram, s-1))
        generator(stochasticprogram, stage_key)(proxy(stochasticprogram, s), stage_parameters(stochasticprogram, s), scenario(stochasticprogram, s, 1))
    end
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
    clear!(structure(stochasticprogram))
    # Clear proxy
    for s in 1:N
        proxy_ = proxy(stochasticprogram, s)
        # Clear decisions
        if haskey(proxy_.ext, :decisions)
            clear!(proxy_.ext[:decisions])
        end
        # Clear model
        empty!(proxy_)
    end
    return nothing
end
"""
    generate!(stochasticprogram::StochasticProgram)

Generate the `stochasticprogram` using the model definitions from @stage and available data.
"""
function generate!(stochasticprogram::StochasticProgram{N}) where N
    # Clear stochasticprogram before re-generation
    clear!(stochasticprogram)
    # Abort early if there are no scenarios
    num_scenarios(stochasticprogram) == 0 && return nothing
    # Check generators
    check_generators(stochasticprogram::StochasticProgram{N})
    # Generate proxy
    generate_proxy!(stochasticprogram)
    # Dispatch generation on stochastic structure
    generate!(stochasticprogram, structure(stochasticprogram))
    return nothing
end
# Outcome model generation #
# ========================== #
function _outcome_model!(outcome_model::JuMP.Model,
                         decision_generator::Function,
                         generator::Function,
                         decision_params::Any,
                         stage_params::Any,
                         stage_one_model::JuMP.Model,
                         decisions::AbstractVector,
                         scenario::AbstractScenario)
    # Prepare decisions
    outcome_model.ext[:decisions] = Decisions(Val{2}())
    add_decision_bridges!(outcome_model)
    # Generate the outcome model
    decision_generator(outcome_model, decision_params)
    generator(outcome_model, stage_params, scenario)
    # Copy first-stage objective
    copy_decision_objective!(stage_one_model,
                             outcome_model,
                             all_known_decision_variables(outcome_model, 1))
    # Update the known decision values
    update_known_decisions!(outcome_model.ext[:decisions][1], decisions)
    update_known_decisions!(outcome_model)
    return nothing
end
"""
    outcome_model(stochasticprogram::TwoStageStochasticProgram,
                  decision::AbstractVector,
                  scenario::AbstractScenario;
                  optimizer = nothing)

Return the resulting second stage model if `decision` is the first-stage decision in the provided `scenario`, in `stochasticprogram`. The supplied `decision` must match the defined decision variables in `stochasticprogram`. Optionally, supply a capable `optimizer` to the outcome model.
"""
function outcome_model(stochasticprogram::TwoStageStochasticProgram,
                       decision::AbstractVector,
                       scenario::AbstractScenario;
                       optimizer = nothing)
    # Check generators
    has_generator(stochasticprogram,:stage_1_decisions) || error("First-stage not defined in stochastic program. Consider @first_stage or @stage 1.")
    has_generator(stochasticprogram,:stage_2) || error("Second-stage problem not defined in stochastic program. Consider @second_stage.")
    # Sanity checks on given decision vector
    length(decision) == num_decisions(stochasticprogram) || error("Incorrect length of given decision vector, has ", length(decision), " should be ", num_decisions(stochasticprogram))
    all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
    # Create outcome model
    outcome_model = optimizer == nothing ? Model() : Model(optimizer)
    _outcome_model!(outcome_model,
                    generator(stochasticprogram,:stage_1_decisions),
                    generator(stochasticprogram,:stage_2),
                    stage_parameters(stochasticprogram, 1),
                    stage_parameters(stochasticprogram, 2),
                    stage_one_model(stochasticprogram),
                    decision,
                    scenario)
    return outcome_model
end
"""
    outcome_model(stochasticprogram::StochasticProgram{N},
                  decisions::NTuple{N-1,AbstractVector}
                  scenario_path::NTuple{N-1,AbstractScenario},
                  optimizer = nothing)

Return the resulting `N`:th stage model if `decisions` are the decisions taken in the previous stages and `scenario_path` are the realized scenarios up to stage `N` in `stochasticprogram`. Optionally, supply a capable `solver` to the outcome model.
"""
function outcome_model(stochasticprogram::StochasticProgram{N},
                       decisions::NTuple{M,AbstractVector},
                       scenario_path::NTuple{M,AbstractScenario};
                       optimizer = nothing) where {N,M}
    N == M - 1 || error("Inconsistent number of stages $N and number of decisions and scenarios $M")
    # TODO
end
# ========================== #
