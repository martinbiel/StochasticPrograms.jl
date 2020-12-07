"""
    Optimizer(; <keyword arguments>)

Return a progressive-hedging optimizer.

...
# Arguments
- `subproblem_optimizer::AbstractOptimizer`: MathOptInterface solver capable of solving quadratic programs.
- `penalty::AbstractPenalizer = Fixed()`: Specify penalty update procedure (Fixed, Adaptive)
- `execution::AbstractExecuter = Serial`: Specify how algorithm should be executed (Serial, Synchronous, Asynchronous). Distributed variants requires worker cores.
- `penaltyterm::PenaltyTerm = Quadratic`: Specify penaltyterm variant ([`Quadratic`](@ref), [`Linearized`](@ref), [`InfNorm`](@ref), [`ManhattanNorm`][@ref])
- <keyword arguments>: Algorithm specific parameters, consult individual docstrings (see above list) for list of possible arguments and default values.
...
"""
mutable struct Optimizer <: AbstractStructuredOptimizer
    subproblem_optimizer
    sub_params::Dict{MOI.AbstractOptimizerAttribute, Any}
    execution::AbstractExecution
    penalizer::AbstractPenalizer
    penaltyterm::AbstractPenaltyterm
    parameters::ProgressiveHedgingParameters{Float64}

    status::MOI.TerminationStatusCode
    primal_status::MOI.ResultStatusCode
    dual_status::MOI.ResultStatusCode
    raw_status::String
    solve_time::Float64
    progressivehedging::Union{AbstractProgressiveHedging, Nothing}

    function Optimizer(; subproblem_optimizer = nothing,
                       execution::AbstractExecution = nworkers() == 1 ? Serial() : Synchronous(),
                       penalty::AbstractPenalizer = Fixed(),
                       penaltyterm::AbstractPenaltyterm = Quadratic(),
                       kw...)
        return new(subproblem_optimizer,
                   Dict{MOI.AbstractOptimizerAttribute, Any}(),
                   execution,
                   penalty,
                   penaltyterm,
                   ProgressiveHedgingParameters{Float64}(; kw...),
                   MOI.OPTIMIZE_NOT_CALLED,
                   MOI.NO_SOLUTION,
                   MOI.NO_SOLUTION,
                   "Progressive-hedging optimizer has not been run.",
                   NaN,
                   nothing)
    end
end

# Interface #
# ========================== #
function supports_structure(optimizer::Optimizer, ::HorizontalStructure)
    return true
end

function default_structure(::UnspecifiedInstantiation, optimizer::Optimizer)
    if optimizer.execution isa Serial && nworkers() == 1
        return Horizontal()
    else
        return DistributedHorizontal()
    end
end

function check_loadable(optimizer::Optimizer, ::HorizontalStructure)
    if optimizer.subproblem_optimizer === nothing
        msg = "Subproblem optimizer not set. Consider setting `SubproblemOptimizer` attribute."
        throw(UnloadableStructure{Optimizer, HorizontalStructure}(msg))
    end
    return nothing
end

function ensure_compatible_execution!(optimizer::Optimizer, ::HorizontalStructure{2, 1, <:Tuple{ScenarioProblems}})
    if !(optimizer.execution isa Serial)
        @warn "Distributed execution policies are not compatible with a single-core horizontal structure. Switching to `Serial` execution by default."
        MOI.set(optimizer, Execution(), Serial())
    end
    return nothing
end

function ensure_compatible_execution!(optimizer::Optimizer, ::HorizontalStructure{2, 1, <:Tuple{DistributedScenarioProblems}})
    if optimizer.execution isa Serial
        @warn "Serial execution not compatible with distributed horizontal structure. Switching to `Synchronous` execution by default."
        MOI.set(optimizer, Execution(), Synchronous())
    end
    return nothing
end

function load_structure!(optimizer::Optimizer, structure::HorizontalStructure, x₀::AbstractVector)
    # Sanity check
    check_loadable(optimizer, structure)
    # Restore structure if optimization has been run before
    restore_structure!(optimizer)
    # Ensure that execution policy is compatible
    ensure_compatible_execution!(optimizer, structure)
    # Create new progressive-hedging algorithm
    optimizer.progressivehedging = ProgressiveHedgingAlgorithm(structure,
                                                               x₀,
                                                               optimizer.execution,
                                                               optimizer.penalizer,
                                                               optimizer.penaltyterm;
                                                               type2dict(optimizer.parameters)...)
    for (attr, value) in optimizer.sub_params
        MOI.set(scenarioproblems(optimizer.progressivehedging.structure), attr, value)
    end
    return nothing
end

function restore_structure!(optimizer::Optimizer)
    if optimizer.progressivehedging !== nothing
        restore_subproblems!(optimizer.progressivehedging)
    end
    return nothing
end

function MOI.optimize!(optimizer::Optimizer)
    if optimizer.progressivehedging === nothing
        throw(StochasticProgram.UnloadedStructure{Optimizer}())
    end
    start_time = time()
    optimizer.status = optimizer.progressivehedging()
    if optimizer.status == MOI.OPTIMAL
        optimizer.primal_status = MOI.FEASIBLE_POINT
        optimizer.dual_status = MOI.FEASIBLE_POINT
        optimizer.raw_status = "Progressive-hedging procedure converged to optimal solution."
    end
    optimizer.solve_time = time() - start_time
    return nothing
end

function optimizer_name(optimizer::Optimizer)
    return "$(str(optimizer.execution))Progressive-hedging with $(str(optimizer.penalizer))"
end

# MOI #
# ========================== #
function MOI.get(optimizer::Optimizer, ::MOI.Silent)
    return !MOI.get(optimizer, MOI.RawParameter("log"))
end

function MOI.set(optimizer::Optimizer, attr::MOI.Silent, flag::Bool)
    MOI.set(optimizer, MOI.RawParameter("log"), !flag)
    optimizer.sub_params[attr] = flag
    return nothing
end

function MOI.get(optimizer::Optimizer, param::MOI.RawParameter)
    name = Symbol(param.name)
    if !(name in fieldnames(ProgressiveHedgingParameters))
        error("Unrecognized parameter name: $(name).")
    end
    return getfield(optimizer.parameters, name)
end

function MOI.set(optimizer::Optimizer, param::MOI.RawParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(ProgressiveHedgingParameters))
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

function MOI.get(optimizer::Optimizer, ::PrimalTolerance)
    return MOI.get(optimizer, MOI.RawParameter("ϵ₁"))
end

function MOI.set(optimizer::Optimizer, ::PrimalTolerance, limit::Real)
    MOI.set(optimizer, MOI.RawParameter("ϵ₁"), limit)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::DualTolerance)
    return MOI.get(optimizer, MOI.RawParameter("ϵ₂"))
end

function MOI.set(optimizer::Optimizer, ::DualTolerance, limit::Real)
    MOI.set(optimizer, MOI.RawParameter("ϵ₂"), limit)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::MasterOptimizer)
    return MOI.get(optimizer, SubproblemOptimizer())
end

function MOI.get(optimizer::Optimizer, ::SubproblemOptimizer)
    if optimizer.subproblem_optimizer === nothing
        return MOI.get(optimizer, MasterOptimizer())
    end
    return () -> begin
        opt = optimizer.subproblem_optimizer()
        for (attr, value) in optimizer.sub_params
            MOI.set(opt, attr, value)
        end
        return opt
    end
end

function MOI.set(optimizer::Optimizer, ::SubproblemOptimizer, optimizer_constructor)
    optimizer.subproblem_optimizer = optimizer_constructor
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

function MOI.get(optimizer::Optimizer, ::Execution)
    return optimizer.execution
end

function MOI.set(optimizer::Optimizer, ::Execution, execution::AbstractExecution)
    optimizer.execution = execution
    return nothing
end

function MOI.get(optimizer::Optimizer, ::Penalizer)
    return optimizer.penalizer
end

function MOI.set(optimizer::Optimizer, ::Penalizer, penalizer::AbstractPenalizer)
    optimizer.penalizer = penalizer
    return nothing
end

function MOI.get(optimizer::Optimizer, ::Penaltyterm)
    return optimizer.penaltyterm
end

function MOI.set(optimizer::Optimizer, ::Penaltyterm, penaltyterm::AbstractPenaltyterm)
    optimizer.penaltyterm = penaltyterm
    return nothing
end

function MOI.get(optimizer::Optimizer, param::ExecutionParameter)
    return MOI.get(optimizer.execution, param)
end

function MOI.set(optimizer::Optimizer, param::ExecutionParameter, value)
    MOI.set(optimizer.execution, param, value)
    return nothing
end

function MOI.get(optimizer::Optimizer, param::PenalizationParameter)
    return MOI.get(optimizer.penalizer, param)
end

function MOI.set(optimizer::Optimizer, param::PenalizationParameter, value)
    MOI.set(optimizer.penalizer, param, value)
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

function MOI.get(optimizer::Optimizer, ::MOI.VariablePrimal, index::MOI.VariableIndex)
    if optimizer.progressivehedging === nothing
        throw(StochasticProgram.UnloadedStructure{Optimizer}())
    end
    return decision(optimizer.progressivehedging, index)
end

function MOI.get(optimizer::Optimizer, ::MOI.ConstraintPrimal, ci::MOI.ConstraintIndex)
    if optimizer.progressivehedging === nothing
        throw(StochasticProgram.UnloadedStructure{Optimizer}())
    end
    return scalar_subproblem_reduction(optimizer.progressivehedging) do subproblem
        return MOI.get(subproblem.optimizer, MOI.ConstraintPrimal(), ci)
    end
end

function MOI.get(optimizer::Optimizer, ::MOI.ConstraintDual, ci::MOI.ConstraintIndex)
    if optimizer.progressivehedging === nothing
        throw(StochasticProgram.UnloadedStructure{Optimizer}())
    end
    return scalar_subproblem_reduction(optimizer.progressivehedging) do subproblem
        return MOI.get(subproblem.optimizer, MOI.ConstraintDual(), ci)
    end
end

function MOI.get(optimizer::Optimizer, ::MOI.ObjectiveValue)
    if optimizer.progressivehedging === nothing
        throw(StochasticProgram.UnloadedStructure{Optimizer}())
    end
    return objective_value(optimizer.progressivehedging)
end

function MOI.get(optimizer::Optimizer, ::MOI.DualObjectiveValue)
    if optimizer.progressivehedging === nothing
        throw(StochasticProgram.UnloadedStructure{Optimizer}())
    end
    if optimizer.status == MOI.OPTIMAL
        return objective_value(optimizer.progressivehedging)
    elseif optimizer.status == MOI.INFEASIBLE
        sense = MOI.get(optimizer.progressivehedging.structure, MOI.ObjectiveSense())
        return sense == MOI.MAX_SENSE ? Inf : -Inf
    elseif optimizer.status == MOI.DUAL_INFEASIBLE
        sense = MOI.get(optimizer.progressivehedging.structure, MOI.ObjectiveSense())
        return sense == MOI.MAX_SENSE ? -Inf : Inf
    else
        return NaN
    end
end

function MOI.get(optimizer::Optimizer, ::MOI.SolveTime)
    return optimizer.solve_time
end

function MOI.get(optimizer::Optimizer, attr::Union{MOI.AbstractOptimizerAttribute, MOI.AbstractModelAttribute})
    # Fallback to through structure
    if optimizer.progressivehedging === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.progressivehedging.structure, attr)
end

function MOI.get(optimizer::Optimizer, attr::MOI.AbstractConstraintAttribute, ci::MOI.ConstraintIndex)
    # Fallback to first-stage optimizer through structure
    if optimizer.progressivehedging === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.progressivehedging.structure, attr, ci)
end

function MOI.set(optimizer::Optimizer, attr::Union{MOI.AbstractOptimizerAttribute, MOI.AbstractModelAttribute}, value)
    # Fallback to first-stage optimizer through structure
    if optimizer.progressivehedging === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.progressivehedging.structure, attr, value)
end

function MOI.set(optimizer::Optimizer, attr::MOI.AbstractVariableAttribute, index::MOI.VariableIndex, value)
    # Fallback to first-stage optimizer through structure
    if optimizer.progressivehedging === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.progressivehedging.structure, attr, index, value)
end

function MOI.set(optimizer::Optimizer, attr::MOI.AbstractConstraintAttribute, ci::MOI.ConstraintIndex, value)
    # Fallback to first-stage optimizer through structure
    if optimizer.progressivehedging === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.progressivehedging.structure, attr, ci, value)
end

function MOI.get(optimizer::Optimizer, attr::ScenarioDependentModelAttribute)
    # Fallback to subproblem optimizer through structure
    if optimizer.progressivehedging === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.progressivehedging.structure, attr)
end

function MOI.get(optimizer::Optimizer, attr::ScenarioDependentVariableAttribute, index::MOI.VariableIndex)
    # Fallback to subproblem optimizer through structure
    if optimizer.progressivehedging === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.progressivehedging.structure, attr, index)
end

function MOI.get(optimizer::Optimizer, attr::ScenarioDependentConstraintAttribute, ci::MOI.ConstraintIndex)
    # Fallback to subproblem optimizer through structure
    if optimizer.progressivehedging === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.progressivehedging.structure, attr, ci)
end

function MOI.set(optimizer::Optimizer, attr::ScenarioDependentModelAttribute, value)
    # Fallback to subproblem optimizer through structure
    if optimizer.progressivehedging === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.progressivehedging.structure, attr, value)
end

function MOI.set(optimizer::Optimizer, attr::ScenarioDependentVariableAttribute, index::MOI.VariableIndex, value)
    # Fallback to subproblem optimizer through structure
    if optimizer.progressivehedging === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.progressivehedging.structure, attr, index, value)
end

function MOI.set(optimizer::Optimizer, attr::ScenarioDependentVariableAttribute, ci::MOI.ConstraintIndex, value)
    # Fallback to subproblem optimizer through structure
    if optimizer.progressivehedging === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.progressivehedging.structure, attr, ci, value)
end

function MOI.is_empty(optimizer::Optimizer)
    return optimizer.progressivehedging === nothing
end

MOI.supports(::Optimizer, ::MOI.Silent) = true
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true
MOI.supports(::Optimizer, ::MOI.RawParameter) = true
MOI.supports(::Optimizer, ::AbstractStructuredOptimizerAttribute) = true
MOI.supports(::Optimizer, ::RelativeTolerance) = false
MOI.supports(::Optimizer, ::RawInstanceOptimizerParameter) = true
MOI.supports(::Optimizer, ::AbstractProgressiveHedgingAttribute) = true

# High-level attribute setting #
# ========================== #
"""
    get_penalization_attribute(stochasticprogram::StochasticProgram, name::String)

Return the value associated with the penalization-specific attribute named `name` in `stochasticprogram`.

See also: [`set_penalization_attribute`](@ref), [`set_penalization_attributes`](@ref).
"""
function get_penalization_attribute(stochasticprogram::StochasticProgram, name::String)
    return return MOI.get(optimizer(stochasticprogram), RawPenalizationParameter(name))
end
"""
    set_penalization_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)

Sets the penalization-specific attribute identified by `name` to `value`.

"""
function set_penalization_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawPenalizationParameter(String(name)), value)
end
"""
    set_penalization_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)

Given a list of `attribute => value` pairs or a collection of keyword arguments, calls
`set_penalization_attribute(stochasticprogram, attribute, value)` for each pair.

"""
function set_penalization_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_penalization_attribute(stochasticprogram, name, value)
    end
end
function set_penalization_attributes(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_penalization_attribute(stochasticprogram, name, value)
    end
end
