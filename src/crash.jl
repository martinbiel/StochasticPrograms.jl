"""
    Crash

Collection of crash methods used to generate initial decisions in structured algorithms.

...
# Available crash methods
- [`None`](@ref)
- [`EVP`](@ref)
- [`Scenario`](@ref)
- [`Custom`](@ref)
...

## Examples

The following solves a stochastic program `sp` created in `StochasticPrograms.jl` using an L-shaped algorithm with trust-region and Clp as an `lpsolver` and by generating an initial decision with the `EVP` crash.

```jldoctest
julia> optimize!(sp, solver = LShapedSolver(GLPKSolverLP(), crash=Crash.EVP(), regularize = TrustRegion()))
L-Shaped Gap  Time: 0:00:00 (8 iterations)
  Objective:       -855.8333333333339
  Gap:             0.0
  Number of cuts:  4
  Iterations:      8
:Optimal
```
"""
module Crash

using StochasticPrograms
using MathProgBase

abstract type CrashMethod end

"""
    None

Randomize the initial decision (default).

"""
struct None <: CrashMethod end

function (::None)(stochasticprogram::StochasticProgram, solver::MathProgBase.AbstractMathProgSolver)
    return rand(decision_length(stochasticprogram))
end

"""
    EVP

Solve the expected value problem corresponding to the stochastic program and use the expected value solution as initial decision.

"""
struct EVP <: CrashMethod end

function (::EVP)(sp::StochasticProgram, solver::MathProgBase.AbstractMathProgSolver)
    evp = StochasticPrograms.EVP(sp; solver = solver)
    status = solve(evp)
    status != :Optimal && error("Could not solve EVP model during crash procedure. Aborting.")
    return evp.colVal[1:decision_length(sp)]
end

"""
    Scenario

Solve the wait-and-see problem corresponding a supplied scenario and use the optimal solution as initial decision.

"""
struct Scenario{S <: AbstractScenario} <: CrashMethod
    scenario::S

    function Scenario(scenario::S) where S <: AbstractScenario
        return new{S}(scenario)
    end
end

function (crash::Scenario)(so::StochasticProgram, solver::MathProgBase.AbstractMathProgSolver)
    ws = WS(sp, crash.scenario; solver = solver)
    status = solve(ws)
    status != :Optimal && error("Could not solve wait-and-see model during crash procedure. Aborting.")
    return ws.colVal[1:decision_length(sp)]
end

"""
    Custom(x₀)

Use the user-supplied `x₀` as initial decision.

"""
struct Custom{T <: AbstractFloat} <: CrashMethod
    x₀::Vector{T}

    function Custom(x₀::Vector{T}) where T <: AbstractFloat
        return new{T}(x₀)
    end
end

function (crash::Custom)(sp::StochasticProgram, solver::MathProgBase.AbstractMathProgSolver)
    return crash.x₀[1:decision_length(sp)]
end

end

CrashMethod = Crash.CrashMethod
