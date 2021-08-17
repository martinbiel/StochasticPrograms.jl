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

@with_kw mutable struct SAAData{T <: AbstractFloat}
    sample_size::Integer = 16
    interval::ConfidenceInterval{T} = ConfidenceInterval(-Inf, Inf, 1.0)
end

@with_kw mutable struct SAAParameters{T <: AbstractFloat}
    confidence::T = 0.95
    num_lower_trials::Integer = 10
    num_upper_trials::Integer = 10
    num_samples::Integer = 100
    num_eval_samples::Integer = 1000
    num_ews_samples::Integer = 1000
    num_eev_samples::Integer = 1000
    tolerance::T = 1e-2
    init_num_samples::Int = 16
    max_num_samples::Int = 5000
    optimize_config::Function = (optimizer, N) -> nothing
    time_limit::T = Inf
    log::Bool = true
    keep::Bool = false
    offset::Int = 5
    indent::Int = 4
end

"""
    SampleAverageApproximation

Functor object for the sample average approximation algorithm.
"""
mutable struct SampleAverageApproximation{T <: AbstractFloat, A <: AbstractVector, SM <: StochasticModel, S <: AbstractSampler}
    model::SM
    sampler::S
    optimizer
    x₀::A
    interval_history::Vector{ConfidenceInterval{T}}
    data::SAAData{T}
    parameters::SAAParameters{T}

    function SampleAverageApproximation(model::StochasticModel, sampler::AbstractSampler, x₀::AbstractVector; optimizer = nothing, kw...)
        T = eltype(x₀)
        A = typeof(x₀)
        SM = typeof(model)
        S = typeof(sampler)
        # Algorithm parameters
        params = SAAParameters{T}(; kw...)
        return new{T,A,SM,S}(model,
                             sampler,
                             optimizer,
                             x₀,
                             Vector{ConfidenceInterval{T}}(),
                             SAAData{T}(),
                             params)
    end
end

function (saa::SampleAverageApproximation)()
    @unpack log, tolerance, confidence = saa.parameters
    @unpack init_num_samples, max_num_samples = saa.parameters
    @unpack num_lower_trials, num_upper_trials, num_eval_samples = saa.parameters
    N = init_num_samples
    α = 1 - confidence
    progress = ProgressThresh(tolerance, 0.0, "SAA gap")
    log && ProgressMeter.update!(progress, Inf,
                                 showvalues = [
                                     ("Confidence interval", NaN),
                                     ("Relative error", Inf),
                                     ("Sample size", NaN),
                                 ])
    status = MOI.OPTIMIZE_NOT_CALLED
    while true
        saa.data.sample_size = N
        CI = confidence_interval(saa.model, saa.sampler)
        saa.data.interval = CI
        push!(saa.interval_history, CI)
        Q = (upper(CI) + lower(CI)) / 2
        gap = length(CI) / abs(Q + 1e-10)
        log && ProgressMeter.update!(progress, gap,
                                     showvalues = [
                                         ("Confidence interval", CI),
                                         ("Relative error", gap),
                                         ("Sample size", N)
                                     ])
        if gap <= tolerance
            status = MOI.OPTIMAL
            break
        end
        N = N * 2
        if N > max_num_samples
            status = MOI.ITERATION_LIMIT
            log && ProgressMeter.update!(progress, 0.0,
                                         showvalues = [
                                             ("Confidence interval", CI),
                                             ("Early termination", status),
                                             ("Sample size", N)
                                         ])
            break
        end
        #optimizer_config(optimizer(stochasticmodel), N)
    end
    # Move cursor down
    for _ in 1:saa.parameters.offset + 2
        print("\r\u1b[B")
    end
    # Return status
    return status
end

function instance(saa::SampleAverageApproximation)
    sp = instantiate(saa.model,
                     saa.sampler,
                     saa.data.sample_size;
                     optimizer = saa.optimizer)
    optimize!(sp)
    Q = objective_value(sp)
    while !(Q ∈ saa.data.interval)
        sp = instantiate(saa.model,
                         saa.sampler,
                         saa.data.sample_size;
                         optimizer = saa.optimizer)
        optimize!(sp)
        Q = objective_value(sp)
    end
    return sp
end
