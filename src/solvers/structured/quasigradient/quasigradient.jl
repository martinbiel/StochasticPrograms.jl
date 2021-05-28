@reexport module QuasiGradient

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
using StochasticPrograms: DecisionMap, get_decisions, all_decisions, set_decision!, set_stage!, SingleDecisionSet, NoSpecifiedConstraint
using StochasticPrograms: all_decisions, all_known_decisions, remove_decision!, update_known_decisions!, KnownValuesChange, NotTaken, Known, KnownDecision
using StochasticPrograms: add_subscript
using StochasticPrograms: AbstractPenaltyTerm, Quadratic, InfNorm, ManhattanNorm, initialize_penaltyterm!, update_penaltyterm!, remove_penalty!, remove_penalty_variables!, remove_penalty_constraints!
using ProgressMeter
using ProgressMeter: AbstractProgress

import Base: show, put!, wait, isready, take!, fetch, zero, +, length, size
import StochasticPrograms: supports_structure, num_iterations, default_structure, check_loadable, load_structure!, restore_structure!, optimize!, optimizer_name, master_optimizer, subproblem_optimizer, num_subproblems, remove_penalty_variables!, remove_penalty_constraints!
using ProgressMeter: Progress

const MOI = MathOptInterface
const MOIU = MOI.Utilities
const CI = MOI.ConstraintIndex

export
    AbstractQuasiGradientAttribute,
    QuasiGradientAlgorithm,
    num_iterations,
    SubProblems,
    Unaltered,
    Smoothed,
    StepSize,
    StepParameter,
    RawStepParameter,
    set_step_attribute,
    set_step_attributes,
    Constant,
    Diminishing,
    Polyak,
    BB,
    Prox,
    ProxParameter,
    RawProxParameter,
    set_prox_attribute,
    set_prox_attributes,
    NoProx,
    Polyhedron,
    AndersonAcceleration,
    DryFriction,
    Nesterov,
    Termination,
    TerminationParameter,
    set_termination_attribute,
    set_termination_attributes,
    AfterMaximumIterations,
    AtObjectiveThreshold,
    AtGradientThreshold

# Include files
include("types/types.jl")
include("step/step.jl")
#include("boosting/boosting.jl")
include("prox/prox.jl")
include("termination/termination.jl")
include("execution/execution.jl")
include("solver.jl")
include("MOI_wrapper.jl")

end # module
