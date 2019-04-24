# Structured solvers

A stochastic program has a structure that can exploited in solver algorithms through decomposition. This can heavily reduce the computation time required to optimize the stochastic program, compared to solving the extensive form directly. Moreover, a distributed stochastic program is by definition decomposed and a structured solver that can operate in parallel will be much more efficient.

## Solver interface

The structured solver interface mimics that of `MathProgBase`, and it needs to be implemented by any structured solver to be compatible with StochasticPrograms. Define a new structured solver as a subtype of [`AbstractStructuredModel`](@ref). Moreoever, define a shallow object of type [`AbstractStructuredSolver`](@ref). This object is intended to be the interface to end users of the solver and is what should be passed to [`optimize!`](@ref). Next, implement [`StructuredModel`](@ref), that takes the stochastic program and the [`AbstractStructuredSolver`](@ref) object and return and instance of [`AbstractStructuredModel`](@ref) which internal state depends on the given stochastic program. Next, the solver algorithm should be run when calling [`optimize_structured!`](@ref) on the [`AbstractStructuredModel`](@ref). After successfuly optimizing the model, the solver must be able to fill in the optimal solution in the first stage and all second stages through [`fill_solution!`](@ref).

Some procedures in StochasticPrograms require a `MathProgBase` solver. It is common that structured solvers rely internally on some `MathProgBase` solver. Hence, for convenience, a structured solver can implement [`internal_solver`](@ref) to return any internal `MathProgBase` solver. A stochastic program that has an loaded structured solver that implements this method can then make use of that solver for those procedures, instead of requiring an external solver to be supplied. Finally, a structured solver can optionally implement [`solverstr`](@ref) to return an informative description string for printouts.

As an example, a simplified version of the implementation of the structured solver interface in [LShapedSolvers.jl](@ref) is given below:
```julia
abstract AbstractLShapedSolver <: AbstractStructuredModel end

const MPB = MathProgBase

mutable struct LShapedSolver <: AbstractStructuredSolver
    lpsolver::MPB.AbstractMathProgSolver
    subsolver::MPB.AbstractMathProgSolver
    complete_recourse::Bool
    crash::Crash.CrashMethod
    parameters::Dict{Symbol,Any}

    function LShapedSolver(lpsolver::MPB.AbstractMathProgSolver;
                           complete_recourse::Bool = true,
                           regularize::AbstractRegularizer = DontRegularize(),
                           crash::Crash.CrashMethod = Crash.None(),
                           subsolver::MPB.AbstractMathProgSolver = lpsolver, kwargs...)
        return new(lpsolver, subsolver, complete_recourse, regularize, crash, Dict{Symbol,Any}(kwargs))
    end
end

function StructuredModel(stochasticprogram::StochasticProgram, solver::LShapedSolver)
    x₀ = solver.crash(stochasticprogram, solver.lpsolver)
    return LShaped(stochasticprogram, x₀, solver.lpsolver, solver.subsolver, solver.checkfeas; solver.parameters...)
end

function internal_solver(solver::LShapedSolver)
    return solver.lpsolver
end

function optimize_structured!(lshaped::AbstractLShapedSolver)
    return lshaped()
end

function fill_solution!(stochasticprogram::StochasticProgram, lshaped::AbstractLShapedSolver)
    # First stage
    first_stage = StochasticPrograms.get_stage_one(stochasticprogram)
    nrows, ncols = first_stage_dims(stochasticprogram)
    StochasticPrograms.set_decision!(stochasticprogram, decision(lshaped))
    μ = try
        MPB.getreducedcosts(lshaped.mastersolver.lqmodel)[1:ncols]
    catch
        fill(NaN, ncols)
    end
    StochasticPrograms.set_first_stage_redcosts!(stochasticprogram, μ)
    λ = try
        MPB.getconstrduals(lshaped.mastersolver.lqmodel)[1:nrows]
    catch
        fill(NaN, nrows)
    end
    StochasticPrograms.set_first_stage_duals!(stochasticprogram, λ)
    # Second stage
    fill_submodels!(lshaped, scenarioproblems(stochasticprogram))
end

function solverstr(solver::LShapedSolver)
    return "L-shaped solver"
end
```

## LShapedSolvers.jl

LShapedSolvers is a collection of structured optimization algorithms for two-stage (L-shaped) stochastic recourse problems. All algorithm variants are based on the L-shaped method by Van Slyke and Wets. LShapedSolvers interfaces with StochasticPrograms through the structured solver interface. It is available as an unregistered package on Github, ans can be installed as follows:
```julia
pkg> add https://github.com/martinbiel/LShapedSolvers.jl
```
```@setup lshaped
using StochasticPrograms
@scenario SimpleScenario = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end
ξ₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)
ξ₂ = SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)
sp = StochasticProgram([ξ₁, ξ₂])
@first_stage sp = begin
    @variable(model, x₁ >= 40)
    @variable(model, x₂ >= 20)
    @objective(model, Min, 100*x₁ + 150*x₂)
    @constraint(model, x₁ + x₂ <= 120)
end
@second_stage sp = begin
    @decision x₁ x₂
    @uncertain ξ::SimpleScenario
    @variable(model, 0 <= y₁ <= ξ.d₁)
    @variable(model, 0 <= y₂ <= ξ.d₂)
    @objective(model, Min, ξ.q₁*y₁ + ξ.q₂*y₂)
    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
end
```
As an example, we solve the simple problem introduced in the [Quick start](@ref):
```julia
using LShapedSolvers
using GLPKMathProgInterface

optimize!(sp, solver = LShapedSolver(GLPKSolverLP()))
```
```julia
L-Shaped Gap  Time: 0:00:01 (6 iterations)
  Objective:       -855.8333333333358
  Gap:             0.0
  Number of cuts:  8
:Optimal
```
Note, that an LP capable `AbstractMathProgSolver` is required to solve emerging subproblems. The following variants of the L-shaped algorithm are implemented:

1. L-shaped with multiple cuts (default): `regularization = DontRegularize()`
2. L-shaped with regularized decomposition: `regularization = RegularizedDecomposition(; kw...)/RD(; kw...)`
3. L-shaped with trust region: `regularization = TrustRegion(; kw...)/TR(; kw...)`
4. L-shaped with level sets: `regularization = LevelSet(; projectionsolver, kw...)/LV(; projectionsolver, kw...)`

Note, that `RD` and `LV` both require a QP capable `AbstractMathProgSolver` for the master/projection problems. If not available, setting the `linearize` keyword to `true` is an alternative.

In addition, there is a distributed variant of each algorithm, created by supplying `distributed = true` to the factory method. This requires adding processes with `addprocs` prior to execution. The distributed variants are designed for StochasticPrograms, and are most efficient when run on distributed stochastic programs.

Each algorithm has a set of parameters that can be tuned prior to execution. For a list of these parameters and their default values, use `?` in combination with the solver object. For example, `?TrustRegion` gives the parameter list of the L-shaped algorithm with trust-region regularization. For a list of all solvers and their handle names, use `?LShapedSolver`.

## ProgressiveHedgingSolvers.jl

ProgressiveHedgingSolvers includes implementations of the progressive-hedging algorithm for two-stage stochastic recourse problems. All algorithm variants are based on the original progressive-hedging algorithm by Rockafellar and Wets. ProgressiveHedgingSolvers interfaces with StochasticPrograms through the structured solver interface. It is available as an unregistered package on Github, ans can be installed as follows:
```julia
pkg> add https://github.com/martinbiel/LShapedSolvers.jl
```
As an example, we solve the simple problem introduced in the [Quick start](@ref):
```julia
using ProgressiveHedgingSolvers
using Ipopt

optimize!(sp, solver = ProgressiveHedgingSolver(:ph, IpoptSolver(print_level=0)))
```
```julia
Progressive Hedging Time: 0:00:06 (1315 iterations)
  Objective:  -855.8332803469448
  δ:          9.570267362791345e-7
:Optimal
```
Note, that a QP capable `AbstractMathProgSolver` is required to solve emerging subproblems.

An adaptive penalty parameter can be used by supplying `penalty = :adaptive` to the factory method.

By default, the execution is `:sequential`. Supplying either `execution = :synchronous` or `execution = :asynchronous` to the factory method yields distributed variants of the algorithm. This requires adding processes with `addprocs` prior to execution. The distributed variants are designed for StochasticPrograms, and is most efficient when run on distributed stochastic programs.

The algorithm variants has a set of parameters that can be tuned prior to execution. For a list of these parameters and their default values, use `?` in combination with the solver object. For example, `?ProgressiveHedging` gives the parameter list of the sequential progressive-hedging algorithm. For a list of all solvers and their handle names, use `?ProgressiveHedgingSolver`.
