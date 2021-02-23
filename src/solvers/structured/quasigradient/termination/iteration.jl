@with_kw mutable struct MaximumIterationParameters
    maximum::Int = 1000
end

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
struct AfterMaximumIterations <: AbstractTermination
    parameters::MaximumIterationParameters
end
AfterMaximumIterations(maximum::Integer) = AfterMaximumIterations(MaximumIterationParameters(; maximum))
AfterMaximumIterations(; kw...) = AfterMaximumIterations(MaximumIterationParameters(; kw...))

function (criteria::AfterMaximumIterations)(::Type{T}) where T <: AbstractFloat
    return MaximumIterations(; type2dict(criteria.parameters)...)
end
