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
    stochasticprogram = JuMP.Model()
    stochasticprogram.ext[:SP] = StochasticProgram(stage_1,stage_2,SD,procs)
    stochasticprogram.ext[:SP].spsolver.solver = solver
    # Set hooks
    JuMP.setsolvehook(stochasticprogram, _solve)
    JuMP.setprinthook(stochasticprogram, _printhook)
    # Return stochastic program
    return stochasticprogram
end
StochasticProgram(scenariodata::Vector{<:AbstractScenarioData}; solver = JuMP.UnsetSolver(), procs = workers()) = StochasticProgram(nothing,nothing,scenariodata; solver = solver, procs = procs)
function StochasticProgram(stage_1::D1,stage_2::D2,scenariodata::Vector{<:AbstractScenarioData}; solver = JuMP.UnsetSolver(), procs = workers()) where {D1,D2}
    stochasticprogram = JuMP.Model()
    stochasticprogram.ext[:SP] = StochasticProgram(stage_1,stage_2,scenariodata,procs)
    stochasticprogram.ext[:SP].spsolver.solver = solver
    # Set hooks
    JuMP.setsolvehook(stochasticprogram, _solve)
    JuMP.setprinthook(stochasticprogram, _printhook)
    # Return stochastic program
    return stochasticprogram
end
StochasticProgram(sampler::AbstractSampler; solver = JuMP.UnsetSolver(), procs = workers()) = StochasticProgram(nothing,nothing,sampler; solver = solver, procs = procs)
function StochasticProgram(stage_1::D1,stage_2::D2,sampler::AbstractSampler; solver = JuMP.UnsetSolver(), procs = workers()) where {D1,D2}
    stochasticprogram = JuMP.Model()
    stochasticprogram.ext[:SP] = StochasticProgram(stage_1,stage_2,sampler,procs)
    stochasticprogram.ext[:SP].spsolver.solver = solver
    # Set hooks
    JuMP.setsolvehook(stochasticprogram, _solve)
    JuMP.setprinthook(stochasticprogram, _printhook)
    # Return stochastic program
    return stochasticprogram
end

# Hooks #
# ========================== #
function _solve(stochasticprogram::JuMP.Model; suppress_warnings=false, solver = JuMP.UnsetSolver(), kwargs...)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    if nsubproblems(stochasticprogram) != nscenarios(stochasticprogram)
        generate!(stochasticprogram)
    end
    # Prefer cached solver if available
    supplied_solver = pick_solver(stochasticprogram,solver)
    # Switch on solver type
    if supplied_solver isa MathProgBase.AbstractMathProgSolver
        # Standard mathprogbase solver. Fallback to solving DEP, relying on JuMP.
        dep = DEP(stochasticprogram,optimsolver(supplied_solver))
        status = solve(dep; kwargs...)
        fill_solution!(stochasticprogram)
        return status
    elseif supplied_solver isa AbstractStructuredSolver
        # Use structured solver
        structuredmodel = StructuredModel(supplied_solver,stochasticprogram)
        stochasticprogram.internalModel = structuredmodel
        stochasticprogram.internalModelLoaded = true
        status = optimize_structured!(structuredmodel)
        fill_solution!(structuredmodel,stochasticprogram)
        return status
    else
        error("Unknown solver object given. Aborting.")
    end
end

function _printhook(io::IO, stochasticprogram::JuMP.Model)
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
function stochastic(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP]
end
"""
    scenarioproblems(stochasticprogram::JuMP.Model)

Returns the scenario problems in `stochasticprogram`.
"""
function scenarioproblems(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP].scenarioproblems
end
"""
    first_stage_data(stochasticprogram::JuMP.Model)

Returns the first stage data structure, if any exists, in `stochasticprogram`.
"""
function first_stage_data(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP].first_stage.data
end
"""
    second_stage_data(stochasticprogram::JuMP.Model)

Returns the second stage data structure, if any exists, in `stochasticprogram`.
"""
function second_stage_data(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stage_data(stochasticprogram.ext[:SP].scenarioproblems)
end
"""
    scenario(stochasticprogram::JuMP.Model, i::Integer)

Returns the `i`th scenario in `stochasticprogram`.
"""
function scenario(stochasticprogram::JuMP.Model, i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return scenario(scenarioproblems(stochasticprogram),i)
end
"""
    scenarios(stochasticprogram::JuMP.Model)

Returns an array of all scenarios in `stochasticprogram`.
"""
function scenarios(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return scenarios(scenarioproblems(stochasticprogram))
end
"""
    expected(stochasticprogram::JuMP.Model)

Returns the exected scenario of all scenarios in `stochasticprogram`.
"""
function expected(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return expected(scenarioproblems(stochasticprogram))
end
"""
    scenariotype(stochasticprogram::JuMP.Model)

Returns the type of the scenario structure associated with `stochasticprogram`.
"""
function scenariotype(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return scenariotype(scenarioproblems(stochasticprogram))
end
"""
    probability(stochasticprogram::JuMP.Model)

Returns the probability of scenario `i`th scenario in `stochasticprogram` occuring.
"""
function probability(stochasticprogram::JuMP.Model, i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return probability(scenario(stochasticprogram,i))
end
"""
    probability(stochasticprogram::JuMP.Model)

Returns the probability of any scenario in `stochasticprogram` occuring. A well defined model should return 1.
"""
function probability(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return probability(stochasticprogram.ext[:SP].scenarioproblems)
end
"""
    has_generator(stochasticprogram::JuMP.Model, key::Symbol)

Returns true if a problem generator with `key` exists in `stochasticprogram`.
"""
function has_generator(stochasticprogram::JuMP.Model, key::Symbol)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return haskey(stochasticprogram.ext[:SP].generator,key)
end
"""
    generator(stochasticprogram::JuMP.Model, key::Symbol)

Returns the problem generator associated with `key` in `stochasticprogram`.
"""
function generator(stochasticprogram::JuMP.Model, key::Symbol)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP].generator[key]
end
"""
    subproblem(stochasticprogram::JuMP.Model, i::Integer)

Returns the `i`th subproblem in `stochasticprogram`.
"""
function subproblem(stochasticprogram::JuMP.Model, i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return subproblem(stochasticprogram.ext[:SP].scenarioproblems,i)
end
"""
    subproblems(stochasticprogram::JuMP.Model)

Returns an array of all subproblems in `stochasticprogram`.
"""
function subproblems(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return subproblems(stochasticprogram.ext[:SP].scenarioproblems)
end
"""
    nsubproblems(stochasticprogram::JuMP.Model)

Returns the number of subproblems in `stochasticprogram`.
"""
function nsubproblems(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return nsubproblems(stochasticprogram.ext[:SP].scenarioproblems)
end
"""
    masterterms(stochasticprogram::JuMP.Model, i::Integer)

Returns the first stage terms appearing in scenario `i` in `stochasticprogram`. The master terms are given in sparse format as an array of tuples `(row,col,coeff)` which specify the occurance of master problem variables in the second stage constraints.
"""
function masterterms(stochasticprogram::JuMP.Model, i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return masterterms(stochasticprogram.ext[:SP].scenarioproblems,i)
end
"""
    nscenarios(stochasticprogram::JuMP.Model)

Returns the number of scenarios in `stochasticprogram`.
"""
function nscenarios(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return nscenarios(stochasticprogram.ext[:SP].scenarioproblems)
end
"""
    sampler(stochasticprogram::JuMP.Model)

Returns the sampler object, if any, in `stochasticprogram`.
"""
function sampler(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return sampler(stochasticprogram.ext[:SP].scenarioproblems)
end
"""
    nstages(stochasticprogram::JuMP.Model)

Returns the number of stages in `stochasticprogram`. Will return 2 for two-stage problems.
"""
function nstages(stochasticprogram::JuMP.Model)
    if haskey(stochasticprogram.ext,:SP)
        return 2
    elseif haskey(stochasticprogram.ext,:MSSP)
        return length(stochasticprogram.ext[:MSSP].stages)+1
    else
        error("The given model is not a stochastic program.")
    end
end
problemcache(stochasticprogram::JuMP.Model) = stochasticprogram.ext[:SP].problemcache
"""
    spsolver(stochasticprogram::JuMP.Model)

Returns the stochastic program solver, if any, in `stochasticprograms`.
"""
function spsolver(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP].spsolver.solver
end
"""
    optimal_decision(stochasticprogram::JuMP.Model)

Returns the optimal first stage decision of `stochasticprogram`, after a call to `solve(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    decision = stochasticprogram.colVal
    if any(isnan.(decision))
        @warn "Optimal decision not defined. Check that the model was properly solved."
    end
    return decision
end
"""
    optimal_decision(stochasticprogram::JuMP.Model, var::Symbol)

Returns the optimal first stage variable `var` of `stochasticprogram`, after a call to `solve(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::JuMP.Model, var::Symbol)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return getvalue(stochasticprogram.objDict[var])
end
"""
    optimal_decision(stochasticprogram::JuMP.Model, i::Integer)

Returns the optimal second stage decision of `stochasticprogram` in the `i`th scenario, after a call to `solve(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::JuMP.Model, i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    submodel = subproblem(stochasticprogram,i)
    decision = submodel.colVal
    if any(isnan.(decision))
        @warn "Optimal decision not defined in subproblem $i. Check that the model was properly solved."
    end
    return decision
end
"""
    optimal_decision(stochasticprogram::JuMP.Model, var::Symbol)

Returns the optimal second stage variable `var` of `stochasticprogram` in the `i`th scenario, after a call to `solve(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::JuMP.Model, i::Integer, var::Symbol)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    submodel = subproblem(stochasticprogram,i)
    return getvalue(subproblem.objDict[var])
end
"""
    optimal_value(stochasticprogram::JuMP.Model)

Returns the optimal value of `stochasticprogram`, after a call to `solve(stochasticprogram)`.
"""
function optimal_value(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.objVal
end
"""
    optimal_value(stochasticprogram::JuMP.Model, i::Integer)

Returns the optimal value of the `i`th subproblem in `stochasticprogram`, after a call to `solve(stochasticprogram)`.
"""
function optimal_value(stochasticprogram::JuMP.Model, i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    submodel = subproblem(stochasticprogram,i)
    return submodel.objVal
end
# ========================== #

# Setters
# ========================== #
"""
    set_spsolver(stochasticprogram::JuMP.Model, spsolver::Union{MathProgBase.AbstractMathProgSolver,AbstractStructuredSolver})

Stores the stochastic program solver `spsolver` in `stochasticprogram`.
"""
function set_spsolver(stochasticprogram::JuMP.Model, spsolver::Union{MathProgBase.AbstractMathProgSolver,AbstractStructuredSolver})
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    stochasticprogram.ext[:SP].spsolver.solver = spsolver
    nothing
end
"""
    set_first_stage_data(stochasticprogram::JuMP.Model, data::Any)

Stores the first stage `data` in first stage of `stochasticprogram`.
"""
function set_first_stage_data!(stochasticprogram::JuMP.Model, data::Any)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    stochasticprogram.ext[:SP].first_stage.data = data
    nothing
end
"""
    set_second_stage_data!(stochasticprogram::JuMP.Model, data::Any)

Stores the second stage `data` in second stage of `stochasticprogram`.
"""
function set_second_stage_data!(stochasticprogram::JuMP.Model, data::Any)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    set_stage_data(stochasticprogram.ext[:SP].scenarioproblems, data)
    nothing
end
function add_scenario!(stochasticprogram::JuMP.Model, scenario::AbstractScenarioData; defer::Bool = false)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    push!(scenarioproblems(stochasticprogram),sdata)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
function add_scenarios!(stochasticprogram::JuMP.Model, sdata::Vector{<:AbstractScenarioData}; defer::Bool = false)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    append!(scenarioproblems(stochasticprogram),sdata)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
# ========================== #

# Sampling #
# ========================== #
"""
    sample!(stochasticprogram::JuMP.Model, n::Integer)

Samples `n` scenarios from the sampler object in `stochasticprogram`, if any, and generates subproblems for each of them.
"""
function sample!(stochasticprogram::JuMP.Model, n::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    sample!(scenarioproblems(stochasticprogram),n)
    generate_stage_two!(stochasticprogram)
end
# ========================== #
