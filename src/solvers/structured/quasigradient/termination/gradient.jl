@with_kw mutable struct GradientThresholdParameters{T <: AbstractFloat}
    τ::T = 1e-6
end

struct GradientThreshold{T <: AbstractFloat} <: AbstractTerminationCriterion
    parameters::GradientThresholdParameters{T}

    function GradientThreshold(::Type{T}; kw...) where T <: AbstractFloat
        return new{T}(GradientThresholdParameters{T}(; kw...))
    end
end

function Progress(termination::GradientThreshold, str::AbstractString)
    @unpack τ = termination.parameters
    return ProgressThresh(τ, 0.0, str)
end

function progress_value(::GradientThreshold, k::Integer, f::AbstractFloat, ∇f_norm::AbstractFloat)
    return ∇f_norm
end

function terminate(termination::GradientThreshold, k::Integer, f::Float64, x::AbstractVector, ∇f::AbstractVector)
    return norm(∇f) <= termination.τ
end

# API
# ------------------------------------------------------------
mutable struct AtGradientThreshold <: AbstractTermination
    parameters::GradientThresholdParameters{Float64}
end
AtGradientThreshold(τ::AbstractFloat) = AtGradientThreshold(GradientThresholdParameters(; τ = Float64(τ)))
AtGradientThreshold(; kw...) = AtGradientThreshold(GradientThresholdParameters(; kw...))

function (criteria::AtGradientThreshold)(::Type{T}) where T <: AbstractFloat
    return GradientThreshold(T; type2dict(criteria.parameters)...)
end
