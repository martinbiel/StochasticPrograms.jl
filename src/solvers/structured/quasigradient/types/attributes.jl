# Attributes #
# ========================== #
"""
    AbstractQuasiGradientAttribute

Abstract supertype for attribute objects specific to the L-shaped algorithm.
"""
abstract type AbstractQuasiGradientAttribute <: AbstractStructuredOptimizerAttribute end
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
    ProxParameter

Abstract supertype for prox-specific attributes.
"""
abstract type ProxParameter <: AbstractQuasiGradientAttribute end
"""
    StepParameter

Abstract supertype for step-specific attributes.
"""
abstract type StepParameter <: AbstractQuasiGradientAttribute end
