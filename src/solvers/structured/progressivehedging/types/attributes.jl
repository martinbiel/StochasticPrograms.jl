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

"""
    AbstractProgressiveHedgingAttribute

Abstract supertype for attribute objects specific to the progressive-hedging algorithm.
"""
abstract type AbstractProgressiveHedgingAttribute <: AbstractStructuredOptimizerAttribute end
"""
    PrimalTolerance

An optimizer attribute for specifying the primal tolerance in the progressive-hedging algorithm.
"""
struct PrimalTolerance <: AbstractProgressiveHedgingAttribute end
"""
    DualTolerance

An optimizer attribute for specifying the dual tolerance in the progressive-hedging algorithm.
"""
struct DualTolerance <: AbstractProgressiveHedgingAttribute end
"""
    Regularizer

An optimizer attribute for specifying a penalization procedure to be used in the progressive-hedging algorithm. Options are:

- [`Fixed`](@ref):  Fixed penalty (default) ?Fixed for parameter descriptions.
- [`Adaptive`](@ref): Adaptive penalty update ?Adaptive for parameter descriptions.
"""
struct Penalizer <: AbstractProgressiveHedgingAttribute end
"""
    PenaltyTerm

An optimizer attribute for specifying what proximal term should be used in subproblemsof the progressive-hedging algorithm. Options are:

- [`Quadratic`](@ref) (default)
- [`Linearized`](@ref)
- [`InfNorm`](@ref)
- [`ManhattanNorm`](@ref)
"""
struct PenaltyTerm <: AbstractProgressiveHedgingAttribute end
"""
    PenalizationParameter

Abstract supertype for penalization-specific attributes.
"""
abstract type PenalizationParameter <: AbstractProgressiveHedgingAttribute end
