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

include("types.jl")
include("generation.jl")
include("evaluation.jl")
include("spconstructs.jl")
include("util.jl")
include("creation.jl")
include("spinterface.jl")

end # module
