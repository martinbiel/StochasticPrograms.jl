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
julia> optimize!(sp, solver = LShaped.Optimizer(GLPKSolverLP()))
L-Shaped Gap  Time: 0:00:00 (6 iterations)
  Objective:       -855.8333333333339
  Gap:             0.0
  Number of cuts:  8
  Iterations:      6
:Optimal
```
"""
mutable struct Optimizer <: AbstractStructuredOptimizer
    master_optimizer
    subproblem_optimizer
    master_params::Dict{MOI.AbstractOptimizerAttribute, Any}
    sub_params::Dict{MOI.AbstractOptimizerAttribute, Any}
    feasibility_cuts::Bool
    execution::AbstractExecution
    regularizer::AbstractRegularizer
    aggregator::AbstractAggregator
    consolidator::AbstractConsolidator
    parameters::LShapedParameters{Float64}

    status::MOI.TerminationStatusCode

    lshaped::Union{AbstractLShaped, Nothing}

    function Optimizer(; master_optimizer = nothing,
                       execution::AbstractExecution = nworkers() == 1 ? Serial() : Synchronous(),
                       feasibility_cuts::Bool = false,
                       regularize::AbstractRegularizer = DontRegularize(),
                       aggregate::AbstractAggregator = DontAggregate(),
                       consolidate::AbstractConsolidator = DontConsolidate(),
                       subproblem_optimizer = nothing, kw...)
        return new(master_optimizer,
                   subproblem_optimizer,
                   Dict{MOI.AbstractOptimizerAttribute, Any}(),
                   Dict{MOI.AbstractOptimizerAttribute, Any}(),
                   feasibility_cuts,
                   execution,
                   regularize,
                   aggregate,
                   consolidate,
                   LShapedParameters{Float64}(; kw...),
                   MOI.OPTIMIZE_NOT_CALLED,
                   nothing)
    end
end

# Interface #
# ========================== #
function supports_structure(optimizer::Optimizer, ::VerticalBlockStructure{2, 1, <:Tuple{ScenarioProblems}})
    if optimizer.execution isa Serial
        return true
    end
    @warn "Distributed execution policies are not compatible with a single-core vertical structure. Consider setting the execution policy to `Serial` or re-instantiate the stochastic program on worker cores."
    return false
end

function supports_structure(optimizer::Optimizer, ::VerticalBlockStructure{2, 1, <:Tuple{DistributedScenarioProblems}})
    if optimizer.execution isa Serial
        @warn "Serial execution not compatible with distributed vertical structure. Consider setting the execution policy to `Synchronous` or `Asynchronous` or re-instantiate the stochastic program on a single core."
        return false
    end
    return true
end

function default_structure(::UnspecifiedInstantiation, optimizer::Optimizer)
    if optimizer.execution isa Serial && nworkers() == 1
        return BlockVertical()
    else
        return DistributedBlockVertical()
    end
end

function check_loadable(optimizer::Optimizer, ::VerticalBlockStructure)
    if optimizer.master_optimizer === nothing
        msg = "Master optimizer not set. Consider setting `MasterOptimizer` attribute."
        throw(UnloadableStructure{Optimizer, VerticalBlockStructure}(msg))
    end
    return nothing
end

function load_structure!(optimizer::Optimizer, structure::VerticalBlockStructure, x₀::AbstractVector)
    # Sanity check
    check_loadable(optimizer, structure)
    # Default subproblem optimizer to master optimizer if
    # none have been set
    if optimizer.subproblem_optimizer === nothing
        StochasticPrograms.set_subproblem_optimizer!(structure, optimizer.master_optimizer)
    end
    # Restore structure if optimization has been run before
    restore_structure!(optimizer)
    # Create new L-shaped algorithm
    optimizer.lshaped = LShapedAlgorithm(structure,
                                         x₀,
                                         optimizer.feasibility_cuts,
                                         optimizer.execution,
                                         optimizer.regularizer,
                                         optimizer.aggregator,
                                         optimizer.consolidator;
                                         type2dict(optimizer.parameters)...)
    # Set any given master/sub optimizer attributes
    for (attr, value) in optimizer.master_params
        MOI.set(optimizer.lshaped.master, attr, value)
    end
    for (attr, value) in optimizer.sub_params
        MOI.set(scenarioproblems(optimizer.lshaped.structure), attr, value)
    end
    return nothing
end

function restore_structure!(optimizer::Optimizer)
    if optimizer.lshaped !== nothing
        restore_master!(optimizer.lshaped)
        restore_subproblems!(optimizer.lshaped)
    end
    return nothing
end

function reload_structure!(optimizer::Optimizer)
    if optimizer.lshaped !== nothing
        x₀ = copy(optimizer.lshaped.x)
        structure = optimizer.lshaped.structure
        restore_structure!(optimizer)
        load_structure!(optimizer, structure, x₀)
    end
    return nothing
end

function MOI.optimize!(optimizer::Optimizer)
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    optimizer.status = optimizer.lshaped()
    return nothing
end

function optimizer_name(optimizer::Optimizer)
    optimizer_str = "$(str(optimizer.execution))$(str(optimizer.regularizer))"
    aggregate_str = str(optimizer.aggregator)
    if aggregate_str != ""
        return string(optimizer_str, " with ", aggregate_str)
    else
        return optimizer_str
    end
end

# MOI #
# ========================== #
function MOI.get(optimizer::Optimizer, ::MOI.Silent)
    return !MOI.get(optimizer, MOI.RawParameter("log"))
end

function MOI.set(optimizer::Optimizer, attr::MOI.Silent, flag::Bool)
    MOI.set(optimizer, MOI.RawParameter("log"), !flag)
    optimizer.master_params[attr] = flag
    optimizer.sub_params[attr] = flag
    if optimizer.lshaped != nothing
        MOI.set(optimizer.lshaped.master, attr, flag)
        MOI.set(scenarioproblems(optimizer.lshaped.structure), attr, flag)
    end
    return nothing
end

function MOI.get(optimizer::Optimizer, param::MOI.RawParameter)
    name = Symbol(param.name)
    if !(name in fieldnames(LShapedParameters))
        error("Unrecognized parameter name: $(name).")
    end
    return getfield(optimizer.parameters, name)
end

function MOI.set(optimizer::Optimizer, param::MOI.RawParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(LShapedParameters))
        error("Unrecognized parameter name: $(name).")
    end
    setfield!(optimizer.parameters, name, value)
    if optimizer.lshaped != nothing
        setfield!(optimizer.lshaped.parameters, name, value)
    end
    return nothing
end

function MOI.get(optimizer::Optimizer, ::MOI.TimeLimitSec)
    limit = MOI.get(optimizer, MOI.RawParameter("time_limit"))
    return isinf(limit) ? nothing : limit
end

function MOI.set(optimizer::Optimizer, ::MOI.TimeLimitSec, limit::Union{Real, Nothing})
    limit = limit === nothing ? Inf : limit
    MOI.set(optimizer, MOI.RawParameter("time_limit"), limit)
    return
end

function MOI.get(optimizer::Optimizer, ::RelativeTolerance)
    return MOI.get(optimizer, MOI.RawParameter("τ"))
end

function MOI.set(optimizer::Optimizer, ::RelativeTolerance, limit::Real)
    MOI.set(optimizer, MOI.RawParameter("τ"), limit)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::MasterOptimizer)
    return optimizer.master_optimizer
end

function MOI.set(optimizer::Optimizer, ::MasterOptimizer, optimizer_constructor)
    optimizer.master_optimizer = optimizer_constructor
    # Trigger reload
    reload_structure!(optimizer)
    return nothing
end

function MOI.get(optimizer::Optimizer, param::RawMasterOptimizerParameter)
    moi_param = MOI.RawParameter(param.name)
    if !haskey(optimizer.master_params, moi_param)
        error("Master optimizer attribute $(param.name) has not been set.")
    end
    return optimizer.master_params[moi_param]
end

function MOI.set(optimizer::Optimizer, param::RawMasterOptimizerParameter, value)
    moi_param = MOI.RawParameter(param.name)
    optimizer.master_params[moi_param] = value
    if optimizer.lshaped != nothing
        MOI.set(optimizer.lshaped.master, moi_param, value)
    end
    return nothing
end

function MOI.get(optimizer::Optimizer, ::SubproblemOptimizer)
    if optimizer.subproblem_optimizer === nothing
        return optimizer.master_optimizer
    end
    return optimizer.subproblem_optimizer
end

function MOI.set(optimizer::Optimizer, ::SubproblemOptimizer, optimizer_constructor)
    optimizer.subproblem_optimizer = optimizer_constructor
    # Trigger reload
    reload_structure!(optimizer)
    return nothing
end

function MOI.get(optimizer::Optimizer, param::RawSubproblemOptimizerParameter)
    moi_param = MOI.RawParameter(param.name)
    if !haskey(optimizer.sub_params, moi_param)
        error("Subproblem optimizer attribute $(param.name) has not been set.")
    end
    return optimizer.sub_params[moi_param]
end

function MOI.set(optimizer::Optimizer, param::RawSubproblemOptimizerParameter, value)
    moi_param = MOI.RawParameter(param.name)
    optimizer.sub_params[moi_param] = value
    if optimizer.lshaped != nothing
        MOI.set(scenarioproblems(optimizer.lshaped.structure), attr, flag)
    end
    return nothing
end

function MOI.get(optimizer::Optimizer, ::FeasibilityCuts)
    return optimizer.feasibility_cuts
end

function MOI.set(optimizer::Optimizer, ::FeasibilityCuts, use_feasibility_cuts)
    optimizer.feasibility_cuts = use_feasibility_cuts
    # Trigger reload
    reload_structure!(optimizer)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::Execution)
    return optimizer.execution
end

function MOI.set(optimizer::Optimizer, ::Execution, execution::AbstractExecution)
    optimizer.execution = execution
    # Trigger reload
    reload_structure!(optimizer)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::Regularizer)
    return optimizer.regularizer
end

function MOI.set(optimizer::Optimizer, ::Regularizer, regularizer::AbstractRegularizer)
    optimizer.regularizer = regularizer
    # Trigger reload
    reload_structure!(optimizer)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::Aggregator)
    return optimizer.aggregator
end

function MOI.set(optimizer::Optimizer, ::Aggregator, aggregator::AbstractAggregator)
    optimizer.aggregator = aggregator
    # Trigger reload
    reload_structure!(optimizer)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::Consolidator)
    return optimizer.consolidator
end

function MOI.set(optimizer::Optimizer, ::Consolidator, consolidator::AbstractConsolidator)
    optimizer.consolidator = consolidator
    # Trigger reload
    reload_structure!(optimizer)
    return nothing
end

function MOI.get(optimizer::Optimizer, param::ExecutionParameter)
    return MOI.get(optimizer.execution, param)
end

function MOI.set(optimizer::Optimizer, param::ExecutionParameter, value)
    MOI.set(optimizer.execution, param, value)
    # Trigger reload
    reload_structure!(optimizer)
    return nothing
end

function MOI.get(optimizer::Optimizer, param::RegularizationParameter)
    return MOI.get(optimizer.regularizer, param)
end

function MOI.set(optimizer::Optimizer, param::RegularizationParameter, value)
    MOI.set(optimizer.regularizer, param, value)
    # Trigger reload
    reload_structure!(optimizer)
    return nothing
end

function MOI.get(optimizer::Optimizer, param::AggregationParameter)
    return MOI.get(optimizer.aggregator, param)
end

function MOI.set(optimizer::Optimizer, param::AggregationParameter, value)
    MOI.set(optimizer.aggregator, param, value)
    # Trigger reload
    reload_structure!(optimizer)
    return nothing
end

function MOI.get(optimizer::Optimizer, param::ConsolidationParameter)
    return MOI.get(optimizer.consolidator, param)
end

function MOI.set(optimizer::Optimizer, param::ConsolidationParameter, value)
    MOI.set(optimizer.consolidator, param, value)
    # Trigger reload
    reload_structure!(optimizer)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::MOI.TerminationStatus)
    return optimizer.status
end

function MOI.get(optimizer::Optimizer, ::MOI.VariablePrimal, index::MOI.VariableIndex)
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return decision(optimizer.lshaped, index)
end

function MOI.get(optimizer::Optimizer, ::MOI.ObjectiveValue)
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return objective_value(optimizer.lshaped)
end

function MOI.is_empty(optimizer::Optimizer)
    return optimizer.lshaped === nothing
end

MOI.supports(::Optimizer, ::MOI.Silent) = true
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true
MOI.supports(::Optimizer, ::MOI.RawParameter) = true
MOI.supports(::Optimizer, ::AbstractStructuredOptimizerAttribute) = true
MOI.supports(::Optimizer, ::RawInstanceOptimizerParameter) = true
MOI.supports(::Optimizer, ::AbstractLShapedAttribute) = true

# High-level attribute setting #
# ========================== #
function set_regularization_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawRegularizationParameter(String(name)), value)
end
function set_regularization_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_regularization_attributes(stochasticprogram, name, value)
    end
end
function set_regularization_attribute(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_regularization_attributes(stochasticprogram, name, value)
    end
end
function set_aggregation_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawAggregationParameter(String(name)), value)
end
function set_aggregation_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_aggregation_attributes(stochasticprogram, name, value)
    end
end
function set_aggregation_attribute(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_aggregation_attributes(stochasticprogram, name, value)
    end
end
function set_consolidation_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawConsolidationParameter(String(name)), value)
end
function set_consolidation_attribute(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_consolidation_attributes(stochasticprogram, name, value)
    end
end
function set_consolidation_attribute(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_consolidation_attributes(stochasticprogram, name, value)
    end
end
