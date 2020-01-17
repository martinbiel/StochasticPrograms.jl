abstract type Execution end
"""
    Serial

Factory object for [`SerialExecution`](@ref). Passed by default to `execution ` in the `LShapedSolver` and `ProgressiveHedgingSolver` factory functions.

"""
struct Serial <: Execution end

function str(::Serial)
    return ""
end

"""
    Synchronous

Factory object for [`SynchronousExecution`](@ref). Pass to `execution` in the `LShapedSolver` and `ProgressiveHedgingSolver` factory functions.

"""
struct Synchronous <: Execution end

function str(::Synchronous)
    return "Synchronous "
end

"""
    Asynchronous

Factory object for [`AsynchronousExecution`](@ref). Pass to `execution` in the `LShapedSolver` and `ProgressiveHedgingSolver` factory functions

...
# Parameters
- `max_active::Int = 3`: Maximum number of active iterations that run asynchronously.
- `κ::T = 0.5`: Relative amount of finished subproblems required to start a new iterate. Governs the amount of asynchronicity.
...
"""
struct Asynchronous <: Execution
    max_active::Int
    κ::Float64

    function Asynchronous(; max_active::Int = 3, κ::AbstractFloat = 0.5)
        return new(max_active, κ)
    end
end

function str(::Asynchronous)
    return "Asynchronous "
end
