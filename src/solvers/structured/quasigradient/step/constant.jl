@with_kw mutable struct ConstantStepParameters{T <: AbstractFloat}
    γ::T = 0.01
end

"""
    ConstantStep

Functor object for using a constant step size in a quasigradient algorithm. Create by supplying a [`Constant`](@ref) object through `step` to `QuasiGradient.Optimizer` or by setting the [`StepSize`](@ref) attribute.

...
# Parameters
- `γ::AbstractFloat = 0.01`: Step length
...
"""
struct ConstantStep{T <: AbstractFloat} <: AbstractStep
    parameters::ConstantStepParameters{T}

    function ConstantStep(::Type{T}; kw...) where T <: AbstractFloat
        return new{T}(ConstantStepParameters{T}(; kw...))
    end
end
step(step::ConstantStep, ::Integer, ::Float64, ::AbstractVector, ::AbstractVector) = step.parameters.γ


# API
# ------------------------------------------------------------
"""
    Constant

Factory object for [`ConstantStep`](@ref). Pass to `step` in `Quasigradient.Optimizer` or set the [`StepSize`](@ref) attribute. See ?ConstantStep for parameter descriptions.

"""
struct Constant <: AbstractStepSize
    parameters::ConstantStepParameters{Float64}
end
Constant(γ::AbstractFloat) = Constant(ConstantStepParameters(; γ = Float64(γ)))
Constant(; kw...) = Constant(ConstantStepParameters(; kw...))

function (stepsize::Constant)(::Type{T}) where T <: AbstractFloat
    return ConstantStep(T; type2dict(stepsize.parameters)...)
end

function str(::Constant)
    return "constant step size"
end
