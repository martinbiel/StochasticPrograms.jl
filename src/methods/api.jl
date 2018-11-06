# API (Two-stage) #
# ========================== #
"""
    optimize!(sp::StochasticProgram; solver::SPSolverType = JuMP.UnsetSolver())

Optimize `sp` after calls to `@first_stage sp = begin ... end` and `second_stage sp = begin ... end`, assuming scenarios are available.

`generate!(sp)` is called internally, so deferred models can be passed. Optionally, supply an AbstractMathProgSolver or an AbstractStructuredSolver as `solver`. Otherwise, any previously set solver will be used.

## Examples

The following solves the stochastic program `sp` using the L-shaped algorithm.

```julia
using LShapedSolvers
using GLPKMathProgInterface

optimize!(sp, solver = LShapedSolver(:ls, GLPKSolverLP()));

# output

L-Shaped Gap  Time: 0:00:01 (4 iterations)
  Objective:       -855.8333333333339
  Gap:             0.0
  Number of cuts:  7
:Optimal
```

The following solves the stochastic program `sp` using GLPK on the extended form.

```julia
using GLPKMathProgInterface

optimize!(sp, solver = GLPKSolverLP())

:Optimal
```

See also: [`VRP`](@ref)
"""
function optimize!(stochasticprogram::StochasticProgram; solver::SPSolverType = JuMP.UnsetSolver(), kwargs...)
    if deferred(stochasticprogram)
        generate!(stochasticprogram)
    end
    # Prefer cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Abort if no solver was given
    if isa(supplied_solver, JuMP.UnsetSolver)
        error("Cannot optimize without a solver.")
    end
    # Switch on solver type
    return _optimize!(stochasticprogram, supplied_solver; kwargs...)
end
function _optimize!(stochasticprogram::StochasticProgram, solver::MathProgBase.AbstractMathProgSolver; kwargs...)
    # Standard mathprogbase solver. Fallback to solving DEP, relying on JuMP.
    dep = DEP(stochasticprogram; solver = solver)
    status = solve(dep; kwargs...)
    stochasticprogram.spsolver.internal_model = dep.internalModel
    fill_solution!(stochasticprogram)
    return status
end
function _optimize!(stochasticprogram::StochasticProgram, solver::AbstractStructuredSolver; kwargs...)
    # Use structured solver
    structuredmodel = StructuredModel(stochasticprogram, solver)
    stochasticprogram.spsolver.internal_model = structuredmodel
    status = optimize_structured!(structuredmodel)
    fill_solution!(stochasticprogram, structuredmodel)
    # Now safe to generate the objective value of the stochastic program
    calculate_objective_value!(stochasticprogram)
    return status
end
"""
    optimal_decision(stochasticprogram::StochasticProgram)

Return the optimal first stage decision of `stochasticprogram`, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::StochasticProgram)
    decision = get_stage_one(stochasticprogram).colVal
    if any(isnan.(decision))
        @warn "Optimal decision not defined. Check that the model was properly solved."
    end
    return decision
end
"""
    optimal_decision(stochasticprogram::StochasticProgram, var::Symbol)

Return the optimal first stage variable `var` of `stochasticprogram`, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::StochasticProgram, var::Symbol)
    return getvalue(get_stage_one(stochasticprogram).objDict[var])
end
"""
    optimal_decision(stochasticprogram::StochasticProgram, i::Integer)

Return the optimal second stage decision of `stochasticprogram` in the `i`th scenario, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::StochasticProgram, i::Integer)
    submodel = subproblem(stochasticprogram, i)
    decision = submodel.colVal
    if any(isnan.(decision))
        @warn "Optimal decision not defined in subproblem $i. Check that the model was properly solved."
    end
    return decision
end
"""
    optimal_decision(stochasticprogram::StochasticProgram, var::Symbol)

Return the optimal second stage variable `var` of `stochasticprogram` in the `i`th scenario, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::StochasticProgram, i::Integer, var::Symbol)
    submodel = subproblem(stochasticprogram, i)
    return getvalue(subproblem.objDict[var])
end
"""
    optimal_value(stochasticprogram::StochasticProgram)

Return the optimal value of `stochasticprogram`, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_value(stochasticprogram::StochasticProgram)
    return get_stage_one(stochasticprogram).objVal
end
"""
    optimal_value(stochasticprogram::StochasticProgram, i::Integer)

Return the optimal value of the `i`th subproblem in `stochasticprogram`, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_value(stochasticprogram::StochasticProgram, i::Integer)
    submodel = subproblem(stochasticprogram, i)
    return submodel.objVal
end
"""
    scenarioproblems(stochasticprogram::StochasticProgram)

Return the scenario problems in `stochasticprogram`.
"""
function scenarioproblems(stochasticprogram::StochasticProgram)
    return stochasticprogram.scenarioproblems
end
"""
    first_stage_data(stochasticprogram::StochasticProgram)

Return the first stage data structure, if any exists, in `stochasticprogram`.
"""
function first_stage_data(stochasticprogram::StochasticProgram)
    return stochasticprogram.first_stage.data
end
"""
    decision_length(stochasticprogram::StochasticProgram)

Return the length of the first stage decision in `stochasticprogram`.
"""
function decision_length(stochasticprogram::StochasticProgram)
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @first_stage.")
    !haskey(stochasticprogram.problemcache, :stage_1) && return 0
    first_stage = get_stage_one(stochasticprogram)
    return first_stage.numCols
end
"""
    first_stage_nconstraints(stochasticprogram::StochasticProgram)

Return the number of constraints in the the first stage of `stochasticprogram`.
"""
function first_stage_nconstraints(stochasticprogram::StochasticProgram)
    !haskey(stochasticprogram.problemcache, :stage_1) && return 0
    first_stage = get_stage_one(stochasticprogram)
    return length(first_stage.linconstr)
end
"""
    first_stage_dims(stochasticprogram::StochasticProgram)

Return a the number of variables and the number of constraints in the the first stage of `stochasticprogram` as a tuple.
"""
function first_stage_dims(stochasticprogram::StochasticProgram)
    !haskey(stochasticprogram.problemcache, :stage_1) && return 0, 0
    first_stage = get_stage_one(stochasticprogram)
    return length(first_stage.linconstr), first_stage.numCols
end
"""
    second_stage_data(stochasticprogram::StochasticProgram)

Return the second stage data structure, if any exists, in `stochasticprogram`.
"""
function second_stage_data(stochasticprogram::StochasticProgram)
    return stage_data(stochasticprogram.scenarioproblems)
end
"""
    recourse_length(stochasticprogram::StochasticProgram)

Return the length of the second stage decision in `stochasticprogram`.
"""
function recourse_length(stochasticprogram::StochasticProgram)
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Consider @second_stage.")
    nsubproblems(stochasticprogram) == 0 && return 0
    return recourse_length(scenarioproblems(stochasticprogram))
end
"""
    scenario(stochasticprogram::StochasticProgram, i::Integer)

Return the `i`th scenario in `stochasticprogram`.
"""
function scenario(stochasticprogram::StochasticProgram, i::Integer)
    return scenario(scenarioproblems(stochasticprogram), i)
end
"""
    scenarios(stochasticprogram::StochasticProgram)

Return an array of all scenarios in `stochasticprogram`.
"""
function scenarios(stochasticprogram::StochasticProgram)
    return scenarios(scenarioproblems(stochasticprogram))
end
"""
    expected(stochasticprogram::StochasticProgram)

Return the exected scenario of all scenarios in `stochasticprogram`.
"""
function expected(stochasticprogram::StochasticProgram)
    return expected(scenarioproblems(stochasticprogram)).scenario
end
"""
    scenariotype(stochasticprogram::StochasticProgram)

Return the type of the scenario structure associated with `stochasticprogram`.
"""
function scenariotype(stochasticprogram::StochasticProgram)
    return scenariotype(scenarioproblems(stochasticprogram))
end
"""
    probability(stochasticprogram::StochasticProgram)

Return the probability of scenario `i`th scenario in `stochasticprogram` occuring.
"""
function probability(stochasticprogram::StochasticProgram, i::Integer)
    return probability(scenario(stochasticprogram, i))
end
"""
    probability(stochasticprogram::StochasticProgram)

Return the probability of any scenario in `stochasticprogram` occuring. A well defined model should return 1.
"""
function probability(stochasticprogram::StochasticProgram)
    return probability(stochasticprogram.scenarioproblems)
end
"""
    has_generator(stochasticprogram::StochasticProgram, key::Symbol)

Return true if a problem generator with `key` exists in `stochasticprogram`.
"""
function has_generator(stochasticprogram::StochasticProgram, key::Symbol)
    return haskey(stochasticprogram.generator, key)
end
"""
    generator(stochasticprogram::StochasticProgram, key::Symbol)

Return the problem generator associated with `key` in `stochasticprogram`.
"""
function generator(stochasticprogram::StochasticProgram, key::Symbol)
    return stochasticprogram.generator[key]
end
"""
    subproblem(stochasticprogram::StochasticProgram, i::Integer)

Return the `i`th subproblem in `stochasticprogram`.
"""
function subproblem(stochasticprogram::StochasticProgram, i::Integer)
    return subproblem(stochasticprogram.scenarioproblems, i)
end
"""
    subproblems(stochasticprogram::StochasticProgram)

Return an array of all subproblems in `stochasticprogram`.
"""
function subproblems(stochasticprogram::StochasticProgram)
    return subproblems(stochasticprogram.scenarioproblems)
end
"""
    nsubproblems(stochasticprogram::StochasticProgram)

Return the number of subproblems in `stochasticprogram`.
"""
function nsubproblems(stochasticprogram::StochasticProgram)
    return nsubproblems(stochasticprogram.scenarioproblems)
end
"""
    masterterms(stochasticprogram::StochasticProgram, i::Integer)

Return the first stage terms appearing in scenario `i` in `stochasticprogram`.

The master terms are given in sparse format as an array of tuples `(row,col,coeff)` which specify the occurance of master problem variables in the second stage constraints.
"""
function masterterms(stochasticprogram::StochasticProgram, i::Integer)
    return masterterms(stochasticprogram.scenarioproblems, i)
end
"""
    nscenarios(stochasticprogram::StochasticProgram)

Return the number of scenarios in `stochasticprogram`.
"""
function nscenarios(stochasticprogram::StochasticProgram)
    return nscenarios(stochasticprogram.scenarioproblems)
end
"""
    sampler(stochasticprogram::StochasticProgram)

Return the sampler object, if any, in `stochasticprogram`.
"""
function sampler(stochasticprogram::StochasticProgram)
    return sampler(stochasticprogram.scenarioproblems)
end
"""
    nstages(stochasticprogram::StochasticProgram)

Return the number of stages in `stochasticprogram`. Will return 2 for two-stage problems.
"""
nstages(stochasticprogram::StochasticProgram) = 2
"""
    distributed(stochasticprogram::StochasticProgram)

Return true if `stochasticprogram` is memory distributed.
p"""
distributed(stochasticprogram::StochasticProgram) = distributed(scenarioproblems(stochasticprogram))
"""
    deferred(stochasticprogram::StochasticProgram)

Return true if `stochasticprogram` is not fully generated.
"""
deferred(stochasticprogram::StochasticProgram) = deferred_first_stage(stochasticprogram) || deferred_second_stage(stochasticprogram)
deferred_first_stage(stochasticprogram::StochasticProgram) = has_generator(stochasticprogram, :stage_1) && !haskey(stochasticprogram.problemcache, :stage_1)
deferred_second_stage(stochasticprogram::StochasticProgram) = nsubproblems(stochasticprogram) < nscenarios(stochasticprogram)
"""
    spsolver(stochasticprogram::StochasticProgram)

Return the stochastic program solver `spsolver` in `stochasticprogram`.
"""
function spsolver(stochasticprogram::StochasticProgram)
    return stochasticprogram.spsolver.solver
end
"""
    internal_model(stochasticprogram::StochasticProgram)

Return the internal model of the solver object in `stochasticprogram`, after a call to `optimize!(stochasticprogram)`.
"""
function internal_model(stochasticprogram::StochasticProgram)
    return stochasticprogram.spsolver.internal_model
end
# ========================== #

# Setters
# ========================== #
"""
    set_spsolver(stochasticprogram::StochasticProgram, spsolver::Union{MathProgBase.AbstractMathProgSolver,AbstractStructuredSolver})

Store the stochastic program solver `spsolver` in `stochasticprogram`.
"""
function set_spsolver(stochasticprogram::StochasticProgram, spsolver::Union{MathProgBase.AbstractMathProgSolver,AbstractStructuredSolver})
    stochasticprogram.spsolver.solver = spsolver
    nothing
end
"""
    set_first_stage_data!(stochasticprogram::StochasticProgram, data::Any)

Store the first stage `data` in the first stage of `stochasticprogram`.
"""
function set_first_stage_data!(stochasticprogram::StochasticProgram, data::Any)
    stochasticprogram.first_stage.data = data
    remove_first_stage!(stochasticprogram)
    invalidate_cache!(stochasticprogram)
    nothing
end
"""
    set_second_stage_data!(stochasticprogram::StochasticProgram, data::Any)

Store the second stage `data` in the second stage of `stochasticprogram`.
"""
function set_second_stage_data!(stochasticprogram::StochasticProgram, data::Any)
    set_stage_data!(stochasticprogram.scenarioproblems, data)
    remove_subproblems!(stochasticprogram)
    invalidate_cache!(stochasticprogram)
    nothing
end
"""
    add_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario; defer::Bool = false, w = rand(workers()))

Store the second stage `scenario` in the second stage of `stochasticprogram`.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called. If the `stochasticprogram` is distributed, the worker that the scenario should be loaded on can be set through `w`.
"""
function add_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario; defer::Bool = false, w = rand(workers()))
    add_scenario!(scenarioproblems(stochasticprogram), scenario; w = w)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram; defer::Bool = false, w = rand(workers()))

Store the second stage scenario returned by `scenariogenerator` in the second stage of `stochasticprogram`.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called. If the `stochasticprogram` is distributed, the worker that the scenario should be loaded on can be set through `w`.
"""
function add_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram; defer::Bool = false, w = rand(workers()))
    add_scenario!(scenarioproblems(stochasticprogram), scenariogenerator; w = w)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}; defer::Bool = false, w = rand(workers()))

Store the colllection of second stage `scenarios` in the second stage of `stochasticprogram`.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called. If the `stochasticprogram` is distributed, the worker that the scenario should be loaded on can be set through `w`.
"""
function add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}; defer::Bool = false, w = rand(workers()))
    add_scenarios!(scenarioproblems(stochasticprogram), scenarios; w = w)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    sample!(stochasticprogram::StochasticProgram, n::Integer; defer::Bool = false)

Sample `n` scenarios from the sampler object in `stochasticprogram`, if any, and generates subproblems for each of them.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called.
"""
function sample!(stochasticprogram::StochasticProgram, n::Integer; defer::Bool = false)
    sample!(scenarioproblems(stochasticprogram), n)
    if !defer
        generate!(stochasticprogram)
    end
end
# ========================== #
