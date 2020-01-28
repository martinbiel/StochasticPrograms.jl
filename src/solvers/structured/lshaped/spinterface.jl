"""
    LShapedSolver(lpsolver::AbstractMathProgSolver; <keyword arguments>)

Return an L-shaped algorithm object that can optimize a two-stage `StochasticPrograms`. Supply `lpsolver`, a MathProgBase solver capable of solving linear-quadratic problems.

The following L-shaped regularizations are available
- [`NoRegularization`](@ref):  L-shaped algorithm (default)
- [`RegularizedDecomposition`](@ref):  Regularized decomposition ?RegularizedDecomposition for parameter descriptions.
- [`TrustRegion`](@ref):  Trust-region ?TrustRegion for parameter descriptions.
- [`LevelSet`](@ref):  Level-set ?LevelSet for parameter descriptions.

The following aggregation schemes are available
- [`NoAggregation`](@ref):  Multi-cut L-shaped algorithm (default)
- [`PartialAggregation`](@ref):  ?PartialAggregation for parameter descriptions.
- [`FullAggregation`](@ref):  ?FullAggregation for parameter descriptions.
- [`DynamicAggregation`](@ref):  ?DynamicAggregation for parameter descriptions.
- [`ClusterAggregation`](@ref):  ?ClusterAggregation for parameter descriptions.
- [`HybridAggregation`](@ref):  ?HybridAggregation for parameter descriptions.

The following consolidation schemes are available
- [`NoConsolidation`](@ref)
- [`Consolidation`](@ref)

The following execution policies are available
- [`Serial`](@ref):  Classical L-shaped (default)
- [`Synchronous`](@ref): Classical L-shaped run in parallel
- [`Asynchronous`](@ref): Asynchronous L-shaped ?Asynchronous for parameter descriptions.

...
# Arguments
- `lpsolver::AbstractMathProgSolver`: MathProgBase solver capable of solving linear (and possibly quadratic) programs.
- `feasibility_cuts::Bool = false`: Specify if feasibility cuts should be used
- `subsolver::AbstractMathProgSolver = lpsolver`: Optionally specify a different solver for the subproblems.
- `regularize::AbstractRegularizer = DontRegularize()`: Specify regularization procedure (DontRegularize, RegularizedDecomposition/RD/WithRegularizedDecomposition, TrustRegion/TR/WithTrustRegion, LevelSet/LV/WithLevelSets).
- `aggregate::AbstractAggregator = DontAggregate()`: Specify aggregation procedure (DontAggregate, Aggregate, PartialAggregate, DynamicAggregate)
- `consolidate::AbstractConsolidator = DontConsolidate()`: Specify consolidation procedure (DontConsolidate, Consolidate)
- `execution::Execution = Serial`: Specify how algorithm should be executed (Serial, Synchronous, Asynchronous). Distributed variants requires worker cores.
- `crash::CrashMethod = Crash.None`: Crash method used to generate an initial decision. See ?Crash for alternatives.
- <keyword arguments>: Algorithm specific parameters, See `?LShaped` for list of possible arguments and default values.
...

## Examples

The following solves a stochastic program `sp` created in `StochasticPrograms.jl` using the L-shaped algorithm with GLPK as an `lpsolver`.

```jldoctest
julia> optimize!(sp, solver = LShapedSolver(GLPKSolverLP()))
L-Shaped Gap  Time: 0:00:00 (6 iterations)
  Objective:       -855.8333333333339
  Gap:             0.0
  Number of cuts:  8
  Iterations:      6
:Optimal
```
"""
mutable struct LShapedSolver{S <: SubSolver, E <: Execution, R <: AbstractRegularizer, A <: AbstractAggregator, C <: AbstractConsolidator} <: AbstractStructuredSolver
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
                           feasibility_cuts::Bool = false,
                           regularize::AbstractRegularizer = DontRegularize(),
                           aggregate::AbstractAggregator = DontAggregate(),
                           consolidate::AbstractConsolidator = DontConsolidate(),
                           crash::CrashMethod = Crash.None(),
                           subsolver::SubSolver = lpsolver, kwargs...)
        S = typeof(subsolver)
        E = typeof(execution)
        R = typeof(regularize)
        A = typeof(aggregate)
        C = typeof(consolidate)
        return new{S, E, R, A, C}(lpsolver,
                                  subsolver,
                                  feasibility_cuts,
                                  execution,
                                  regularize,
                                  aggregate,
                                  consolidate,
                                  crash,
                                  Dict{Symbol,Any}(kwargs))
    end
end

function StructuredModel(stochasticprogram::StochasticProgram, solver::LShapedSolver)
    x₀ = solver.crash(stochasticprogram, solver.lpsolver)
    return LShaped(stochasticprogram, x₀, solver.lpsolver, get_solver(solver.subsolver), solver.feasibility_cuts, solver.execution, solver.regularize, solver.aggregate, solver.consolidate; solver.parameters...)
end

function add_params!(solver::LShapedSolver; kwargs...)
    push!(solver.parameters, kwargs...)
    for (k,v) in kwargs
        if k ∈ [:variant, :lpsolver, :subsolver, :feasibility_cuts, :execution, :regularize, :aggregate, :crash]
            setfield!(solver, k, v)
            delete!(solver.parameters, k)
        end
    end
    return nothing
end

function add_regularization_params!(solver::LShapedSolver; kwargs...)
    add_regularization_params!(solver.regularize; kwargs...)
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
    return nothing
end

function solverstr(solver::LShapedSolver)
    solver_str = "$(str(solver.execution))$(str(solver.regularize))"
    aggregate_str = str(solver.aggregate)
    if aggregate_str != ""
        return string(solver_str, " with ", aggregate_str)
    else
        return solver_str
    end
end

function solver_complexity(sp, ls)
    optimize!(sp, solver = ls)
    sm = spsolver_model(sp)
    return ncuts(sm)*niterations(sm)
end

function default_choice(given, default, null)
    if default isa null
        return given
    end
    return default
end
