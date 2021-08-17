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

See also: [`Scenario`](@ref), [`@scenario`](@ref), [`@sampler`](@ref)
"""
struct Sampler <: AbstractSampler{Scenario}
    sampler::Function
end

function (sampler::Sampler)()
    return sampler.sampler()
end

function sample!(scenarios::Scenarios{S}, sampler::AbstractSampler{S}, n::Integer) where S <: AbstractScenario
    _sample!(scenarios, sampler, n, length(scenarios), 1/n)
    return nothing
end
function sample!(scenarios::Scenarios{S}, sampler::AbstractSampler{Scenario}, n::Integer) where S <: Scenario
    _sample!(scenarios, sampler, n, length(scenarios), 1/n)
    return nothing
end

function _sample!(scenarios::Scenarios, sampler::AbstractSampler, n::Integer, m::Integer, π::AbstractFloat)
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
