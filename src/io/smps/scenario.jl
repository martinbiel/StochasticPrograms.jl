struct SMPSScenario{T <: AbstractFloat, M <: AbstractMatrix} <: AbstractScenario
    probability::Probability
    Δq::Vector{T}
    ΔT::M
    ΔW::M
    Δh::Vector{T}
    ΔC::M
    Δd₁::Vector{T}
    Δd₂::Vector{T}
end

function Base.zero(::Type{SMPSScenario{T}}) where T <: AbstractFloat
    return SMPSScenario(Probability(1.0),
                        AdditiveZeroArray{T,1}(),
                        AdditiveZeroArray{T,2}(),
                        AdditiveZeroArray{T,2}(),
                        AdditiveZeroArray{T,1}(),
                        AdditiveZeroArray{T,2}(),
                        AdditiveZeroArray{T,1}(),
                        AdditiveZeroArray{T,1}())
end

function StochasticPrograms.expected(scenarios::Vector{<:SMPSScenario{T}}) where T <: AbstractFloat
    isempty(scenarios) && return zero(SMPSScenario{T})
    expected = reduce(scenarios) do ξ₁, ξ₂
        SMPSScenario(Probability(1.0),
                     probability(ξ₁) * ξ₁.Δq + probability(ξ₁) * ξ₂.Δq,
                     probability(ξ₁) * ξ₁.ΔT + probability(ξ₁) * ξ₂.ΔT,
                     probability(ξ₁) * ξ₁.ΔW + probability(ξ₁) * ξ₂.ΔW,
                     probability(ξ₁) * ξ₁.Δh + probability(ξ₁) * ξ₂.Δh,
                     probability(ξ₁) * ξ₁.ΔC + probability(ξ₁) * ξ₂.ΔC,
                     probability(ξ₁) * ξ₁.Δd₁ + probability(ξ₁) * ξ₂.Δd₁,
                     probability(ξ₁) * ξ₁.Δd₂ + probability(ξ₁) * ξ₂.Δd₂)
    end
    return StochasticPrograms.ExpectedScenario(expected)
end
