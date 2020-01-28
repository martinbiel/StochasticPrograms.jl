# Structured solvers

A stochastic program has a structure that can be exploited in solver algorithms through decomposition. This can heavily reduce the computation time required to optimize the stochastic program, compared to solving the extensive form directly. Moreover, a distributed stochastic program is by definition decomposed and a structured solver that can operate in parallel will be much more efficient.

## Solver interface

The structured solver interface mimics that of `MathProgBase`, and it needs to be implemented by any structured solver to be compatible with StochasticPrograms. We distinguish between structure-exploiting solvers for solving finite stochastic programs and sampled-bases solvers for approximately solving stochastic models, even though they can be based on the same algorithm.

Some procedures in StochasticPrograms require a `MathProgBase` solver. It is common that structured solvers rely internally on some `MathProgBase` solver. Hence, for convenience, a solver can implement [`internal_solver`](@ref) to return any internal `MathProgBase` solver. A stochastic program that has an loaded structured solver that implements this method can then make use of that solver for those procedures, instead of requiring an external solver to be supplied. Finally, a structured solver can optionally implement [`solverstr`](@ref) to return an informative description string for printouts.

### Stochastic programs

To interface a new structure-exploiting solver, define a shallow object of type [`AbstractStructuredSolver`](@ref). This object is intended to be the interface to end users of the solver and is what should be passed to [`optimize!`](@ref). Define a new structured solver as a subtype of [`AbstractStructuredModel`](@ref). Next, implement [`StructuredModel`](@ref), that takes the stochastic program and the [`AbstractStructuredSolver`](@ref) object and return an instance of [`AbstractStructuredModel`](@ref) which internal state depends on the given stochastic program. Next, the solver algorithm should be run when calling [`optimize_structured!`](@ref) on the [`AbstractStructuredModel`](@ref). After successfuly optimizing the model, the solver must be able to fill in the optimal solution in the first stage and all second stages through [`fill_solution!`](@ref).

In summary, the solver interface that a new [`AbstractStructuredModel`](@ref) and [`AbstractStructuredSolver`](@ref) pair should adhere to is given by

 - [`StructuredModel`](@ref)
 - [`optimize_structured!`](@ref)
 - [`fill_solution!`](@ref)
 - [`internal_solver`](@ref)
 - [`solverstr`](@ref)

As an example, a simplified version of the implementation of the structured solver interface for [`LShaped`](@ref) is given below:
```julia
abstract AbstractLShapedSolver <: AbstractStructuredModel end

const MPB = MathProgBase

mutable struct LShapedSolver <: AbstractStructuredSolver
    lpsolver::MPB.AbstractMathProgSolver
    subsolver::S
    feasibility_cuts::Bool
    execution::E
    regularize::R
    aggregate::A
    consolidate::C
    crash::CrashMethod
    parameters::Dict{Symbol,Any}

    function LShapedSolver(lpsolver::MPB.AbstractMathProgSolver;
                           execution::Execution = Serial(),
                           feasibility_cuts::Bool = true,
                           regularize::AbstractRegularizer = DontRegularize(),
                           aggregate::AbstractAggregator = DontAggregate(),
                           consolidate::AbstractConsolidator = DontConsolidate(),
                           crash::CrashMethod = Crash.None(),
                           subsolver::SubSolver = lpsolver, kwargs...)
        return new(lpsolver, subsolver, feasibility_cuts, execution, regularize, aggregate, consolidate, crash, Dict{Symbol,Any}(kwargs))
    end
end

function StructuredModel(stochasticprogram::StochasticProgram, solver::LShapedSolver)
    x₀ = solver.crash(stochasticprogram, solver.lpsolver)
    return LShaped(stochasticprogram, x₀, solver.lpsolver, get_solver(solver.subsolver), solver.feasibility_cuts, solver.execution, solver.regularize, solver.aggregate, solver.consolidate; solver.parameters...)
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

### Stochastic models

To interface a new sampled-based solver, define a shallow object of type [`AbstractSampledSolver`](@ref). This object is intended to be the interface to end users of the solver and is what should be passed to [`optimize!`](@ref).Similar to finite programs, define a new sampled-based solver as a subtype of [`AbstractSampledModel`](@ref). Next, implement [`SampledModel`](@ref), that takes a stochastic model and the [`AbstractStructuredSolver`](@ref) object and returns an instance of [`AbstractSampledModel`](@ref). Next, the solver algorithm should be run when calling [`optimize_sampled!`](@ref) on the [`AbstractSampledModel`](@ref), some [`AbstractSampler`](@ref) and a desired confidence level. After successfuly optimizing the model, a [`StochasticSolution`](@ref) should be retrivable from the [`AbstractSampledModel`](@ref) using [`stochastic_solution`](@ref)

In summary, the solver interface that a new [`AbstractSampledModel`](@ref) and [`AbstractStructuredSolver`](@ref) pair should adhere to is given by

 - [`SampledModel`](@ref)
 - [`optimize_sampled!`](@ref)
 - [`stochastic_solution`](@ref)
 - [`internal_solver`](@ref)
 - [`solverstr`](@ref)

As an example, consider the implementation of [`SAA`](@ref):
```julia
struct SAA{S <: SPSolverType} <: AbstractStructuredSolver
    internal_solver::S

    function SAA(solver::SPSolverType)
        if isa(solver, JuMP.UnsetSolver)
            error("Cannot solve emerging SAA problems without functional solver.")
        end
        S = typeof(solver)
        return new{S}(solver)
    end
end
function SAA(; solver::SPSolverType = JuMP.UnsetSolver())
    return SAA(solver)
end

mutable struct SAAModel{M <: StochasticModel, S <: SPSolverType} <: AbstractSampledModel
    stochasticmodel::M
    solver::S
    solution::StochasticSolution
end

function SampledModel(stochasticmodel::StochasticModel, solver::SAA)
    return SAAModel(stochasticmodel, solver.internal_solver, EmptySolution())
end

function optimize_sampled!(saamodel::SAAModel, sampler::AbstractSampler, confidence::AbstractFloat; M::Integer = 10, tol::AbstractFloat = 1e-1, Nmax::Integer = 5000)
    sm = saamodel.stochasticmodel
    solver = saamodel.solver
    n = 16
    α = 1-confidence
    while true
        CI = confidence_interval(sm, sampler; solver = solver, confidence = 1-α, N = N, M = M, Ñ = max(N, Ñ), T = T)
        Q = (upper(CI) + lower(CI))/2
        gap = length(CI)/abs(Q+1e-10)
        if gap <= tol
            sp = sample(sm, sampler, N)
            optimize!(sp, solver = solver)
            Q = optimal_value(sp)
            while !(Q ∈ CI)
                sp = sample(sm, sampler, N)
                optimize!(sp, solver = solver)
                Q = optimal_value(sp)
            end
            saamodel.solution = StochasticSolution(optimal_decision(saa), Q, N, CI)
            saamodel.saa = saa
            return :Optimal
        end
        N = N * 2
        if N > Nmax
            return :LimitReached
        end
        solver_config(solver, N)
    end
end

function stochastic_solution(saamodel::SAAModel)
    return saamodel.solution
end
```

## L-shaped solvers

StochasticPrograms includes a collection of L-shaped algorithms in the submodule `LShapedSolvers`. All algorithm variants are based on the L-shaped method by Van Slyke and Wets. `LShapedSolvers` interfaces with StochasticPrograms through the structured solver interface. Every algorithm variant is an instance of the functor object [`LShaped`](@ref), and are instanced using the factory object [`LShapedSolver`](@ref).

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
Note, that an LP capable `AbstractMathProgSolver` is required to solve emerging subproblems.

`LShapedSolvers` uses a policy-based design. This allows combinatorially many variants of the original algorithm to be instanced by supplying linearly many policies to the factory function [`LShapedSolver`](@ref). We briefly describe the various policies in the following.

### Feasibility cuts

If the stochastic program does not have complete, or relatively complete, recourse then subproblems may be infeasible for some master iterates. Convergence can be maintained through the use of feasibility cuts. To reduce overhead and memory usage, feasibility issues are ignored by default. If you know that your problem does not have complete recourse, or if the algorithm terminates due to infeasibility, supply `feasibility_cuts = true` to the factory function to turn on this feature.

### Regularization

A Regularization procedure can improve algorithm performance. The idea is to limit the candidate search to a neighborhood of the current best iterate in the master problem. This can result in more effective cutting planes. Moreover, regularization enables warm-starting the L-shaped procedure with [`Crash`](@ref) decisions. Regularization is enabled by supplying a factory object through `regularize` to [`LShapedSolver`](@ref).

The following L-shaped regularizations are available:
- [`NoRegularization`](@ref) (default)
- [`RegularizedDecomposition`](@ref)
- [`TrustRegion`](@ref)
- [`LevelSet`](@ref)

Note, that [`RegularizedDecomposition`](@ref) and [`LevelSet`](@ref) require an `AbstractMathProgSolver` capable of solving QP problems. Alternatively, the 2-norm penalty term in the objective can be approximated through various linear terms. This is achieved by supplying a `PenaltyTerm` object through `penaltyterm` in either [`RD`](@ref) or [`LV`](@ref). The alternatives are given below:

- [`Quadratic`](@ref) (default)
- [`Linearized`](@ref)
- [`InfNorm`](@ref)
- [`ManhattanNorm`](@ref)

### Aggregation

Cut aggregation can be applied to reduce communication latency and load imbalance. This can yield major performance improvements in distributed settings. Aggregation is enabled by supplying a factory object through `aggregate` to the factory function.

The following aggregation schemes are available:
- [`NoAggregation`](@ref) (default)
- [`PartialAggregation`](@ref)
- [`DynamicAggregation`](@ref)
- [`ClusterAggregation`](@ref)
- [`HybridAggregation`](@ref)

### Consolidation

If cut consolidation is enabled, cuts from previous iterations that are no longer active are aggregated to reduce the size of the master. Consolidation is enabled by supplying `consolidate = Consolidate()` to the factory function. See [`Consolidation`](@ref) for further details.

### Crash

The L-shaped algorithm can be crash started in various way. A good initial guess in combination with a regularization procedure can improve convergence.

The following [`Crash`](@ref) methods can be used through the `crash` option in the factory function.
- [`Crash.None`](@ref) (default)
- [`Crash.EVP`](@ref)
- [`Crash.Scenario`](@ref)
- [`Crash.Custom`](@ref)

### Execution

There are three available modes of execution:

- [`Serial`](@ref) (default)
- [`Synchronous`](@ref)
- [`Asynchronous`](@ref)

Running a distributed L-shaped algorithm, either synchronously or asynchronously, required adding Julia worker cores with [`addprocs`].

### References

1. Van Slyke, R. and Wets, R. (1969), [L-Shaped Linear Programs with Applications to Optimal Control and Stochastic Programming](https://epubs.siam.org/doi/abs/10.1137/0117061), SIAM Journal on Applied Mathematics, vol. 17, no. 4, pp. 638-663.

2. Ruszczyński, A (1986), [A regularized decomposition method for minimizing a sum of polyhedral functions](https://link.springer.com/article/10.1007/BF01580883), Mathematical Programming, vol. 35, no. 3, pp. 309-333.

3. Linderoth, J. and Wright, S. (2003), [Decomposition Algorithms for Stochastic Programming on a Computational Grid](https://link.springer.com/article/10.1023/A:1021858008222), Computational Optimization and Applications, vol. 24, no. 2-3, pp. 207-250.

4. Fábián, C. and Szőke, Z. (2006), [Solving two-stage stochastic programming problems with level decomposition](https://link.springer.com/article/10.1007%2Fs10287-006-0026-8), Computational Management Science, vol. 4, no. 4, pp. 313-353.

5. Wolf, C. and Koberstein, A. (2013), [Dynamic sequencing and cut con-solidation for the parallel hybrid-cut nested l-shaped method](https://www.sciencedirect.com/science/article/pii/S0377221713003159), European Journal of Operational Research, vol. 230, no. 1, pp. 143-156.

6. Biel, M. and Johansson, M. (2018), [Distributed L-shaped Algorithms in Julia](https://ieeexplore.ieee.org/document/8639173), 2018 IEEE/ACM Parallel Applications Workshop, Alternatives To MPI (PAW-ATM).

7. Biel, M. and Johansson, M. (2019), [Dynamic cut aggregation in L-shaped algorithms](https://arxiv.org/abs/1910.13752), arXiv preprint arXiv:1910.13752.

## ProgressiveHedgingSolvers.jl

StochasticPrograms also includes a collection of progressive-hedging algorithms in the submodule `ProgressiveHedgingSolvers`. All algorithm variants are based on the original progressive-hedging algorithm by Rockafellar and Wets. `ProgressiveHedgingSolvers` interfaces with StochasticPrograms through the structured solver interface. Every algorithm variant is an instance of the functor object [`ProgressiveHedging`](@ref), and are instanced using the factory object [`ProgressiveHedgingSolver`](@ref).

As an example, we solve the simple problem introduced in the [Quick start](@ref):
```julia
using ProgressiveHedgingSolvers
using GLPKMathProgInterface

optimize!(sp, solver = ProgressiveHedgingSolver(GLPKSolverLP, penaltyterm = Linearized(nbreakpoints=30))
```
```julia
Progressive Hedging Time: 0:00:00 (91 iterations)
  Objective:  -855.8017375415484
  δ:          9.700002687897287e-6
:Optimal
```
Note, that an QP/LP capable `AbstractMathProgSolver` is required to solve emerging subproblems.

`ProgressiveHedgingSolvers` also uses a policy-based design. See [`ProgressiveHedgingSolver`](@ref) for options. We briefly describe the various policies in the following.

### Penalty

There are two options for the penalty parameter used in the progressive-hedging algorithm. The alternatives are

- [`Fixed`](@ref) (default)
- [`Adaptive`](@ref)

### Execution

The same execution policies as for `LShapedSolvers` are available in `ProgressiveHedgingSolvers`, i.e.

- [`Serial`](@ref) (default)
- [`Synchronous`](@ref)
- [`Asynchronous`](@ref)

### Penalty term

As with the L-shaped variants with quadratic 2-norm terms, the 2-norm term in progressive-hedging subproblems can be approximated. This enables the use of `AbstractMathProgSolver` that only solve linear problems. The alternatives are as before:

- [`Quadratic`](@ref) (default)
- [`Linearized`](@ref)
- [`InfNorm`](@ref)
- [`ManhattanNorm`](@ref)

### References

1. R. T. Rockafellar and Roger J.-B. Wets (1991), [Scenarios and Policy Aggregation in Optimization Under Uncertainty](https://pubsonline.informs.org/doi/10.1287/moor.16.1.119), Mathematics of Operations Research, vol. 16, no. 1, pp. 119-147.

2. Zehtabian. S and Bastin. F (2016), [Penalty parameter update strategies in progressive hedging algorithm](http://www.cirrelt.ca/DocumentsTravail/CIRRELT-2016-12.pdf)
