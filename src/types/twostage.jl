"""
    StochasticProgram{SD <: AbstractScenarioData}

A mathematical model of a stochastic optimization problem. Every instance is linked to some given scenario type `AbstractScenarioData`. A StochasticProgram can be memory-distributed on multiple Julia processes.
"""
struct StochasticProgram{D1, D2, SD <: AbstractScenarioData, S <: AbstractSampler{SD}, SP <: Union{ScenarioProblems{D2,SD,S},
                                                                                                   DScenarioProblems{D2,SD,S}}}
    first_stage::Stage{D1}
    scenarioproblems::SP
    generator::Dict{Symbol,Function}
    problemcache::Dict{Symbol,JuMP.Model}
    spsolver::SPSolver

    function (::Type{StochasticProgram})(stage_1::D1, stage_2::D2, ::Type{SD}, solver::SPSolverType, procs::Vector{Int}) where {D1, D2, SD <: AbstractScenarioData}
        S = NullSampler{SD}
        scenarioproblems = ScenarioProblems(2, stage_2, SD, procs)
        return new{D1,D2,SD,S,typeof(scenarioproblems)}(Stage(1,stage_1), scenarioproblems, Dict{Symbol,Function}(), Dict{Symbol,JuMP.Model}(), SPSolver(solver))
    end

    function (::Type{StochasticProgram})(stage_1::D1, stage_2::D2, scenarios::Vector{<:AbstractScenarioData}, solver::SPSolverType, procs::Vector{Int}) where {D1, D2}
        SD = eltype(scenarios)
        S = NullSampler{SD}
        scenarioproblems = ScenarioProblems(2, stage_2, scenarios, procs)
        return new{D1,D2,SD,S,typeof(scenarioproblems)}(Stage(1,stage_1), scenarioproblems, Dict{Symbol,Function}(), Dict{Symbol,JuMP.Model}(), SPSolver(solver))
    end

    function (::Type{StochasticProgram})(stage_1::D1, stage_2::D2, sampler::AbstractSampler{SD}, solver::SPSolverType, procs::Vector{Int}) where {D1, D2, SD <: AbstractScenarioData}
        S = typeof(sampler)
        scenarioproblems = ScenarioProblems(2, stage_2, sampler, procs)
        return new{D1,D2,SD,S,typeof(scenarioproblems)}(Stage(1,stage_1), scenarioproblems, Dict{Symbol,Function}(), Dict{Symbol,JuMP.Model}(), SPSolver(solver))
    end
end

# Constructors #
# ========================== #
"""
    StochasticProgram(first_stage_data::Any,
                      second_stage_data::Any,
                      ::Type{SD};
                      solver = JuMP.UnsetSolver(),
                      procs = workers()) where {SD <: AbstractScenarioData}

Create a new stochastic program with stage data given by `first_stage_data` and `second_stage_data`. After construction, scenarios of type `SD` can be added through `add_scenario!`. Optionally, a capable `solver` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(first_stage_data::Any, second_stage_data::Any, ::Type{SD}; solver = JuMP.UnsetSolver(), procs = workers()) where {SD <: AbstractScenarioData}
    return StochasticProgram(first_stage_data, second_stage_data, SD, solver, procs)
end
"""
    StochasticProgram(first_stage_data::Any,
                      second_stage_data::Any,
                      scenarios::Vector{<:AbstractScenarioData};
                      solver = JuMP.UnsetSolver(),
                      procs = workers()) where {SD <: AbstractScenarioData}

Create a new stochastic program with a given collection of `scenarios`
"""
function StochasticProgram(first_stage_data::Any, second_stage_data::Any, scenarios::Vector{<:AbstractScenarioData}; solver = JuMP.UnsetSolver(), procs = workers())
    return StochasticProgram(first_stage_data, second_stage_data, scenarios, solver, procs)
end
"""
    StochasticProgram(scenarios::Vector{<:AbstractScenarioData};
                      solver = JuMP.UnsetSolver(),
                      procs = workers()) where {SD <: AbstractScenarioData}

Create a new stochastic program with a given collection of `scenarios` and no stage data.
"""
StochasticProgram(scenarios::Vector{<:AbstractScenarioData}; solver = JuMP.UnsetSolver(), procs = workers()) = StochasticProgram(nothing, nothing, scenarios; solver = solver, procs = procs)
"""
    StochasticProgram(first_stage_data::Any,
                      second_stage_data::Any,
                      sampler::AbstractSampler;
                      solver = JuMP.UnsetSolver(),
                      procs = workers()) where {SD <: AbstractScenarioData}

Create a new stochastic program with a `sampler` that implicitly defines the scenario type.
"""
function StochasticProgram(first_stage_data::Any, second_stage_data::Any, sampler::AbstractSampler; solver = JuMP.UnsetSolver(), procs = workers())
    return StochasticProgram(first_stage_data, second_stage_data, sampler, solver, procs)
end
"""
    StochasticProgram(scenarios::Vector{<:AbstractScenarioData};
                      solver = JuMP.UnsetSolver(),
                      procs = workers()) where {SD <: AbstractScenarioData}

Create a new stochastic program with a `sampler` and no stage data.
"""
StochasticProgram(sampler::AbstractSampler; solver = JuMP.UnsetSolver(), procs = workers()) = StochasticProgram(nothing, nothing, sampler; solver = solver, procs = procs)
# ========================== #

# Printing #
# ========================== #
function Base.show(io::IO, stochasticprogram::StochasticProgram)
    plural(n) = (n==1 ? "" : "s")
    defer(sp) = deferred(sp) ? " (deferred)" : ""
    dist(sp) = distributed(sp) ? "Distributed stochastic program$(defer(sp)) with:" : "Stochastic program$(defer(sp)) with:"
    println(io, dist(stochasticprogram))
    xdim = decision_length(stochasticprogram)
    println(io, " * $(xdim) decision variable$(plural(xdim))")
    n = nscenarios(stochasticprogram)
    println(io, " * $(n) scenario$(plural(n))")
    print(io, "Solver is ")
    if isa(spsolver(stochasticprogram), JuMP.UnsetSolver)
        print(io, "default solver")
    else
        print(io, solverstr(spsolver(stochasticprogram)))
    end
end
function Base.print(io::IO, stochasticprogram::StochasticProgram)
    print(io, "First-stage \n")
    print(io, "============== \n")
    print(io, get_stage_one(stochasticprogram))
    print(io, "\nSecond-stage \n")
    print(io, "============== \n")
    for (id, subproblem) in enumerate(subproblems(stochasticprogram))
        @printf(io, "Subproblem %d:\n", id)
        print(io, subproblem)
        print(io, "\n")
    end
end
# ========================== #

# API #
# ========================== #
"""
    optimize!(sp::StochasticProgram; solver::SPSolverType = JuMP.UnsetSolver())

Optimize `sp` after calls to `@first_stage sp = begin ... end` and `second_stage sp = begin ... end`, assuming scenarios are available.

`generate!(sp)` is called internally, so deferred models can be passed. The `solver` can either be am AbstractMathProgSolver or a AbstractStructuredSolver. The default behaviour is to rely on any previously set solver.

## Examples

The following solves the stochastic program `sp` using the L-shaped algorithm.

```jldoctest
julia> optimize!(sp, solver = LShapedSolver(:ls, GLPKSolverLP()))
L-Shaped Gap  Time: 0:00:01 (6 iterations)
  Objective:       -855.8333333333358
  Gap:             4.250802890466926e-15
  Number of cuts:  8
:Optimal
```

The following solves the stochastic program `sp` using GLPK on the extended form.

```jldoctest
julia> optimize!(sp, solver = GLPKSolverLP())
:Optimal
```
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
    return expected(scenarioproblems(stochasticprogram))
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
deferred(stochasticprogram::StochasticProgram) = (has_generator(stochasticprogram, :stage_1) && !haskey(stochasticprogram.problemcache, :stage_1)) || nsubproblems(stochasticprogram) < nscenarios(stochasticprogram)
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
    set_first_stage_data(stochasticprogram::StochasticProgram, data::Any)

Store the first stage `data` in the first stage of `stochasticprogram`.
"""
function set_first_stage_data!(stochasticprogram::StochasticProgram, data::Any)
    stochasticprogram.first_stage.data = data
    nothing
end
"""
    set_second_stage_data!(stochasticprogram::StochasticProgram, data::Any)

Store the second stage `data` in the second stage of `stochasticprogram`.
"""
function set_second_stage_data!(stochasticprogram::StochasticProgram, data::Any)
    set_stage_data!(stochasticprogram.scenarioproblems, data)
    nothing
end
"""
    add_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenarioData; defer::Bool = false)

Store the second stage `scenario` in the second stage of `stochasticprogram`.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called.
"""
function add_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenarioData; defer::Bool = false)
    add_scenario!(scenarioproblems(stochasticprogram), scenario)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenarioData}; defer::Bool = false)

Store the colllection of second stage `scenarios` in the second stage of `stochasticprogram`.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called.
"""
function add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenarioData}; defer::Bool = false)
    add_scenarios!(scenarioproblems(stochasticprogram), scenarios)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
# ========================== #

# Sampling #
# ========================== #
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
