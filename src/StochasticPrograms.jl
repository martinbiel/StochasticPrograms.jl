__precompile__()
module StochasticPrograms

# Standard library
using LinearAlgebra
using SparseArrays
using Distributed
using Printf

# External libraries
using JuMP
using Distributions
using MathProgBase
using MacroTools
using MacroTools: @q, postwalk

const MPB = MathProgBase

export
    StochasticProgram,
    Probability,
    AbstractScenario,
    AbstractSampler,
    AbstractStructuredSolver,
    AbstractStructuredModel,
    StructuredModel,
    optimize_structured!,
    fill_solution!,
    solverstr,
    internal_solver,
    spsolver,
    distributed,
    deferred,
    set_spsolver,
    internal_model,
    add_scenario!,
    add_scenarios!,
    scenarioproblems,
    first_stage_data,
    set_first_stage_data!,
    decision_length,
    recourse_length,
    first_stage_nconstraints,
    first_stage_dims,
    second_stage_data,
    set_second_stage_data!,
    stage_data,
    nstages,
    scenario,
    scenarios,
    scenariotype,
    probability,
    ExpectedScenario,
    expected,
    has_generator,
    generator,
    subproblem,
    subproblems,
    nsubproblems,
    parentmodel,
    masterterms,
    transfer_model!,
    nscenarios,
    AbstractSampler,
    sample,
    sampler,
    sample!,
    generate!,
    stage_two_model,
    outcome_model,
    evaluate_decision,
    lower_bound,
    optimize!,
    optimal_decision,
    optimal_value,
    calculate_objective_value,
    @scenario,
    @sampler,
    @first_stage,
    @second_stage,
    @stage,
    @zero,
    @expectation,
    @sample,
    @decision,
    WS,
    WS_decision,
    EWS,
    SSA,
    DEP,
    VRP,
    EVPI,
    EVP,
    EVP_decision,
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
