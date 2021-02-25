@with_kw mutable struct ADAMParameters{T <: AbstractFloat}
    μ::T = 0.9
    ϵ::T = 1e-3
    ρ::T = 0.9
end

struct ADAMBoosting{T <: AbstractFloat} <: AbstractGradientBoosting
    parameters::ADAMParameters{T}
    ν::Vector{T}
    grms::Vector{T}

    function ADAMBoosting(::Type{T}; kw...) where T <: AbstractFloat
        return new{T}(ADAMParameters{T}(; kw...), Vector{T}(), Vector{T}())
    end
end

function boost!(adam::ADAMBoosting, k::Integer, x::AbstractVector, ∇f::AbstractVector)
    if k == 1
        resize!(adam.ν, length(x))
        resize!(adam.grms, length(x))
        adam.ν .= zero(x)
        adam.grms .= zero(x)
    end
    @unpack μ, ϵ, ρ = adam.parameters
    ν = adam.ν
    grms = adam.grms
    ν .= μ * ν + ϵ * ∇f
    grms .= ρ * grms + (1-ρ) * (∇f .* ∇f)
    ∇f .= ∇f ./ (.√grms .+ eps())
    return nothing
end

# API
# ------------------------------------------------------------
struct ADAM <: AbstractBoosting
    parameters::ADAMParameters{Float64}
end
ADAM(; kw...) = ADAM(ADAMParameters(; kw...))

function (adam::ADAM)(::Type{T}) where T <: AbstractFloat
    return ADAMBoosting(T; type2dict(adam.parameters)...)
end

function str(::ADAM)
    return "ADAM boosting"
end
