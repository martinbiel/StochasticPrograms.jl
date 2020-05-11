# Abstract optimizer types #
# ========================== #
"""
    AbstractStructuredOptimizer

Abstract supertype for structure-exploiting optimizers.
"""
abstract type AbstractStructuredOptimizer <: MOI.AbstractOptimizer end
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

"""
    AbstractCrash

Abstract supertype for crash methods.
"""
abstract type AbstractCrash end

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

    function StochasticProgramOptimizer(optimizer_constructor, optimizer::MOI.AbstractOptimizer)
        universal_fallback = MOIU.UniversalFallback(MOIU.Model{Float64}())
        caching_optimizer = MOIU.CachingOptimizer(universal_fallback, MOIU.AUTOMATIC)
        MOIU.reset_optimizer(caching_optimizer, optimizer)
        Opt = MOI.AbstractOptimizer
        return new{Opt}(optimizer_constructor, caching_optimizer)
    end

    function StochasticProgramOptimizer(optimizer_constructor, optimizer::AbstractStructuredOptimizer)
        Opt = AbstractStructuredOptimizer
        return new{Opt}(optimizer_constructor, optimizer)
    end
end

function StochasticProgramOptimizer(optimizer_constructor)
    optimizer = MOI.instantiate(optimizer_constructor; with_bridge_type = bridge_type(optimizer_constructor))
    return StochasticProgramOptimizer(optimizer_constructor, optimizer)
end

bridge_type(optimizer::Type{<:AbstractStructuredOptimizer}) = nothing
bridge_type(optimizer::Type{<:MOI.AbstractOptimizer}) = Float64
bridge_type(optimizer::MOI.OptimizerWithAttributes) = bridge_type(optimizer.optimizer_constructor)
bridge_type(optimizer::Function) = bridge_type(first(Base.return_types(optimizer)))

function has_provided_optimizer(sp_optimizer::StochasticProgramOptimizer)
    return sp_optimizer.optimizer_constructor !== nothing
end

function _check_provided_optimizer(sp_optimizer::StochasticProgramOptimizer)
    if !has_provided_optimizer(sp_optimizer)
        throw(NoOptimizer())
    end
end

function master_optimizer(sp_optimizer::StochasticProgramOptimizer)
    return master_optimizer(sp_optimizer, sp_optimizer.optimizer)
end

function sub_optimizer(sp_optimizer::StochasticProgramOptimizer)
    return sub_optimizer(sp_optimizer, sp_optimizer.optimizer)
end

function master_optimizer(sp_optimizer::StochasticProgramOptimizer, ::MOI.AbstractOptimizer)
    return sp_optimizer.optimizer_constructor
end

function sub_optimizer(sp_optimizer::StochasticProgramOptimizer, optimizer::MOI.AbstractOptimizer)
    return master_optimizer(sp_optimizer, optimizer)
end

function master_optimizer(sp_optimizer::StochasticProgramOptimizer, optimizer::AbstractStructuredOptimizer)
    return master_optimizer(optimizer)
end

function sub_optimizer(sp_optimizer::StochasticProgramOptimizer, optimizer::AbstractStructuredOptimizer)
    return sub_optimizer(optimizer)
end

function reset_optimizer!(sp_optimizer::StochasticProgramOptimizer{Opt}, optimizer) where Opt <: StochasticProgramOptimizerType
    @warn "Only optimizers of type $Opt can be set. Consider reinstantiating stochastic program."
    return nothing
end

function reset_optimizer!(sp_optimizer::StochasticProgramOptimizer, optimizer::MOI.AbstractOptimizer)
    MOIU.reset_optimizer(sp_optimizer.optimizer, optimizer)
    return nothing
end

function reset_optimizer!(sp_optimizer::StochasticProgramOptimizer, optimizer::AbstractStructuredOptimizer)
    if sp_optimizer.optimizer != nothing && sp_optimizer.optimizer isa AbstractStructuredOptimizer
        restore_structure!(sp_optimizer.optimizer)
    end
    sp_optimizer.optimizer = optimizer
    return nothing
end

function set_optimizer!(sp_optimizer::StochasticProgramOptimizer, optimizer_constructor)
    optimizer = MOI.instantiate(optimizer_constructor; with_bridge_type = bridge_type(optimizer_constructor))
    reset_optimizer!(sp_optimizer, optimizer)
    sp_optimizer.optimizer_constructor = optimizer_constructor
    return nothing
end
