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
    AbstractScenario

Abstract supertype for scenario objects.
"""
abstract type AbstractScenario end
"""
    Probability

A type-safe wrapper for `Float64` used to represent probability of a scenario occuring.
"""
mutable struct Probability
    π::Float64
end
"""
    probability(scenario::AbstractScenario)

Return the probability of `scenario` occuring.

Is always defined for scenarios created through @scenario. Other user defined scenario types must implement this method to generate a proper probability. The default behaviour is to assume that `scenario` has a `probability` field of type [`Probability`](@ref)

See also: [`Probability`](@ref)
"""
probability(scenario::AbstractScenario)::Float64 = scenario.probability.π
"""
    probability(scenarios::Vector{<:AbstractScenario})

Return the probability of that any scenario in the collection `scenarios` occurs.
"""
probability(scenarios::Vector{<:AbstractScenario}) = sum(probability.(scenarios))
"""
    set_probability!(scenario::AbstractScenario, probability::AbstractFloat)

Set the probability of `scenario` occuring.

Is always defined for scenarios created through @scenario. Other user defined scenario types must implement this method.
"""
function set_probability!(scenario::AbstractScenario, π::AbstractFloat)
    scenario.probability.π = π
end
function Base.zero(::Type{S}) where S <: AbstractScenario
    error("zero not implemented for scenario type: ", S)
end
function Base.show(io::IO, scenario::S) where S <: AbstractScenario
    print(io, "$(S.name.name) with probability $(probability(scenario))")
    scenariotext(io, scenario)
    return io
end
"""
    scenariotext(io::IO, scenario::AbstractScenario)

Custom printout called when printing `scenario`.
"""
function scenariotext(io::IO, scenario::AbstractScenario)
    return io
end
function Base.getindex(ξ::AbstractScenario, field::Symbol)
    return getfield(ξ, field)
end
"""
    ExpectedScenario{S <: AbstractScenario}

Wrapper type around an `AbstractScenario`. Should for convenience be used as the result of a call to `expected`.

See also [`expected`](@ref)
"""
struct ExpectedScenario{S <: AbstractScenario} <: AbstractScenario
    scenario::S

    function ExpectedScenario(scenario::AbstractScenario)
        return new{typeof(scenario)}(scenario)
    end
end
function Base.show(io::IO, scenario::ExpectedScenario{S}) where S <: AbstractScenario
    print(io, "Expected scenario of type $(S.name.name)")
    scenariotext(io, scenario.scenario)
    return io
end
"""
    expected(scenarios::Vector{<:AbstractScenario})

Return the expected scenario out of the collection `scenarios` in an [`ExpectedScenario`](@ref) wrapper.

This is defined through classical expectation: sum([probability(s)*s for s in scenarios]), and is always defined for scenarios created through @scenario, if the requested fields support it.

Otherwise, user-defined scenario types must implement this method for full functionality.

See also [`ExpectedScenario`](@ref)
"""
function expected(scenarios::Vector{S}) where S <: AbstractScenario
    isempty(scenarios) && return ExpectedScenario(zero(S))
    return reduce(expected, scenarios; init = ExpectedScenario(zero(S)))
end
function expected(ξ₁::ExpectedScenario{S}, ξ₂::S) where S <: AbstractScenario
    set_probability!(ξ₁.scenario, 1.0)
    return expected(ξ₁.scenario, ξ₂)
end
function expected(ξ₁::S, ξ₂::ExpectedScenario{S}) where S <: AbstractScenario
    set_probability!(ξ₂.scenario, 1.0)
    return expected(ξ₁, ξ₂.scenario)
end
function expected(ξ₁::ExpectedScenario{S}, ξ₂::ExpectedScenario{S}) where S <: AbstractScenario
    set_probability!(ξ₁.scenario, 1.0)
    set_probability!(ξ₂.scenario, 1.0)
    return expected(ξ₁.scenario, ξ₂.scenario)
end

"""
    Scenario

Conveniece type that adheres to the [`AbstractScenario`](@ref) abstraction. Useful when uncertain parameters are defined using [`@uncertain`](@ref) and instances are created using [`@scenario`](@ref).
"""
struct Scenario{T} <: AbstractScenario
    probability::Probability
    data::T

    function Scenario(data::T; probability::AbstractFloat = 1.0) where T
        return new{T}(Probability(probability), data)
    end

    function Scenario(; probability::AbstractFloat = 1.0, kw...)
        data = values(kw)
        NT = typeof(data)
        return new{NT}(Probability(probability), data)
    end
end

function Base.zero(::Type{Scenario{NT}}) where NT <: NamedTuple
    return Scenario(NamedTuple{Tuple(fieldnames(NT))}(zero.(NT.types)); probability = 1.0)
end
function Base.zero(::Type{Scenario{D}}) where {T, N, D <: Array{T,N}}
    return Scenario(Array{T,N}(undef, ntuple(Val{N}()) do i 0 end); probability = 1.0)
end
function Base.zero(::Type{Scenario{D}}) where {T, N, Ax <: NTuple, D <: DenseAxisArray{T,N,Ax}}
    axs = ntuple(Val{N}()) do i Ax.types[i]() end
    return Scenario(DenseAxisArray(Array{T,N}(undef, ntuple(Val{N}()) do i 0 end), axs...); probability = 1.0)
end
function Base.zero(::Type{Scenario{D}}) where {T, N, K, D <: SparseAxisArray{T,N,K}}
    return Scenario(Dict{K,T}(); probability = 1.0)
end
function scenariotext(io::IO, scenario::Scenario{NT}) where NT <: NamedTuple
    for (k,v) in pairs(scenario.data)
        print(io, "\n  $k: $v")
    end
    return io
end
function scenariotext(io::IO, scenario::Scenario)
    print(io, " and underlying data:\n\n")
    print(io, scenario.data)
    return io
end

Scenarios{S <: AbstractScenario} = Vector{S}
ScenarioTypes{N} = NTuple{N, Union{DataType, UnionAll}}

function expected(ξ₁::Scenario{NT}, ξ₂::Scenario{NT}) where NT <: NamedTuple
    keys(ξ₁.data) == keys(ξ₂.data) || error("Inconsistent scenarios. $(keys(ξ₁)) and $(keys(ξ₂)) do not match.")
    data = map(zip(values(ξ₁.data), values(ξ₂.data))) do (x, y)
        probability(ξ₁) * x + probability(ξ₂) * y
    end
    expected = Scenario(NamedTuple{Tuple(keys(ξ₁.data))}(data))
    return ExpectedScenario(expected)
end

function expected(ξ₁::Scenario{D}, ξ₂::Scenario{D}) where D <: Array
    if isempty(ξ₁.data)
        weighted = Scenario(probability(ξ₂) * ξ₂.data)
        return ExpectedScenario(weighted)
    end
    if isempty(ξ₂.data)
        weighted = Scenario(probability(ξ₁) * ξ₁.data)
        return ExpectedScenario(weighted)
    end
    size(ξ₁.data) == size(ξ₂.data) || error("Inconsistent scenarios. $(size(ξ₁.data)) and $(size(ξ₂.data)) do not match.")
    expected = Scenario(probability(ξ₁) * ξ₁.data + probability(ξ₂) * ξ₂.data)
    return ExpectedScenario(expected)
end

function expected(ξ₁::Scenario{D}, ξ₂::Scenario{D}) where D <: DenseAxisArray
    if isempty(ξ₁.data.data)
        weighted = Scenario(DenseAxisArray(probability(ξ₂) * ξ₂.data.data, axes(ξ₂.data)...))
        return ExpectedScenario(weighted)
    end
    if isempty(ξ₂.data.data)
        weighted = Scenario(DenseAxisArray(probability(ξ₁) * ξ₁.data.data, axes(ξ₁.data)...))
        return ExpectedScenario(weighted)
    end
    axes(ξ₁.data) == axes(ξ₂.data) || error("Inconsistent scenarios. $(axes(ξ₁.data)) and $(axes(ξ₂.data)) do not match.")
    size(ξ₁.data) == size(ξ₂.data) || error("Inconsistent scenarios. $(size(ξ₁.data)) and $(size(ξ₂.data)) do not match.")
    data = DenseAxisArray(probability(ξ₁) * ξ₁.data.data + probability(ξ₂) * ξ₂.data.data, axes(ξ₁.data)...)
    expected = Scenario(data)
    return ExpectedScenario(expected)
end

function expected(ξ₁::Scenario{D}, ξ₂::Scenario{D}) where D <: SparseAxisArray
    if isempty(ξ₁.data.data)
        weighted = Scenario(Dict([key => probability(ξ₂) * ξ₂.data.data[key] for key in keys(ξ₂.data.data)]))
        return ExpectedScenario(weighted)
    end
    if isempty(ξ₂.data.data)
        weighted = Scenario(Dict([key => probability(ξ₁) * ξ₁.data.data[key] for key in keys(ξ₁.data.data)]))
        return ExpectedScenario(weighted)
    end
    keys(ξ₁.data.data) == keys(ξ₂.data.data) || error("Inconsistent scenarios. $(keys(ξ₁.data.data)) and $(keys(ξ₂.data.data)) do not match.")
    expected = Scenario(Dict([key => probability(ξ₁) * ξ₁.data.data[key] + probability(ξ₂) * ξ₂.data.data[key] for key in keys(ξ₁.data.data)]))
    return ExpectedScenario(expected)
end
