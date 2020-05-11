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
using StochasticPrograms: UnspecifiedInstantiation, VerticalBlockStructure, BlockVertical, AbstractScenarioProblems, ScenarioProblems, DistributedScenarioProblems
using StochasticPrograms: Execution, Serial, Synchronous, Asynchronous
using StochasticPrograms: AbstractStructuredOptimizer
using StochasticPrograms: SingleDecisionSet, update_decision_constraint!
using StochasticPrograms: set_known_decision!, update_known_decisions!, SingleKnownSet, KnownModification, KnownValuesChange
using StochasticPrograms: add_subscript
using StochasticPrograms: PenaltyTerm, Quadratic, InfNorm, ManhattanNorm, initialize_penaltyterm!, update_penaltyterm!, remove_penalty!
using ProgressMeter
using Clustering

import Base: show, put!, wait, isready, take!, fetch, zero, +, length, size
import StochasticPrograms: supports_structure, default_structure, load_structure!, restore_structure!, optimize!, optimizer_name, master_optimizer, sub_optimizer, num_subproblems

const MOI = MathOptInterface
const MOIU = MOI.Utilities
const CI = MOI.ConstraintIndex
const CutConstraint = CI{AffineDecisionFunction{Float64}, MOI.GreaterThan{Float64}}

export
    num_cuts,
    num_iterations,
    add_params!,
    optimsolver,
    hyperoptimal_lshaped,
    optimize_structured!,
    fill_solution!,
    Serial,
    Synchronous,
    Asynchronous,
    Quadratic,
    Linearized,
    InfNorm,
    ManhattanNorm,
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
    DontConsolidate,
    Consolidate,
    Consolidation,
    at_tolerance,
    num_iters,
    tolerance_reached,
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
    SelectUniform,
    SelectDecaying,
    SelectRandom,
    SelectClosest,
    SelectClosestToReference,
    StaticCluster,
    ClusterByReference,
    Kmedoids,
    Hierarchical,
    absolute_distance,
    angular_distance,
    spatioangular_distance


# Include files
include("types/types.jl")
include("consolidators/consolidation.jl")
include("aggregators/aggregation.jl")
include("regularizers/regularization.jl")
include("execution/execution.jl")
include("solver.jl")
include("MOI_wrapper.jl")

end # module
