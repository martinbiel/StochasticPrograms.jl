abstract type AbstractStructuredSolver end
abstract type AbstractScenarioData end

probability(sd::AbstractScenarioData) = sd.π

function expected(::Vector{<:AbstractScenarioData})
   error("Not Implemented!")
end

mutable struct StochasticProgramData{S <: AbstractScenarioData}
    scenariodata::Vector{S}
    generator::Function
    subproblems::Vector{JuMP.Model}
    num_scenarios::Int
    problemcache::Dict{Symbol,JuMP.Model}

    function (::Type{StochasticProgramData})(::Type{S}) where S <: AbstractScenarioData
        return new{S}(scenariodata,(model,sdata)->nothing,Vector{JuMP.Model}(),0,Dict{Symbol,JuMP.Model}())
    end

    function (::Type{StochasticProgramData})(scenariodata::Vector{<:AbstractScenarioData})
        S = eltype(scenariodata)
        return new{S}(scenariodata,(model,sdata)->nothing,Vector{JuMP.Model}(),0,Dict{Symbol,JuMP.Model}())
    end
end

function StochasticProgram(scenariodata::Vector{<:AbstractScenarioData})
    model = JuMP.Model(solver=JuMP.UnsetSolver())
    model.ext[:SP] = StochasticProgramData(scenariodata)

    # Set hooks
    JuMP.setsolvehook(model, _solve)
    JuMP.setprinthook(model, _printhook)

    return model
end

function _solve(model::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver(), kwargs...)
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")
    lqmodel = MathProgBase.LinearQuadraticModel(solver)
    MathProgBase.loadproblem!(lqmodel,load_depmodel(model)...)

    numRows, numCols = length(model.linconstr), model.numCols
    model.objBound = NaN
    model.objVal = NaN
    model.colVal = fill(NaN, numCols)
    model.linconstrDuals = Array{Float64}(0)

    optimize!(lqmodel)
    status = MathProgBase.SolverInterface.status(lqmodel)
    status == :Optimal || error("LP could not be solved, returned status: ", status)

    if status == :Optimal
        model.colVal = MathProgBase.getsolution(lqmodel)[1:numCols]
        model.objVal = MathProgBase.getobjval(lqmodel) + model.obj.aff.constant

        model.redCosts = try
            MathProgBase.getreducedcosts(lqmodel)[1:numCols]
        catch
            fill(NaN, numCols)
        end

        model.linconstrDuals = try
            MathProgBase.getconstrduals(lqmodel)[1:numRows]
        catch
            fill(NaN, numRows)
        end
    else
        warn("Not solved to optimality, status: $status")
        if status == :Infeasible
            m.linconstrDuals = try
                infray = MathProgBase.getinfeasibilityray(m.internalModel)
                @assert length(infray) == numRows
                infray
            catch
                suppress_warnings || warn("Infeasibility ray (Farkas proof) not available")
                fill(NaN, numRows)
            end
        elseif status == :Unbounded
            m.colVal = try
                unbdray = MathProgBase.getunboundedray(m.internalModel)
                @assert length(unbdray) == numCols
                unbdray
            catch
                suppress_warnings || warn("Unbounded ray not available")
                fill(NaN, numCols)
            end
        end
    end
end

# function _solve(model::JuMP.Model; solver::AbstractStructuredSolver, kwargs...)
#     haskey(model.ext,:SP) || error("The given model is not a stochastic program.")
# end

function _printhook(io::IO, model::JuMP.Model)
    print(io, model, ignore_print_hook=true)
    print(io, "*** subproblems ***\n")
    for (id, subproblem) in enumerate(subproblems(model))
      @printf(io, "Subproblem %d:\n", id)
      print(io, subproblem)
      print(io, "\n")
    end
end

function stochastic(model::JuMP.Model)
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")
    return model.ext[:SP]
end
function scenario(model::JuMP.Model,i::Integer)
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")
    return model.ext[:SP].scenariodata[i]
end
function scenarios(model::JuMP.Model)
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")
    return model.ext[:SP].scenariodata
end
function probability(model::JuMP.Model,i::Integer)
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")
    return probability(model.ext[:SP].scenariodata[i])
end
function generator(model::JuMP.Model)
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")
    return model.ext[:SP].generator
end
function subproblem(model::JuMP.Model,i::Integer)
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")
    return subproblems(model)[i]
end
function subproblems(model::JuMP.Model)
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")
    return model.ext[:SP].subproblems
end
function num_scenarios(model::JuMP.Model)
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")
    return model.ext[:SP].num_scenarios
end
problemcache(model::JuMP.Model) = model.ext[:SP].problemcache

function Base.push!(sp::StochasticProgramData{S},sdata::S) where S <: AbstractScenarioData
    push!(sp.scenariodata,sdata)
end
function Base.push!(model::JuMP.Model,sdata::AbstractScenarioData)
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")

    push!(stochastic(model),sdata)
    generate_subproblems!(model)
    invalidate_cache!(model)
end

function Base.append!(sp::StochasticProgramData{S},sdata::Vector{S}) where S <: AbstractScenarioData
    append!(sp.scenariodata,sdata)
end
function Base.append!(model::JuMP.Model,sdata::AbstractScenarioData)
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")

    append!(stochastic(model),sdata)
    generate_subproblems!(model)
    invalidate_cache!(model)
end

function generate_subproblems!(model::JuMP.Model)
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")
    sp = stochastic(model)
    for i in sp.num_scenarios+1:length(sp.scenariodata)
        subproblem = Model(solver=JuMP.UnsetSolver())
        generator(model)(subproblem,scenario(model,i))
        push!(sp.subproblems,subproblem)
    end
    sp.num_scenarios = length(sp.scenariodata)
end

function invalidate_cache!(model::JuMP.Model)
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")
    cache = problemcache(model)
    delete!(cache,:evp)
    delete!(cache,:dep)
end

macro define_subproblem(args)
    @capture(args, model_Symbol = modeldef_)
    code = @q begin
        $(esc(model)).ext[:SP].generator = ($(esc(:model))::JuMP.Model,$(esc(:scenario))::AbstractScenarioData) -> begin
            $(esc(modeldef))
	    return $(esc(:model))
        end
        generate_subproblems!($(esc(model)))
        nothing
    end
    return prettify(code)
end
