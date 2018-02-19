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
    if isa(solver,JuMP.UnsetSolver)
        warn("No given solver. Aborting.")
        return :NotSolved
    end

    if length(subproblems(stochasticprogram)) != length(scenarios(stochasticprogram))
        generate_subproblems!(stochasticprogram)
    end

    if isa(solver,MathProgBase.AbstractMathProgSolver)
        dep = DEP(stochasticprogram)
        setsolver(dep,solver)
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

function eval_stage_two(stochasticprogram::JuMP.Model,i::Integer,origin::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    i <= num_scenarios(stochasticprogram) || error("Subproblem ",i," not in range of scenarios. ",num_scenarios(stochasticprogram), "scenarios are included in the given stochastic program.")
    has_generator(stochasticprogram,:subproblem) || error("Second-stage problem not defined in stochastic program. Use @second_stage when defining stochastic program. Aborting.")
    eval_model = Model()
    generator(stochasticprogram,:subproblem)(eval_model,scenario(stochasticprogram,i),origin)

    return eval_model
end

function EVP(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:evp)
        return cache[:evp]
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    ev_model = Model()
    generator(stochasticprogram,:first_stage)(ev_model)
    ev_obj = copy(ev_model.obj)
    generator(stochasticprogram,:second_stage)(ev_model,expected(scenarios(stochasticprogram)),ev_model)
    append!(ev_obj,ev_model.obj)
    ev_model.obj = ev_obj

    # Cache evp model
    cache[:evp] = ev_model

    return ev_model
end

function DEP(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:dep)
        return cache[:dep]
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    # Define first-stage problem
    dep_model = Model()
    generator(stochasticprogram,:first_stage)(dep_model)
    dep_obj = copy(dep_model.obj)

    # Define second-stage problems, renaming variables according to scenario.
    visited_vars = collect(keys(dep_model.objDict))
    for (i,scenario) in enumerate(scenarios(stochasticprogram))
        generator(stochasticprogram,:second_stage)(dep_model,scenario,dep_model)
        append!(dep_obj,probability(stochasticprogram,i)*dep_model.obj)
        for (varkey,var) ∈ dep_model.objDict
            if varkey ∉ visited_vars
                varname = @sprintf("%s_%d",dep_model.colNames[var.col],i)
                newkey = Symbol(varname)
                dep_model.colNames[var.col] = varname
                dep_model.colNamesIJulia[var.col] = varname
                dep_model.objDict[newkey] = var
                delete!(dep_model.objDict,varkey)
                push!(visited_vars,newkey)
            end
        end
    end
    dep_model.obj = dep_obj

    # Cache dep model
    cache[:dep] = dep_model

    return dep_model
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

    detached_def = postwalk(modeldef) do x
        @capture(x, @decision args__) || return x
        code = Expr(:block)
        for var in args
            varkey = Meta.quot(var)
            push!(code.args,:(@variable(model,$var == getvalue(origin.objDict[$varkey]))))
        end
        return code
    end

    code = @q begin
        $(esc(model)).ext[:SP].generator[:second_stage] = ($(esc(:model))::JuMP.Model,$(esc(:scenario))::AbstractScenarioData,$(esc(:parent))::JuMP.Model) -> begin
            $(esc(def))
	    return $(esc(:model))
        end
        generate_stage_two!($(esc(model)))

        $(esc(model)).ext[:SP].generator[:subproblem] = ($(esc(:model))::JuMP.Model,$(esc(:scenario))::AbstractScenarioData,$(esc(:origin))::JuMP.Model) -> begin
            $(esc(detached_def))
	    return $(esc(:model))
        end
        nothing
    end
    return prettify(code)
end
# ========================== #
