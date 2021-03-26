abstract type AbstractStep end
abstract type AbstractStepSize end

step(quasigradient::AbstractQuasiGradient, k::Integer, f::Float64, x::AbstractVector, ∇f::AbstractVector) = step(quasigradient.step, k, f, x, ∇f)

"""
    RawStepParameter

An optimizer attribute used for raw parameters of the step. Defers to `RawParameter`.
"""
struct RawStepParameter <: StepParameter
    name::Any
end

include("common.jl")
include("constant.jl")
include("diminishing.jl")
include("polyak.jl")
include("bb.jl")
