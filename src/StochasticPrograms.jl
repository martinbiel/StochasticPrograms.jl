__precompile__()
module StochasticPrograms

# Standard library
using LinearAlgebra
using SparseArrays
using Distributed
using Printf

# External libraries
using JuMP
using Compat
using OrderedCollections
using MathOptInterface
using Distributions
using MacroTools
using MacroTools: @q, postwalk, prewalk
using Reexport
using ProgressMeter

import Base: getindex, length, in, issubset, show
import JuMP: optimize!, termination_status, index, value

const DenseAxisArray = JuMP.Containers.DenseAxisArray
const SparseAxisArray = JuMP.Containers.SparseAxisArray
const VectorizedProductIterator = JuMP.Containers.VectorizedProductIterator

const MOI = MathOptInterface
const MOIU = MOI.Utilities
const MOIB = MOI.Bridges
const VI = MOI.VariableIndex
const CI = MOI.ConstraintIndex
const AcceptableTermination = [MOI.OPTIMAL, MOI.LOCALLY_SOLVED, MOI.ALMOST_OPTIMAL, MOI.ALMOST_LOCALLY_SOLVED]

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
    AbsoluteTolerance,
    RelativeTolerance,
    MasterOptimizer,
    MasterOptimizerAttribute,
    RawMasterOptimizerParameter,
    SubProblemOptimizer,
    SubProblemOptimizerAttribute,
    RawSubProblemOptimizerParameter,
    InstanceOptimizer,
    InstanceOptimizerAttribute,
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
    optimizer,
    optimizer_constructor,
    AbstractStochasticStructure,
    StochasticInstantiation,
    UnspecifiedInstantiation,
    Deterministic,
    DeterministicEquivalent,
    Vertical,
    VerticalStructure,
    Horizontal,
    HorizontalStructure,
    DistributedVertical,
    DistributedHorizontal,
    SampleAverageApproximation,
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
    AffineDecisionFunction,
    QuadraticDecisionFunction,
    VectorAffineDecisionFunction,
    DecisionVariable,
    SPConstraintRef,
    ScenarioDependentModelAttribute,
    ScenarioDependentVariableAttribute,
    ScenarioDependentConstraintAttribute,
    DecisionRef,
    DecisionAffExpr,
    DecisionQuadExpr,
    SingleDecision,
    VectorOfDecisions,
    AffineDecisionFunction,
    VectorAffineDecisionFunction,
    decision,
    state,
    decisions,
    num_decisions,
    decision_names,
    all_decision_variables,
    all_known_decision_variables,
    all_auxiliary_variables,
    decision_by_name,
    recourse_length,
    first_stage,
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
    recourse_decision,
    lower_bound,
    lower,
    upper,
    confidence,
    confidence_interval,
    lower_confidence_interval,
    upper_confidence_interval,
    gap,
    instantiate,
    set_optimizer,
    master_optimizer,
    set_masteroptimizer_attribute,
    set_masteroptimizer_attributes,
    subproblem_optimizer,
    set_suboptimizer_attribute,
    set_suboptimizer_attributes,
    set_instanceoptimizer_attribute,
    set_instanceoptimizer_attributes,
    optimize!,
    num_iterations,
    default_structure,
    supports_structure,
    check_loadable,
    load_structure!,
    restore_structure!,
    load_model!,
    optimal_instance,
    decision,
    optimal_decision,
    optimal_recourse_decision,
    @define_scenario,
    @sampler,
    @first_stage,
    @second_stage,
    @stage,
    @stochastic_model,
    @zero,
    @expectation,
    @sample,
    @decision,
    @recourse,
    @known,
    @parameters,
    @uncertain,
    @scenario,
    WS,
    wait_and_see_decision,
    EWS,
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
include("io/io.jl")

end # module
