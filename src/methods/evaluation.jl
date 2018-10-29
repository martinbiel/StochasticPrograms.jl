# Problem evaluation #
# ========================== #
function _eval_first_stage(stochasticprogram::JuMP.Model, x::AbstractVector)
    return eval_objective(stochasticprogram.obj,x)
end
function _eval_second_stage(stochasticprogram::JuMP.Model, x::AbstractVector, scenario::AbstractScenarioData,solver::MathProgBase.AbstractMathProgSolver)
    outcome = outcome_model(stochasticprogram,scenario,x,solver)
    solve(outcome)

    return probability(scenario)*getobjectivevalue(outcome)
end
function _eval_second_stages(stochasticprogram::StochasticProgram{D1,D2,SD,S,ScenarioProblems{D2,SD,S}},
                             x::AbstractVector,
                             solver::MathProgBase.AbstractMathProgSolver) where {D1, D2, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return sum([begin
                outcome = _outcome_model(stochasticprogram.generator[:stage_1_vars],
                                         stochasticprogram.generator[:stage_2],
                                         stochasticprogram.first_stage.data,
                                         stage_data(stochasticprogram.scenarioproblems),
                                         scenario,
                                         x,
                                         solver)
                solve(outcome)
                probability(scenario)*getobjectivevalue(outcome)
                end for scenario in scenarios(stochasticprogram.scenarioproblems)])
end
function _eval_second_stages(stochasticprogram::StochasticProgram{D1, D2, SD,S,DScenarioProblems{D2,SD,S}},
                             x::AbstractVector,
                             solver::MathProgBase.AbstractMathProgSolver) where {D1, D2, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    active_workers = Vector{Future}(undef,nworkers())
    for w in workers()
        active_workers[w-1] = remotecall((sp,stage_one_generator,stage_two_generator,x,first_stage,second_stage,solver)->begin
                                         scenarioproblems = fetch(sp)
                                         isempty(scenarioproblems.scenariodata) && return zero(eltype(x))
                                         return sum([begin
                                                     outcome = _outcome_model(stage_one_generator,
                                                                              stage_two_generator,
                                                                              first_stage,
                                                                              second_stage,
                                                                              scenario,
                                                                              x,
                                                                              solver)
                                                     solve(outcome)
                                                     probability(scenario)*getobjectivevalue(outcome)
                                                     end for scenario in scenarioproblems.scenariodata])
                                         end,
                                         w,
                                         stochasticprogram.scenarioproblems[w-1],
                                         stochasticprogram.generator[:stage_1_vars],
                                         stochasticprogram.generator[:stage_2],
                                         x,
                                         stochasticprogram.first_stage.data,
                                         stage_data(stochasticprogram.scenarioproblems),
                                         solver)
    end
    map(wait,active_workers)
    return sum(fetch.(active_workers))
end
function _eval(stochasticprogram::JuMP.Model,x::AbstractVector,solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    length(x) == stochasticprogram.numCols || error("Incorrect length of given decision vector, has ",length(x)," should be ",stochasticprogram.numCols)
    all(.!(isnan.(x))) || error("Given decision vector has NaN elements")

    val = _eval_first_stage(stochasticprogram,x)
    val += _eval_second_stages(stochastic(stochasticprogram),x,solver)

    return val
end
"""
    evaluate_decision(stochasticprogram::JuMP.Model,
                      x::AbstractVector;
                      solver = JuMP.UnsetSolver())

Evaluates the first stage decision `x` in `stochasticprogram`. This involves evaluatin the first stage objective at `x` as well as solving outcome models of `x` for every available scenario. Optionally, a capable `solver` can be supplied to solve the outome models. The default behaviour is to rely on any previously set solver.
"""
function eval_decision(stochasticprogram::JuMP.Model,x::AbstractVector; solver = JuMP.UnsetSolver())
    # Prefer cached solver if available
    supplied_solver = pick_solver(stochasticprogram,solver)
    # Abort if no solver was given
    if isa(supplied_solver,JuMP.UnsetSolver)
        error("Cannot evaluate decision without a solver.")
    end
    return _eval(stochasticprogram,x,optimsolver(supplied_solver))
end
# ========================== #
