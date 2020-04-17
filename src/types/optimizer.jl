# Abstract optimizer types #
# ========================== #
"""
    AbstractStructuredOptimizer

Abstract supertype for structure-exploiting optimizers.
"""
abstract type AbstractStructuredOptimizer end
"""
    AbstractStructuredOptimizerAttribute

Abstract supertype for attribute objects that can be used to set or get attributes (properties) of the structure-exploiting optimizer.
"""
abstract type AbstractStructuredOptimizerAttribute end
"""
    AbstractSampledOptimizer

Abstract supertype for sample-based optimizers.
"""
abstract type AbstractSampledOptimizer end

StochasticProgramOptimizerType = Union{MOI.AbstractOptimizer, AbstractStructuredOptimizer}

# StochasticProgramOptimizer #
# ========================== #
"""
    StochasticProgramOptimizer

Wrapper type around both the optimizer_constructor provided to a stochastic program and the resulting optimizer object. Used to conviently distinguish between standard MOI optimizers and structure-exploiting optimizers when instantiating the stochastic program.
"""
mutable struct StochasticProgramOptimizer{Opt <: StochasticProgramOptimizerType}
    optimizer_constructor
    optimizer::Opt

    function StochasticProgramOptimizer(::Nothing)
        universal_fallback = MOIU.UniversalFallback(MOIU.Model{Float64}())
        caching_optimizer = MOIU.CachingOptimizer(universal_fallback, MOIU.AUTOMATIC)
        return new{StochasticProgramOptimizerType}(nothing, caching_optimizer)
    end

    function StochasticProgramOptimizer(optimizer_constructor)
        optimizer = MOI.instantiate(optimizer_constructor)
        Opt = typeof(optimizer)
        return new{Opt}(optimizer_constructor, optimizer)
    end
end

function _check_provided_optimizer(sp_optimizer::StochasticProgramOptimizer)
    if sp_optimizer.optimizer_constructor == nothing
        throw(NoOptimizer())
    end
end

function moi_optimizer(sp_optimizer::StochasticProgramOptimizer)
    return moi_optimizer(sp_optimizer, sp_optimizer.optimizer)
end

function moi_optimizer(sp_optimizer::StochasticProgramOptimizer, ::MOI.AbstractOptimizer)
    if sp_optimizer.optimizer_constructor == nothing
        throw(NoOptimizer())
    end
    return sp_optimizer.optimizer_constructor
end

function moi_optimizer(sp_optimizer::StochasticProgramOptimizer, optimizer::AbstractStructuredOptimizer)
    return moi_optimizer(optimizer)
end

function reset_optimizer!(sp_optimizer::StochasticProgramOptimizer{Opt}, optimizer) where Opt <: StochasticProgramOptimizerType
    @warn "Only optimizers of type $Opt can be set. Consider reinstantiating stochastic program."
    return nothing
end

function reset_optimizer!(sp_optimizer::StochasticProgramOptimizer{Opt}, optimizer::Opt) where Opt <: StochasticProgramOptimizerType
    sp_optimizer.optimizer = optimizer
    return nothing
end

function set_optimizer!(sp_optimizer::StochasticProgramOptimizer, optimizer_constructor)
    optimizer = MOI.instantiate(optimizer_constructor)
    reset_optimizer!(sp_optimizer, optimizer_constructor)
    return nothing
end
