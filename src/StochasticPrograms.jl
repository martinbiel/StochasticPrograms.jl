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
    scenarioproblems,
    scenario,
    scenarios,
    probability,
    subproblem,
    subproblems,
    parentmodel,
    nscenarios,
    generate!,
    stage_two_model,
    outcome_model,
    eval_decision,
    @first_stage,
    @second_stage,
    WS,
    EWS,
    DEP,
    VRP,
    EVPI,
    EVP,
    EV,
    EEV,
    VSS

macro exportJuMP()
    Expr(:export, names(JuMP)...)
end
@exportJuMP

include("types.jl")
include("generation.jl")
include("evaluation.jl")
include("spconstructs.jl")
include("util.jl")
include("creation.jl")
include("spinterface.jl")

end # module
