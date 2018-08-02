mutable struct Probability <: AbstractFloat
    π::Float64
end
Base.convert(::Type{Probability},π::Float64) = Probability(π)
Base.convert(::Type{Float64},π::Probability) = π.π
Base.promote_rule(::Type{T},::Type{Probability}) where T <: AbstractFloat = Float64
