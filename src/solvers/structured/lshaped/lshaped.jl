@reexport module LShapedSolvers

# Standard library
using LinearAlgebra
using SparseArrays
using Distributed
using Printf

# External libraries
using Parameters
using JuMP
using StochasticPrograms
using StochasticPrograms: AbstractScenarioProblems, ScenarioProblems, DScenarioProblems
using StochasticPrograms: LQSolver, getsolution, getobjval, getredcosts, getduals, status, SubSolver, get_solver, loadLP, feasibility_problem!
using StochasticPrograms: Execution, Serial, Synchronous, Asynchronous
using StochasticPrograms: PenaltyTerm, Quadratic, Linearized, InfNorm, ManhattanNorm, initialize_penaltyterm!, update_penaltyterm!, solve_penalized!
using MathProgBase
using ProgressMeter
using Clustering

import Base: show, put!, wait, isready, take!, fetch, zero, +, length, size
import StochasticPrograms: StructuredModel, internal_solver, optimize_structured!, fill_solution!, solverstr

const MPB = MathProgBase

export
    LShapedSolver,
    LShaped,
    Crash,
    ncuts,
    niterations,
    StructuredModel,
    add_params!,
    optimsolver,
    hyperoptimal_lshaped,
    optimize_structured!,
    fill_solution!,
    LShaped,
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
    niters,
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
include("spinterface.jl")

end # module
