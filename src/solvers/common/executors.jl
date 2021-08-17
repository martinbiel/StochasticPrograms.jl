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

abstract type AbstractExecution end
"""
    RawExecutionParameter

An optimizer attribute used for raw parameters of the execution. Defers to `RawParameter`.
"""
struct RawExecutionParameter <: ExecutionParameter
    name::Any
end

function MOI.get(executor::AbstractExecution, param::RawExecutionParameter)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(executor)))
        error("Unrecognized parameter name: $(name) for executor $(typeof(executor)).")
    end
    return getfield(executor, name)
end

function MOI.set(executor::AbstractExecution, param::RawExecutionParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(executor)))
        error("Unrecognized parameter name: $(name) for executor $(typeof(executor)).")
    end
    setfield!(executor, name, value)
    return nothing
end
"""
    get_execution_attribute(stochasticprogram::StochasticProgram, name::String)

Return the value associated with the execution-specific attribute named `name` in `stochasticprogram`.

See also: [`set_execution_attribute`](@ref), [`set_execution_attributes`](@ref).
"""
function get_execution_attribute(stochasticprogram::StochasticProgram, name::String)
    return return MOI.get(optimizer(stochasticprogram), RawExecutionParameter(name))
end
"""
    set_execution_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)

Sets the execution-specific parameter identified by `name` to `value`.

"""
function set_execution_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawExecutionParameter(name), value)
end
"""
    set_execution_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)

Given a list of `attribute => value` pairs or a collection of keyword arguments, calls
`set_execution_attribute(stochasticprogram, attribute, value)` for each pair.

"""
function set_execution_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_execution_attribute(stochasticprogram, name, value)
    end
end
function set_execution_attributes(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_execution_attribute(stochasticprogram, name, value)
    end
end

"""
    Serial

Factory object for [`LShaped.SerialExecution`](@ref)/[`ProgressiveHedging.SerialExecution`](@ref). Pass through the `Execution` attribute.

"""
struct Serial <: AbstractExecution end

function str(::Serial)
    return ""
end

"""
    Synchronous

Factory object for [`LShaped.SynchronousExecution`](@ref)/[`ProgressiveHedging.SynchronousExecution`](@ref). Pass through the `Execution` attribute.

"""
struct Synchronous <: AbstractExecution end

function str(::Synchronous)
    return "Synchronous "
end

"""
    Asynchronous

Factory object for [`LShaped.AsynchronousExecution`](@ref)/[`ProgressiveHedging.AsynchronousExecution`](@ref). Pass through the `Execution` attribute.

...
# Parameters
- `max_active::Int = 3`: Maximum number of active iterations that run asynchronously.
- `κ::T = 0.5`: Relative amount of finished subproblems required to start a new iterate. Governs the amount of asynchronicity.
...
"""
mutable struct Asynchronous <: AbstractExecution
    max_active::Int
    κ::Float64

    function Asynchronous(; max_active::Int = 3, κ::AbstractFloat = 0.5)
        return new(max_active, κ)
    end
end

function str(::Asynchronous)
    return "Asynchronous "
end
