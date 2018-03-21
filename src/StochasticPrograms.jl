module StochasticPrograms

using JuMP
using MathProgBase
using MacroTools
using MacroTools: @q, postwalk

export
    StochasticProgram,
    AbstractScenarioData,
    AbstractStructuredSolver,
    AbstractStructuredModel,
    StructuredModel,
    stochastic,
    scenario,
    scenarios,
    probability,
    subproblem,
    subproblems,
    nscenarios,
    stage_two_model,
    outcome_model,
    eval_decision,
    @first_stage,
    @second_stage,
    WS,
    EWS,
    DEP,
    RP,
    EVPI,
    EVP,
    EV,
    EEV,
    VSS

abstract type AbstractStructuredSolver end
abstract type AbstractScenarioData end
abstract type AbstractSampler{SD <: AbstractScenarioData} end
struct NullSampler{SD <: AbstractScenarioData} <: AbstractSampler{SD} end

probability(sd::AbstractScenarioData) = sd.π

function expected(::Vector{SD}) where SD <: AbstractScenarioData
   error("Expected value operation not implemented for scenariodata type: ", SD)
end

struct StochasticProgramData{SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    scenariodata::Vector{SD}
    sampler::S
    generator::Dict{Symbol,Function}
    subproblems::Vector{JuMP.Model}
    problemcache::Dict{Symbol,JuMP.Model}

    function (::Type{StochasticProgramData})(::Type{SD}) where SD <: AbstractScenarioData
        S = NullSampler{SD}
        return new{SD,S}(Vector{SD}(),NullSampler{SD}(),Dict{Symbol,Function}(),Vector{JuMP.Model}(),Dict{Symbol,JuMP.Model}())
    end

    function (::Type{StochasticProgramData})(scenariodata::Vector{<:AbstractScenarioData})
        SD = eltype(scenariodata)
        S = NullSampler{SD}
        return new{SD,S}(scenariodata,NullSampler{SD}(),Dict{Symbol,Function}(),Vector{JuMP.Model}(),Dict{Symbol,JuMP.Model}())
    end

    function (::Type{StochasticProgramData})(sampler::AbstractSampler{SD}) where SD <: AbstractScenarioData
        S = typeof(sampler)
        return new{SD,S}(Vector{SD}(),sampler,Dict{Symbol,Function}(),Vector{JuMP.Model}(),Dict{Symbol,JuMP.Model}())
    end
end

function StochasticProgram(::Type{SD}; solver = JuMP.UnsetSolver()) where SD <: AbstractScenarioData
    stochasticprogram = JuMP.Model(solver=solver)
    stochasticprogram.ext[:SP] = StochasticProgramData(SD)

    # Set hooks
    JuMP.setsolvehook(stochasticprogram, _solve)
    JuMP.setprinthook(stochasticprogram, _printhook)

    return stochasticprogram
end
function StochasticProgram(scenariodata::Vector{SD}; solver = JuMP.UnsetSolver()) where SD <: AbstractScenarioData
    stochasticprogram = JuMP.Model(solver=solver)
    stochasticprogram.ext[:SP] = StochasticProgramData(scenariodata)

    # Set hooks
    JuMP.setsolvehook(stochasticprogram, _solve)
    JuMP.setprinthook(stochasticprogram, _printhook)

    return stochasticprogram
end
function StochasticProgram(sampler::AbstractSampler; solver = JuMP.UnsetSolver())
    stochasticprogram = JuMP.Model(solver=solver)
    stochasticprogram.ext[:SP] = StochasticProgramData(sampler)

    # Set hooks
    JuMP.setsolvehook(stochasticprogram, _solve)
    JuMP.setprinthook(stochasticprogram, _printhook)

    return stochasticprogram
end

function _solve(stochasticprogram::JuMP.Model; suppress_warnings=false, solver = JuMP.UnsetSolver(), kwargs...)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    if length(subproblems(stochasticprogram)) != length(scenarios(stochasticprogram))
        generate_subproblems!(stochasticprogram)
    end

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    if optimsolver isa MathProgBase.AbstractMathProgSolver
        # Standard mathprogbase solver. Fallback to solving DEP model, relying on JuMP.
        dep = DEP(stochasticprogram,optimsolver)
        status = solve(dep; kwargs...)
        fill_solution!(stochasticprogram)
        return status
    elseif optimsolver isa AbstractStructuredSolver
        # Use structured solver
        structuredmodel = StructuredModel(optimsolver,stochasticprogram; kwargs...)
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
    print(io, "Second-stage \n")
    print(io, "============== \n")
    for (id, subproblem) in enumerate(subproblems(stochasticprogram))
      @printf(io, "Subproblem %d:\n", id)
      print(io, subproblem)
      print(io, "\n")
    end
end

# Getters #
# ========================== #
function stochastic(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP]
end
function scenario(stochasticprogram::JuMP.Model,i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP].scenariodata[i]
end
function scenarios(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP].scenariodata
end
function probability(stochasticprogram::JuMP.Model,i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return probability(stochasticprogram.ext[:SP].scenariodata[i])
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
    return subproblems(stochasticprogram)[i]
end
function subproblems(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP].subproblems
end
function nscenarios(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return length(stochasticprogram.ext[:SP].subproblems)
end
problemcache(stochasticprogram::JuMP.Model) = stochasticprogram.ext[:SP].problemcache
# ========================== #

# Base overloads
# ========================== #
function Base.push!(sp::StochasticProgramData{SD},sdata::SD) where SD <: AbstractScenarioData
    push!(sp.scenariodata,sdata)
end
function Base.push!(stochasticprogram::JuMP.Model,sdata::AbstractScenarioData)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    push!(stochastic(stochasticprogram),sdata)
    invalidate_cache!(stochasticprogram)
end
function Base.append!(sp::StochasticProgramData{SD},sdata::Vector{SD}) where SD <: AbstractScenarioData
    append!(sp.scenariodata,sdata)
end
function Base.append!(stochasticprogram::JuMP.Model,sdata::Vector{<:AbstractScenarioData})
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    append!(stochastic(stochasticprogram),sdata)
    invalidate_cache!(stochasticprogram)
end
# ========================== #

# Problem generation #
# ========================== #
function stage_two_model(stochasticprogram::JuMP.Model,scenario::AbstractScenarioData)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Use @second_stage when defining stochastic program. Aborting.")
    stage_two_model = Model(solver=JuMP.UnsetSolver())
    generator(stochasticprogram,:second_stage)(stage_two_model,scenario,stochasticprogram)
    return stage_two_model
end

function generate_stage_two!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    sp = stochastic(stochasticprogram)
    for i in nscenarios(stochasticprogram)+1:length(sp.scenariodata)
        push!(sp.subproblems,stage_two_model(stochasticprogram,scenario(stochasticprogram,i)))
    end
    nothing
end

function outcome_model(stochasticprogram::JuMP.Model,scenario::AbstractScenarioData,x::AbstractVector,solver::MathProgBase.AbstractMathProgSolver)
    has_generator(stochasticprogram,:first_stage_vars) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    outcome_model = Model(solver = solver)
    generator(stochasticprogram,:first_stage_vars)(outcome_model)
    for obj in values(outcome_model.objDict)
        if isa(obj,JuMP.Variable)
            val = x[obj.col]
            outcome_model.colCat[obj.col] = :Fixed
            outcome_model.colVal[obj.col] = val
            outcome_model.colLower[obj.col] = val
            outcome_model.colUpper[obj.col] = val
        elseif isa(obj,JuMP.JuMPArray{JuMP.Variable})
            for var in obj.innerArray
                val = x[var.col]
                outcome_model.colCat[var.col] = :Fixed
                outcome_model.colVal[var.col] = val
                outcome_model.colLower[var.col] = val
                outcome_model.colUpper[var.col] = val
            end
        else
            continue
        end
    end
    generator(stochasticprogram,:second_stage)(outcome_model,scenario,outcome_model)

    return outcome_model
end
# ========================== #

# Problem evaluation #
# ========================== #
function _eval_first_stage(stochasticprogram::JuMP.Model,x::AbstractVector)
    return eval_objective(stochasticprogram.obj,x)
end

function _eval_second_stage(stochasticprogram::JuMP.Model,scenario::AbstractScenarioData,x::AbstractVector,solver::MathProgBase.AbstractMathProgSolver)
    outcome = outcome_model(stochasticprogram,scenario,x,solver)
    solve(outcome)

    return probability(scenario)*getobjectivevalue(outcome)
end

function _eval(stochasticprogram::JuMP.Model,x::AbstractVector,solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    length(x) == stochasticprogram.numCols || error("Incorrect length of given decision vector, has ",length(x)," should be ",stochasticprogram.numCols)
    all(.!(isnan.(x))) || error("Given decision vector has NaN elements")

    val = _eval_first_stage(stochasticprogram,x)

    for scenario in scenarios(stochasticprogram)
        val += _eval_second_stage(stochasticprogram,scenario,x,solver)
    end

    return val
end

function eval_decision(stochasticprogram::JuMP.Model,x::AbstractVector; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot evaluate decision without a solver.")
    end

    return _eval(stochasticprogram,x,optimsolver)
end
# ========================== #

# SP Constructs #
# ========================== #
WS(stochasticprogram::JuMP.Model,scenario::AbstractScenarioData) = WS(stochasticprogram,scenario,JuMP.UnsetSolver())
function WS(stochasticprogram::JuMP.Model, scenario::AbstractScenarioData, solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot create WS model without a solver.")
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    ws_model = Model(solver = optimsolver)
    generator(stochasticprogram,:first_stage)(ws_model)
    ws_obj = copy(ws_model.obj)
    generator(stochasticprogram,:second_stage)(ws_model,scenario,ws_model)
    append!(ws_obj,ws_model.obj)
    ws_model.obj = ws_obj

    return ws_model
end
function EWS(stochasticprogram::JuMP.Model, scenarios::Vector{<:AbstractScenarioData}; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end

    # Solve all possible WS models and compute EWS
    ews = sum([
        begin
        ws = WS(stochasticprogram,scenario,optimsolver)
        solve(ws)
        probability(scenario)*getobjectivevalue(ws)
        end for scenario in scenarios])
    return ews
end

DEP(stochasticprogram::JuMP.Model) = DEP(stochasticprogram,JuMP.UnsetSolver())
function DEP(stochasticprogram::JuMP.Model, solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:dep)
        return cache[:dep]
    end
    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end
    # Abort at this stage if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot create new DEP model without a solver.")
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    # Define first-stage problem
    dep_model = Model(solver = optimsolver)
    generator(stochasticprogram,:first_stage)(dep_model)
    dep_obj = copy(dep_model.obj)

    # Define second-stage problems, renaming variables according to scenario.
    visited_objs = collect(keys(dep_model.objDict))
    for (i,scenario) in enumerate(scenarios(stochasticprogram))
        generator(stochasticprogram,:second_stage)(dep_model,scenario,dep_model)
        append!(dep_obj,probability(scenario)*dep_model.obj)
        for (objkey,obj) ∈ dep_model.objDict
            if objkey ∉ visited_objs
                newkey = if (isa(obj,JuMP.Variable))
                    varname = @sprintf("%s_%d",dep_model.colNames[obj.col],i)
                    dep_model.colNames[obj.col] = varname
                    dep_model.colNamesIJulia[obj.col] = varname
                    newkey = Symbol(varname)
                elseif isa(obj,JuMP.ConstraintRef)
                    arrayname = @sprintf("%s_%d",objkey,i)
                    newkey = Symbol(arrayname)
                elseif isa(obj,JuMP.JuMPArray)
                    newkey = if isa(obj,JuMP.JuMPArray{JuMP.ConstraintRef})
                        arrayname = @sprintf("%s_%d",objkey,i)
                        newkey = Symbol(arrayname)
                    else
                        JuMP.fill_var_names(JuMP.REPLMode, dep_model.colNames, obj)
                        arrayname = @sprintf("%s_%d",dep_model.varData[obj].name,i)
                        newkey = Symbol(arrayname)
                        dep_model.varData[obj].name = newkey
                        for var in obj.innerArray
                            splitname = split(dep_model.colNames[var.col],"[")
                            varname = @sprintf("%s_%d[%s",splitname[1],i,splitname[2])
                            dep_model.colNames[var.col] = varname
                            dep_model.colNamesIJulia[var.col] = varname
                        end
                        newkey
                    end
                 else
                    continue
                end
                dep_model.objDict[newkey] = obj
                delete!(dep_model.objDict,objkey)
                push!(visited_objs,newkey)
            end
        end
    end
    dep_model.obj = dep_obj

    # Cache dep model
    cache[:dep] = dep_model

    return dep_model
end

function RP(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end

    # Solve EVP model
    dep = DEP(stochasticprogram,optimsolver)
    solve(dep)

    return getobjectivevalue(dep)
end

function EVPI(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end

    # Solve DEP model
    dep = DEP(stochasticprogram,optimsolver)
    solve(dep)
    evpi = (dep.objSense == :Max ? -1 : 1)*getobjectivevalue(dep)

    # Solve all possible WS models
    for scenario in scenarios(stochasticprogram)
        ws = WS(stochasticprogram,scenario,solver)
        solve(ws)
        evpi += (ws.objSense == :Max ? 1 : -1)*probability(scenario)*getobjectivevalue(ws)
    end

    return evpi
end

EVP(stochasticprogram::JuMP.Model) = EVP(stochasticprogram,JuMP.UnsetSolver())
function EVP(stochasticprogram::JuMP.Model, solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:evp)
        return cache[:evp]
    end
    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end
    # Abort at this stage if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot create new EVP model without a solver.")
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    ev_model = Model(solver = optimsolver)
    generator(stochasticprogram,:first_stage)(ev_model)
    ev_obj = copy(ev_model.obj)
    generator(stochasticprogram,:second_stage)(ev_model,expected(scenarios(stochasticprogram)),ev_model)
    append!(ev_obj,ev_model.obj)
    ev_model.obj = ev_obj

    # Cache evp model
    cache[:evp] = ev_model

    return ev_model
end

function EV(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end

    # Solve EVP model
    evp = EVP(stochasticprogram, solver)
    solve(evp)

    return getobjectivevalue(evp)
end

function EEV(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot evaluate decision without a solver.")
    end

    # Solve EVP model
    evp = EVP(stochasticprogram,optimsolver)
    solve(evp)

    eev = _eval(stochasticprogram,evp.colVal[1:stochasticprogram.numCols],optimsolver)

    return eev
end

function VSS(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot evaluate decision without a solver.")
    end

    # Solve DEP model
    dep = DEP(stochasticprogram,optimsolver)
    solve(dep)
    vss = (dep.objSense == :Max ? 1 : -1)*getobjectivevalue(dep)

    vss += (dep.objSense == :Max ? -1 : 1)*EEV(stochasticprogram; solver = optimsolver)

    return vss
end
# ========================== #

# Utility #
# ========================== #
function eval_objective(objective::JuMP.GenericQuadExpr,x::AbstractVector)
    aff = objective.aff
    val = aff.constant
    for (i,var) in enumerate(aff.vars)
        val += aff.coeffs[i]*x[var.col]
    end

    return val
end

function fill_solution!(stochasticprogram::JuMP.Model)
    dep = DEP(stochasticprogram)

    # First stage
    nrows, ncols = length(stochasticprogram.linconstr), stochasticprogram.numCols
    stochasticprogram.objVal = dep.objVal
    stochasticprogram.colVal = dep.colVal[1:ncols]
    stochasticprogram.redCosts = dep.redCosts[1:ncols]
    stochasticprogram.linconstrDuals = dep.linconstrDuals[1:nrows]

    # Second stage
    for (i,subproblem) in enumerate(subproblems(stochasticprogram))
        snrows, sncols = length(subproblem.linconstr), subproblem.numCols
        subproblem.colVal = dep.colVal[ncols+1:ncols+sncols]
        subproblem.redCosts = dep.redCosts[ncols+1:ncols+sncols]
        subproblem.linconstrDuals = dep.linconstrDuals[nrows+1:nrows:snrows]
        subproblem.objVal = eval_objective(subproblem.obj,subproblem.colVal)
        ncols += sncols
        nrows += snrows
    end
end

function invalidate_cache!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    cache = problemcache(stochasticprogram)
    delete!(cache,:evp)
    delete!(cache,:dep)
end

# Creation macros #
# ========================== #
macro first_stage(args)
    @capture(args, model_Symbol = modeldef_) || error("Invalid syntax. Expected stochasticprogram = begin JuMPdef end")
    vardefs = Expr(:block)
    for line in modeldef.args
        @capture(line, @variable(m_Symbol,vardef_)) && push!(vardefs.args,line)
    end
    code = @q begin
        $(esc(model)).ext[:SP].generator[:first_stage_vars] = ($(esc(:model))::JuMP.Model) -> begin
            $(esc(vardefs))
	    return $(esc(:model))
        end
        $(esc(model)).ext[:SP].generator[:first_stage] = ($(esc(:model))::JuMP.Model) -> begin
            $(esc(modeldef))
	    return $(esc(:model))
        end
        $(esc(model)).ext[:SP].generator[:first_stage]($(esc(model)))
    end
    return code
end

macro second_stage(args)
    @capture(args, model_Symbol = modeldef_) || error("Invalid syntax. Expected stochasticprogram = begin JuMPdef end")
    def = postwalk(modeldef) do x
        @capture(x, @decision args__) || return x
        code = Expr(:block)
        for var in args
            varkey = Meta.quot(var)
            push!(code.args,:($var = parent.objDict[$varkey]))
        end
        return code
    end

    code = @q begin
        $(esc(model)).ext[:SP].generator[:second_stage] = ($(esc(:model))::JuMP.Model,$(esc(:scenario))::AbstractScenarioData,$(esc(:parent))::JuMP.Model) -> begin
            $(esc(def))
	    return $(esc(:model))
        end
        generate_stage_two!($(esc(model)))
        nothing
    end
    return prettify(code)
end
# ========================== #

# Structured solver interface
# ========================== #
abstract type AbstractStructuredSolver end
abstract type AbstractStructuredModel end

function StructuredModel(solver::AbstractStructuredSolver,stochasticprogram::JuMP.Model)
    throw(MethodError(StructuredModel,(solver,stochasticprogram)))
end

function optimize_structured!(structuredmodel::AbstractStructuredModel)
    throw(MethodError(optimize!,structuredmodel))
end

function fill_solution!(structuredmodel::AbstractStructuredModel,stochasticprogram::JuMP.Model)
    throw(MethodError(optimize!,structuredmodel))
end

end # module
