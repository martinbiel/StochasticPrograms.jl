abstract type AbstractScenarioData end

probability(sd::AbstractScenarioData) = sd.π

function expected(::Vector{<:AbstractScenarioData})
   error("Not Implemented!")
end

mutable struct StochasticProgramData{S <: AbstractScenarioData}
    scenariodata::Vector{S}
    num_scenarios::Int
    generator::Function
    subproblems::Vector{JuMP.Model}
    evp::JuMP.Model

    function (::Type{StochasticProgramData})(::Type{S}) where S <: AbstractScenarioData
        return new{S}(scenariodata,0,Void,Vector{JuMP.Model}(),Model(solver=JuMP.UnsetSolver()))
    end

    function (::Type{StochasticProgramData})(scenariodata::Vector{<:AbstractScenarioData})
        S = eltype(scenariodata)
        num_scenarios = length(scenariodata)
        return new{S}(scenariodata,num_scenarios,Void,Vector{JuMP.Model}(num_scenarios),Model(solver=JuMP.UnsetSolver()))
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

function _solve(model::Model; variant = :dep, kwargs...)
    if variant == :dep
        solve_dep(model,kwargs...)
    elseif variant == :evp
        solve_evp(model,kwargs...)
    elseif variant == :struct
        solve_struct(model,kwargs...)
    else
        error("Invalid variant option")
    end
end

function _printhook(io::IO, model::Model)
    print(io, model, ignore_print_hook=true)
    print(io, "*** subproblems ***\n")
    for (id, subproblem) in enumerate(subproblems(model))
      @printf(io, "Subproblem %d:\n", id)
      print(io, subproblem)
      print(io, "\n")
    end
end

stochastic(m::JuMP.Model)       = m.ext[:SP]
generator(m::JuMP.Model)        = m.ext[:SP].generator
subproblems(m::JuMP.Model)      = m.ext[:SP].subproblems
expected_value(m::JuMP.Model)   = m.ext[:SP].evp
getsubproblem(m::JuMP.Model,i)  = subproblems(m)[i]
getprobability(m::JuMP.Model,i) = probability(m.ext[:SP].scenariodata[i])
num_scenarios(m::JuMP.Model)    = m.ext[:SP].num_scenarios

function Base.push!(sp::StochasticProgram{S},sdata::S) where S <: AbstractScenarioData
    push!(sp.scenariodata,sdata)
    sp.num_scenarios += 1
end

function Base.append!(sp::StochasticProgram{S},sdata::Vector{S}) where S <: AbstractScenarioData
    append!(sp.scenariodata,sdata)
    sp.num_scenarios += length(sdata)
end

function generate_subproblems(model::JuMP.Model)
    sp = stochastic(model)
    for i in indices(sp.subproblems)
        sp.subproblems[i] = sp.generator(sp.scenariodata[i])
    end
end

macro define_subproblem(args)
    @capture(args, model_Symbol = modeldef_)
    code = @q begin
        $(esc(model)).ext[:SP].generator = ($(esc(sdata))::AbstractScenarioData) -> begin
            $(esc(model)) = Model(solver=JuMP.UnsetSolver())
            $(esc(modeldef))
        end
    end
    return prettify(code)
end
