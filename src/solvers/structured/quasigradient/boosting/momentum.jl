@with_kw mutable struct MomentumParameters{T <: AbstractFloat}
    μ::T = 0.9
    ϵ::T = 1e-3
end

struct ClassicMomentum{T <: AbstractFloat} <: AbstractGradientBoosting
    parameters::MomentumParameters{T}
    ν::Vector{Float64}

    function ClassicMomentum(::Type{T}; kw...) where T <: AbstractFloat
        return new{T}(MomentumParameters{T}(; kw...), Vector{Float64}())
    end
end

function boost!(momentum::ClassicMomentum, k::Integer, x::AbstractVector, ∇f::AbstractVector)
    if k == 1
        resize!(momentum.ν, length(x))
        momentum.ν .= zero(x)
    end
    @unpack μ, ϵ = momentum.parameters
    ν = momentum.ν
    ν .= μ * ν + ϵ * ∇f
    ∇f .= ν
    return nothing
end

struct NesterovMomentum{T <: AbstractFloat} <: AbstractGradientBoosting
    parameters::MomentumParameters{T}
    ν::Vector{Float64}

    function NesterovMomentum(::Type{T}; kw...) where T <: AbstractFloat
        return new{T}(MomentumParameters{T}(; kw...), Vector{Float64}())
    end
end

function boost!(momentum::NesterovMomentum, k::Integer, x::AbstractVector, ∇f::AbstractVector)
    if k == 1
        resize!(momentum.ν, length(x))
        momentum.ν .= zero(x)
    end
    @unpack μ, ϵ = momentum.parameters
    ν = momentum.ν
    ν_prev = copy(ν)
    ν .= μ * ν_prev + ϵ * ∇f
    ∇f .= μ^2 * ν_prev + (1 + μ) * ϵ * ∇f
    return nothing
end

# API
# ------------------------------------------------------------
struct Momentum <: AbstractBoosting
    parameters::MomentumParameters{Float64}
end
Momentum(; kw...) = Momentum(MomentumParameters(; kw...))

function (momentum::Momentum)(::Type{T}) where T <: AbstractFloat
    return ClassicMomentum(T; type2dict(momentum.parameters)...)
end

function str(::Momentum)
    return "Momentum boosting"
end

struct Nesterov <: AbstractBoosting
    parameters::MomentumParameters{Float64}
end
Nesterov(; kw...) = Nesterov(MomentumParameters(; kw...))

function (momentum::Nesterov)(::Type{T}) where T <: AbstractFloat
    return NesterovMomentum(T; type2dict(momentum.parameters)...)
end

function str(::Nesterov)
    return "Nesterov boosting"
end
