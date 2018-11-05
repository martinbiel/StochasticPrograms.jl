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
"""
    sample(sampler::AbstractSampler{S}, π::AbstractSampler)

Sample a scenario of type `S` using `sampler` and set the probability of the sampled scenario to `π`.
"""
function sample(sampler::AbstractSampler, π::AbstractFloat)
    scenario = sampler()
    set_probability!(scenario, π)
    return scenario
end

struct NullSampler{S <: AbstractScenario} <: AbstractSampler{S} end
