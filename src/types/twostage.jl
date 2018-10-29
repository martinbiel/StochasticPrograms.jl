"""
    StochasticProgram

A mathematical model of a stochastic optimization problem.
"""
struct StochasticProgram{D1, D2, SD <: AbstractScenarioData, S <: AbstractSampler{SD}, SP <: Union{ScenarioProblems{D2,SD,S},
                                                                                                   DScenarioProblems{D2,SD,S}}}
    first_stage::Stage{D1}
    scenarioproblems::SP
    generator::Dict{Symbol,Function}
    problemcache::Dict{Symbol,JuMP.Model}
    spsolver::SPSolver

    function (::Type{StochasticProgram})(stage_1::D1,stage_2::D2,::Type{SD},procs::Vector{Int}) where {D1,D2,SD <: AbstractScenarioData}
        S = NullSampler{SD}
        scenarioproblems = ScenarioProblems(2,stage_2,SD,procs)
        return new{D1,D2,SD,S,typeof(scenarioproblems)}(Stage(1,stage_1),scenarioproblems,Dict{Symbol,Function}(),Dict{Symbol,JuMP.Model}(),SPSolver(JuMP.UnsetSolver()))
    end

    function (::Type{StochasticProgram})(stage_1::D1,stage_2::D2,scenariodata::Vector{<:AbstractScenarioData},procs::Vector{Int}) where {D1,D2}
        SD = eltype(scenariodata)
        S = NullSampler{SD}
        scenarioproblems = ScenarioProblems(2,stage_2,scenariodata,procs)
        return new{D1,D2,SD,S,typeof(scenarioproblems)}(Stage(1,stage_1),scenarioproblems,Dict{Symbol,Function}(),Dict{Symbol,JuMP.Model}(),SPSolver(JuMP.UnsetSolver()))
    end

    function (::Type{StochasticProgram})(stage_1::D1,stage_2::D2,sampler::AbstractSampler{SD},procs::Vector{Int}) where {D1,D2,SD <: AbstractScenarioData}
        S = typeof(sampler)
        scenarioproblems = ScenarioProblems(2,stage_2,sampler,procs)
        return new{D1,D2,SD,S,typeof(scenarioproblems)}(Stage(1,stage_1),scenarioproblems,Dict{Symbol,Function}(),Dict{Symbol,JuMP.Model}(),SPSolver(JuMP.UnsetSolver()))
    end
end

"""
    StochasticProgram(stage_1,
                      stage_2,
                      ::Type{<:AbstractScenarioData};
                      solver = JuMP.UnsetSolver(),
                      procs = workers())

Return a new stochastic program
"""
function StochasticProgram(stage_1::D1,stage_2::D2,::Type{SD}; solver = JuMP.UnsetSolver(), procs = workers()) where {D1,D2,SD <: AbstractScenarioData}
    stochasticprogram = StochasticProgram(stage_1,stage_2,SD,procs)
    stochasticprogram.spsolver.solver = solver
    # Return stochastic program
    return stochasticprogram
end
StochasticProgram(scenariodata::Vector{<:AbstractScenarioData}; solver = JuMP.UnsetSolver(), procs = workers()) = StochasticProgram(nothing,nothing,scenariodata; solver = solver, procs = procs)
function StochasticProgram(stage_1::D1,stage_2::D2,scenariodata::Vector{<:AbstractScenarioData}; solver = JuMP.UnsetSolver(), procs = workers()) where {D1,D2}
    stochasticprogram = StochasticProgram(stage_1,stage_2,scenariodata,procs)
    stochasticprogram.spsolver.solver = solver
    # Return stochastic program
    return stochasticprogram
end
StochasticProgram(sampler::AbstractSampler; solver = JuMP.UnsetSolver(), procs = workers()) = StochasticProgram(nothing,nothing,sampler; solver = solver, procs = procs)
function StochasticProgram(stage_1::D1,stage_2::D2,sampler::AbstractSampler; solver = JuMP.UnsetSolver(), procs = workers()) where {D1,D2}
    stochasticprogram = StochasticProgram(stage_1,stage_2,sampler,procs)
    stochasticprogram.spsolver.solver = solver
    # Return stochastic program
    return stochasticprogram
end

#  #
# ========================== #
function solve!(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver(), kwargs...)
    if nsubproblems(stochasticprogram) != nscenarios(stochasticprogram)
        generate!(stochasticprogram)
    end
    # Prefer cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Switch on solver type
    return _solve!(stochasticprogram, supplied_solver)
end
function _solve!(stochasticprogram::StochasticProgram, solver::MathProgBase.AbstractMathProgSolver)
    # Standard mathprogbase solver. Fallback to solving DEP, relying on JuMP.
    dep = DEP(stochasticprogram, supplied_solver)
    status = solve(dep; kwargs...)
    fill_solution!(stochasticprogram)
    return status
end
function _solve!(stochasticprogram::StochasticProgram, solver::AbstractStructuredSolver)
    # Use structured solver
    structuredmodel = StructuredModel(stochasticprogram, supplied_solver)
    stochasticprogram.internalmodel = structuredmodel
    status = optimize_structured!(structuredmodel)
    fill_solution!(structuredmodel, stochasticprogram)
    return status
end

function print(io::IO, stochasticprogram::StochasticProgram)
    print(io, "First-stage \n")
    print(io, "============== \n")
    print(io, stochasticprogram, ignore_print_hook=true)
    print(io, "\nSecond-stage \n")
    print(io, "============== \n")
    for (id, subproblem) in enumerate(subproblems(stochasticprogram))
        @printf(io, "Subproblem %d:\n", id)
        print(io, subproblem)
        print(io, "\n")
    end
end
# ========================== #

# Getters #
# ========================== #
"""
    scenarioproblems(stochasticprogram::StochasticProgram)

Returns the scenario problems in `stochasticprogram`.
"""
function scenarioproblems(stochasticprogram::StochasticProgram)
    return stochasticprogram.scenarioproblems
end
"""
    first_stage_data(stochasticprogram::StochasticProgram)

Returns the first stage data structure, if any exists, in `stochasticprogram`.
"""
function first_stage_data(stochasticprogram::StochasticProgram)
    return stochasticprogram.first_stage.data
end
"""
    second_stage_data(stochasticprogram::StochasticProgram)

Returns the second stage data structure, if any exists, in `stochasticprogram`.
"""
function second_stage_data(stochasticprogram::StochasticProgram)
    return stage_data(stochasticprogram.scenarioproblems)
end
"""
    scenario(stochasticprogram::StochasticProgram, i::Integer)

Returns the `i`th scenario in `stochasticprogram`.
"""
function scenario(stochasticprogram::StochasticProgram, i::Integer)
    return scenario(scenarioproblems(stochasticprogram), i)
end
"""
    scenarios(stochasticprogram::StochasticProgram)

Returns an array of all scenarios in `stochasticprogram`.
"""
function scenarios(stochasticprogram::StochasticProgram)
    return scenarios(scenarioproblems(stochasticprogram))
end
"""
    expected(stochasticprogram::StochasticProgram)

Returns the exected scenario of all scenarios in `stochasticprogram`.
"""
function expected(stochasticprogram::StochasticProgram)
    return expected(scenarioproblems(stochasticprogram))
end
"""
    scenariotype(stochasticprogram::StochasticProgram)

Returns the type of the scenario structure associated with `stochasticprogram`.
"""
function scenariotype(stochasticprogram::StochasticProgram)
    return scenariotype(scenarioproblems(stochasticprogram))
end
"""
    probability(stochasticprogram::StochasticProgram)

Returns the probability of scenario `i`th scenario in `stochasticprogram` occuring.
"""
function probability(stochasticprogram::StochasticProgram, i::Integer)
    return probability(scenario(stochasticprogram, i))
end
"""
    probability(stochasticprogram::StochasticProgram)

Returns the probability of any scenario in `stochasticprogram` occuring. A well defined model should return 1.
"""
function probability(stochasticprogram::StochasticProgram)
    return probability(stochasticprogram.scenarioproblems)
end
"""
    has_generator(stochasticprogram::StochasticProgram, key::Symbol)

Returns true if a problem generator with `key` exists in `stochasticprogram`.
"""
function has_generator(stochasticprogram::StochasticProgram, key::Symbol)
    return haskey(stochasticprogram.generator, key)
end
"""
    generator(stochasticprogram::StochasticProgram, key::Symbol)

Returns the problem generator associated with `key` in `stochasticprogram`.
"""
function generator(stochasticprogram::StochasticProgram, key::Symbol)
    return stochasticprogram.generator[key]
end
"""
    subproblem(stochasticprogram::StochasticProgram, i::Integer)

Returns the `i`th subproblem in `stochasticprogram`.
"""
function subproblem(stochasticprogram::StochasticProgram, i::Integer)
    return subproblem(stochasticprogram.scenarioproblems, i)
end
"""
    subproblems(stochasticprogram::StochasticProgram)

Returns an array of all subproblems in `stochasticprogram`.
"""
function subproblems(stochasticprogram::StochasticProgram)
    return subproblems(stochasticprogram.scenarioproblems)
end
"""
    nsubproblems(stochasticprogram::StochasticProgram)

Returns the number of subproblems in `stochasticprogram`.
"""
function nsubproblems(stochasticprogram::StochasticProgram)
    return nsubproblems(stochasticprogram.scenarioproblems)
end
"""
    masterterms(stochasticprogram::StochasticProgram, i::Integer)

Returns the first stage terms appearing in scenario `i` in `stochasticprogram`. The master terms are given in sparse format as an array of tuples `(row,col,coeff)` which specify the occurance of master problem variables in the second stage constraints.
"""
function masterterms(stochasticprogram::StochasticProgram, i::Integer)
    return masterterms(stochasticprogram.scenarioproblems, i)
end
"""
    nscenarios(stochasticprogram::StochasticProgram)

Returns the number of scenarios in `stochasticprogram`.
"""
function nscenarios(stochasticprogram::StochasticProgram)
    return nscenarios(stochasticprogram.scenarioproblems)
end
"""
    sampler(stochasticprogram::StochasticProgram)

Returns the sampler object, if any, in `stochasticprogram`.
"""
function sampler(stochasticprogram::StochasticProgram)
    return sampler(stochasticprogram.scenarioproblems)
end
"""
    nstages(stochasticprogram::StochasticProgram)

Returns the number of stages in `stochasticprogram`. Will return 2 for two-stage problems.
"""
nstages(stochasticprogram::StochasticProgram) = 2
"""
    spsolver(stochasticprogram::StochasticProgram)

Returns the stochastic program solver `spsolver` in `stochasticprogram`.
"""
function spsolver(stochasticprogram::StochasticProgram)
    return stochasticprogram.spsolver.solver
end
"""
    optimal_decision(stochasticprogram::StochasticProgram)

Returns the optimal first stage decision of `stochasticprogram`, after a call to `solve(stochasticprogram)`.
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

Returns the optimal first stage variable `var` of `stochasticprogram`, after a call to `solve(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::StochasticProgram, var::Symbol)
    return getvalue(get_stage_one(stochasticprogram).objDict[var])
end
"""
    optimal_decision(stochasticprogram::StochasticProgram, i::Integer)

Returns the optimal second stage decision of `stochasticprogram` in the `i`th scenario, after a call to `solve(stochasticprogram)`.
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

Returns the optimal second stage variable `var` of `stochasticprogram` in the `i`th scenario, after a call to `solve(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::StochasticProgram, i::Integer, var::Symbol)
    submodel = subproblem(stochasticprogram, i)
    return getvalue(subproblem.objDict[var])
end
"""
    optimal_value(stochasticprogram::StochasticProgram)

Returns the optimal value of `stochasticprogram`, after a call to `solve(stochasticprogram)`.
"""
function optimal_value(stochasticprogram::StochasticProgram)
    return get_stage_one(stochasticprogram).objVal
end
"""
    optimal_value(stochasticprogram::StochasticProgram, i::Integer)

Returns the optimal value of the `i`th subproblem in `stochasticprogram`, after a call to `solve(stochasticprogram)`.
"""
function optimal_value(stochasticprogram::StochasticProgram, i::Integer)
    submodel = subproblem(stochasticprogram, i)
    return submodel.objVal
end
# ========================== #

# Setters
# ========================== #
"""
    set_spsolver(stochasticprogram::StochasticProgram, spsolver::Union{MathProgBase.AbstractMathProgSolver,AbstractStructuredSolver})

Stores the stochastic program solver `spsolver` in `stochasticprogram`.
"""
function set_spsolver(stochasticprogram::StochasticProgram, spsolver::Union{MathProgBase.AbstractMathProgSolver,AbstractStructuredSolver})
    stochasticprogram.spsolver.solver = spsolver
    nothing
end
"""
    set_first_stage_data(stochasticprogram::StochasticProgram, data::Any)

Stores the first stage `data` in first stage of `stochasticprogram`.
"""
function set_first_stage_data!(stochasticprogram::StochasticProgram, data::Any)
    stochasticprogram.first_stage.data = data
    nothing
end
"""
    set_second_stage_data!(stochasticprogram::StochasticProgram, data::Any)

Stores the second stage `data` in second stage of `stochasticprogram`.
"""
function set_second_stage_data!(stochasticprogram::StochasticProgram, data::Any)
    set_stage_data(stochasticprogram.scenarioproblems, data)
    nothing
end
function add_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenarioData; defer::Bool = false)
    add_scenario!(scenarioproblems(stochasticprogram), scenario)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
function add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenarioData}; defer::Bool = false)
    add_scenarios!(scenarioproblems(stochasticprogram), scenarios)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
# ========================== #

# Sampling #
# ========================== #
"""
    sample!(stochasticprogram::StochasticProgram, n::Integer)

Samples `n` scenarios from the sampler object in `stochasticprogram`, if any, and generates subproblems for each of them.
"""
function sample!(stochasticprogram::StochasticProgram, n::Integer)
    sample!(scenarioproblems(stochasticprogram), n)
    generate_stage_two!(stochasticprogram)
end
# ========================== #

# Private #
# ========================== #
problemcache(stochasticprogram::StochasticProgram) = stochasticprogram.problemcache
get_problem(stochasticprogram::StochasticProgram, key::Symbol) = stochasticprogram.problemcache[key]
get_stage_one(stochasticprogram::StochasticProgram) = get_problem(stochasticprogram, :stage_1)
# ========================== #
