@with_kw mutable struct MaximumIterationParameters
    maximum::Int = 1000
end

"""
    MaximumIterations

Functor object for using maximum number of iterations as termination criterion in a quasigradient algorithm. Create by supplying a [`AfterMaximumIterations`](@ref) object through `terminate` to `QuasiGradient.Optimizer` or by setting the [`Termination`](@ref) attribute.

...
# Parameters
- `maximum::Integer = 1000`: Maximum number of iterations
...
"""
struct MaximumIterations <: AbstractTerminationCriterion
    parameters::MaximumIterationParameters

    function MaximumIterations(; kw...)
        return new(MaximumIterationParameters(; kw...))
    end
end

function Progress(termination::MaximumIterations, str::AbstractString)
    return Progress(termination.parameters.maximum, str)
end

function progress_value(::MaximumIterations, k::Integer, f::AbstractFloat, ∇f_norm::AbstractFloat)
    return k
end

function terminate(termination::MaximumIterations, k::Integer, f::Float64, x::AbstractVector, ∇f::AbstractVector)
    return k >= termination.parameters.maximum
end

# API
# ------------------------------------------------------------
"""
    AfterMaximumIterations

Factory object for [`MaximumIterations`](@ref). Pass to `terminate` in `Quasigradient.Optimizer` or set the [`Termination`](@ref) attribute. See ?MaximumIterations for parameter descriptions.

"""
struct AfterMaximumIterations <: AbstractTermination
    parameters::MaximumIterationParameters
end
AfterMaximumIterations(maximum::Integer) = AfterMaximumIterations(MaximumIterationParameters(; maximum))
AfterMaximumIterations(; kw...) = AfterMaximumIterations(MaximumIterationParameters(; kw...))

function (criteria::AfterMaximumIterations)(::Type{T}) where T <: AbstractFloat
    return MaximumIterations(; type2dict(criteria.parameters)...)
end
