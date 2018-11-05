"""
    StochasticProgram{SD <: AbstractScenario}

A mathematical model of a stochastic optimization problem. Every instance is linked to some given scenario type `AbstractScenario`. A StochasticProgram can be memory-distributed on multiple Julia processes.
"""
struct StochasticProgram{D₁, D₂, SD <: AbstractScenario, S <: AbstractSampler{SD}, SP <: Union{ScenarioProblems{D₂,SD,S},
                                                                                               DScenarioProblems{D₂,SD,S}}}
    first_stage::Stage{D₁}
    scenarioproblems::SP
    generator::Dict{Symbol,Function}
    problemcache::Dict{Symbol,JuMP.Model}
    spsolver::SPSolver

    function (::Type{StochasticProgram})(stage_1::D₁, stage_2::D₂, ::Type{SD}, solver::SPSolverType, procs::Vector{Int}) where {D₁, D₂, SD <: AbstractScenario}
        S = NullSampler{SD}
        scenarioproblems = ScenarioProblems(2, stage_2, SD, procs)
        D₁_ = D₁ == Nothing ? Any : D₁
        D₂_ = D₂ == Nothing ? Any : D₂
        return new{D₁_,D₂_,SD,S,typeof(scenarioproblems)}(Stage(1,stage_1), scenarioproblems, Dict{Symbol,Function}(), Dict{Symbol,JuMP.Model}(), SPSolver(solver))
    end

    function (::Type{StochasticProgram})(stage_1::D₁, stage_2::D₂, scenarios::Vector{<:AbstractScenario}, solver::SPSolverType, procs::Vector{Int}) where {D₁, D₂}
        SD = eltype(scenarios)
        S = NullSampler{SD}
        scenarioproblems = ScenarioProblems(2, stage_2, scenarios, procs)
        D₁_ = D₁ == Nothing ? Any : D₁
        D₂_ = D₂ == Nothing ? Any : D₂
        return new{D₁_,D₂_,SD,S,typeof(scenarioproblems)}(Stage(1,stage_1), scenarioproblems, Dict{Symbol,Function}(), Dict{Symbol,JuMP.Model}(), SPSolver(solver))
    end

    function (::Type{StochasticProgram})(stage_1::D₁, stage_2::D₂, sampler::AbstractSampler{SD}, solver::SPSolverType, procs::Vector{Int}) where {D₁, D₂, SD <: AbstractScenario}
        S = typeof(sampler)
        scenarioproblems = ScenarioProblems(2, stage_2, sampler, procs)
        D₁_ = D₁ == Nothing ? Any : D₁
        D₂_ = D₂ == Nothing ? Any : D₂
        return new{D₁_,D₂_,SD,S,typeof(scenarioproblems)}(Stage(1,stage_1), scenarioproblems, Dict{Symbol,Function}(), Dict{Symbol,JuMP.Model}(), SPSolver(solver))
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
    defer_stage_1(sp) = deferred_first_stage(sp) ? " * deferred first stage" :  " * $(xdim) decision variable$(plural(xdim))"
    defer_stage_2(sp) = deferred_second_stage(sp) ? " * deferred second stage" :  " * $(ydim) recourse variable$(plural(ydim))"
    stage_1(sp) = has_generator(sp, :stage_1) ? defer_stage_1(sp) : " * undefined first stage"
    stage_2(sp) = has_generator(sp, :stage_2) ? defer_stage_2(sp) : " * undefined second stage"
    dist(sp) = distributed(sp) ? "Distributed stochastic program with:" : "Stochastic program with:"
    xdim = has_generator(stochasticprogram, :stage_1) ? decision_length(stochasticprogram) : 0
    ydim = has_generator(stochasticprogram, :stage_2) ? recourse_length(stochasticprogram) : 0
    n = nscenarios(stochasticprogram)
    ns = nsubproblems(stochasticprogram)
    println(io, dist(stochasticprogram))
    println(io, " * $(n) scenario$(plural(n)) of type $(typename(scenariotype(stochasticprogram)))")
    println(io, stage_1(stochasticprogram))
    println(io, stage_2(stochasticprogram))
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
