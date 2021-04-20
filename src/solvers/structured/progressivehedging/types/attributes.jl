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
