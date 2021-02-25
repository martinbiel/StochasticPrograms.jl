struct NoBoosting <: AbstractGradientBoosting end

function boost!(::NoBoosting, k::Integer, x::AbstractVector, ∇f::AbstractVector)
    return nothing
end

# API
# ------------------------------------------------------------
struct DontBoost <: AbstractBoosting end

function (::DontBoost)(::Type{T}) where T <: AbstractFloat
    return NoBoosting()
end

function str(::DontBoost)
    return ""
end
