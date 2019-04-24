"""
    Crash

Collection of crash methods used to generate initial decisions in structured algorithms.

...
# Crash methods
- `Crash.None()`: Randomize the initial decision (default).
- `Crash.EVP()`: Solve the expected value problem corresponding to the stochastic program and use the expected value solution as initial decision.
- `Crash.Scenario(scenario::AbstractScenario)`: Solve the wait-and-see problem corresponding a supplied scenario and use the optimal solution as initial decision.
- `Crash.Custom(x₀)`: Use the user-supplied `x₀` as initial decision.
...

## Examples

The following solves a stochastic program `sp` created in `StochasticPrograms.jl` using the trust-region L-shaped algorithm with Clp as an `lpsolver` and by generating an initial decision with the `EVP` crash.

```jldoctest
julia> solve(sp, solver=LShapedSolver(ClpSolver(), crash=Crash.EVP(), regularizer = TrustRegion()))
TR L-Shaped Gap  Time: 0:00:00 (8 iterations)
  Objective:       -855.8333333333321
  Gap:             0.0
  Number of cuts:  4
:Optimal
```
"""
module Crash

using StochasticPrograms
using MathProgBase

abstract type CrashMethod end

struct None <: CrashMethod end

function (::None)(stochasticprogram::StochasticProgram, solver::MathProgBase.AbstractMathProgSolver)
    return rand(decision_length(stochasticprogram))
end

struct EVP <: CrashMethod end

function (::EVP)(sp::StochasticProgram, solver::MathProgBase.AbstractMathProgSolver)
    evp = StochasticPrograms.EVP(sp; solver = solver)
    status = solve(evp)
    status != :Optimal && error("Could not solve EVP model during crash procedure. Aborting.")
    return evp.colVal[1:decision_length(sp)]
end

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
