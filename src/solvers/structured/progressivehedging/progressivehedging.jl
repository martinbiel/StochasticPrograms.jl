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

@reexport module ProgressiveHedging

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
using StochasticPrograms: UnspecifiedInstantiation, ScenarioDecompositionStructure, AbstractScenarioProblems, ScenarioProblems, DistributedScenarioProblems
using StochasticPrograms: AbstractExecution, ExecutionParameter, Serial, Synchronous, Asynchronous
using StochasticPrograms: AbstractStructuredOptimizer, set_master_optimizer!, set_subproblem_optimizer!
using StochasticPrograms: DecisionMap, get_decisions, all_decisions, remove_decision!, set_decision!, set_stage!, SingleDecisionSet, DecisionCoefficientChange, KnownDecision, NoSpecifiedConstraint
using StochasticPrograms: add_subscript
using StochasticPrograms: AbstractPenaltyTerm, Quadratic, InfNorm, ManhattanNorm, initialize_penaltyterm!, update_penaltyterm!, remove_penalty!
using ProgressMeter

import Base: show, put!, wait, isready, take!, fetch
import StochasticPrograms: supports_structure, num_iterations, default_structure, load_structure!, restore_structure!, optimize!, optimizer_name, master_optimizer, subproblem_optimizer, num_subproblems

const MOI = MathOptInterface
const MOIU = MOI.Utilities

export
    AbstractProgressiveHedgingAttribute,
    ProgressiveHedgingAlgorithm,
    PrimalTolerance,
    DualTolerance,
    Penalizer,
    PenalizationParameter,
    RawPenalizationParameter,
    set_penalization_attribute,
    set_penalization_attributes,
    PenaltyTerm,
    Fixed,
    Adaptive


# Include files
include("types/types.jl")
include("penalties/penalization.jl")
include("execution/execution.jl")
include("solver.jl")
include("MOI_wrapper.jl")

end # module
