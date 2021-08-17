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

# Attributes #
# ========================== #
"""
    AbstractQuasiGradientAttribute

Abstract supertype for attribute objects specific to the L-shaped algorithm.
"""
abstract type AbstractQuasiGradientAttribute <: AbstractStructuredOptimizerAttribute end
"""
    SubProblems

An optimizer attribute for specifying if subproblems should be smoothed. Options are:

- [`Unaltered`](@ref):  Subproblems are solved in their original state (default)
- [`Smoothed`](@ref):  Subproblems are smoothed using Moreau envelopes ?SmoothSubProblem for parameter descriptions.
"""
struct SubProblems <: AbstractQuasiGradientAttribute end
"""
    Prox

An optimizer attribute for specifying a prox policy to be used in the quasi-gradient algorithm. Options are:

- [`NoProx`](@ref): Unconstrained.
- [`Polyhedron`](@ref): QP projection on polyhedral space ?PolyhedronProjection for parameter descriptions. (default)
- [`AndersonAcceleration`](@ref):  Anderson acceleration of inner prox step ?AndersonAcceleratedProximal for parameter descriptions.
- [`Nesterov`](@ref):  Nesterov acceleration of inner prox step ?NesterovProximal for parameter descriptions.
- [`DryFriction`](@ref):  Dry-friction acceleration of inner prox step ?DryFrictionProximal for parameter descriptions.
"""
struct Prox <: AbstractQuasiGradientAttribute end
"""
    StepSize

An optimizer attribute for specifying an aggregation procedure to be used in the quasi-gradient algorithm. Options are:

- [`Constant`](@ref):  Constant step size ?ConstantStep for parameter descriptions (default)
- [`Diminishing`](@ref):  Diminishing step size ?DiminishingStep for parameter descriptions.
- [`Polyak`](@ref):  Polyak step size ?PolyakStep for parameter descriptions.
- [`BB`](@ref):  Barzilai-Borwein step size ?BBStep for parameter descriptions.
"""
struct StepSize <: AbstractQuasiGradientAttribute end
"""
    Termination

An optimizer attribute for specifying a termination criterion to be used in the quasi-gradient algorithm. Options are:

- [`AfterMaximumIterations`](@ref):  Terminate after set number of iterations ?MaximumIterations for parameter descriptions (default)
- [`AtObjectiveThreshold`](@ref):  Terminate after reaching reference objective ?ObjectiveThreshold for parameter descriptions.
- [`AtGradientThreshold`](@ref):  Terminate after reaching zero gradient ?GradientThreshold for parameter descriptions.
"""
struct Termination <: AbstractQuasiGradientAttribute end
"""
    ProxParameter

Abstract supertype for prox-specific attributes.
"""
abstract type ProxParameter <: AbstractQuasiGradientAttribute end
"""
    StepParameter

Abstract supertype for step-specific attributes.
"""
abstract type StepParameter <: AbstractQuasiGradientAttribute end
"""
    TerminationParameter

Abstract supertype for termination-specific attributes.
"""
abstract type TerminationParameter <: AbstractQuasiGradientAttribute end
