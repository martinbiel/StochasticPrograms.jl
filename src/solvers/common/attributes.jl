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

# Structured optimizer attributes #
# ========================== #
"""
    RelativeTolerance

An optimizer attribute for specifying the relative tolerance of a structure-exploiting algorithm.
"""
struct RelativeTolerance <: AbstractStructuredOptimizerAttribute end
"""
    MasterOptimizer

An optimizer attribute for specifying the MathOptInterface optimizer used to solve master problems arising in a structure-exploiting procedure.
"""
struct MasterOptimizer <: AbstractStructuredOptimizerAttribute end

function JuMP.set_optimizer_attribute(stochasticprogram::StochasticProgram, attr::MasterOptimizer, value)
    MOI.set(stochasticprogram, attr, value)
    set_master_optimizer!(structure(stochasticprogram), value)
end
"""
    MasterOptimizerAttribute

An optimizer attribute used for setting attributes of the master optimizer.
"""
struct MasterOptimizerAttribute <: AbstractStructuredOptimizerAttribute end
"""
    RawMasterOptimizerParameter

An optimizer attribute used for raw parameters of the master optimizer. Defers to `RawParameter`.
"""
struct RawMasterOptimizerParameter <: AbstractStructuredOptimizerAttribute
    name::Any
end

function MOI.set(sp::StochasticProgram, attr::MasterOptimizerAttribute, master_attr::MOI.AbstractOptimizerAttribute, value)
    MOI.set(optimizer(sp), attr, master_attr, value)
    return nothing
end

function JuMP.set_optimizer_attribute(stochasticprogram::StochasticProgram, attr::MasterOptimizerAttribute, master_attr::MOI.AbstractOptimizerAttribute, value)
    MOI.set(stochasticprogram, attr, master_attr, value)
    set_master_optimizer_attribute!(structure(stochasticprogram), master_attr, value)
end

function JuMP.set_optimizer_attribute(stochasticprogram::StochasticProgram, param::RawMasterOptimizerParameter, value)
    MOI.set(stochasticprogram, param, value)
    set_master_optimizer_attribute!(structure(stochasticprogram), MOI.RawParameter(param.name), value)
end
"""
    get_masteroptimizer_attribute(stochasticprogram::StochasticProgram, name::String)

Return the value associated with the solver-specific attribute named `name` of the master optimizer in `stochasticprogram`.

See also: [`set_masteroptimizer_attribute`](@ref), [`set_masteroptimizer_attributes`](@ref).
"""
function get_masteroptimizer_attribute(stochasticprogram::StochasticProgram, name::String)
    return get_masteroptimizer_attribute(stochasticprogram, RawMasterOptimizerParameter(name))
end
"""
    get_masteroptimizer_attribute(stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute)

Return the value of the solver-specific attribute `attr` of the master optimizer in `stochasticprogram`.

See also: [`set_masteroptimizer_attribute`](@ref), [`set_masteroptimizer_attributes`](@ref).
"""
function get_masteroptimizer_attribute(stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute)
    return MOI.get(optimizer(stochasticprogram), MasterOptimizerAttribute(), attr)
end
"""
    set_masteroptimizer_attribute(stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute, value)

Sets solver-specific attribute `attr` of the master optimizer to `value`.

"""
function set_masteroptimizer_attribute(stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute, value)
    return set_optimizer_attribute(stochasticprogram, MasterOptimizerAttribute(), attr, value)
end
"""
    set_masteroptimizer_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)

Sets solver-specific attribute of the master optimizer identified by `name` to `value`.

"""
function set_masteroptimizer_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawMasterOptimizerParameter(String(name)), value)
end
"""
    set_masteroptimizer_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)

Given a list of `attribute => value` pairs or a collection of keyword arguments, calls
`set_masteroptimizer_attribute(stochasticprogram, attribute, value)` for each pair.

"""
function set_masteroptimizer_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_masteroptimizer_attribute(stochasticprogram, name, value)
    end
end
function set_masteroptimizer_attributes(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_masteroptimizer_attribute(stochasticprogram, name, value)
    end
end
"""
    SubProblemOptimizer

An optimizer attribute for specifying the MathOptInterface optimizer used to solve subproblems arising in a structure-exploiting procedure.
"""
struct SubProblemOptimizer <: AbstractStructuredOptimizerAttribute end

function JuMP.set_optimizer_attribute(stochasticprogram::StochasticProgram, attr::SubProblemOptimizer, value)
    MOI.set(stochasticprogram, attr, value)
    set_subproblem_optimizer!(structure(stochasticprogram), value)
end

struct SubProblemOptimizerAttribute <: AbstractStructuredOptimizerAttribute end
"""
    RawSubProblemOptimizerParameter

An optimizer attribute used for raw parameters of the subproblem optimizer. Defers to `RawParameter`.
"""
struct RawSubProblemOptimizerParameter <: AbstractStructuredOptimizerAttribute
    name::Any
end

function MOI.set(sp::StochasticProgram, attr::SubProblemOptimizerAttribute, sub_attr::MOI.AbstractOptimizerAttribute, value)
    MOI.set(optimizer(sp), attr, sub_attr, value)
    return nothing
end

function JuMP.set_optimizer_attribute(stochasticprogram::StochasticProgram, attr::SubProblemOptimizerAttribute, sub_attr::MOI.AbstractOptimizerAttribute, value)
    MOI.set(stochasticprogram, attr, sub_attr, value)
    set_subproblem_optimizer_attribute!(structure(stochasticprogram), sub_attr, value)
end

function JuMP.set_optimizer_attribute(stochasticprogram::StochasticProgram, param::RawSubProblemOptimizerParameter, value)
    MOI.set(stochasticprogram, param, value)
    set_subproblem_optimizer_attribute!(structure(stochasticprogram), MOI.RawParameter(param.name), value)
end
"""
    get_suboptimizer_attribute(stochasticprogram::StochasticProgram, name::String)

Return the value associated with the solver-specific attribute named `name` of the subproblem optimizer in `stochasticprogram`.

See also: [`set_suboptimizer_attribute`](@ref), [`set_suboptimizer_attributes`](@ref).
"""
function get_suboptimizer_attribute(stochasticprogram::StochasticProgram, name::String)
    return get_suboptimizer_attribute(stochasticprogram, RawSubProblemOptimizerParameter(name))
end
"""
    get_suboptimizer_attribute(stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute)

Return the value of the solver-specific attribute `attr` of the subproblem optimizer in `stochasticprogram`.

See also: [`set_suboptimizer_attribute`](@ref), [`set_suboptimizer_attributes`](@ref).
"""
function get_suboptimizer_attribute(stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute)
    return MOI.get(optimizer(stochasticprogram), SubProblemOptimizerAttribute(), attr)
end
"""
    set_suboptimizer_attribute(stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute, value)

Sets solver-specific attribute `attr` of the subproblem optimizer to `value`.

"""
function set_suboptimizer_attribute(stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute, value)
    return set_optimizer_attribute(stochasticprogram, SubProblemOptimizerAttribute(), attr, value)
end
"""
    set_suboptimizer_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)

Sets solver-specific attribute of the subproblem optimizer identified by `name` to `value`.

"""
function set_suboptimizer_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawSubProblemOptimizerParameter(String(name)), value)
end
"""
    set_suboptimizer_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)

Given a list of `attribute => value` pairs or a collection of keyword arguments, calls
`set_suboptimizer_attribute(stochasticprogram, attribute, value)` for each pair.

"""
function set_suboptimizer_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_suboptimizer_attribute(stochasticprogram, name, value)
    end
end
function set_suboptimizer_attributes(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_suboptimizer_attribute(stochasticprogram, name, value)
    end
end
"""
    Execution

An optimizer attribute for specifying an execution policy for a structure-exploiting algorithm. Options are:

- [`Serial`](@ref):  Classical L-shaped (default)
- [`Synchronous`](@ref): Classical L-shaped run in parallel
- [`Asynchronous`](@ref): Asynchronous L-shaped ?Asynchronous for parameter descriptions.
"""
struct Execution <: AbstractStructuredOptimizerAttribute end
"""
    ExecutionParameter

Abstract supertype for execution-specific attributes.
"""
abstract type ExecutionParameter <: AbstractStructuredOptimizerAttribute end


# Sampled optimizer attributes #
# ========================== #
"""
    Confidence

An optimizer attribute for specifying the confidence level of sample-based procedures.
"""
struct Confidence <: AbstractSampledOptimizerAttribute end
"""
    NumSamples

An optimizer attribute for specifying the sample size of sample-based procedures.
"""
struct NumSamples <: AbstractSampledOptimizerAttribute end
"""
    NumEvalSamples

An optimizer attribute for specifying the sample size of evaluation instances of sample-based procedures.
"""
struct NumEvalSamples <: AbstractSampledOptimizerAttribute end
"""
    NumEWSSamples

An optimizer attribute for specifying the sample size of wait-and-see instances in sample-based procedures.
"""
struct NumEWSSamples <: AbstractSampledOptimizerAttribute end
"""
    NumEEVSamples

An optimizer attribute for specifying the sample size of expected-value evaluation instances in sample-based procedures.
"""
struct NumEEVSamples <: AbstractSampledOptimizerAttribute end
"""
    NumLowerTrials

An optimizer attribute for specifying the number of trials used to compute lower bounds of confidence intervals in sample-based procedures.
"""
struct NumLowerTrials <: AbstractSampledOptimizerAttribute end
"""
    NumUpperTrials

An optimizer attribute for specifying the number of trials used to compute upper bounds of confidence intervals in sample-based procedures.
"""
struct NumUpperTrials <: AbstractSampledOptimizerAttribute end
"""
    InstanceOptimizer

An optimizer attribute for specifying the AbstractStructuredOptimizer/AbstractOptimizer used to solve sampled problems in sample-based procedures.
"""
struct InstanceOptimizer <: AbstractSampledOptimizerAttribute end
"""
    InstanceCrash

An optimizer attribute for specifying a crash start to be used when solving sampled instances.
"""
struct InstanceCrash <: AbstractSampledOptimizerAttribute end
"""
    InstanceOptimizerAttribute

An optimizer attribute used for setting attributes of the instance optimizer.
"""
struct InstanceOptimizerAttribute end
"""
    RawInstanceOptimizerParameter

An optimizer attribute used for raw parameters of the instance optimizer. Defers to `RawParameter`.
"""
struct RawInstanceOptimizerParameter <: AbstractSampledOptimizerAttribute
    name::Any
end
MOI.supports(::MOI.AbstractOptimizer, ::RawInstanceOptimizerParameter) = false

function MOI.set(sm::StochasticModel, attr::InstanceOptimizerAttribute, instance_attr::MOI.AbstractOptimizerAttribute, value)
    MOI.set(optimizer(sm), attr, instance_attr, value)
    return nothing
end
"""
    get_instanceoptimizer_attribute(stochasticprogram::StochasticProgram, name::String)

Return the value associated with the solver-specific attribute named `name` of the instance optimizer in `stochasticprogram`.

See also: [`set_instanceoptimizer_attribute`](@ref), [`set_instanceoptimizer_attributes`](@ref).
"""
function get_instanceoptimizer_attribute(stochasticprogram::StochasticProgram, name::String)
    return get_instanceoptimizer_attribute(stochasticprogram, RawInstanceOptimizerParameter(name))
end
"""
    get_instanceoptimizer_attribute(stochasticmodel::StochasticModel, attr::MOI.AbstractOptimizerAttribute)

Return the value of the solver-specific attribute `attr` of the instance optimizer in `stochasticmodel`.

See also: [`set_instanceoptimizer_attribute`](@ref), [`set_instanceoptimizer_attributes`](@ref).
"""
function get_instanceoptimizer_attribute(stochasticmodel::StochasticModel, attr::MOI.AbstractOptimizerAttribute)
    return MOI.get(optimizer(stochasticmodel), InstanceOptimizerAttribute(), attr)
end
"""
    set_instanceoptimizer_attribute(stochasticmodel::StochasticModel, attr::MOI.AbstractOptimizerAttribute, value)

Sets solver-specific attribute `attr` of the instance optimizer to `value` in `stochasticmodel`.
"""
function set_instanceoptimizer_attribute(stochasticmodel::StochasticModel, attr::MOI.AbstractOptimizerAttribute, value)
    return MOI.set(optimizer(stochasticmodel), InstanceOptimizerAttribute(), attr, value)
end
"""
    set_instanceoptimizer_attribute(stochasticmodel::StochasticModel, name::Union{Symbol, String}, value)

Sets solver-specific attribute of the instance optimizer identified by `name` to `value` in `stochasticmodel`.

"""
function set_instanceoptimizer_attribute(stochasticmodel::StochasticModel, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticmodel, RawInstanceOptimizerParameter(String(name)), value)
end
"""
    set_instanceoptimizer_attributes(stochasticmodel::StochasticModel, pairs::Pair...)

Given a list of `attribute => value` pairs or a collection of keyword arguments, calls
`set_instanceoptimizer_attribute(stochasticmodel, attribute, value)` for each pair.

"""
function set_instanceoptimizer_attributes(stochasticmodel::StochasticModel, pairs::Pair...)
    for (name, value) in pairs
        set_instanceoptimizer_attribute(stochasticmodel, name, value)
    end
end
function set_instanceoptimizer_attributes(stochasticmodel::StochasticModel; kw...)
    for (name, value) in kw
        set_instanceoptimizer_attribute(stochasticmodel, name, value)
    end
end
