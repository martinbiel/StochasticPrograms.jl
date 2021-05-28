"""
    NoProximal

Empty functor object for running a quasi-gradient algorithm without a prox step.

"""
struct NoProximal <: AbstractProximal end

function initialize_prox!(::AbstractQuasiGradient, ::NoProximal)
    return nothing
end

function restore_proximal_master!(::AbstractQuasiGradient, ::NoProximal)
    return nothing
end

function prox!(::AbstractQuasiGradient, ::NoProximal, x::AbstractVector, ∇f::AbstractVector, γ::AbstractFloat)
    x .= x - γ*∇f
    return nothing
end

# API
# ------------------------------------------------------------
"""
    NoProx

Factory object for [`NoProximal`](@ref). Passed by default to `prox` in `QuasiGradient.Optimizer`.

"""
struct NoProx <: AbstractProx end

function (::NoProx)(::StageDecompositionStructure, ::AbstractVector, ::Type{T}) where T <: AbstractFloat
    return NoProximal()
end

function str(::NoProx)
    return ""
end
