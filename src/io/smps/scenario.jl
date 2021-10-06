# MIT License
#
# Copyright (c) 2018 Martin Biel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

"""
    SMPSScenario

Conveniece type that adheres to the [`AbstractScenario`](@ref) abstraction. Obtained when reading scenarios specified in SMPS format.

See also: [`SMPSSampler`](@ref)
"""
struct SMPSScenario{T <: AbstractFloat, A <: AbstractArray{T,1}, M <: AbstractArray{T,2}} <: AbstractScenario
    probability::Probability
    Δq::A
    ΔT::M
    ΔW::M
    Δh::A
    ΔC::M
    Δd₁::A
    Δd₂::A

    function SMPSScenario(π::Probability, Δq::A, ΔT::M, ΔW::M, Δh::A, ΔC::M, Δd₁::A, Δd₂::A) where {T <: AbstractFloat, A <: AbstractArray{T,1}, M <: AbstractArray{T,2}}
        return new{T,A,M}(π, Δq, ΔT, ΔW, Δh, ΔC, Δd₁, Δd₂)
    end

    function SMPSScenario(π::Probability, Δq::AbstractVector, ΔT::AbstractMatrix, ΔW::AbstractMatrix, Δh::AbstractVector, ΔC::AbstractMatrix, Δd₁::AbstractVector, Δd₂::AbstractVector)
        T = promote_type(eltype(Δq), eltype(ΔT), eltype(ΔW), eltype(Δh), eltype(ΔC), eltype(Δd₁), eltype(Δd₂), Float32)
        return new{T,Vector{T},Matrix{T}}(π,
                                          convert(Vector{T}, Δq),
                                          convert(Matrix{T}, ΔT),
                                          convert(Matrix{T}, ΔW),
                                          convert(Vector{T}, Δh),
                                          convert(Matrix{T}, ΔC),
                                          convert(Vector{T}, Δd₁),
                                          convert(Vector{T}, Δd₂))
    end
end

function StochasticPrograms.expected(ξ₁::SMPSScenario{T}, ξ₂::SMPSScenario{T}) where T <: AbstractFloat
    expected = SMPSScenario(Probability(1.0),
                            probability(ξ₁) * ξ₁.Δq + probability(ξ₂) * ξ₂.Δq,
                            probability(ξ₁) * ξ₁.ΔT + probability(ξ₂) * ξ₂.ΔT,
                            probability(ξ₁) * ξ₁.ΔW + probability(ξ₂) * ξ₂.ΔW,
                            probability(ξ₁) * ξ₁.Δh + probability(ξ₂) * ξ₂.Δh,
                            probability(ξ₁) * ξ₁.ΔC + probability(ξ₂) * ξ₂.ΔC,
                            probability(ξ₁) * ξ₁.Δd₁ + probability(ξ₂) * ξ₂.Δd₁,
                            probability(ξ₁) * ξ₁.Δd₂ + probability(ξ₂) * ξ₂.Δd₂)
    return StochasticPrograms.ExpectedScenario(expected)
end

function StochasticPrograms.scenariotext(io::IO, scenario::SMPSScenario)
    print(io, " and underlying data:\n\n")
    println(io, "Δq = $(scenario.Δq)")
    println(io, "ΔT = $(scenario.ΔT)")
    println(io, "ΔW = $(scenario.ΔW)")
    println(io, "Δh = $(scenario.Δh)")
    println(io, "ΔC = $(scenario.ΔC)")
    println(io, "Δd₁ = $(scenario.Δd₁)")
    print(io, "Δd₂ = $(scenario.Δd₂)")
    return io
end
