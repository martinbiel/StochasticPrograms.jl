# API (Two-stage) #
# ========================== #
"""
    instantiate(stochasticmodel::StochasticModel{2},
                scenarios::Vector{<:AbstractScenario};
                solver = JuMP.UnsetSolver(),
                procs = workers(),
                kw...)

Instantiate a new two-stage stochastic program using the model definition stored in the two-stage `stochasticmodel`, and the given collection of `scenarios`.
"""
function instantiate(sm::StochasticModel{2}, scenarios::Vector{<:AbstractScenario}; solver = JuMP.UnsetSolver(), procs = workers(), kw...)
    sp = StochasticProgram(parameters(sm.parameters[1]; kw...),
                           parameters(sm.parameters[2]; kw...),
                           scenarios,
                           solver,
                           procs)
    sm.generator(sp)
    return sp
end
"""
    instantiate(stochasticmodel::StochasticModel{2};
                scenariotype::Type{S} = Scenario,
                solver = JuMP.UnsetSolver(),
                procs = workers(),
                kw...) where S <: AbstractScenario

Instantiate a deferred two-stage stochastic program using the model definition stored in the two-stage `stochasticmodel` over the scenario type `S`.
"""
function instantiate(sm::StochasticModel{2}; scenariotype::Type{S} = Scenario, solver = JuMP.UnsetSolver(), procs = workers(), kw...) where S <: AbstractScenario
    sp = StochasticProgram(parameters(sm.parameters[1]; kw...),
                           parameters(sm.parameters[2]; kw...),
                           scenariotype,
                           solver,
                           procs)
    sm.generator(sp)
    return sp
end
"""
    instantiate(stochasticmodel::StochasticModel,
                scenarios::Vector{<:AbstractScenario};
                solver = JuMP.UnsetSolver(),
                procs = workers(),
                kw...)

Instantiate a new stochastic program using the model definition stored in `stochasticmodel`, and the given collection of `scenarios`.
"""
function instantiate(sm::StochasticModel{N},
                     scenarios::NTuple{M,Vector{<:AbstractScenario}};
                     solver = JuMP.UnsetSolver(),
                     procs = workers(),
                     kw...) where {N,M}
    M == N - 1 || error("Inconsistent number of stages $N and number of scenario types $M")
    params = ntuple(Val(N)) do i
        parameters(sm.parameters[i]; kw...)
    end
    sp = StochasticProgram(params,
                           scenarios,
                           solver,
                           procs)
    sm.generator(sp)
    return sp
end
"""
    optimize!(stochasticprogram::StochasticProgram; solver::SPSolverType = JuMP.UnsetSolver())

Optimize the `stochasticprogram` in expectation using `solver`.

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
function optimize!(stochasticprogram::StochasticProgram{2}; solver::SPSolverType = JuMP.UnsetSolver(), kwargs...)
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
function _optimize!(stochasticprogram::StochasticProgram{2}, solver::MathProgBase.AbstractMathProgSolver; kwargs...)
    # Standard mathprogbase solver. Fallback to solving DEP, relying on JuMP.
    dep = DEP(stochasticprogram; solver = solver)
    status = solve(dep; kwargs...)
    stochasticprogram.spsolver.internal_model = dep.internalModel
    fill_solution!(stochasticprogram)
    return status
end
function _optimize!(stochasticprogram::StochasticProgram{2}, solver::AbstractStructuredSolver; kwargs...)
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
    optimize(stochasticmodel::StochasticModel, sampler::AbstractSampler; solver::SPSolverType = JuMP.UnsetSolver(), confidence::AbstractFloat = 0.95, kwargs...)

Approximately optimize the `stochasticmodel` using `solver` when the underlying scenario distribution is inferred by `sampler` and return a `StochasticSolution` with the given `confidence` level.

See also: [`StochasticSolution`](@ref)
"""
function optimize!(stochasticmodel::StochasticModel, sampler::AbstractSampler; solver::SPSolverType = JuMP.UnsetSolver(), confidence::AbstractFloat = 0.95, kwargs...)
    # Abort if no solver was given
    if isa(solver, JuMP.UnsetSolver)
        error("Cannot optimize without a solver.")
    end
    # Switch on solver type
    return _optimize!(stochasticmodel, sampler, solver, confidence; kwargs...)
end
function _optimize!(stochasticmodel::StochasticModel, sampler::AbstractSampler, solver::MathProgBase.AbstractMathProgSolver, confidence::AbstractFloat; kwargs...)
    return _optimize!(stochasticmodel, sampler, SAASolver(solver), confidence; kwargs...)
end
function _optimize!(stochasticmodel::StochasticModel, sampler::AbstractSampler, solver::AbstractStructuredSolver, confidence::AbstractFloat; kwargs...)
    return _optimize!(stochasticmodel, sampler, SAASolver(solver), confidence; kwargs...)
end
function _optimize!(stochasticmodel::StochasticModel, sampler::AbstractSampler, solver::AbstractSampledSolver, confidence::AbstractFloat; kwargs...)
    sampledmodel = SampledModel(stochasticmodel, solver)
    status = optimize_sampled!(sampledmodel, sampler, confidence; kwargs...)
    stochasticmodel.spsolver.internal_model = sampledmodel
    if status != :Optimal
        @warn "Optimal solution not found. Returned status $status"
    end
    return stochastic_solution(sampledmodel)
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
    return getvalue(submodel.objDict[var])
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
    stage_parameters(stochasticprogram::StochasticProgram, s::Integer)

Return the parameters at stage `s` in `stochasticprogram`.
"""
function stage_parameters(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    return stochasticprogram.stages[s].parameters
end
"""
    scenarioproblems(stochasticprogram::StochasticProgram, s::Integer)

Return the scenario problems at stage `s` in `stochasticprogram`.
"""
function scenarioproblems(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 < s <= N || error("Stage $s not in range 2 to $N.")
    return stochasticprogram.scenarioproblems[s-1]
end
"""
    scenarioproblems(stochasticprogram::TwoStageStochasticProgram)

Return the scenario problems in `stochasticprogram`.
"""
function scenarioproblems(stochasticprogram::StochasticProgram{2}, s::Integer = 2)
    s == 1 && error("Stage 1 does not have scenario problems.")
    s == 2 || error("Stage $s not available in two-stage model.")
    return stochasticprogram.scenarioproblems
end
"""
    decision_length(stochasticprogram::StochasticProgram, s::Integer)

Return the length of the decision at stage `s` in the `stochasticprogram`.
"""
function decision_length(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    if s == 1
        haskey(stochasticprogram.problemcache, :stage_1) || return 0
        return stochasticprogram.problemcache[:stage_1].numCols
    end
    nsubproblems(stochasticprogram, s) == 0 && return 0
    return recourse_length(scenarioproblems(stochasticprogram, s))
end
"""
    decision_length(stochasticprogram::TwoStageStochasticProgram)

Return the length of the first-stage decision of the two-stage `stochasticprogram`.
"""
function decision_length(stochasticprogram::StochasticProgram{2})
    return decision_length(stochasticprogram, 1)
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
    recourse_length(stochasticprogram::TwoStageStochasticProgram)

Return the length of the second-stage decision in the two-stage `stochasticprogram`.
"""
function recourse_length(stochasticprogram::StochasticProgram{2})
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Consider @second_stage.")
    nsubproblems(stochasticprogram) == 0 && return 0
    return recourse_length(scenarioproblems(stochasticprogram))
end
"""
    scenario(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)


Return the `i`th scenario of stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function scenario(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)
    return scenario(scenarioproblems(stochasticprogram, s), i)
end
"""
    scenarios(stochasticprogram::StochasticProgram, s::Integer = 2)

Return an array of all scenarios of the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function scenarios(stochasticprogram::StochasticProgram, s::Integer = 2)
    return scenarios(scenarioproblems(stochasticprogram, s))
end
"""
    expected(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the exected scenario of all scenarios of the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function expected(stochasticprogram::StochasticProgram, s::Integer = 2)
    return expected(scenarioproblems(stochasticprogram, s)).scenario
end
"""
    scenariotype(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the type of the scenario structure associated with `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function scenariotype(stochasticprogram::StochasticProgram, s::Integer = 2)
    return scenariotype(scenarioproblems(stochasticprogram, s))
end
"""
    probability(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)

Return the probability of scenario `i`th scenario in the `stochasticprogram` at stage `s` occuring. Defaults to the second stage.
"""
function probability(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)
    return probability(scenario(stochasticprogram, s, i))
end
"""
    stage_probability(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the probability of any scenario in the `stochasticprogram` at stage `s` occuring. A well defined model should return 1. Defaults to the second stage.
"""
function stage_probability(stochasticprogram::StochasticProgram, s::Integer = 2)
    return probability(scenarioproblems(stochasticprogram, s))
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
    subproblem(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)

Return the `i`th subproblem of the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function subproblem(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)
    return subproblem(scenarioproblems(stochasticprogram, s), i)
end
"""
    subproblems(stochasticprogram::StochasticProgram, s::Integer = 2)

Return an array of all subproblems of the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function subproblems(stochasticprogram::StochasticProgram, s::Integer = 2)
    return subproblems(scenarioproblems(stochasticprogram, s))
end
"""
    nsubproblems(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the number of subproblems in the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function nsubproblems(stochasticprogram::StochasticProgram, s::Integer = 2)
    s == 1 && return 0
    return nsubproblems(scenarioproblems(stochasticprogram, s))
end
"""
    masterterms(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)

Return the first stage terms appearing in scenario `i` in the `stochasticprogram` at stage `s`. Defaults to the second stage.

The master terms are given in sparse format as an array of tuples `(row,col,coeff)` which specify the occurance of master problem variables in the second stage constraints.
"""
function masterterms(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)
    return masterterms(scenarioproblems(stochasticprogram, s), i)
end
"""
    nscenarios(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the number of scenarios in the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function nscenarios(stochasticprogram::StochasticProgram, s::Integer = 2)
    s == 1 && return 0
    return nscenarios(scenarioproblems(stochasticprogram, s))
end
"""
    nstages(stochasticprogram::StochasticProgram)

Return the number of stages in `stochasticprogram`.
"""
nstages(::StochasticProgram{N}) where N = N
"""
    distributed(stochasticprogram::StochasticProgram, s::Integer = 2)

Return true if the `stochasticprogram` is memory distributed at stage `s`. Defaults to the second stage.
"""
distributed(stochasticprogram::StochasticProgram, s::Integer = 2) = distributed(scenarioproblems(stochasticprogram, s))
"""
    deferred(stochasticprogram::StochasticProgram)

Return true if `stochasticprogram` is not fully generated.
"""
deferred(stochasticprogram::StochasticProgram{N}) where N = deferred(stochasticprogram, Val(N))
deferred(stochasticprogram::StochasticProgram, ::Val{1}) = deferred_first_stage(stochasticprogram)
function deferred(stochasticprogram::StochasticProgram, ::Val{N}) where N

    return deferred_stage(stochasticprogram, N) || deferred(stochasticprogram, Val(N-1))
end
deferred_first_stage(stochasticprogram::StochasticProgram) = has_generator(stochasticprogram, :stage_1) && !haskey(stochasticprogram.problemcache, :stage_1)
function deferred_stage(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    s == 1 && return deferred_first_stage(stochasticprogram)
    nsubproblems(stochasticprogram, s) < nscenarios(stochasticprogram, s)
end
"""
    spsolver(stochasticprogram::StochasticProgram)

Return the stochastic program solver `spsolver` of the `stochasticprogram`.
"""
function spsolver(stochasticprogram::StochasticProgram)
    return stochasticprogram.spsolver.solver
end
"""
    internal_model(stochasticprogram::StochasticProgram)

Return the internal solve model object of the `stochasticprogram`, after a call to `optimize!(stochasticprogram)`.
"""
function spsolver_model(stochasticprogram::StochasticProgram)
    return stochasticprogram.spsolver.internal_model
end
# ========================== #

# Setters
# ========================== #
"""
    set_spsolver(stochasticprogram::StochasticProgram, spsolver::Union{MathProgBase.AbstractMathProgSolver,AbstractStructuredSolver})

Store the stochastic program solver `spsolver` of the `stochasticprogram`.
"""
function set_spsolver(stochasticprogram::StochasticProgram, spsolver::Union{MathProgBase.AbstractMathProgSolver,AbstractStructuredSolver})
    stochasticprogram.spsolver.solver = spsolver
    nothing
end
"""
    add_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario, stage::Integer = 2; defer::Bool = false)

Store the second stage `scenario` in the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called. If the `stochasticprogram` is distributed, the scenario will be defined on the node that currently has the fewest scenarios.
"""
function add_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario, stage::Integer = 2; defer::Bool = false)
    add_scenario!(scenarioproblems(stochasticprogram, stage), scenario)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_worker_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario, w::Integer, stage::Integer = 2; defer::Bool = false)

Store the second stage `scenario` in worker node `w` of the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called.
"""
function add_worker_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario, w::Integer, stage::Integer = 2; defer::Bool = false)
    add_scenario!(scenarioproblems(stochasticprogram, stage), scenario, w)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, stage::Integer = 2; defer::Bool = false)

Store the second stage scenario returned by `scenariogenerator` in the second stage of the `stochasticprogram`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called. If the `stochasticprogram` is distributed, the scenario will be defined on the node that currently has the fewest scenarios.
"""
function add_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, stage::Integer = 2; defer::Bool = false)
    add_scenario!(scenariogenerator, scenarioproblems(stochasticprogram, stage))
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_worker_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, w::Integer, stage::Integer = 2; defer::Bool = false)

Store the second stage scenario returned by `scenariogenerator` in worker node `w` of the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called.
"""
function add_worker_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, w::Integer, stage::Integer = 2; defer::Bool = false)
    add_scenario!(scenariogenerator, scenarioproblems(stochasticprogram, stage), w)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}, stage::Integer = 2; defer::Bool = false)

Store the collection of second stage `scenarios` in the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}, stage::Integer = 2; defer::Bool = false)
    add_scenarios!(scenarioproblems(stochasticprogram, stage), scenarios)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_worker_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}, w::Integer, stage::Integer = 2; defer::Bool = false)

Store the collection of second stage `scenarios` in in worker node `w` of the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called.
"""
function add_worker_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}, w::Integer, stage::Integer = 2; defer::Bool = false)
    add_scenarios!(scenarioproblems(stochasticprogram, stage), scenarios, w)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, n::Integer, stage::Integer = 2; defer::Bool = false)

Generate `n` second-stage scenarios using `scenariogenerator`and store in the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function add_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, n::Integer, stage::Integer = 2; defer::Bool = false)
    add_scenarios!(scenariogenerator, scenarioproblems(stochasticprogram, stage), n)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_worker_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, n::Integer, w::Integer, stage::Integer = 2; defer::Bool = false)

Generate `n` second-stage scenarios using `scenariogenerator`and store them in worker node `w` of the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called.
"""
function add_worker_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, n::Integer, w::Integer, stage::Integer = 2; defer::Bool = false)
    add_scenarios!(scenariogenerator, scenarioproblems(stochasticprogram, stage), n, w)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    sample!(stochasticprogram::StochasticProgram, sampler::AbstractSampler, n::Integer, stage::Integer = 2; defer::Bool = false)

Sample `n` scenarios using `sampler` and add to the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function sample!(stochasticprogram::StochasticProgram, sampler::AbstractSampler, n::Integer, stage::Integer = 2; defer::Bool = false)
    sample!(scenarioproblems(stochasticprogram, stage), sampler, n)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
# ========================== #
