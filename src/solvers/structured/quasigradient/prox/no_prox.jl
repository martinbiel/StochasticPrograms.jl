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
struct NoProx <: AbstractProx end

function (::NoProx)(::VerticalStructure, ::AbstractVector, ::Type{T}) where T <: AbstractFloat
    return NoProximal()
end

function str(::NoProx)
    return ""
end
