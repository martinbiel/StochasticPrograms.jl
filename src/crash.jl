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
using StochasticPrograms: AbstractCrash, StochasticProgramOptimizer
import MathOptInterface as MOI

"""
    None

Randomize the initial decision (default).

"""
struct None <: AbstractCrash end

function (::None)(stochasticprogram::StochasticProgram)
    return rand(num_decisions(stochasticprogram))
end

function (::None)(stochasticmodel::StochasticModel, sampler::AbstractSampler)
    # Get instance optimizer
    optimizer = MOI.get(stochasticmodel, InstanceOptimizer())
    sp = instantiate(stochasticmodel, sampler, 1; optimizer = optimizer)
    return rand(num_decisions(sp))
end

"""
    EVP

Solve the expected value problem corresponding to the stochastic program and use the expected value solution as initial decision.

"""
struct EVP <: AbstractCrash end

function (::EVP)(stochasticprogram::StochasticProgram)
    return expected_value_decision(stochasticprogram)
end

function (crash::EVP)(stochasticmodel::StochasticModel, sampler::AbstractSampler)
    # Get instance optimizer
    optimizer = MOI.get(stochasticmodel, InstanceOptimizer())
    sp = instantiate(stochasticmodel, sampler, 10; optimizer = optimizer)
    return crash(sp)
end

"""
    FeasiblePoint

Generate a feasible first-stage decision as initial decision.

"""
struct FeasiblePoint <: AbstractCrash end

function (::FeasiblePoint)(stochasticprogram::StochasticProgram)
    # Generate first-stage
    m = stage_one_model(stochasticprogram, optimizer = master_optimizer(stochasticprogram))
    # Solve feasibility problem
    @objective(m, MOI.FEASIBILITY_SENSE, 0)
    optimize!(m)
    # Return feasible point
    return JuMP.value.(all_decision_variables(m, 1))
end

function (crash::FeasiblePoint)(stochasticmodel::StochasticModel, sampler::AbstractSampler)
    # Get instance optimizer
    optimizer = MOI.get(stochasticmodel, InstanceOptimizer())
    sp = instantiate(stochasticmodel, sampler, 10; optimizer = optimizer)
    return crash(sp)
end

"""
    Scenario

Solve the wait-and-see problem corresponding a supplied scenario and use the optimal solution as initial decision.

"""
struct Scenario{S <: AbstractScenario} <: AbstractCrash
    scenario::S

    function Scenario(scenario::S) where S <: AbstractScenario
        return new{S}(scenario)
    end
end

function (crash::Scenario)(stochasticprogram::StochasticProgram)
    return wait_and_see_decision(stochasticprogram, crash.scenario)
end

function (crash::Scenario)(stochasticmodel::StochasticModel, sampler::AbstractSampler)
    # Get instance optimizer
    optimizer = MOI.get(stochasticmodel, InstanceOptimizer())
    sp = instantiate(stochasticmodel, sampler, 10; optimizer = optimizer)
    return crash(sp)
end

"""
    PreSolve

Run a provided (ideally suboptimal) optimization procedure and use the (sub)optimal solution as initial decision.

"""
struct PreSolve <: AbstractCrash
    optimizer::StochasticProgramOptimizer

    function PreSolve(optimizer_constructor)
        return new(StochasticProgramOptimizer(optimizer_constructor))
    end
end

function (crash::PreSolve)(stochasticprogram::StochasticProgram)
    optimizer = crash.optimizer.optimizer
    structure_ = structure(stochasticprogram)
    # Generate random starting point
    x₀ = None()(stochasticprogram)
    # Sanity checks
    if !supports_structure(optimizer, structure_)
        @warn "The provided presolve optimizer does not support the underlying structure of the stochastic program. Defaulting to random starting point."
        return x₀
    end
    check_loadable(optimizer, structure_)
    # Better printing
    MOI.set(optimizer, MOI.RawOptimizerAttribute("keep"), false)
    # Load structure
    load_structure!(optimizer, structure_, x₀)
    # Run presolve
    MOI.optimize!(optimizer)
    # Get solution
    x₀ = map(all_decision_variables(stochasticprogram, 1)) do dvar
        return MOI.get(optimizer, MOI.VariablePrimal(), index(dvar))
    end
    # Restore problem
    restore_structure!(optimizer)
    return x₀
end

function (crash::PreSolve)(stochasticmodel::StochasticModel, sampler::AbstractSampler)
    # Get instance optimizer
    sp = instantiate(stochasticmodel, sampler, 10; optimizer = crash.optimizer.optimizer_constructor)
    return crash(sp)
end

"""
    Custom(x₀)

Use the user-supplied `x₀` as initial decision.

"""
struct Custom{T <: AbstractFloat} <: AbstractCrash
    x₀::Vector{T}

    function Custom(x₀::Vector{T}) where T <: AbstractFloat
        return new{T}(x₀)
    end
end

function (crash::Custom)(stochasticprogram::StochasticProgram)
    return crash.x₀[1:num_decisions(stochasticprogram)]
end

function (crash::Custom)(stochasticmodel::StochasticModel, sampler::AbstractSampler)
    # Get instance optimizer
    optimizer = MOI.get(stochasticmodel, InstanceOptimizer())
    sp = instantiate(stochasticmodel, sampler, 1; optimizer = optimizer)
    return crash.x₀[1:num_decisions(sp)]
end

end
