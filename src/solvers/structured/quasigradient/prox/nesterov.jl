@with_kw mutable struct NesterovData{T}
    t::T = 1.0
end

@with_kw mutable struct NesterovParameters
    stabilizing_projection::Bool = false
end

struct NesterovProximal{T <: AbstractFloat, P <: AbstractProximal} <: AbstractProximal
    data::NesterovData{T}
    parameters::NesterovParameters

    prox::P
    xprev::Vector{T}

    function NesterovProximal(proximal::AbstractProximal, ::Type{T}; kw...) where T <: AbstractFloat
        P = typeof(proximal)
        return new{T,P}(NesterovData{T}(),
                        NesterovParameters(; kw...),
                        proximal,
                        Vector{T}())
    end
end

function initialize_prox!(quasigradient::AbstractQuasiGradient, nesterov::NesterovProximal)
    # Initialize inner
    initialize_prox!(quasigradient, nesterov.prox)
    return nothing
end

function restore_proximal_master!(quasigradient::AbstractQuasiGradient, nesterov::NesterovProximal)
    # Restore inner
    restore_proximal_master!(quasigradient, nesterov.prox)
    return nothing
end

function prox!(quasigradient::AbstractQuasiGradient, nesterov::NesterovProximal, x::AbstractVector, ∇f::AbstractVector, h::AbstractFloat)
    if length(nesterov.xprev) == 0
        resize!(nesterov.xprev, length(x))
        nesterov.xprev .= x
        return nothing
    end
    @unpack t = nesterov.data
    # Prox step
    prox!(quasigradient, nesterov.prox, x, ∇f, h)
    # Update incumbent xₖ
    quasigradient.ξ .= x
    # Update t
    tnext = (1 + sqrt(1 + 4*t^2)) / 2
    # Look-ahead
    x .= x + ((t - 1) / tnext) * (x - nesterov.xprev)
    # Possibly stabilize the iterate
    if nesterov.parameters.stabilizing_projection
        prox!(quasigradient, nesterov.prox, x, ∇f, 0.0)
    end
    # Update memory
    nesterov.xprev .= quasigradient.ξ
    nesterov.data.t = tnext
    return nothing
end

# API
# ------------------------------------------------------------
mutable struct Nesterov <: AbstractProx
    prox::AbstractProx
    parameters::NesterovParameters
end
Nesterov(; prox::AbstractProx = Polyhedron(), kw...) = Nesterov(prox, NesterovParameters(; kw...))

function (nesterov::Nesterov)(structure::VerticalStructure, x₀::AbstractVector, ::Type{T}) where T <: AbstractFloat
    proximal = nesterov.prox(structure, x₀, T)
    return NesterovProximal(proximal, T; type2dict(nesterov.parameters)...)
end

function str(::Nesterov)
    return ""
end
