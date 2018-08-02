struct StochasticProgramData{D1, D2, SD <: AbstractScenarioData, S <: AbstractSampler{SD}, SP <: Union{ScenarioProblems{D2,SD,S},
                                                                                                       DScenarioProblems{D2,SD,S}}}
    first_stage::Stage{D1}
    scenarioproblems::SP
    generator::Dict{Symbol,Function}
    problemcache::Dict{Symbol,JuMP.Model}
    spsolver::SPSolver

    function (::Type{StochasticProgramData})(stage_1::D1,stage_2::D2,::Type{SD},procs::Vector{Int}) where {D1,D2,SD <: AbstractScenarioData}
        S = NullSampler{SD}
        scenarioproblems = ScenarioProblems(2,stage_2,SD,procs)
        return new{D1,D2,SD,S,typeof(scenarioproblems)}(Stage(1,stage_1),scenarioproblems,Dict{Symbol,Function}(),Dict{Symbol,JuMP.Model}(),SPSolver(JuMP.UnsetSolver()))
    end

    function (::Type{StochasticProgramData})(stage_1::D1,stage_2::D2,scenariodata::Vector{<:AbstractScenarioData},procs::Vector{Int}) where {D1,D2}
        SD = eltype(scenariodata)
        S = NullSampler{SD}
        scenarioproblems = ScenarioProblems(2,stage_2,scenariodata,procs)
        return new{D1,D2,SD,S,typeof(scenarioproblems)}(Stage(1,stage_1),scenarioproblems,Dict{Symbol,Function}(),Dict{Symbol,JuMP.Model}(),SPSolver(JuMP.UnsetSolver()))
    end

    function (::Type{StochasticProgramData})(stage_1::D1,stage_2::D2,sampler::AbstractSampler{SD},procs::Vector{Int}) where {D1,D2,SD <: AbstractScenarioData}
        S = typeof(sampler)
        scenarioproblems = ScenarioProblems(2,stage_2,sampler,procs)
        return new{D1,D2,SD,S,typeof(scenarioproblems)}(Stage(1,stage_1),scenarioproblems,Dict{Symbol,Function}(),Dict{Symbol,JuMP.Model}(),SPSolver(JuMP.UnsetSolver()))
    end
end

function StochasticProgram(stage_1::D1,stage_2::D2,::Type{SD}; solver = JuMP.UnsetSolver(), procs = workers) where {D1,D2,SD <: AbstractScenarioData}
    stochasticprogram = JuMP.Model()
    stochasticprogram.ext[:SP] = StochasticProgramData(stage_1,stage_2,SD,procs)
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
    stochasticprogram.ext[:SP] = StochasticProgramData(stage_1,stage_2,scenariodata,procs)
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
    stochasticprogram.ext[:SP] = StochasticProgramData(stage_1,stage_2,sampler,procs)
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
    if length(subproblems(stochasticprogram)) != length(scenarios(stochasticprogram))
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
        structuredmodel = StructuredModel(supplied_solver,stochasticprogram; kwargs...)
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
function scenarioproblems(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP].scenarioproblems
end
function first_stage_data(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP].first_stage.data
end
function second_stage_data(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stage_data(stochasticprogram.ext[:SP].scenarioproblems)
end
function scenario(stochasticprogram::JuMP.Model,i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return scenario(scenarioproblems(stochasticprogram),i)
end
function scenarios(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return scenarios(scenarioproblems(stochasticprogram))
end
function scenariotype(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return scenariotype(scenarioproblems(stochasticprogram))
end
function probability(stochasticprogram::JuMP.Model,i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return probability(scenario(stochasticprogram,i))
end
function probability(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return probability(stochasticprogram.ext[:SP].scenarioproblems)
end
function has_generator(stochasticprogram::JuMP.Model,key::Symbol)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return haskey(stochasticprogram.ext[:SP].generator,key)
end
function generator(stochasticprogram::JuMP.Model,key::Symbol)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP].generator[key]
end
function subproblem(stochasticprogram::JuMP.Model,i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return subproblem(stochasticprogram.ext[:SP].scenarioproblems,i)
end
function subproblems(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return subproblems(stochasticprogram.ext[:SP].scenarioproblems)
end
function nsubproblems(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return length(stochasticprogram.ext[:SP].scenarioproblems)
end
function masterterms(stochasticprogram::JuMP.Model,i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return subproblems(stochasticprogram.ext[:SP].scenarioproblems,i)
end
function nscenarios(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return nscenarios(stochasticprogram.ext[:SP].scenarioproblems)
end
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
function spsolver(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP].spsolver.solver
end
function optimal_decision(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    decision = stochasticprogram.colVal
    if any(isnan.(decision))
        warn("Optimal decision not defined. Check that the model was properly solved.")
    end
    return decision
end
function optimal_decision(stochasticprogram::JuMP.Model,i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    submodel = subproblem(stochasticprogram,i)
    decision = submodel.colVal
    if any(isnan.(decision))
        warn("Optimal decision not defined in subproblem $i. Check that the model was properly solved.")
    end
    return decision
end
function optimal_decision(stochasticprogram::JuMP.Model,var::Symbol)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return getvalue(stochasticprogram.objDict[var])
end
function optimal_value(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.objVal
end
function optimal_value(stochasticprogram::JuMP.Model,i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    submodel = subproblem(stochasticprogram,i)
    return submodel.objVal
end
# ========================== #

# Setters
# ========================== #
function set_spsolver(stochasticprogram::JuMP.Model,spsolver::Union{MathProgBase.AbstractMathProgSolver,AbstractStructuredSolver})
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    stochasticprogram.ext[:SP].spsolver.solver = spsolver
    nothing
end
# ========================== #

# Base overloads
# ========================== #
function Base.push!(stochasticprogram::JuMP.Model,sdata::AbstractScenarioData)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    push!(scenarioproblems(stochasticprogram),sdata)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
function Base.append!(stochasticprogram::JuMP.Model,sdata::Vector{<:AbstractScenarioData})
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    append!(scenarioproblems(stochasticprogram),sdata)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
# ========================== #

# Sampling #
# ========================== #
function sample!(stochasticprogram::JuMP.Model,n::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    sample!(scenarioproblems(stochasticprogram),n)
    generate_stage_two!(stochasticprogram)
end
# ========================== #
