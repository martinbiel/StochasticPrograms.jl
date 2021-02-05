mutable struct AndersonAcceleratedProx{P <: AbstractProx} <: AbstractProx
    prox::P
    x::Vector{Float64}
    save_g::Vector{Float64}
    grad_mapping::Vector{Float64}
    residuals::Vector{Float64}
    y::Vector{Vector{Float64}}
    g::Vector{Vector{Float64}}
    m::Int
    current::Int

    function AndersonAcceleratedProx(prox::AbstractProx, m::Integer)
        P = typeof(prox)
        return new{P}(prox, Vector{Float64}(), Vector{Float64}(), Vector{Float64}(), Vector{Float64}(), Vector{Vector{Float64}}(), Vector{Vector{Float64}}(), m, 1)
    end
end

function first_iteration(anderson::AndersonAcceleratedProx)
    return length(anderson.y) == 0
end

function anderson_update!(anderson::AndersonAcceleratedProx)
    mk = min(anderson.m, length(anderson.y))
    index_set = collect(1:mk)
    R = reduce(hcat, [anderson.g[i] - anderson.y[i] for i in reverse(index_set)])
    RR = transpose(R)*R
    RR ./= norm(RR)
    x = (RR + 1e-10I) \ ones(size(RR, 1))
    α = x / sum(x)
    # Update active index and memory
    anderson.current = (anderson.current % anderson.m) + 1
    # Reserve memory if still smaller than m
    if length(anderson.y) < anderson.m
        push!(anderson.y, zero(anderson.y[1]))
        push!(anderson.g, zero(anderson.y[1]))
    end
    anderson.y[anderson.current] .= sum([α[i]*anderson.g[mk-i+1] for i in index_set])
    push!(anderson.residuals, norm(R*α))
    return nothing
end

function prox!(x::AbstractVector, ∇f::AbstractVector, γ::AbstractFloat, anderson::AndersonAcceleratedProx)
    if first_iteration(anderson)
        # First iteration standard prox
        push!(anderson.y, copy(x))
        push!(anderson.y, x - γ*∇f)
        push!(anderson.g, copy(anderson.y[2]))
        push!(anderson.g, zero(x))
        prox!(x, ∇f, γ, anderson.prox)
        append!(anderson.x, copy(x))
        append!(anderson.grad_mapping, fill(Inf, length(x)))
        anderson.current = 2
        return nothing
    end
    anderson.g[anderson.current] .=  x - γ*∇f
    anderson.save_g = copy(anderson.g[anderson.current])
    _x = copy(x)
    prox!(_x, ∇f, γ, anderson.prox)
    anderson.grad_mapping = x-_x
    anderson.x .= _x
    # Anderson update
    anderson_update!(anderson)
    # Proximal update on y
    x .= anderson.y[anderson.current]
    prox!(x, ∇f, 0.0, anderson.prox)
    return nothing
end
