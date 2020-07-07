abstract type AbstractExecution end

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

function set_execution_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawExecutionParameter(name), value)
end
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

Factory object for [`LShapedSolvers.SerialExecution`](@ref)/[`ProgressiveHedgingSolvers.SerialExecution`](@ref). Passed by default to `execution ` in the `LShapedSolver` and `ProgressiveHedgingSolver` factory functions.

"""
struct Serial <: AbstractExecution end

function str(::Serial)
    return ""
end

"""
    Synchronous

Factory object for [`LShapedSolvers.SynchronousExecution`](@ref)/[`ProgressiveHedgingSolvers.SynchronousExecution`](@ref). Pass to `execution` in the `LShapedSolver` and `ProgressiveHedgingSolver` factory functions.

"""
struct Synchronous <: AbstractExecution end

function str(::Synchronous)
    return "Synchronous "
end

"""
    Asynchronous

Factory object for [`LShapedSolvers.AsynchronousExecution`](@ref)/[`ProgressiveHedgingSolvers.AsynchronousExecution`](@ref). Pass to `execution` in the `LShapedSolver` and `ProgressiveHedgingSolver` factory functions

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
