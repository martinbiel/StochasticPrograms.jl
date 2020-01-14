# AdaptivePenalization penalty
# ------------------------------------------------------------
@with_kw mutable struct AdaptiveData{T <: AbstractFloat}
    r::T = 1.0
end

@with_kw mutable struct AdaptiveParameters{T <: AbstractFloat}
    ζ::T = 0.1
    γ₁::T = 1e-5
    γ₂::T = 0.01
    γ₃::T = 0.25
    σ::T = 1e-5
    α::T = 0.95
    θ::T = 1.1
    ν::T = 0.1
    β::T = 1.1
    η::T = 1.25
end

struct AdaptivePenalization{T <: AbstractFloat} <: AbstractPenalization
    data::AdaptiveData{T}
    parameters::AdaptiveParameters{T}

    function AdaptivePenalization(r::AbstractFloat; kw...)
        T = typeof(r)
        return new{T}(AdaptiveData{T}(; r = r), AdaptiveParameters{T}(;kw...))
    end
end
function penalty(::AbstractProgressiveHedgingSolver, penalty::AdaptivePenalization)
    return penalty.data.r
end
function init_penalty!(ph::AbstractProgressiveHedgingSolver, penalty::AdaptivePenalization)
    update_dual_gap!(ph)
    @unpack δ₂ = ph.data
    @unpack ζ = penalty.parameters
    penalty.data.r = max(1., 2*ζ*abs(calculate_objective_value(ph)))/max(1., δ₂)
end
function update_penalty!(ph::AbstractProgressiveHedgingSolver, penalty::AdaptivePenalization)
    @unpack δ₁, δ₂ = ph.data
    @unpack r = penalty.data
    @unpack γ₁, γ₂, γ₃, σ, α, θ, ν, β, η = penalty.parameters

    δ₂_prev = length(ph.dual_gaps) > 0 ? ph.dual_gaps[end] : Inf

    μ = if δ₁/norm(ph.ξ,2)^2 >= γ₁
        if (δ₁-δ₂)/(1e-10 + δ₂) > γ₂
            α
        elseif (δ₂-δ₁)/(1e-10 + δ₁) > γ₃
            θ
        else
            1.
        end
    elseif δ₂ > δ₂_prev
        if (δ₂-δ₂_prev)/δ₂_prev > ν
            β
        else
            1.
        end
    else
        η
    end
    penalty.data.r = μ*r
end

# API
# ------------------------------------------------------------
"""
    Adaptive

...
# Parameters

...
"""
struct Adaptive{T <: AbstractFloat} <: AbstractPenalizer
    r::T
    parameters::Dict{Symbol,Any}

    function Adaptive(r::AbstractFloat; kw...)
        T = typeof(r)
        return new{T}(r, Dict{Symbol,Any}(kw))
    end
end
Adaptive(; kw...) = Adaptive(1.0; kw...)

function (adaptive::Adaptive)()
    return AdaptivePenalization(adaptive.r; adaptive.parameters...)
end

function str(::Adaptive)
    return "adaptive penalty"
end
