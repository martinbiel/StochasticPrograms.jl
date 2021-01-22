"""
    Optimizer(; <keyword arguments>)

Return an L-shaped optimizer.
...
# Arguments
- `master_optimizer::AbstractOptimizer`: MathOptInterface solver capable of solving linear (and possibly quadratic) programs.
- `subproblem_optimizer::AbstractOptimizer`: Optionally specify a different solver for the subproblems.
- `feasibility_cuts::Bool = false`: Specify if feasibility cuts should be used
- `regularize::AbstractRegularizer = DontRegularize()`: Specify regularization procedure (DontRegularize, RegularizedDecomposition/RD/WithRegularizedDecomposition, TrustRegion/TR/WithTrustRegion, LevelSet/LV/WithLevelSets).
- `aggregate::AbstractAggregator = DontAggregate()`: Specify aggregation procedure (DontAggregate, Aggregate, PartialAggregate, DynamicAggregate, ClusterAggregate, GranulatedAggregate, HybridAggregate)
- `consolidate::AbstractConsolidator = DontConsolidate()`: Specify consolidation procedure (DontConsolidate, Consolidate)
- `execution::Execution = Serial`: Specify how algorithm should be executed (Serial, Synchronous, Asynchronous). Distributed variants requires worker cores.
- <keyword arguments>: Algorithm specific parameters, See `?LShaped` for list of possible arguments and default values.
...
"""
mutable struct Optimizer <: AbstractStructuredOptimizer
    master_optimizer
    subproblem_optimizer
    master_params::Dict{MOI.AbstractOptimizerAttribute, Any}
    sub_params::Dict{MOI.AbstractOptimizerAttribute, Any}
    feasibility_strategy::AbstractFeasibilityStrategy
    integer_strategy::AbstractIntegerStrategy
    execution::AbstractExecution
    regularizer::AbstractRegularizer
    aggregator::AbstractAggregator
    consolidator::AbstractConsolidator
    parameters::LShapedParameters{Float64}

    status::MOI.TerminationStatusCode
    primal_status::MOI.ResultStatusCode
    dual_status::MOI.ResultStatusCode
    raw_status::String
    solve_time::Float64

    lshaped::Union{AbstractLShaped, Nothing}

    function Optimizer(; master_optimizer = nothing,
                       execution::AbstractExecution = nworkers() == 1 ? Serial() : Synchronous(),
                       feasibility_strategy::AbstractFeasibilityStrategy = IgnoreFeasibility(),
                       integer_strategy::AbstractIntegerStrategy = IgnoreIntegers(),
                       regularize::AbstractRegularizer = DontRegularize(),
                       aggregate::AbstractAggregator = DontAggregate(),
                       consolidate::AbstractConsolidator = DontConsolidate(),
                       subproblem_optimizer = nothing, kw...)
        return new(master_optimizer,
                   subproblem_optimizer,
                   Dict{MOI.AbstractOptimizerAttribute, Any}(),
                   Dict{MOI.AbstractOptimizerAttribute, Any}(),
                   feasibility_strategy,
                   integer_strategy,
                   execution,
                   regularize,
                   aggregate,
                   consolidate,
                   LShapedParameters{Float64}(; kw...),
                   MOI.OPTIMIZE_NOT_CALLED,
                   MOI.NO_SOLUTION,
                   MOI.NO_SOLUTION,
                   "L-shaped optimizer has not been run.",
                   NaN,
                   nothing)
    end
end

# Interface #
# ========================== #
function supports_structure(optimizer::Optimizer, ::VerticalStructure)
    return true
end

function default_structure(::UnspecifiedInstantiation, optimizer::Optimizer)
    if optimizer.execution isa Serial && nworkers() == 1
        return Vertical()
    else
        return DistributedVertical()
    end
end

function check_loadable(optimizer::Optimizer, ::VerticalStructure)
    if optimizer.master_optimizer === nothing
        msg = "Master optimizer not set. Consider setting `MasterOptimizer` attribute."
        throw(UnloadableStructure{Optimizer, VerticalStructure}(msg))
    end
    return nothing
end

function ensure_compatible_execution!(optimizer::Optimizer, ::VerticalStructure{2, 1, <:Tuple{ScenarioProblems}})
    if !(optimizer.execution isa Serial)
        @warn "Distributed execution policies are not compatible with a single-core vertical structure. Switching to `Serial` execution by default."
        MOI.set(optimizer, Execution(), Serial())
    end
    return nothing
end

function ensure_compatible_execution!(optimizer::Optimizer, ::VerticalStructure{2, 1, <:Tuple{DistributedScenarioProblems}})
    if optimizer.execution isa Serial
        @warn "Serial execution not compatible with distributed vertical structure. Switching to `Synchronous` execution by default."
        MOI.set(optimizer, Execution(), Synchronous())
    end
    return nothing
end

function load_structure!(optimizer::Optimizer, structure::VerticalStructure, x₀::AbstractVector)
    # Sanity check
    check_loadable(optimizer, structure)
    # Default subproblem optimizer to master optimizer if
    # none have been set
    if optimizer.subproblem_optimizer === nothing
        StochasticPrograms.set_subproblem_optimizer!(structure, optimizer.master_optimizer)
    end
    if optimizer.integer_strategy isa Convexification && optimizer.integer_strategy.parameters.optimizer === nothing
        optimizer.integer_strategy.parameters.optimizer = MOI.OptimizerWithAttributes(optimizer.subproblem_optimizer, collect(optimizer.sub_params))
    end
    # Restore structure if optimization has been run before
    restore_structure!(optimizer)
    # Ensure that execution policy is compatible
    ensure_compatible_execution!(optimizer, structure)
    # Create new L-shaped algorithm
    optimizer.lshaped = LShapedAlgorithm(structure,
                                         x₀,
                                         optimizer.feasibility_strategy,
                                         optimizer.integer_strategy,
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

function MOI.optimize!(optimizer::Optimizer)
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    start_time = time()
    optimizer.status = optimizer.lshaped()
    if optimizer.status == MOI.OPTIMAL
        optimizer.primal_status = MOI.FEASIBLE_POINT
        optimizer.dual_status = MOI.FEASIBLE_POINT
        optimizer.raw_status = "L-shaped procedure converged to optimal solution."
    end
    optimizer.solve_time = time() - start_time
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
    if optimizer.master_optimizer === nothing
        return nothing
    end
    return MOI.OptimizerWithAttributes(optimizer.master_optimizer, collect(optimizer.master_params))
end

function MOI.set(optimizer::Optimizer, ::MasterOptimizer, optimizer_constructor)
    optimizer.master_optimizer = optimizer_constructor
    # Clear any old parameters
    empty!(optimizer.master_params)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::MasterOptimizerAttribute, attr::MOI.AbstractOptimizerAttribute)
    if !haskey(optimizer.master_params, attr)
        error("Master optimizer attribute $(attr) has not been set.")
    end
    return optimizer.master_params[attr]
end

function MOI.set(optimizer::Optimizer, ::MasterOptimizerAttribute, attr::MOI.AbstractOptimizerAttribute, value)
    optimizer.master_params[attr] = value
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
    return nothing
end

function MOI.get(optimizer::Optimizer, ::SubproblemOptimizer)
    if optimizer.subproblem_optimizer === nothing
        return MOI.get(optimizer, MasterOptimizer())
    end
    return MOI.OptimizerWithAttributes(optimizer.subproblem_optimizer, collect(optimizer.sub_params))
end

function MOI.set(optimizer::Optimizer, ::SubproblemOptimizer, optimizer_constructor)
    optimizer.subproblem_optimizer = optimizer_constructor
    # Clear any old parameters
    empty!(optimizer.sub_params)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::SubproblemOptimizerAttribute, attr::MOI.AbstractOptimizerAttribute)
    if !haskey(optimizer.sub_params, attr)
        error("Subproblem optimizer attribute $(attr) has not been set.")
    end
    return optimizer.sub_params[attr]
end

function MOI.set(optimizer::Optimizer, ::SubproblemOptimizerAttribute, attr::MOI.AbstractOptimizerAttribute, value)
    optimizer.sub_params[attr] = value
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
    return nothing
end

function MOI.get(optimizer::Optimizer, ::FeasibilityStrategy)
    return optimizer.feasibility_strategy
end

function MOI.set(optimizer::Optimizer, ::FeasibilityStrategy, strategy::AbstractFeasibilityStrategy)
    optimizer.feasibility_strategy = strategy
    return nothing
end

function MOI.get(optimizer::Optimizer, ::IntegerStrategy)
    return optimizer.integer_strategy
end

function MOI.set(optimizer::Optimizer, ::IntegerStrategy, strategy::AbstractIntegerStrategy)
    optimizer.integer_strategy = strategy
    return nothing
end

function MOI.get(optimizer::Optimizer, ::Execution)
    return optimizer.execution
end

function MOI.set(optimizer::Optimizer, ::Execution, execution::AbstractExecution)
    optimizer.execution = execution
    return nothing
end

function MOI.get(optimizer::Optimizer, ::Regularizer)
    return optimizer.regularizer
end

function MOI.set(optimizer::Optimizer, ::Regularizer, regularizer::AbstractRegularizer)
    optimizer.regularizer = regularizer
    return nothing
end

function MOI.get(optimizer::Optimizer, ::Aggregator)
    return optimizer.aggregator
end

function MOI.set(optimizer::Optimizer, ::Aggregator, aggregator::AbstractAggregator)
    optimizer.aggregator = aggregator
    return nothing
end

function MOI.get(optimizer::Optimizer, ::Consolidator)
    return optimizer.consolidator
end

function MOI.set(optimizer::Optimizer, ::Consolidator, consolidator::AbstractConsolidator)
    optimizer.consolidator = consolidator
    return nothing
end

function MOI.get(optimizer::Optimizer, param::ExecutionParameter)
    return MOI.get(optimizer.execution, param)
end

function MOI.set(optimizer::Optimizer, param::ExecutionParameter, value)
    MOI.set(optimizer.execution, param, value)
    return nothing
end

function MOI.get(optimizer::Optimizer, param::RegularizationParameter)
    return MOI.get(optimizer.regularizer, param)
end

function MOI.set(optimizer::Optimizer, param::RegularizationParameter, value)
    MOI.set(optimizer.regularizer, param, value)
    return nothing
end

function MOI.get(optimizer::Optimizer, param::AggregationParameter)
    return MOI.get(optimizer.aggregator, param)
end

function MOI.set(optimizer::Optimizer, param::AggregationParameter, value)
    MOI.set(optimizer.aggregator, param, value)
    return nothing
end

function MOI.get(optimizer::Optimizer, param::ConsolidationParameter)
    return MOI.get(optimizer.consolidator, param)
end

function MOI.set(optimizer::Optimizer, param::ConsolidationParameter, value)
    MOI.set(optimizer.consolidator, param, value)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::MOI.TerminationStatus)
    return optimizer.status
end

function MOI.get(optimizer::Optimizer, ::MOI.PrimalStatus)
    return optimizer.primal_status
end

function MOI.get(optimizer::Optimizer, ::MOI.DualStatus)
    return optimizer.dual_status
end

function MOI.get(optimizer::Optimizer, ::MOI.RawStatusString)
    return optimizer.raw_status
end

function MOI.get(optimizer::Optimizer, attr::MOI.ListOfVariableIndices)
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    list = MOI.get(optimizer.lshaped.structure, attr)
    # Remove the master variables
    filter!(vi -> !(vi in optimizer.lshaped.master_variables), list)
    # Remove any auxiliary variables from regularization
    filter_variables!(optimizer.lshaped.regularization, list)
    return list
end

function MOI.get(optimizer::Optimizer, ::MOI.VariablePrimal, index::MOI.VariableIndex)
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return decision(optimizer.lshaped, index)
end

function MOI.get(optimizer::Optimizer, attr::MOI.ListOfConstraintIndices)
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    list = MOI.get(optimizer.lshaped.structure, attr)
    # Remove any cut constraints
    filter_cuts!(optimizer.lshaped, list)
    # Remove any penaltyterm constraints
    filter_constraints!(optimizer.lshaped.regularization, list)
    return list
end

function MOI.get(optimizer::Optimizer, ::MOI.ObjectiveValue)
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return objective_value(optimizer.lshaped)
end

function MOI.get(optimizer::Optimizer, ::MOI.SolveTime)
    return optimizer.solve_time
end

function MOI.get(optimizer::Optimizer, attr::Union{MOI.AbstractOptimizerAttribute, MOI.AbstractModelAttribute})
    # Fallback to first-stage optimizer through structure
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.lshaped.structure, attr)
end

function MOI.get(optimizer::Optimizer, attr::MOI.AbstractConstraintAttribute, ci::MOI.ConstraintIndex)
    # Fallback to first-stage optimizer through structure
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.lshaped.structure, attr, ci)
end

function MOI.set(optimizer::Optimizer, attr::Union{MOI.AbstractOptimizerAttribute, MOI.AbstractModelAttribute}, value)
    # Fallback to first-stage optimizer through structure
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.lshaped.structure, attr, value)
end

function MOI.set(optimizer::Optimizer, attr::MOI.AbstractVariableAttribute, index::MOI.VariableIndex, value)
    # Fallback to first-stage optimizer through structure
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.lshaped.structure, attr, index, value)
end

function MOI.set(optimizer::Optimizer, attr::MOI.AbstractConstraintAttribute, ci::MOI.ConstraintIndex, value)
    # Fallback to first-stage optimizer through structure
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.lshaped.structure, attr, ci, value)
end

function MOI.get(optimizer::Optimizer, attr::ScenarioDependentModelAttribute)
    # Fallback to subproblem optimizer through structure
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.lshaped.structure, attr)
end

function MOI.get(optimizer::Optimizer, attr::ScenarioDependentVariableAttribute, index::MOI.VariableIndex)
    # Fallback to subproblem optimizer through structure
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.lshaped.structure, attr, index)
end

function MOI.get(optimizer::Optimizer, attr::ScenarioDependentConstraintAttribute, ci::MOI.ConstraintIndex)
    # Fallback to subproblem optimizer through structure
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.lshaped.structure, attr, ci)
end

function MOI.set(optimizer::Optimizer, attr::ScenarioDependentModelAttribute, value)
    # Fallback to subproblem optimizer through structure
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.lshaped.structure, attr, value)
end

function MOI.set(optimizer::Optimizer, attr::ScenarioDependentVariableAttribute, index::MOI.VariableIndex, value)
    # Fallback to subproblem optimizer through structure
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.lshaped.structure, attr, index, value)
end

function MOI.set(optimizer::Optimizer, attr::ScenarioDependentVariableAttribute, ci::MOI.ConstraintIndex, value)
    # Fallback to subproblem optimizer through structure
    if optimizer.lshaped === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.lshaped.structure, attr, ci, value)
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
"""
    get_regularization_attribute(stochasticprogram::StochasticProgram, name::String)

Return the value associated with the regularization-specific attribute named `name` in `stochasticprogram`.

See also: [`set_regularization_attribute`](@ref), [`set_regularization_attributes`](@ref).
"""
function get_regularization_attribute(stochasticprogram::StochasticProgram, name::String)
    return return MOI.get(optimizer(stochasticprogram), RawRegularizationParameter(name))
end
"""
    set_regularization_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)

Sets the regularization-specific attribute identified by `name` to `value`.

"""
function set_regularization_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawRegularizationParameter(String(name)), value)
end
"""
    set_regularization_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)

Given a list of `attribute => value` pairs or a collection of keyword arguments, calls
`set_regularization_attribute(stochasticprogram, attribute, value)` for each pair.

"""
function set_regularization_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_regularization_attribute(stochasticprogram, name, value)
    end
end
function set_regularization_attributes(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_regularization_attribute(stochasticprogram, name, value)
    end
end
"""
    get_aggregation_attribute(stochasticprogram::StochasticProgram, name::String)

Return the value associated with the aggregation-specific attribute named `name` in `stochasticprogram`.

See also: [`set_aggregation_attribute`](@ref), [`set_aggregation_attributes`](@ref).
"""
function get_aggregation_attribute(stochasticprogram::StochasticProgram, name::String)
    return MOI.get(optimizer(stochasticprogram), RawAggregationParameter(name))
end
"""
    set_aggregation_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)

Sets the aggregation-specific attribute identified by `name` to `value`.

"""
function set_aggregation_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawAggregationParameter(String(name)), value)
end
"""
    set_aggregation_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)

Given a list of `attribute => value` pairs or a collection of keyword arguments, calls
`set_aggregation_attribute(stochasticprogram, attribute, value)` for each pair.

"""
function set_aggregation_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_aggregation_attribute(stochasticprogram, name, value)
    end
end
function set_aggregation_attributes(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_aggregation_attribute(stochasticprogram, name, value)
    end
end
"""
    get_consolidation_attribute(stochasticprogram::StochasticProgram, name::String)

Return the value associated with the consolidation-specific attribute named `name` in `stochasticprogram`.

See also: [`set_consolidation_attribute`](@ref), [`set_consolidation_attributes`](@ref).
"""
function get_consolidation_attribute(stochasticprogram::StochasticProgram, name::String)
    return return MOI.get(optimizer(stochasticprogram), RawConsolidationParameter(name))
end
"""
    set_consolidation_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)

Sets the consolidation-specific attribute identified by `name` to `value`.

"""
function set_consolidation_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawConsolidationParameter(String(name)), value)
end
"""
    set_consolidation_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)

Given a list of `attribute => value` pairs or a collection of keyword arguments, calls
`set_consolidation_attribute(stochasticprogram, attribute, value)` for each pair.

"""
function set_consolidation_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_consolidation_attribute(stochasticprogram, name, value)
    end
end
function set_consolidation_attributes(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_consolidation_attribute(stochasticprogram, name, value)
    end
end
