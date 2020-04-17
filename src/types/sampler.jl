"""
    AbstractSampler

Abstract supertype for sampler objects.
"""
abstract type AbstractSampler{S <: AbstractScenario} end
"""
    sample(sampler::AbstractSampler{S})

Sample a scenario of type `S` using `sampler`.
"""
function sample(sampler::AbstractSampler)
    return sampler()
end
function Base.show(io::IO, sampler::AbstractSampler{S}) where S <: AbstractScenario
    print(io, "$(S.name.name) sampler")
    return io
end
function Base.show(io::IO, sampler::AbstractSampler{S}) where S <: Scenario
    print(io, "Scenario sampler")
    return io
end
"""
    sample(sampler::AbstractSampler{S}, π::AbstractSampler)

Sample a scenario of type `S` using `sampler` and set the probability of the sampled scenario to `π`.
"""
function sample(sampler::AbstractSampler, π::AbstractFloat)
    scenario = sampler()
    set_probability!(scenario, π)
    return scenario
end
"""
    Sampler

General purpose sampler object that samples Scenario.

See also: [`Scenario`](@ref), [`@sampler`](@ref)
"""
struct Sampler <: AbstractSampler{Scenario}
    sampler::Function
end

function (sampler::Sampler)()
    return sampler.sampler()
end

function sample!(scenarios::Scenarios{S}, sampler::AbstractSampler{S}, n::Integer) where S <: AbstractScenario
    _sample!(scenarios, sampler, n, nscenarios(scenarioproblems), 1/n)
    return nothing
end
function sample!(scenarios::Scenarios{S}, sampler::AbstractSampler{Scenario}, n::Integer) where S <: AbstractScenario
    _sample!(scenarios, sampler, n, nscenarios(scenarioproblems), 1/n)
    return nothing
end

function _sample!(scenarios::Scenarios{S}, sampler::AbstractSampler{S}, n::Integer, m::Integer, π::AbstractFloat) where S <: AbstractScenario
    if m > 0
        # Rescale probabilities of existing scenarios
        for scenario in scenarios
            p = probability(scenario) * m / (m+n)
            set_probability!(scenario, p)
        end
        π *= n/(m+n)
    end
    for i = 1:n
        push!(scenarios, sample(sampler, π))
    end
    return nothing
end
