"""
    Optimizer(; <keyword arguments>)

Return a quasi-gradient optimizer.
...
# Arguments
- `master_optimizer::AbstractOptimizer`: MathOptInterface solver capable of solving linear (and possibly quadratic) programs.
- `subproblem_optimizer::AbstractOptimizer`: Optionally specify a different solver for the subproblems.
- `execution::Execution = Serial`: Specify how algorithm should be executed (Serial, Synchronous, Asynchronous). Distributed variants requires worker cores.
- `subproblems::AbstractSubProblemState = Unaltered()`: Specify if a smoothing procedure should be applied.
- `prox::AbstractProx = Polyhedron()`: Specify proximal step.
- `step::AbstractStep = Constant()`: Specify step-size
- `termination::AbstractTermination = AfterMaximumIterations()`: Specify termination criterion

- <keyword arguments>: Algorithm specific parameters, See `?LShaped` for list of possible arguments and default values.
...
"""
mutable struct Optimizer <: AbstractStructuredOptimizer
    master_optimizer
    subproblem_optimizer
    master_params::Dict{MOI.AbstractOptimizerAttribute, Any}
    sub_params::Dict{MOI.AbstractOptimizerAttribute, Any}
    execution::AbstractExecution
    subproblems::AbstractSubProblemState
    prox::AbstractProx
    step::AbstractStepSize
    termination::AbstractTermination
    parameters::QuasiGradientParameters{Float64}

    status::MOI.TerminationStatusCode
    primal_status::MOI.ResultStatusCode
    dual_status::MOI.ResultStatusCode
    raw_status::String
    solve_time::Float64

    quasigradient::Union{AbstractQuasiGradient, Nothing}

    function Optimizer(; master_optimizer = nothing,
                       execution::AbstractExecution = nworkers() == 1 ? Serial() : Synchronous(),
                       subproblems::AbstractSubProblemState = Unaltered(),
                       prox::AbstractProx = Polyhedron(),
                       step::AbstractStepSize = Constant(),
                       terminate::AbstractTermination = AfterMaximumIterations(),
                       subproblem_optimizer = nothing, kw...)
        return new(master_optimizer,
                   subproblem_optimizer,
                   Dict{MOI.AbstractOptimizerAttribute, Any}(),
                   Dict{MOI.AbstractOptimizerAttribute, Any}(),
                   execution,
                   subproblems,
                   prox,
                   step,
                   terminate,
                   QuasiGradientParameters{Float64}(; kw...),
                   MOI.OPTIMIZE_NOT_CALLED,
                   MOI.NO_SOLUTION,
                   MOI.NO_SOLUTION,
                   "Quasi-gradient optimizer has not been run.",
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
    if optimizer.prox isa Polyhedron && optimizer.master_optimizer === nothing
        msg = "Polyhedron proximal operator requires setting `MasterOptimizer` attribute."
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
    # Restore structure if optimization has been run before
    restore_structure!(optimizer)
    # Ensure that execution policy is compatible
    ensure_compatible_execution!(optimizer, structure)
    # Create new L-shaped algorithm
    optimizer.quasigradient = QuasiGradientAlgorithm(structure,
                                                     x₀,
                                                     optimizer.execution,
                                                     optimizer.subproblems,
                                                     optimizer.prox,
                                                     optimizer.step,
                                                     optimizer.termination;
                                                     type2dict(optimizer.parameters)...)
    # Set any given prox/sub optimizer attributes
    for (attr, value) in optimizer.master_params
        MOI.set(optimizer.quasigradient.master, attr, value)
    end
    for (attr, value) in optimizer.sub_params
        MOI.set(scenarioproblems(optimizer.quasigradient.structure), attr, value)
    end
    return nothing
end

function restore_structure!(optimizer::Optimizer)
    if optimizer.quasigradient !== nothing
        restore_master!(optimizer.quasigradient)
        restore_subproblems!(optimizer.quasigradient)
    end
    return nothing
end

function MOI.optimize!(optimizer::Optimizer)
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    start_time = time()
    optimizer.status = optimizer.quasigradient()
    if optimizer.status == MOI.OPTIMAL
        optimizer.primal_status = MOI.FEASIBLE_POINT
        optimizer.dual_status = MOI.FEASIBLE_POINT
        optimizer.raw_status = "Quasi-gradient procedure converged to optimal solution."
    end
    optimizer.solve_time = time() - start_time
    return nothing
end

function optimizer_name(optimizer::Optimizer)
    return "$(str(optimizer.execution))Quasi-gradient"
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
    if !(name in fieldnames(QuasiGradientParameters))
        error("Unrecognized parameter name: $(name).")
    end
    return getfield(optimizer.parameters, name)
end

function MOI.set(optimizer::Optimizer, param::MOI.RawParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(QuasiGradientParameters))
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

function MOI.get(optimizer::Optimizer, ::SubProblems)
    return optimizer.subproblems
end

function MOI.set(optimizer::Optimizer, ::SubProblems, subproblems::AbstractSubProblemState)
    optimizer.subproblems = subproblems
    return nothing
end

function MOI.get(optimizer::Optimizer, ::Prox)
    return optimizer.prox
end

function MOI.set(optimizer::Optimizer, ::Prox, prox::AbstractProx)
    optimizer.prox = prox
    return nothing
end

function MOI.get(optimizer::Optimizer, ::StepSize)
    return optimizer.step
end

function MOI.set(optimizer::Optimizer, ::StepSize, step::AbstractStepSize)
    optimizer.step = step
    return nothing
end

function MOI.get(optimizer::Optimizer, ::Termination)
    return optimizer.termination
end

function MOI.set(optimizer::Optimizer, ::Termination, termination::AbstractTermination)
    optimizer.termination = termination
    return nothing
end

function MOI.get(optimizer::Optimizer, param::ExecutionParameter)
    return MOI.get(optimizer.execution, param)
end

function MOI.set(optimizer::Optimizer, param::ExecutionParameter, value)
    MOI.set(optimizer.execution, param, value)
    return nothing
end

function MOI.get(optimizer::Optimizer, param::ProxParameter)
    return MOI.get(optimizer.prox, param)
end

function MOI.set(optimizer::Optimizer, param::ProxParameter, value)
    MOI.set(optimizer.prox, param, value)
    return nothing
end

function MOI.get(optimizer::Optimizer, param::StepParameter)
    return MOI.get(optimizer.step, param)
end

function MOI.set(optimizer::Optimizer, param::StepParameter, value)
    MOI.set(optimizer.step, param, value)
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
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    list = MOI.get(optimizer.quasigradient.structure, attr)
    # Remove any auxilliary variables from prox
    filter_variables!(optimizer.quasigradient.prox, list)
    return list
end

function MOI.get(optimizer::Optimizer, ::MOI.VariablePrimal, index::MOI.VariableIndex)
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return decision(optimizer.quasigradient, index)
end

function MOI.get(optimizer::Optimizer, attr::MOI.ListOfConstraintIndices)
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    list = MOI.get(optimizer.quasigradient.structure, attr)
    # Remove any prox constraints
    filter_constraints!(optimizer.quasigradient.prox, list)
    return list
end

function MOI.get(optimizer::Optimizer, ::MOI.ObjectiveValue)
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return objective_value(optimizer.quasigradient)
end

function MOI.get(optimizer::Optimizer, ::MOI.SolveTime)
    return optimizer.solve_time
end

function MOI.get(optimizer::Optimizer, attr::Union{MOI.AbstractOptimizerAttribute, MOI.AbstractModelAttribute})
    # Fallback to first-stage optimizer through structure
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.quasigradient.structure, attr)
end

function MOI.get(optimizer::Optimizer, attr::MOI.AbstractConstraintAttribute, ci::MOI.ConstraintIndex)
    # Fallback to first-stage optimizer through structure
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.quasigradient.structure, attr, ci)
end

function MOI.set(optimizer::Optimizer, attr::Union{MOI.AbstractOptimizerAttribute, MOI.AbstractModelAttribute}, value)
    # Fallback to first-stage optimizer through structure
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.quasigradient.structure, attr, value)
end

function MOI.set(optimizer::Optimizer, attr::MOI.AbstractVariableAttribute, index::MOI.VariableIndex, value)
    # Fallback to first-stage optimizer through structure
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.quasigradient.structure, attr, index, value)
end

function MOI.set(optimizer::Optimizer, attr::MOI.AbstractConstraintAttribute, ci::MOI.ConstraintIndex, value)
    # Fallback to first-stage optimizer through structure
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.quasigradient.structure, attr, ci, value)
end

function MOI.get(optimizer::Optimizer, attr::ScenarioDependentModelAttribute)
    # Fallback to subproblem optimizer through structure
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.quasigradient.structure, attr)
end

function MOI.get(optimizer::Optimizer, attr::ScenarioDependentVariableAttribute, index::MOI.VariableIndex)
    # Fallback to subproblem optimizer through structure
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.quasigradient.structure, attr, index)
end

function MOI.get(optimizer::Optimizer, attr::ScenarioDependentConstraintAttribute, ci::MOI.ConstraintIndex)
    # Fallback to subproblem optimizer through structure
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.get(optimizer.quasigradient.structure, attr, ci)
end

function MOI.set(optimizer::Optimizer, attr::ScenarioDependentModelAttribute, value)
    # Fallback to subproblem optimizer through structure
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.quasigradient.structure, attr, value)
end

function MOI.set(optimizer::Optimizer, attr::ScenarioDependentVariableAttribute, index::MOI.VariableIndex, value)
    # Fallback to subproblem optimizer through structure
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.quasigradient.structure, attr, index, value)
end

function MOI.set(optimizer::Optimizer, attr::ScenarioDependentVariableAttribute, ci::MOI.ConstraintIndex, value)
    # Fallback to subproblem optimizer through structure
    if optimizer.quasigradient === nothing
        throw(UnloadedStructure{Optimizer}())
    end
    return MOI.set(optimizer.quasigradient.structure, attr, ci, value)
end

function MOI.is_empty(optimizer::Optimizer)
    return optimizer.quasigradient === nothing
end

MOI.supports(::Optimizer, ::MOI.Silent) = true
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true
MOI.supports(::Optimizer, ::MOI.RawParameter) = true
MOI.supports(::Optimizer, ::AbstractStructuredOptimizerAttribute) = true
MOI.supports(::Optimizer, ::RawInstanceOptimizerParameter) = true
MOI.supports(::Optimizer, ::AbstractQuasiGradientAttribute) = true

# High-level attribute setting #
# ========================== #
"""
    get_prox_attribute(stochasticprogram::StochasticProgram, name::String)

Return the value associated with the prox-specific attribute named `name` in `stochasticprogram`.

See also: [`set_prox_attribute`](@ref), [`set_prox_attributes`](@ref).
"""
function get_prox_attribute(stochasticprogram::StochasticProgram, name::String)
    return return MOI.get(optimizer(stochasticprogram), RawProxParameter(name))
end
"""
    set_prox_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)

Sets the prox-specific attribute identified by `name` to `value`.

"""
function set_prox_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawProxParameter(String(name)), value)
end
"""
    set_prox_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)

Given a list of `attribute => value` pairs or a collection of keyword arguments, calls
`set_prox_attribute(stochasticprogram, attribute, value)` for each pair.

"""
function set_prox_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_prox_attribute(stochasticprogram, name, value)
    end
end
function set_prox_attributes(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_prox_attribute(stochasticprogram, name, value)
    end
end
"""
    get_step_attribute(stochasticprogram::StochasticProgram, name::String)

Return the value associated with the step-specific attribute named `name` in `stochasticprogram`.

See also: [`set_step_attribute`](@ref), [`set_step_attributes`](@ref).
"""
function get_step_attribute(stochasticprogram::StochasticProgram, name::String)
    return MOI.get(optimizer(stochasticprogram), RawStepParameter(name))
end
"""
    set_step_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)

Sets the step-specific attribute identified by `name` to `value`.

"""
function set_step_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawStepParameter(String(name)), value)
end
"""
    set_step_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)

Given a list of `attribute => value` pairs or a collection of keyword arguments, calls
`set_step_attribute(stochasticprogram, attribute, value)` for each pair.

"""
function set_step_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_step_attribute(stochasticprogram, name, value)
    end
end
function set_step_attributes(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_step_attribute(stochasticprogram, name, value)
    end
end
"""
    get_termination_attribute(stochasticprogram::StochasticProgram, name::String)

Return the value associated with the termination-specific attribute named `name` in `stochasticprogram`.

See also: [`set_termination_attribute`](@ref), [`set_termination_attributes`](@ref).
"""
function get_termination_attribute(stochasticprogram::StochasticProgram, name::String)
    return MOI.get(optimizer(stochasticprogram), RawTerminationParameter(name))
end
"""
    set_termination_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)

Sets the termination-specific attribute identified by `name` to `value`.

"""
function set_termination_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawTerminationParameter(String(name)), value)
end
"""
    set_termination_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)

Given a list of `attribute => value` pairs or a collection of keyword arguments, calls
`set_termination_attribute(stochasticprogram, attribute, value)` for each pair.

"""
function set_termination_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_termination_attribute(stochasticprogram, name, value)
    end
end
function set_termination_attributes(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_termination_attribute(stochasticprogram, name, value)
    end
end
