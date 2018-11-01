"""
    StochasticProgram{SD <: AbstractScenario}

A mathematical model of a stochastic optimization problem. Every instance is linked to some given scenario type `AbstractScenario`. A StochasticProgram can be memory-distributed on multiple Julia processes.
"""
struct StochasticProgram{D1, D2, SD <: AbstractScenario, S <: AbstractSampler{SD}, SP <: Union{ScenarioProblems{D2,SD,S},
                                                                                                   DScenarioProblems{D2,SD,S}}}
    first_stage::Stage{D1}
    scenarioproblems::SP
    generator::Dict{Symbol,Function}
    problemcache::Dict{Symbol,JuMP.Model}
    spsolver::SPSolver

    function (::Type{StochasticProgram})(stage_1::D1, stage_2::D2, ::Type{SD}, solver::SPSolverType, procs::Vector{Int}) where {D1, D2, SD <: AbstractScenario}
        S = NullSampler{SD}
        scenarioproblems = ScenarioProblems(2, stage_2, SD, procs)
        return new{D1,D2,SD,S,typeof(scenarioproblems)}(Stage(1,stage_1), scenarioproblems, Dict{Symbol,Function}(), Dict{Symbol,JuMP.Model}(), SPSolver(solver))
    end

    function (::Type{StochasticProgram})(stage_1::D1, stage_2::D2, scenarios::Vector{<:AbstractScenario}, solver::SPSolverType, procs::Vector{Int}) where {D1, D2}
        SD = eltype(scenarios)
        S = NullSampler{SD}
        scenarioproblems = ScenarioProblems(2, stage_2, scenarios, procs)
        return new{D1,D2,SD,S,typeof(scenarioproblems)}(Stage(1,stage_1), scenarioproblems, Dict{Symbol,Function}(), Dict{Symbol,JuMP.Model}(), SPSolver(solver))
    end

    function (::Type{StochasticProgram})(stage_1::D1, stage_2::D2, sampler::AbstractSampler{SD}, solver::SPSolverType, procs::Vector{Int}) where {D1, D2, SD <: AbstractScenario}
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
                      procs = workers()) where {SD <: AbstractScenario}

Create a new stochastic program with stage data given by `first_stage_data` and `second_stage_data`. After construction, scenarios of type `SD` can be added through `add_scenario!`. Optionally, a capable `solver` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(first_stage_data::Any, second_stage_data::Any, ::Type{SD}; solver = JuMP.UnsetSolver(), procs = workers()) where {SD <: AbstractScenario}
    return StochasticProgram(first_stage_data, second_stage_data, SD, solver, procs)
end
"""
    StochasticProgram(first_stage_data::Any,
                      second_stage_data::Any,
                      scenarios::Vector{<:AbstractScenario};
                      solver = JuMP.UnsetSolver(),
                      procs = workers()) where {SD <: AbstractScenario}

Create a new stochastic program with a given collection of `scenarios`
"""
function StochasticProgram(first_stage_data::Any, second_stage_data::Any, scenarios::Vector{<:AbstractScenario}; solver = JuMP.UnsetSolver(), procs = workers())
    return StochasticProgram(first_stage_data, second_stage_data, scenarios, solver, procs)
end
"""
    StochasticProgram(scenarios::Vector{<:AbstractScenario};
                      solver = JuMP.UnsetSolver(),
                      procs = workers()) where {SD <: AbstractScenario}

Create a new stochastic program with a given collection of `scenarios` and no stage data.
"""
StochasticProgram(scenarios::Vector{<:AbstractScenario}; solver = JuMP.UnsetSolver(), procs = workers()) = StochasticProgram(nothing, nothing, scenarios; solver = solver, procs = procs)
"""
    StochasticProgram(first_stage_data::Any,
                      second_stage_data::Any,
                      sampler::AbstractSampler;
                      solver = JuMP.UnsetSolver(),
                      procs = workers()) where {SD <: AbstractScenario}

Create a new stochastic program with a `sampler` that implicitly defines the scenario type.
"""
function StochasticProgram(first_stage_data::Any, second_stage_data::Any, sampler::AbstractSampler; solver = JuMP.UnsetSolver(), procs = workers())
    return StochasticProgram(first_stage_data, second_stage_data, sampler, solver, procs)
end
"""
    StochasticProgram(scenarios::Vector{<:AbstractScenario};
                      solver = JuMP.UnsetSolver(),
                      procs = workers()) where {SD <: AbstractScenario}

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
    ns = nsubproblems(stochasticprogram)
    println(io, " * $(ns) second stage model$(plural(ns))")
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
