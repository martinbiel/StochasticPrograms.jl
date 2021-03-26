@with_kw mutable struct BBParameters{T <: AbstractFloat}
    γ₀::T = 0.1
end

"""
    BBStep

Functor object for using the Barzilai-Borwein step size in a quasigradient algorithm. Create by supplying a [`BB`](@ref) object through `step` to `QuasiGradient.Optimizer` or by setting the [`StepSize`](@ref) attribute.

...
# Parameters
- `γ₀::AbstractFloat = 0.1`: Initial step-size and fallback if BB is numerically unstable
...
"""
struct BBStep{T <: AbstractFloat} <: AbstractStep
    parameters::BBParameters{T}
    xprev::Vector{T}
    gprev::Vector{T}

    function BBStep(::Type{T}; kw...) where T <: AbstractFloat
        return new{T}(BBParameters{T}(; kw...), Vector{T}(), Vector{T}())
    end
end

function step(step::BBStep, k::Integer, fval::Float64, x::AbstractVector, g::AbstractVector)
    if k == 1
        resize!(step.xprev, length(x))
        resize!(step.gprev, length(x))
        step.xprev .= x
        step.gprev .= g
        return step.parameters.γ₀
    end
    s = x - step.xprev
    y = g - step.gprev
    sy = (s⋅y)
    if abs(sy) <= sqrt(eps())
        return step.parameters.γ₀
    end
    η = (norm(s,2) ^ 2) / sy
    step.xprev .= x
    step.gprev .= g
    return η
end


# API
# ------------------------------------------------------------
"""
    BB

Factory object for [`BBStep`](@ref). Pass to `step` in `Quasigradient.Optimizer` or set the [`StepSize`](@ref) attribute. See ?BBStep for parameter descriptions.

"""
struct BB <: AbstractStepSize
    parameters::BBParameters{Float64}
end
BB(γ₀::AbstractFloat) = BB(BBParameters(; γ₀ = Float64(γ₀)))
BB(; kw...) = BB(BBParameters(; kw...))

function (stepsize::BB)(::Type{T}) where T <: AbstractFloat
    return BBStep(T; type2dict(stepsize.parameters)...)
end

function str(::BB)
    return "BB step size"
end
