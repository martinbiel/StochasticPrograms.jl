@reexport module LShaped

# Standard library
using LinearAlgebra
using SparseArrays
using Distributed
using Printf

# External libraries
using Parameters
using JuMP
using MathOptInterface
using StochasticPrograms
using StochasticPrograms: AcceptableTermination
using StochasticPrograms: UnspecifiedInstantiation, VerticalStructure, AbstractScenarioProblems, ScenarioProblems, DistributedScenarioProblems, DecisionChannel
using StochasticPrograms: AbstractExecution, Serial, Synchronous, Asynchronous
using StochasticPrograms: AbstractStructuredOptimizer, RelativeTolerance, MasterOptimizer, SubproblemOptimizer
using StochasticPrograms: all_decisions, set_decision!, SingleDecisionSet, NoSpecifiedConstraint
using StochasticPrograms: all_known_decisions, update_known_decisions!, KnownValuesChange, Known, KnownDecision
using StochasticPrograms: add_subscript
using StochasticPrograms: AbstractPenaltyterm, Quadratic, InfNorm, ManhattanNorm, initialize_penaltyterm!, update_penaltyterm!, remove_penalty!, remove_penalty_variables!, remove_penalty_constraints!
using ProgressMeter
using Clustering

import Base: show, put!, wait, isready, take!, fetch, zero, +, length, size
import StochasticPrograms: supports_structure, default_structure, check_loadable, load_structure!, restore_structure!, optimize!, optimizer_name, master_optimizer, subproblem_optimizer, num_subproblems, remove_penalty_variables!, remove_penalty_constraints!

const MOI = MathOptInterface
const MOIU = MOI.Utilities
const CI = MOI.ConstraintIndex
const CutConstraint = CI{AffineDecisionFunction{Float64}, MOI.GreaterThan{Float64}}

export
    AbstractLShapedAttribute,
    LShapedAlgorithm,
    num_cuts,
    num_iterations,
    FeasibilityCuts,
    Regularizer,
    RegularizationParameter,
    RawRegularizationParameter,
    set_regularization_attribute,
    set_regularization_attributes,
    DontRegularize,
    NoRegularization,
    RegularizedDecomposition,
    WithRegularizedDecomposition,
    RD,
    WithRD,
    TrustRegion,
    WithTrustRegion,
    TR,
    WithTR,
    LevelSet,
    WithLevelSets,
    LV,
    WithLV,
    Consolidator,
    DontConsolidate,
    Consolidate,
    Consolidation,
    ConsolidationParameter,
    RawConsolidationParameter,
    set_consolidation_attribute,
    set_consolidation_attributes,
    at_tolerance,
    num_iters,
    tolerance_reached,
    Aggregator,
    AggregationParameter,
    RawAggregationParameter,
    set_aggregation_attribute,
    set_aggregation_attributes,
    DontAggregate,
    NoAggregation,
    PartialAggregate,
    PartialAggregation,
    Aggregate,
    FullAggregation,
    DynamicAggregate,
    DynamicAggregation,
    ClusterAggregate,
    ClusterAggregation,
    HybridAggregate,
    HybridAggregation,
    GranulatedAggregate,
    GranulatedAggregation,
    SelectUniform,
    SelectDecaying,
    SelectRandom,
    SelectClosest,
    SortByReference,
    StaticCluster,
    ClusterByReference,
    Kmedoids,
    Hierarchical,
    absolute_distance,
    angular_distance,
    spatioangular_distance


# Include files
include("types/types.jl")
include("integer/integer.jl")
include("consolidators/consolidation.jl")
include("aggregators/aggregation.jl")
include("regularizers/regularization.jl")
include("execution/execution.jl")
include("solver.jl")
include("MOI_wrapper.jl")

end # module
