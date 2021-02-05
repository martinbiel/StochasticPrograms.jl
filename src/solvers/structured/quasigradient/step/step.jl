abstract type AbstractStep end
abstract type AbstractStepSize end

step(quasigradient::AbstractQuasiGradient, k::Integer, f::Float64, ∇f::AbstractVector) = step(quasigradient.step, k, f, ∇f)

include("constant.jl")
