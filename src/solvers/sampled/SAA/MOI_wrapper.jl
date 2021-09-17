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

mutable struct Optimizer <: AbstractSampledOptimizer
    instance_optimizer
    instance_crash::AbstractCrash
    optimizer_params::Dict{MOI.AbstractOptimizerAttribute, Any}
    parameters::SAAParameters{Float64}
    status::MOI.TerminationStatusCode
    algorithm::Union{SampleAverageApproximation, Nothing}

    function Optimizer(; optimizer = nothing,
                       crash::AbstractCrash = Crash.None(),
                       kw...)
        return new(optimizer,
                   crash,
                   Dict{MOI.AbstractOptimizerAttribute, Any}(),
                   SAAParameters{Float64}(; kw...),
                   MOI.OPTIMIZE_NOT_CALLED,
                   nothing)
    end
end

function load_model!(optimizer::Optimizer,
                     model::StochasticModel,
                     sampler::AbstractSampler,
                     x₀::AbstractVector)
    instance_optimizer = MOI.get(optimizer, InstanceOptimizer())
    # Default log settings
    try
        MOI.set(instance_optimizer, MOI.RawParameter("log"), optimizer.parameters.log)
        MOI.set(instance_optimizer, MOI.RawParameter("keep"), optimizer.parameters.keep)
        MOI.set(instance_optimizer, MOI.RawParameter("offset"), optimizer.parameters.offset + 1)
        MOI.set(instance_optimizer, MOI.RawParameter("indent"), 2 * optimizer.parameters.indent)
    catch
    end
    # Create new SAA algorithm
    optimizer.algorithm = SampleAverageApproximation(model,
                                                     sampler,
                                                     x₀;
                                                     optimizer = instance_optimizer,
                                                     type2dict(optimizer.parameters)...)
    return nothing
end

function MOI.optimize!(optimizer::Optimizer)
    if optimizer.algorithm === nothing
        error("SAA algorithm has not been loaded properly")
    end
    optimizer.status = optimizer.algorithm()
    return nothing
end

function optimizer_name(optimizer::Optimizer)
    return "Sample average approximation"
end

function optimal_instance(optimizer::Optimizer)
    if optimizer.algorithm === nothing
        error("SAA algorithm has not been loaded properly")
    end
    return instance(optimizer.algorithm)
end

# MOI #
# ========================== #
function MOI.get(optimizer::Optimizer, ::MOI.Silent)
    return !MOI.get(optimizer, MOI.RawParameter("log"))
end

function MOI.set(optimizer::Optimizer, attr::MOI.Silent, flag::Bool)
    MOI.set(optimizer, MOI.RawParameter("log"), !flag)
    optimizer.optimizer_params[attr] = flag
    return nothing
end

function MOI.get(optimizer::Optimizer, param::MOI.RawParameter)
    name = Symbol(param.name)
    if !(name in fieldnames(SAAParameters))
        error("Unrecognized parameter name: $(name).")
    end
    return getfield(optimizer.parameters, name)
end

function MOI.set(optimizer::Optimizer, param::MOI.RawParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(SAAParameters))
        error("Unrecognized parameter name: $(name).")
    end
    setfield!(optimizer.parameters, name, value)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::RelativeTolerance)
    return MOI.get(optimizer, MOI.RawParameter("tolerance"))
end

function MOI.set(optimizer::Optimizer, ::RelativeTolerance, limit::Real)
    MOI.set(optimizer, MOI.RawParameter("tolerance"), limit)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::Confidence)
    return MOI.get(optimizer, MOI.RawParameter("confidence"))
end

function MOI.set(optimizer::Optimizer, ::Confidence, confidence::Real)
    MOI.set(optimizer, MOI.RawParameter("confidence"), confidence)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::NumSamples)
    if optimizer.algorithm != nothing
        return optimizer.algorithm.data.sample_size
    end
    return MOI.get(optimizer, MOI.RawParameter("num_samples"))
end

function MOI.set(optimizer::Optimizer, ::NumSamples, num_samples::Integer)
    MOI.set(optimizer, MOI.RawParameter("num_samples"), num_samples)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::NumEvalSamples)
    return MOI.get(optimizer, MOI.RawParameter("num_eval_samples"))
end

function MOI.set(optimizer::Optimizer, ::NumEvalSamples, num_eval_samples::Integer)
    MOI.set(optimizer, MOI.RawParameter("num_eval_samples"), num_eval_samples)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::NumEWSSamples)
    return MOI.get(optimizer, MOI.RawParameter("num_ews_samples"))
end

function MOI.set(optimizer::Optimizer, ::NumEWSSamples, num_ews_samples::Integer)
    MOI.set(optimizer, MOI.RawParameter("num_ews_samples"), num_ews_samples)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::NumEEVSamples)
    return MOI.get(optimizer, MOI.RawParameter("num_eev_samples"))
end

function MOI.set(optimizer::Optimizer, ::NumEEVSamples, num_eev_samples::Integer)
    MOI.set(optimizer, MOI.RawParameter("num_eev_samples"), num_eev_samples)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::NumLowerTrials)
    return MOI.get(optimizer, MOI.RawParameter("num_lower_trials"))
end

function MOI.set(optimizer::Optimizer, ::NumLowerTrials, num_lower_trials::Integer)
    MOI.set(optimizer, MOI.RawParameter("num_lower_trials"), num_lower_trials)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::NumUpperTrials)
    return MOI.get(optimizer, MOI.RawParameter("num_upper_trials"))
end

function MOI.set(optimizer::Optimizer, ::NumUpperTrials, num_upper_trials::Integer)
    MOI.set(optimizer, MOI.RawParameter("num_upper_trials"), num_upper_trials)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::InstanceOptimizer)
    if optimizer.instance_optimizer === nothing
        error("Instance optimizer not set. Consider setting `InstanceOptimizer` attribute.")
    end
    return MOI.OptimizerWithAttributes(optimizer.instance_optimizer, collect(optimizer.optimizer_params))
end

function MOI.set(optimizer::Optimizer, ::InstanceOptimizer, optimizer_constructor)
    optimizer.instance_optimizer = optimizer_constructor
    return nothing
end

function MOI.get(optimizer::Optimizer, ::InstanceCrash)
    return optimizer.instance_crash
end

function MOI.set(optimizer::Optimizer, ::InstanceCrash, crash::AbstractCrash)
    optimizer.instance_crash = crash
    return nothing
end

function MOI.get(optimizer::Optimizer, ::InstanceOptimizerAttribute, attr::MOI.AbstractOptimizerAttribute)
    if !haskey(optimizer.optimizer_params, attr)
        error("Instance optimizer attribute $(typeof(attr)) has not been set.")
    end
    return optimizer.optimizer_params[attr]
end

function MOI.set(optimizer::Optimizer, ::InstanceOptimizerAttribute, attr::MOI.AbstractOptimizerAttribute, value)
    optimizer.optimizer_params[attr] = value
    return nothing
end

function MOI.get(optimizer::Optimizer, param::RawInstanceOptimizerParameter)
    moi_param = MOI.RawParameter(param.name)
    if !haskey(optimizer.optimizer_params, moi_param)
        error("Instance optimizer attribute $(param.name) has not been set.")
    end
    return optimizer.optimizer_params[moi_param]
end

function MOI.set(optimizer::Optimizer, param::RawInstanceOptimizerParameter, value)
    # Only set parameter if instance optimizer supports it
    if !MOI.supports(MOI.get(optimizer, InstanceOptimizer())(), param)
        return nothing
    end
    moi_param = MOI.RawParameter(param.name)
    optimizer.optimizer_params[moi_param] = value
    return nothing
end

function MOI.get(optimizer::Optimizer, ::MOI.TerminationStatus)
    return optimizer.status
end

function MOI.get(optimizer::Optimizer, ::MOI.VariablePrimal, index::MOI.VariableIndex)
    if optimizer.algorithm === nothing
        error("SAA algorithm has not been loaded properly")
    end
    return decision(optimizer.algorithm, index)
end

function MOI.get(optimizer::Optimizer, ::MOI.ObjectiveValue)
    if optimizer.algorithm === nothing
        error("SAA algorithm has not been loaded properly")
    end
    return optimizer.algorithm.data.interval
end

function MOI.is_empty(optimizer::Optimizer)
    return optimizer.algorithm === nothing
end

MOI.supports(::Optimizer, ::MOI.Silent) = true
MOI.supports(::Optimizer, ::MOI.RawParameter) = true
MOI.supports(::Optimizer, ::AbstractSampledOptimizerAttribute) = true
