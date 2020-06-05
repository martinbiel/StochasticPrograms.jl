"""
    Optimizer(lpsolver::AbstractMathProgSolver; <keyword arguments>)

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
julia> optimize!(sp, solver = Optimizer(GLPKSolverLP()))
L-Shaped Gap  Time: 0:00:00 (6 iterations)
  Objective:       -855.8333333333339
  Gap:             0.0
  Number of cuts:  8
  Iterations:      6
:Optimal
```
"""
mutable struct Optimizer{E <: Execution, R <: AbstractRegularizer, A <: AbstractAggregator, C <: AbstractConsolidator} <: AbstractStructuredOptimizer
    optimizer
    suboptimizer
    feasibility_cuts::Bool
    execution::E
    regularize::R
    aggregate::A
    consolidate::C
    parameters::Dict{Symbol, Any}

    status::MOI.TerminationStatusCode
    lshaped::Union{AbstractLShaped, Nothing}

    function Optimizer(optimizer;
                       execution::Execution = Serial(),
                       feasibility_cuts::Bool = false,
                       regularize::AbstractRegularizer = DontRegularize(),
                       aggregate::AbstractAggregator = DontAggregate(),
                       consolidate::AbstractConsolidator = DontConsolidate(),
                       suboptimizer = optimizer, kwargs...)
        E = typeof(execution)
        R = typeof(regularize)
        A = typeof(aggregate)
        C = typeof(consolidate)
        return new{E, R, A, C}(optimizer,
                               suboptimizer,
                               feasibility_cuts,
                               execution,
                               regularize,
                               aggregate,
                               consolidate,
                               Dict{Symbol,Any}(kwargs),
                               MOI.OPTIMIZE_NOT_CALLED,
                               nothing)
    end
end

# Interface #
# ========================== #
function supports_structure(::Optimizer, ::VerticalBlockStructure)
    return true
end

function default_structure(::UnspecifiedInstantiation, ::Optimizer)
    return BlockVertical()
end

function load_structure!(optimizer::Optimizer, structure::VerticalBlockStructure, x₀::AbstractVector)
    restore_structure!(optimizer)
    optimizer.lshaped = LShapedAlgorithm(structure,
                                         x₀,
                                         optimizer.feasibility_cuts,
                                         optimizer.execution,
                                         optimizer.regularize,
                                         optimizer.aggregate,
                                         optimizer.consolidate;
                                         optimizer.parameters...)
    return nothing
end

function restore_structure!(optimizer::Optimizer)
    if optimizer.lshaped !== nothing
        restore_master!(optimizer.lshaped)
        restore_subproblems!(optimizer.lshaped)
    end
    return nothing
end

function MOI.optimize!(optimizer::Optimizer)
    if optimizer.lshaped === nothing
        throw(StochasticProgram.UnloadedStructure{Optimizer}())
    end
    optimizer.status = optimizer.lshaped()
    return nothing
end

function optimizer_name(optimizer::Optimizer)
    optimizer_str = "$(str(optimizer.execution))$(str(optimizer.regularize))"
    aggregate_str = str(optimizer.aggregate)
    if aggregate_str != ""
        return string(optimizer_str, " with ", aggregate_str)
    else
        return optimizer_str
    end
end

function master_optimizer(optimizer::Optimizer)
    return optimizer.optimizer
end

function sub_optimizer(optimizer::Optimizer)
    return optimizer.suboptimizer
end

# MOI #
# ========================== #
function MOI.get(optimizer::Optimizer, ::MOI.TerminationStatus)
    return optimizer.status
end

function MOI.get(optimizer::Optimizer, ::MOI.VariablePrimal, index::MOI.VariableIndex)
    if optimizer.lshaped === nothing
        throw(StochasticProgram.UnloadedStructure{Optimizer}())
    end
    return decision(optimizer.lshaped, index)
end

function MOI.get(optimizer::Optimizer, ::MOI.ObjectiveValue)
    if optimizer.lshaped === nothing
        throw(StochasticProgram.UnloadedStructure{Optimizer}())
    end
    return objective_value(optimizer.lshaped)
end

function MOI.is_empty(optimizer::Optimizer)
    return optimizer.lshaped === nothing
end

# ========================== #
function add_params!(optimizer::Optimizer; kwargs...)
    push!(optimizer.parameters, kwargs...)
    for (k,v) in kwargs
        if k ∈ [:optimizer, :suboptimizer, :feasibility_cuts, :execution, :regularize, :aggregate]
            setfield!(solver, k, v)
            delete!(solver.parameters, k)
        end
    end
    return nothing
end

function add_regularization_params!(solver::Optimizer; kwargs...)
    add_regularization_params!(solver.regularize; kwargs...)
end

function default_choice(given, default, null)
    if default isa null
        return given
    end
    return default
end
