__precompile__()
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
    set_spsolver,
    stochastic,
    scenarioproblems,
    first_stage_data,
    second_stage_data,
    scenario,
    scenarios,
    probability,
    subproblem,
    subproblems,
    parentmodel,
    masterterms,
    transfer_model!,
    nscenarios,
    generate!,
    stage_two_model,
    outcome_model,
    eval_decision,
    optimal_decision,
    optimal_value,
    calculate_objective_value,
    @first_stage,
    @second_stage,
    @stage,
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

include("types/types.jl")
include("methods/methods.jl")
include("spinterface.jl")

end # module
