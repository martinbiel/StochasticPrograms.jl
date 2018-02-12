abstract type AbstractScenarioData end

probability(sd::AbstractScenarioData) = sd.π

function expected(::Vector{<:AbstractScenarioData})
   error("Not Implemented!")
end

struct StochasticProgramData{S <: AbstractScenarioData}
    scenariodata::Vector{S}
    num_scenarios::Int
    subproblems::Vector{JuMP.Model}
    evp::JuMP.Model

    function (::Type{StochasticProgramData})(scenariodata::Vector{<:AbstractScenarioData})
        S = eltype(scenariodata)
        num_scenarios = length(scenariodata)
        return new{S}(scenariodata,num_scenarios,Vector{JuMP.Model}(num_scenarios),Model(solver=JuMP.UnsetSolver()))
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

subproblems(m::JuMP.Model)      = m.ext[:SP].subproblems
expected_value(m::JuMP.Model)   = m.ext[:SP].evp
getsubproblem(m::JuMP.Model,i)  = subproblems(m)[i]
getprobability(m::JuMP.Model,i) = probability(m.ext[:SP].scenariodata[i])
num_scenarios(m::JuMP.Model)    = m.ext[:SP].num_scenarios

macro define_subproblem(args)
    @capture(args, model_Symbol = modeldef_)
    code = @q begin
        for (i,$(esc(:scenariodata))) = enumerate($(esc(model)).ext[:SP].scenariodata)
            $(esc(model)).ext[:SP].subproblems[i] = Model(solver=JuMP.UnsetSolver())
            $(esc(:subproblem)) = $(esc(model)).ext[:SP].subproblems[i]
            $(esc(modeldef))
        end
        $(esc(:subproblem)) = $(esc(model)).ext[:SP].evp
        $(esc(:scenariodata)) = $(esc(:expected))($(esc(model)).ext[:SP].scenariodata)
        $(esc(modeldef))
    end
    return prettify(code)
end
