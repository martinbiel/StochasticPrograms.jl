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
using StochasticPrograms: UnspecifiedInstantiation, VerticalStructure, AbstractScenarioProblems, ScenarioProblems, DistributedScenarioProblems, DecisionChannel
using StochasticPrograms: AbstractExecution, Serial, Synchronous, Asynchronous
using StochasticPrograms: AbstractStructuredOptimizer, RelativeTolerance, MasterOptimizer, SubproblemOptimizer
using StochasticPrograms: get_decisions, all_decisions, set_decision!, SingleDecisionSet, NoSpecifiedConstraint
using StochasticPrograms: all_known_decisions, update_known_decisions!, KnownValuesChange, Known, KnownDecision
using StochasticPrograms: add_subscript
using StochasticPrograms: AbstractPenaltyterm, Quadratic, InfNorm, ManhattanNorm, initialize_penaltyterm!, update_penaltyterm!, remove_penalty!, remove_penalty_variables!, remove_penalty_constraints!
using ProgressMeter

import Base: show, put!, wait, isready, take!, fetch, zero, +, length, size
import StochasticPrograms: supports_structure, default_structure, check_loadable, load_structure!, restore_structure!, optimize!, optimizer_name, master_optimizer, subproblem_optimizer, num_subproblems, remove_penalty_variables!, remove_penalty_constraints!

const MOI = MathOptInterface
const MOIU = MOI.Utilities
const CI = MOI.ConstraintIndex

export
    AbstractQuasiGradientAttribute,
    QuasiGradientAlgorithm,
    num_iterations,
    StepSize,
    StepParameter,
    RawStepParameter,
    set_step_attribute,
    set_step_attributes,
    Constant,
    Prox,
    ProxParameter,
    RawProxParameter,
    set_prox_attribute,
    set_prox_attributes,
    NoProx,
    Polyhedron,
    AndersonAcceleration

# Include files
include("types/types.jl")
include("step/step.jl")
include("prox/prox.jl")
include("execution/execution.jl")
include("solver.jl")
include("MOI_wrapper.jl")

end # module
