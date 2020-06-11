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

    (::Type{ExpectedScenario})(scenario::AbstractScenario) = new{typeof(scenario)}(scenario)
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
function expected(::Vector{S}) where S <: AbstractScenario
    error("Expectation not implemented for scenario type: ", S)
end
"""
    Scenario

Conveniece type that adheres to the [`AbstractScenario`](@ref) abstraction. Useful when uncertain parameters are a finite set of scalar values.
"""
struct Scenario{NT <: NamedTuple} <: AbstractScenario
    probability::Probability
    data::NT

    function Scenario(data::NT; probability::AbstractFloat = 1.0) where NT <: NamedTuple
        return new{NT}(Probability(probability), data)
    end

    function Scenario(; probability::AbstractFloat = 1.0, kw...)
        data = values(kw)
        NT = typeof(data)
        return new{NT}(Probability(probability), data)
    end
end
function Base.getindex(ξ::Scenario, field::Symbol)
    return getproperty(ξ.data, field)
end
function Base.zero(::Type{Scenario{NT}}) where NT <: NamedTuple
    return Scenario(NamedTuple{Tuple(NT.names)}(zero.(NT.types)); probability = 1.0)
end
function scenariotext(io::IO, scenario::Scenario)
    for (k,v) in pairs(scenario.data)
        print(io, "\n  $k: $v")
    end
    return io
end

Scenarios{S <: AbstractScenario} = Vector{S}
ScenarioTypes{N} = NTuple{N, Union{DataType, UnionAll}}

function expected(scenarios::Vector{<:Scenario{NT}}) where NT <: NamedTuple
    isempty(scenarios) && return StochasticPrograms.ExpectedScenario(zero(Scenario{NT}))
    expected = reduce(scenarios) do s₁, s₂
        keys(s₁.data) == keys(s₂.data) || error("Iconsistent scenarios. $(keys(s₁)) and $(keys(s₂)) do not match.")
        Scenario(NamedTuple{Tuple(keys(s₁.data))}([probability(s₁)*x + probability(s₂)*y for (x,y) in zip(values(s₁.data), values(s₂.data))]); probability = 1.0)
    end
    return StochasticPrograms.ExpectedScenario(expected)
end
