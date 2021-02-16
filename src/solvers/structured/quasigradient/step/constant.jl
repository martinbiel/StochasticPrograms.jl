@with_kw mutable struct ConstantStepParameters{T <: AbstractFloat}
    γ::T = 0.1
end

struct ConstantStep{T <: AbstractFloat} <: AbstractStep
    parameters::ConstantStepParameters{T}

    function ConstantStep(::Type{T}; kw...) where T <: AbstractFloat
        return new{T}(ConstantStepParameters{T}(; kw...))
    end
end
step(step::ConstantStep, ::Integer, ::Float64, ::AbstractVector) = step.parameters.γ


# API
# ------------------------------------------------------------
mutable struct Constant <: AbstractStepSize
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
