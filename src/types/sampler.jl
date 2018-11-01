abstract type AbstractSampler{SD <: AbstractScenario} end

function sample(sampler::AbstractSampler)
    return sampler()
end
function sample(sampler::AbstractSampler, π::AbstractFloat)
    scenario = sampler()
    set_probability!(scenario,π)
    return scenario
end

struct NullSampler{SD <: AbstractScenario} <: AbstractSampler{SD} end
