@with_kw mutable struct ObjectiveThresholdParameters{T <: AbstractFloat}
    reference::T = 0.0
    τ::T = 1e-6
end

"""
    ObjectiveThreshold

Functor object for using an objective threshold as termination criterion in a quasigradient algorithm. Create by supplying a [`AtObjectiveThreshold`](@ref) object through `terminate` to `QuasiGradient.Optimizer` or by setting the [`Termination`](@ref) attribute.

...
# Parameters
- `reference::AbstractFloat = 0.0`: Reference objective value
- `τ::AbstractFloat = 1e-6`: Relative tolerance
...
"""
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
"""
    AtObjectiveThreshold

Factory object for [`ObjectiveThreshold`](@ref). Pass to `terminate` in `Quasigradient.Optimizer` or set the [`Termination`](@ref) attribute. See ?ObjectiveThreshold for parameter descriptions.

"""
struct AtObjectiveThreshold <: AbstractTermination
    parameters::ObjectiveThresholdParameters{Float64}
end
AtObjectiveThreshold(reference::AbstractFloat, τ::AbstractFloat) = AtObjectiveThreshold(ObjectiveThresholdParameters{Float64}(; reference = Float64(reference), τ = Float64(τ)))
AtObjectiveThreshold(; kw...) = AtObjectiveThreshold(ObjectiveThresholdParameters{Float64}(; kw...))

function (criteria::AtObjectiveThreshold)(::Type{T}) where T <: AbstractFloat
    return ObjectiveThreshold(ObjectiveThresholdParameters{T}(; type2dict(criteria.parameters)...))
end
