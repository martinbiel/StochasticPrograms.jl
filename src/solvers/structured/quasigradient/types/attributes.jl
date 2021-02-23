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

- [`NoProx`](@ref):  L-shaped algorithm (default)
- [`RegularizedDecomposition`](@ref):  Regularized decomposition ?RegularizedDecomposition for parameter descriptions.
- [`TrustRegion`](@ref):  Trust-region ?TrustRegion for parameter descriptions.
- [`LevelSet`](@ref):  Level-set ?LevelSet for parameter descriptions.
"""
struct Prox <: AbstractQuasiGradientAttribute end
"""
    StepSize

An optimizer attribute for specifying an aggregation procedure to be used in the L-shaped algorithm. Options are:

- [`NoAggregation`](@ref):  Multi-cut L-shaped algorithm (default)
- [`PartialAggregation`](@ref):  ?PartialAggregation for parameter descriptions.
- [`FullAggregation`](@ref):  ?FullAggregation for parameter descriptions.
- [`DynamicAggregation`](@ref):  ?DynamicAggregation for parameter descriptions.
- [`ClusterAggregation`](@ref):  ?ClusterAggregation for parameter descriptions.
- [`HybridAggregation`](@ref):  ?HybridAggregation for parameter descriptions.
"""
struct StepSize <: AbstractQuasiGradientAttribute end
"""
    Termination

An optimizer attribute for specifying an aggregation procedure to be used in the L-shaped algorithm. Options are:

- [`NoAggregation`](@ref):  Multi-cut L-shaped algorithm (default)
- [`PartialAggregation`](@ref):  ?PartialAggregation for parameter descriptions.
- [`FullAggregation`](@ref):  ?FullAggregation for parameter descriptions.
- [`DynamicAggregation`](@ref):  ?DynamicAggregation for parameter descriptions.
- [`ClusterAggregation`](@ref):  ?ClusterAggregation for parameter descriptions.
- [`HybridAggregation`](@ref):  ?HybridAggregation for parameter descriptions.
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
