# MIT License
#
# Copyright (c) 2018 Martin Biel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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
using StochasticPrograms: UnspecifiedInstantiation, StageDecompositionStructure, AbstractScenarioProblems, ScenarioProblems, DistributedScenarioProblems, DecisionChannel
using StochasticPrograms: AbstractExecution, Serial, Synchronous, Asynchronous
using StochasticPrograms: AbstractStructuredOptimizer, set_master_optimizer!, set_subproblem_optimizer!
using StochasticPrograms: DecisionMap, all_decisions, set_decision!, set_stage!, SingleDecisionSet, NoSpecifiedConstraint
using StochasticPrograms: all_known_decisions, update_known_decisions!, KnownValuesChange, Known, KnownDecision
using StochasticPrograms: add_subscript
using StochasticPrograms: AbstractPenaltyTerm, Quadratic, InfNorm, ManhattanNorm, initialize_penaltyterm!, update_penaltyterm!, remove_penalty!, remove_penalty_variables!, remove_penalty_constraints!
using ProgressMeter
using Clustering

import Base: show, put!, wait, isready, take!, fetch, zero, +, length, size
import StochasticPrograms: supports_structure, num_iterations, default_structure, check_loadable, load_structure!, restore_structure!, optimize!, optimizer_name, master_optimizer, subproblem_optimizer, num_subproblems, remove_penalty_variables!, remove_penalty_constraints!, relax_decision_integrality

const MOI = MathOptInterface
const MOIU = MOI.Utilities
const CI = MOI.ConstraintIndex
const CutConstraint = CI{AffineDecisionFunction{Float64}, MOI.GreaterThan{Float64}}

export
    AbstractLShapedAttribute,
    LShapedAlgorithm,
    num_cuts,
    num_iterations,
    FeasibilityStrategy,
    IgnoreFeasibility,
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
    IntegerStrategy,
    IgnoreIntegers,
    CombinatorialCuts,
    Convexification,
    Gomory,
    LiftAndProject,
    CuttingPlaneTree,
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
