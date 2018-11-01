# Problem evaluation #
# ========================== #
function _eval_first_stage(stochasticprogram::StochasticProgram, x::AbstractVector)
    first_stage = get_stage_one(stochasticprogram)
    return eval_objective(first_stage.obj, x)
end
function _eval_second_stage(stochasticprogram::StochasticProgram, x::AbstractVector, scenario::AbstractScenario, solver::MPB.AbstractMathProgSolver)
    outcome = outcome_model(stochasticprogram, scenario, x, solver)
    solve(outcome)
    return probability(scenario)*getobjectivevalue(outcome)
end
function _eval_second_stages(stochasticprogram::StochasticProgram{D1,D2,SD,S,ScenarioProblems{D2,SD,S}},
                             x::AbstractVector,
                             solver::MPB.AbstractMathProgSolver) where {D1, D2, SD <: AbstractScenario, S <: AbstractSampler{SD}}
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
                             solver::MPB.AbstractMathProgSolver) where {D1, D2, SD <: AbstractScenario, S <: AbstractSampler{SD}}
    active_workers = Vector{Future}(undef,nworkers())
    for w in workers()
        active_workers[w-1] = remotecall((sp,stage_one_generator,stage_two_generator,x,first_stage,second_stage,solver)->begin
                                         scenarioproblems = fetch(sp)
                                         isempty(scenarioproblems.scenarios) && return zero(eltype(x))
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
                                                     end for scenario in scenarioproblems.scenarios])
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
function _eval(stochasticprogram::StochasticProgram, x::AbstractVector, solver::MPB.AbstractMathProgSolver)
    xlength = decision_length(stochasticprogram)
    length(x) == xlength || error("Incorrect length of given decision vector, has ", length(x), " should be ", xlength)
    all(.!(isnan.(x))) || error("Given decision vector has NaN elements")
    val = _eval_first_stage(stochasticprogram, x)
    val += _eval_second_stages(stochasticprogram, x, solver)
    return val
end
"""
    evaluate_decision(stochasticprogram::StochasticProgram,
                      x::AbstractVector;
                      solver = JuMP.UnsetSolver())

Evaluate the first stage decision `x` in `stochasticprogram`.

In other words, evaluate the first stage objective at `x` and solve outcome models of `x` for every available scenario. Optionally, supply a capable `solver` to solve the outcome models. Otherwise, any previously set solver will be used.
"""
function evaluate_decision(stochasticprogram::StochasticProgram, x::AbstractVector; solver::MPB.AbstractMathProgSolver = JuMP.UnsetSolver())
    # Prefer cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Abort if no solver was given
    if isa(supplied_solver, JuMP.UnsetSolver)
        error("Cannot evaluate decision without a solver.")
    end
    return _eval(stochasticprogram, x, internal_solver(supplied_solver))
end
# ========================== #
