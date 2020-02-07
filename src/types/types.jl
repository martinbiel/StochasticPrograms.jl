# Types #
# ========================== #
"""
    AbstractStructuredOptimizer

Abstract supertype for structure-exploiting optimizers.
"""
abstract type AbstractStructuredOptimizer end
"""
    AbstractSampledOptimizer

Abstract supertype for sample-based optimizers.
"""
abstract type AbstractSampledOptimizer end

SPOptimizerType = Union{MOI.AbstractOptimizer, AbstractStructuredOptimizer, AbstractSampledOptimizer}

mutable struct SPOptimizer
    optimizer_factory::Union{Nothing, OptimizerFactory}
    optimizer::SPOptimizerType

    function SPOptimizer(optimizer_factory::Union{Nothing, OptimizerFactory})
        return new(optimizer_factory)
    end
end

include("scenario.jl")
include("sampler.jl")
include("stage.jl")
include("decisionvariable.jl")
include("model.jl")
include("scenarioproblems.jl")
include("stochasticprogram.jl")
include("stochasticsolution.jl")
