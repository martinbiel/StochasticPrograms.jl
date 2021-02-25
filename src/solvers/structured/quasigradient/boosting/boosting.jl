abstract type AbstractGradientBoosting end
abstract type AbstractBoosting end

boost!(quasigradient::AbstractQuasiGradient, k::Integer, x::AbstractVector, ∇f::AbstractVector) = boost!(quasigradient.boosting, k, x, ∇f)

"""
    RawBoostingParameter

An optimizer attribute used for raw parameters of the boosting. Defers to `RawParameter`.
"""
struct RawBoostingParameter <: BoostingParameter
    name::Any
end

include("common.jl")
include("no_boosting.jl")
include("momentum.jl")
include("ADAM.jl")
