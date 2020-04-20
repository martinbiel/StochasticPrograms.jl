__precompile__()
module StochasticPrograms

# Standard library
using LinearAlgebra
using SparseArrays
using Distributed
using Printf

# External libraries
using JuMP
using MathOptInterface
using MacroTools
using MacroTools: @q, postwalk, prewalk
using Reexport
using ProgressMeter

import Base: getindex, length, in, issubset, show
import JuMP: optimize!, termination_status, index, value

const MOI = MathOptInterface
const MOIU = MOI.Utilities
const MOIB = MOI.Bridges
const CI = MOI.ConstraintIndex

import MutableArithmetics
const MA = MutableArithmetics

export
    StochasticModel,
    StochasticProgram,
    Probability,
    AbstractScenario,
    Scenario,
    StageParameters,
    parameters,
    AbstractSampler,
    Sampler,
    ConfidenceInterval,
    StochasticSolution,
    AbstractStructuredSolver,
    AbstractStructuredModel,
    AbstractSampledSolver,
    AbstractSampledModel,
    StructuredModel,
    SampledModel,
    optimize_structured!,
    optimize_sampled!,
    fill_solution!,
    stochastic_solution,
    solverstr,
    internal_solver,
    Crash,
    CrashMethod,
    spsolver,
    spsolver_model,
    distributed,
    initialize!,
    initialized,
    deferred,
    internal_model,
    add_scenario!,
    add_scenarios!,
    scenarioproblems,
    DecisionVariables,
    decision_variables,
    recourse_variables,
    decision_length,
    decisions,
    ndecisions,
    decision_names,
    recourse_length,
    first_stage_nconstraints,
    first_stage_dims,
    nstages,
    scenario,
    scenarios,
    scenariotype,
    scenariotext,
    stage_parameters,
    stage_probability,
    probability,
    ExpectedScenario,
    expected,
    has_generator,
    generator,
    subproblem,
    subproblems,
    nsubproblems,
    masterterms,
    transfer_model!,
    nscenarios,
    AbstractSampler,
    sample,
    sampler,
    sample!,
    generate!,
    stage_one_model,
    stage_two_model,
    outcome_model,
    evaluate_decision,
    lower_bound,
    lower,
    upper,
    confidence,
    confidence_interval,
    lower_bound,
    upper_bound,
    gap,
    instantiate,
    set_optimizer!,
    optimize!,
    decision,
    optimal_decision,
    optimal_recourse_decision,
    optimal_value,
    calculate_objective_value,
    @scenario,
    @sampler,
    @first_stage,
    @second_stage,
    @stage,
    @stochastic_model,
    @zero,
    @expectation,
    @sample,
    @decision,
    @known,
    @parameters,
    @uncertain,
    WS,
    WS_decision,
    EWS,
    SAA,
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
include("optimizer_interface.jl")
#include("crash.jl")
include("solvers/solvers.jl")

end # module
