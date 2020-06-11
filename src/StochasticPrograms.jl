__precompile__()
module StochasticPrograms

# Standard library
using LinearAlgebra
using SparseArrays
using Distributed
using Printf

# External libraries
using JuMP
using OrderedCollections
using MathOptInterface
using Distributions
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
    SampleSize,
    Confidence,
    ConfidenceInterval,
    StochasticSolution,
    AbstractStructuredOptimizerAttribute,
    AbstractSampledOptimizerAttribute,
    RelativeTolerance,
    MasterOptimizer,
    RawMasterOptimizerParameter,
    SubproblemOptimizer,
    RawSubproblemOptimizerParameter,
    InstanceOptimizer,
    RawInstanceOptimizerParameter,
    NumSamples,
    NumEvalSamples,
    NumEWSSamples,
    NumEEVSamples,
    NumUpperTrials,
    NumLowerTrials,
    Execution,
    ExecutionParameter,
    RawExecutionParameter,
    set_execution_attribute,
    set_execution_attributes,
    Serial,
    Synchronous,
    Asynchronous,
    Quadratic,
    Linearized,
    InfNorm,
    ManhattanNorm,
    UnsupportedStructure,
    UnloadedStructure,
    UnloadableStructure,
    AbstractStructuredOptimizer,
    AbstractSampledOptimizer,
    optimizer_name,
    optimizer_constructor,
    AbstractStochasticStructure,
    Deterministic,
    BlockVertical,
    BlockHorizontal,
    DistributedBlockVertical,
    DistributedBlockHorizontal,
    Crash,
    distributed,
    initialize!,
    initialized,
    deferred,
    internal_model,
    add_scenario!,
    add_scenarios!,
    scenarioproblems,
    Decision,
    Decisions,
    SingleDecision,
    VectorOfDecisions,
    SingleKnown,
    VectorOfKnowns,
    AffineDecisionFunction,
    QuadraticDecisionFunction,
    VectorAffineDecisionFunction,
    DecisionRef,
    KnownRef,
    CombinedAffExpr,
    CombinedQuadExpr,
    SingleDecision,
    VectorOfDecisions,
    AffineDecisionFunction,
    VectorAffineDecisionFunction,
    decision,
    decisions,
    num_decisions,
    decision_names,
    recourse_length,
    first_stage_nconstraints,
    first_stage_dims,
    num_stages,
    scenario,
    scenarios,
    scenario_type,
    scenario_types,
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
    num_subproblems,
    masterterms,
    transfer_model!,
    num_scenarios,
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
    set_optimizer,
    set_masteroptimizer_attribute,
    set_suboptimizer_attribute,
    set_instanceoptimizer_attribute,
    set_instanceoptimizer_attributes,
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
    wait_and_see_decision,
    EWS,
    SAA,
    DEP,
    VRP,
    EVPI,
    EVP,
    expected_value_decision,
    EV,
    EEV,
    VSS,
    LShaped

macro exportJuMP()
    Expr(:export, names(JuMP)...)
end
@exportJuMP

include("types/types.jl")
include("methods/methods.jl")
include("optimizer_interface.jl")
include("crash.jl")
include("solvers/solvers.jl")

end # module
