@with_kw mutable struct DiminishingStepParameters{T <: AbstractFloat}
    γ₀::T = 0.1
    η::T = 1.0
end

"""
    DiminishingStep

Functor object for using a constant step size in a quasigradient algorithm. Create by supplying a [`Constant`](@ref) object through `step` to `QuasiGradient.Optimizer` or by setting the [`StepSize`](@ref) attribute.

...
# Parameters
- `γ₀::AbstractFloat = 0.1`: Nominal step
- `η::AbstractFloat = 1.0`: Diminishing factor
...
"""
struct DiminishingStep{T <: AbstractFloat} <: AbstractStep
    parameters::DiminishingStepParameters{T}

    function DiminishingStep(::Type{T}; kw...) where T <: AbstractFloat
        return new{T}(DiminishingStepParameters{T}(; kw...))
    end
end
function step(step::DiminishingStep, k::Integer, ::Float64, ::AbstractVector, ::AbstractVector)
    @unpack γ₀, η = step.parameters
    return γ₀ / (1 + η * k)
end


# API
# ------------------------------------------------------------
"""
    Diminishing

Factory object for [`DiminishingStep`](@ref). Pass to `step` in `Quasigradient.Optimizer` or set the [`StepSize`](@ref) attribute. See ?DiminishingStep for parameter descriptions.

"""
struct Diminishing <: AbstractStepSize
    parameters::DiminishingStepParameters{Float64}
end
DiminishingStepParame(γ::AbstractFloat) = Constant(DiminishingStepParameters(; γ = Float64(γ)))
Diminishing(; kw...) = Diminishing(DiminishingStepParameters(; kw...))

function (stepsize::Diminishing)(::Type{T}) where T <: AbstractFloat
    return DiminishingStep(T; type2dict(stepsize.parameters)...)
end

function str(::Diminishing)
    return "diminishing step size"
end
