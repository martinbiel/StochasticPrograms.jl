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

@reexport module QuasiGradient

# Standard library
using LinearAlgebra
using SparseArrays
using Distributed
using Printf

# External libraries
using Parameters
using JuMP
import MathOptInterface as MOI
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
include("prox/prox.jl")
include("termination/termination.jl")
include("execution/execution.jl")
include("solver.jl")
include("MOI_wrapper.jl")

end # module
