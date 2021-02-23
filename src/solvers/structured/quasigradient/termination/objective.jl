@with_kw mutable struct ObjectiveThresholdParameters{T <: AbstractFloat}
    reference::T = 0.0
    τ::T = 1e-6
end

struct ObjectiveThreshold{T <: AbstractFloat} <: AbstractTerminationCriterion
    parameters::ObjectiveThresholdParameters{T}
end

function Progress(termination::ObjectiveThreshold, str::AbstractString)
    @unpack τ = termination.parameters
    return ProgressThresh(τ, 0.0, str)
end

function progress_value(termination::ObjectiveThreshold, k::Integer, f::AbstractFloat, ∇f_norm::AbstractFloat)
    @unpack reference = termination.parameters
    return abs(f - reference) / abs(reference + 1e-10)
end

function terminate(termination::ObjectiveThreshold, k::Integer, f::Float64, x::AbstractVector, ∇f::AbstractVector)
    @unpack reference, τ = termination.parameters
    return abs(f - reference) / abs(reference + 1e-10) <= τ
end

# API
# ------------------------------------------------------------
struct AtObjectiveThreshold <: AbstractTermination
    parameters::ObjectiveThresholdParameters{Float64}
end
AtObjectiveThreshold(reference::AbstractFloat, τ::AbstractFloat) = AtObjectiveThreshold(ObjectiveThresholdParameters{Float64}(; reference = Float64(reference), τ = Float64(τ)))
AtObjectiveThreshold(; kw...) = AtObjectiveThreshold(ObjectiveThresholdParameters{Float64}(; kw...))

function (criteria::AtObjectiveThreshold)(::Type{T}) where T <: AbstractFloat
    return ObjectiveThreshold(ObjectiveThresholdParameters{T}(; type2dict(criteria.parameters)...))
end
