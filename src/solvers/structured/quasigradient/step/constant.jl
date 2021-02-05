struct ConstantStep <: AbstractStep
    γ::Float64
end
step(step::ConstantStep, ::Integer, ::Float64, ::AbstractVector) = step.γ


# API
# ------------------------------------------------------------
mutable struct Constant <: AbstractStepSize
    γ::Float64
end
Constant(; γ = 0.1) = Constant(γ)

function (stepsize::Constant)()
    return ConstantStep(stepsize.γ)
end

function str(::Constant)
    return "constant step size"
end
