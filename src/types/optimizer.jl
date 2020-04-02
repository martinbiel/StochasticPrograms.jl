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

# Provided optimizer helper types and functions for dispatch #
# ========================== #
abstract type AbstractProvidedOptimizer end

function _check_provided_optimizer(::AbstractProvidedOptimizer) end

struct UnrecognizedOptimizerProvided <: AbstractProvidedOptimizer end
struct NoOptimizerProvided <: AbstractProvidedOptimizer end
struct OptimizerProvided <: AbstractProvidedOptimizer end
struct StructuredOptimizerProvided <: AbstractProvidedOptimizer end
struct SampledOptimizerProvided <: AbstractProvidedOptimizer end

_check_provided_optimizer(::UnrecognizedOptimizerProvided) = throw(NoOptimizer())
_check_provided_optimizer(::NoOptimizerProvided) = throw(NoOptimizer())

function provided_optimizer(::Any)
    # Universal fallback. No functional optimizer recognized
    @warn "Unrecognized optimizer provided."
    return UnrecognizedOptimizerProvided()
end
function provided_optimizer(::Nothing)
    # No optimizer attached
    NoOptimizerProvided()
end
function provided_optimizer(optimizer_constructor::Type{Opt}) where Opt <: MOI.AbstractOptimizer
    return OptimizerProvided()
end
function provided_optimizer(optimizer_constructor::Type{Opt}) where Opt <: AbstractStructuredOptimizer
    return StructuredOptimizerProvided()
end
function provided_optimizer(optimizer_constructor::Type{Opt}) where Opt <: AbstractSampledOptimizer
    return SampledOptimizerProvided()
end
function provided_optimizer(optimizer_constructor::MOI.OptimizerWithAttributes) where Opt <: MOI.AbstractOptimizer
    # Fallback to the inner constructor of OptimizerWithAttributes
    return provided_optimizer(optimizer_constructor.optimizer_constructor)
end
function provided_optimizer(optimizer_constructor::Function)
    # If the constructor is a function fallback to the first returned type
    return provided_optimizer(first(Base.return_types(optimizer_constructor)))
end
# StochasticProgramOptimizer #
# ========================== #
"""
    StochasticProgramOptimizer

Wrapper type around both the optimizer_constructor provided to a stochastic program and the resulting optimizer object. Used to conviently distinguish between standard MOI optimizers and structure-exploiting optimizers when instantiating the stochastic program.
"""
mutable struct StochasticProgramOptimizer
    optimizer_constructor
    optimizer

    function StochasticProgramOptimizer(optimizer_constructor)
        return new(optimizer_constructor)
    end
end

function moi_optimizer(sp_optimizer::StochasticProgramOptimizer)
    return _moi_optimizer(sp_optimizer, provided_optimizer(sp_optimizer.optimizer_constructor))
end

function _moi_optimizer(sp_optimizer::StochasticProgramOptimizer, ::UnrecognizedOptimizerProvided)
    throw(NoOptimizer())
end

function _moi_optimizer(sp_optimizer::StochasticProgramOptimizer, ::NoOptimizerProvided)
    throw(NoOptimizer())
end

function _moi_optimizer(sp_optimizer::StochasticProgramOptimizer, ::OptimizerProvided)
    return sp_optimizer.optimizer_constructor
end

function _moi_optimizer(sp_optimizer::StochasticProgramOptimizer, ::StructuredOptimizerProvided)
    return moi_optimizer(sp_optimizer.optimizer)
end
