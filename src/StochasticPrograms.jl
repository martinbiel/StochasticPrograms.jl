module StochasticPrograms

using JuMP, MacroTools, MathProgBase
using MacroTools: @q, postwalk

export
    StochasticProgram,
    AbstractScenarioData,
    stochastic,
    scenario,
    scenarios,
    probability,
    subproblem,
    subproblems,
    num_scenarios,
    @first_stage,
    @second_stage,
    WS,
    DEP,
    EVPI,
    EVP,
    EV,
    EEV,
    VSS

abstract type AbstractStructuredSolver end
abstract type AbstractScenarioData end

probability(sd::AbstractScenarioData) = sd.π

function expected(::Vector{<:AbstractScenarioData})
   error("Not Implemented!")
end

struct StochasticProgramData{S <: AbstractScenarioData}
    scenariodata::Vector{S}
    generator::Dict{Symbol,Function}
    subproblems::Vector{JuMP.Model}
    problemcache::Dict{Symbol,JuMP.Model}

    function (::Type{StochasticProgramData})(::Type{S}) where S <: AbstractScenarioData
        return new{S}(Vector{S}(),Dict{Symbol,Function}(),Vector{JuMP.Model}(),Dict{Symbol,JuMP.Model}())
    end

    function (::Type{StochasticProgramData})(scenariodata::Vector{<:AbstractScenarioData})
        S = eltype(scenariodata)
        return new{S}(scenariodata,Dict{Symbol,Function}(),Vector{JuMP.Model}(),Dict{Symbol,JuMP.Model}())
    end
end

function StochasticProgram(::Type{S}) where S <: AbstractScenarioData
    stochasticprogram = JuMP.Model(solver=JuMP.UnsetSolver())
    stochasticprogram.ext[:SP] = StochasticProgramData(S)

    # Set hooks
    JuMP.setsolvehook(stochasticprogram, _solve)
    JuMP.setprinthook(stochasticprogram, _printhook)

    return stochasticprogram
end
function StochasticProgram(scenariodata::Vector{S}) where S <: AbstractScenarioData
    stochasticprogram = JuMP.Model(solver=JuMP.UnsetSolver())
    stochasticprogram.ext[:SP] = StochasticProgramData(scenariodata)

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

    if isa(solver,MathProgBase.AbstractMathProgSolver)
        dep = DEP(stochasticprogram,solver)
        return solve(dep; kwargs...)
    else
        # Use structured solver
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
function num_scenarios(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return length(stochasticprogram.ext[:SP].subproblems)
end
problemcache(stochasticprogram::JuMP.Model) = stochasticprogram.ext[:SP].problemcache
# ========================== #

# Base overloads
# ========================== #
function Base.push!(sp::StochasticProgramData{S},sdata::S) where S <: AbstractScenarioData
    push!(sp.scenariodata,sdata)
end
function Base.push!(stochasticprogram::JuMP.Model,sdata::AbstractScenarioData)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    push!(stochastic(stochasticprogram),sdata)
    invalidate_cache!(stochasticprogram)
end
function Base.append!(sp::StochasticProgramData{S},sdata::Vector{S}) where S <: AbstractScenarioData
    append!(sp.scenariodata,sdata)
end
function Base.append!(stochasticprogram::JuMP.Model,sdata::Vector{S}) where S <: AbstractScenarioData
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    append!(stochastic(stochasticprogram),sdata)
    invalidate_cache!(stochasticprogram)
end
# ========================== #

# Problem generation #
# ========================== #
function generate_stage_two!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    sp = stochastic(stochasticprogram)
    if has_generator(stochasticprogram,:second_stage)
        for i in num_scenarios(stochasticprogram)+1:length(sp.scenariodata)
            subproblem = Model(solver=JuMP.UnsetSolver())
            generator(stochasticprogram,:second_stage)(subproblem,scenario(stochasticprogram,i),stochasticprogram)
            push!(sp.subproblems,subproblem)
        end
    else
        warn("Second-stage problem not defined in stochastic program. Use @second_stage when defining stochastic program. Aborting.")
        return nothing
    end
    nothing
end

function eval_first_stage(stochasticprogram::JuMP.Model,origin::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    all(.!(isnan.(origin.colVal))) || error("No solution to evaluate in given model. ")

    val = 0.0
    obj = stochasticprogram.obj.aff
    for (i,var) in enumerate(obj.vars)
        val += obj.coeffs[i]*origin.colVal[var.col]
    end

    return val
end

function eval_second_stage(stochasticprogram::JuMP.Model,scenario::AbstractScenarioData,origin::JuMP.Model,solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    all(.!(isnan.(origin.colVal))) || error("No solution to evaluate in given model. ")
    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    eval_model = Model(solver = solver)
    generator(stochasticprogram,:first_stage)(eval_model)
    for obj in values(eval_model.objDict)
        if isa(obj,JuMP.Variable)
            val = origin.colVal[obj.col]
            eval_model.colCat[obj.col] = :Fixed
            eval_model.colVal[obj.col] = val
            eval_model.colLower[obj.col] = val
            eval_model.colUpper[obj.col] = val
        elseif isa(obj,JuMP.JuMPArray{JuMP.Variable})
            for var in obj.innerArray
                val = origin.colVal[var.col]
                eval_model.colCat[var.col] = :Fixed
                eval_model.colVal[var.col] = val
                eval_model.colLower[var.col] = val
                eval_model.colUpper[var.col] = val
            end
        else
            continue
        end
    end
    generator(stochasticprogram,:second_stage)(eval_model,scenario,eval_model)

    return eval_model
end

WS(stochasticprogram::JuMP.Model,scenario::AbstractScenarioData) = WS(stochasticprogram,scenario,JuMP.UnsetSolver())
function WS(stochasticprogram::JuMP.Model, scenario::AbstractScenarioData, solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    # Abort if no solver was given
    if isa(solver,JuMP.UnsetSolver)
        error("Cannot create WS model without a solver.")
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    ws_model = Model(solver = solver)
    generator(stochasticprogram,:first_stage)(ws_model)
    ws_obj = copy(ws_model.obj)
    generator(stochasticprogram,:second_stage)(ws_model,scenario,ws_model)
    append!(ws_obj,ws_model.obj)
    ws_model.obj = ws_obj

    return ws_model
end

DEP(stochasticprogram::JuMP.Model) = DEP(stochasticprogram,JuMP.UnsetSolver())
function DEP(stochasticprogram::JuMP.Model, solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:dep)
        return cache[:dep]
    end
    # Abort at this stage if no solver was given
    if isa(solver,JuMP.UnsetSolver)
        error("Cannot create new DEP model without a solver.")
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    # Define first-stage problem
    dep_model = Model(solver = solver)
    generator(stochasticprogram,:first_stage)(dep_model)
    dep_obj = copy(dep_model.obj)

    # Define second-stage problems, renaming variables according to scenario.
    visited_objs = collect(keys(dep_model.objDict))
    for (i,scenario) in enumerate(scenarios(stochasticprogram))
        generator(stochasticprogram,:second_stage)(dep_model,scenario,dep_model)
        append!(dep_obj,probability(scenario)*dep_model.obj)
        for (objkey,obj) ∈ dep_model.objDict
            if objkey ∉ visited_objs
                if (isa(obj,JuMP.Variable))
                    varname = @sprintf("%s_%d",dep_model.colNames[obj.col],i)
                    newkey = Symbol(varname)
                    dep_model.colNames[obj.col] = varname
                    dep_model.colNamesIJulia[obj.col] = varname
                    dep_model.objDict[newkey] = obj
                    delete!(dep_model.objDict,objkey)
                    push!(visited_objs,newkey)
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
                    dep_model.objDict[newkey] = obj
                    delete!(dep_model.objDict,objkey)
                    push!(visited_objs,newkey)
                else
                    continue
                end
            end
        end
    end
    dep_model.obj = dep_obj

    # Cache dep model
    cache[:dep] = dep_model

    return dep_model
end

function EVPI(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Abort if no solver was given
    if isa(solver,JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end

    # Solve DEP model
    dep = DEP(stochasticprogram, solver)
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
    # Abort at this stage if no solver was given
    if isa(solver,JuMP.UnsetSolver)
        error("Cannot create new EVP model without a solver.")
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    ev_model = Model(solver = solver)
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

    # Solve EVP model
    evp = EVP(stochasticprogram, solver)
    solve(evp)

    return getobjectivevalue(evp)
end

function EEV(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Solve EVP model
    evp = EVP(stochasticprogram, solver)
    solve(evp)

    eev = eval_first_stage(stochasticprogram,evp)

    for scenario in scenarios(stochasticprogram)
        subproblem = eval_second_stage(stochasticprogram,scenario,evp,solver)
        solve(subproblem)
        eev += probability(scenario)*getobjectivevalue(subproblem)
    end

    return eev
end

function VSS(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Solve DEP model
    dep = DEP(stochasticprogram, solver)
    solve(dep)
    vss = (dep.objSense == :Max ? 1 : -1)*getobjectivevalue(dep)

    vss += (dep.objSense == :Max ? -1 : 1)*EEV(stochasticprogram; solver = solver)

    return vss
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
    code = @q begin
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


end # module
