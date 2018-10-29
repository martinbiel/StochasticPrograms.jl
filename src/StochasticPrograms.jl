__precompile__()
module StochasticPrograms

# Standard library
using LinearAlgebra
using SparseArrays
using Distributed
using Printf

# External libraries
using JuMP
using MathProgBase
using MacroTools
using MacroTools: @q, postwalk

export
    StochasticProgram,
    Probability,
    AbstractScenarioData,
    AbstractSampler,
    AbstractStructuredSolver,
    AbstractStructuredModel,
    StructuredModel,
    spsolver,
    set_spsolver,
    stochastic,
    scenarioproblems,
    first_stage_data,
    second_stage_data,
    stage_data,
    scenario,
    scenarios,
    scenariotype,
    probability,
    has_generator,
    generator,
    subproblem,
    subproblems,
    nsubproblems,
    parentmodel,
    masterterms,
    transfer_model!,
    transfer_scenarios!,
    nscenarios,
    sample!,
    generate!,
    stage_two_model,
    outcome_model,
    evaluate_decision,
    solve!,
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
