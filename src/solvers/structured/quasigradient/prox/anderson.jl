@with_kw mutable struct AndersonAccelerationData{T}
    current::Int = 1
    Q::T = 1e10
end

@with_kw mutable struct AndersonAccelerationParameters
    m::Int = 10
end

struct AndersonAcceleratedProximal{T <: AbstractFloat, P <: AbstractProximal} <: AbstractProximal
    data::AndersonAccelerationData
    parameters::AndersonAccelerationParameters

    prox::P
    x::Vector{T}
    save_g::Vector{T}
    grad_mapping::Vector{T}
    residuals::Vector{T}
    y::Vector{Vector{T}}
    g::Vector{Vector{T}}

    function AndersonAcceleratedProximal(proximal::AbstractProximal, ::Type{T}; kw...) where T <: AbstractFloat
        P = typeof(proximal)
        return new{T,P}(AndersonAccelerationData{T}(),
                        AndersonAccelerationParameters(; kw...),
                        proximal,
                        Vector{T}(),
                        Vector{T}(),
                        Vector{T}(),
                        Vector{T}(),
                        Vector{Vector{T}}(),
                        Vector{Vector{T}}())
    end
end

function initialize_prox!(quasigradient::AbstractQuasiGradient, anderson::AndersonAcceleratedProximal)
    # Initialize inner
    initialize_prox!(quasigradient, anderson.prox)
    return nothing
end

function restore_proximal_master!(quasigradient::AbstractQuasiGradient, anderson::AndersonAcceleratedProximal)
    # Restore inner
    restore_proximal_master!(quasigradient, anderson.prox)
    return nothing
end

function prox!(quasigradient::AbstractQuasiGradient, anderson::AndersonAcceleratedProximal, x::AbstractVector, ∇f::AbstractVector, γ::AbstractFloat)
    if length(anderson.y) == 0
        # First iteration standard prox
        push!(anderson.y, copy(x))
        push!(anderson.y, x - γ*∇f)
        push!(anderson.g, copy(anderson.y[2]))
        push!(anderson.g, zero(x))
        append!(anderson.save_g, copy(anderson.y[2]))
        prox!(quasigradient, anderson.prox, x, ∇f, γ)
        append!(anderson.x, copy(x))
        append!(anderson.grad_mapping, fill(Inf, length(x)))
        anderson.data.current = 2
        anderson.data.Q = quasigradient.data.Q
        return nothing
    else
        # Guard step
        @unpack Q = quasigradient.data
        if Q - anderson.data.Q > -0.5 * γ * norm(anderson.grad_mapping / γ)^2
            # Revert to regular proximal step
            x .= anderson.x
            anderson.y[anderson.data.current] .= anderson.save_g
            # Recompute objective and gradient
            Q = resolve_subproblems!(quasigradient)
            anderson.data.Q = Q
            if Q <= quasigradient.data.Q
                quasigradient.data.Q = Q
            end
            # Skip anderson step if this is the final iteration
            if terminate(quasigradient)
                return nothing
            end
        end
    end
    # Inner prox step
    anderson.g[anderson.data.current] .=  x - γ*∇f
    anderson.save_g .= anderson.g[anderson.data.current]
    _x = copy(x)
    prox!(quasigradient, anderson.prox, _x, ∇f, γ)
    anderson.grad_mapping .= x - _x
    anderson.x .= _x
    # Anderson update
    anderson_update!(anderson)
    # Proximal update on y
    x .= anderson.y[anderson.data.current]
    prox!(quasigradient, anderson.prox, x, ∇f, 0.0)
    anderson.data.Q = quasigradient.data.Q
    return nothing
end

function anderson_update!(anderson::AndersonAcceleratedProximal)
    mk = min(anderson.parameters.m, length(anderson.y))
    index_set = collect(1:mk)
    R = reduce(hcat, [anderson.g[i] - anderson.y[i] for i in reverse(index_set)])
    RR = transpose(R)*R
    RR ./= norm(RR)
    x = (RR + 1e-10I) \ ones(size(RR, 1))
    α = x / sum(x)
    # Update active index and memory
    anderson.data.current = (anderson.data.current % anderson.parameters.m) + 1
    # Reserve memory if still smaller than m
    if length(anderson.y) < anderson.parameters.m
        push!(anderson.y, zero(anderson.y[1]))
        push!(anderson.g, zero(anderson.y[1]))
    end
    anderson.y[anderson.data.current] .= sum([α[i]*anderson.g[mk-i+1] for i in index_set])
    push!(anderson.residuals, norm(R*α))
    return nothing
end

# API
# ------------------------------------------------------------
mutable struct AndersonAcceleration <: AbstractProx
    prox::AbstractProx
    parameters::AndersonAccelerationParameters
end
AndersonAcceleration(; prox::AbstractProx = Polyhedron(), kw...) = AndersonAcceleration(prox, AndersonAccelerationParameters(; kw...))

function (anderson::AndersonAcceleration)(structure::VerticalStructure, x₀::AbstractVector, ::Type{T}) where T <: AbstractFloat
    proximal = anderson.prox(structure, x₀, T)
    return AndersonAcceleratedProximal(proximal, T; type2dict(anderson.parameters)...)
end

function str(::AndersonAcceleration)
    return ""
end
