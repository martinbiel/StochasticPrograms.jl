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
