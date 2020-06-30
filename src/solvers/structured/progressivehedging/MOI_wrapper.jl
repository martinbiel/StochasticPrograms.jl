"""
    Optimizer(solver::AbstractMathProgSolver; <keyword arguments>)

Return a progressive-hedging algorithm object specified. Supply `qpsolver`, a MathProgBase solver capable of solving linear-quadratic problems.

The following penalty parameter update procedures are available
- [`Fixed`](@ref):  Fixed penalty (default) ?Fixed for parameter descriptions.
- [`Adaptive`](@ref): Adaptive penalty update ?Adaptive for parameter descriptions.

The following execution policies are available
- [`Serial`](@ref):  Classical progressive-hedging (default)
- [`Synchronous`](@ref): Classical progressive-hedging run in parallel
- [`Asynchronous`](@ref): Asynchronous progressive-hedging ?Asynchronous for parameter descriptions.

...
# Arguments
- `qpsolver::AbstractMathProgSolver`: MathProgBase solver capable of solving quadratic programs.
- `penalty::AbstractPenalizer = Fixed()`: Specify penalty update procedure (Fixed, Adaptive)
- `execution::AbstractExecuter = Serial`: Specify how algorithm should be executed (Serial, Synchronous, Asynchronous). Distributed variants requires worker cores.
- `penaltyterm::PenaltyTerm = Quadratic`: Specify penaltyterm variant ([`Quadratic`](@ref), [`Linearized`](@ref), [`InfNorm`](@ref), [`ManhattanNorm`][@ref])
- <keyword arguments>: Algorithm specific parameters, consult individual docstrings (see above list) for list of possible arguments and default values.
...

## Examples

The following solves a stochastic program `sp` created in `StochasticPrograms.jl` using the progressive-hedging algorithm with Ipopt as an `qpsolver`.

```jldoctest
julia> solve(sp,solver=ProgressiveHedgingSolver(IpoptSolver(print_level=0)))
Progressive Hedging Time: 0:00:06 (1315 iterations)
  Objective:  -855.8332803469432
  δ:          9.436947935542464e-7
:Optimal
```
"""
mutable struct Optimizer <: AbstractStructuredOptimizer
    subproblem_optimizer
    sub_params::Dict{MOI.AbstractOptimizerAttribute, Any}
    execution::AbstractExecution
    penalizer::AbstractPenalizer
    penaltyterm::AbstractPenaltyterm
    parameters::ProgressiveHedgingParameters{Float64}

    status::MOI.TerminationStatusCode
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
                   nothing)
    end
end

# Interface #
# ========================== #
function supports_structure(optimizer::Optimizer, ::HorizontalBlockStructure{2, 1, <:Tuple{ScenarioProblems}})
    if optimizer.execution isa Serial
        return true
    end
    @warn "Distributed execution policies are not compatible with a single-core horizontal structure. Consider setting the execution policy to `Serial` or re-instantiate the stochastic program on worker cores."
    return false
end

function supports_structure(optimizer::Optimizer, ::HorizontalBlockStructure{2, 1, <:Tuple{DistributedScenarioProblems}})
    if optimizer.execution isa Serial
        @warn "Serial execution not compatible with distributed horizontal structure. Consider setting the execution policy to `Synchronous` or `Asynchronous` or re-instantiate the stochastic program on a single core."
        return false
    end
    return true
end

function default_structure(::UnspecifiedInstantiation, optimizer::Optimizer)
    if optimizer.execution isa Serial && nworkers() == 1
        return BlockHorizontal()
    else
        return DistributedBlockHorizontal()
    end
end

function check_loadable(optimizer::Optimizer, ::HorizontalBlockStructure)
    if optimizer.subproblem_optimizer === nothing
        msg = "Subproblem optimizer not set. Consider setting `SubproblemOptimizer` attribute."
        throw(UnloadableStructure{Optimizer, HorizontalBlockStructure}(msg))
    end
    return nothing
end

function load_structure!(optimizer::Optimizer, structure::HorizontalBlockStructure, x₀::AbstractVector)
    # Sanity check
    check_loadable(optimizer, structure)
    # Restore structure if optimization has been run before
    restore_structure!(optimizer)
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

function reload_structure!(optimizer::Optimizer)
    if optimizer.progressivehedging !== nothing
        x₀ = copy(optimizer.progressivehedging.ξ)
        structure = optimizer.progressivehedging.structure
        restore_structure!(optimizer)
        load_structure!(optimizer, structure, x₀)
    end
    return nothing
end

function MOI.optimize!(optimizer::Optimizer)
    if optimizer.progressivehedging === nothing
        throw(StochasticProgram.UnloadedStructure{Optimizer}())
    end
    optimizer.status = optimizer.progressivehedging()
    return nothing
end

function termination_status(optimizer::Optimizer)
    return optimizer.status
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
    if optimizer.progressivehedging != nothing
        MOI.set(scenarioproblems(optimizer.progressivehedging.structure), attr, flag)
    end
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
    if optimizer.progressivehedging != nothing
        setfield!(optimizer.progressivehedging.parameters, name, value)
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

function MOI.get(optimizer::Optimizer, ::SubproblemOptimizer)
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
    if optimizer.progressivehedging != nothing
        MOI.set(scenarioproblems(optimizer.progressivehedging.structure), moi_param, value)
    end
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

function MOI.get(optimizer::Optimizer, ::Penalizer)
    return optimizer.penalizer
end

function MOI.set(optimizer::Optimizer, ::Penalizer, penalizer::AbstractPenalizer)
    optimizer.penalizer = penalizer
    # Trigger reload
    reload_structure!(optimizer)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::Penaltyterm)
    return optimizer.penaltyterm
end

function MOI.set(optimizer::Optimizer, ::Penaltyterm, penaltyterm::AbstractPenaltyterm)
    optimizer.penaltyterm = penaltyterm
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

function MOI.get(optimizer::Optimizer, param::PenalizationParameter)
    return MOI.get(optimizer.penalizer, param)
end

function MOI.set(optimizer::Optimizer, param::PenalizationParameter, value)
    MOI.set(optimizer.penalizer, param, value)
    # Trigger reload
    reload_structure!(optimizer)
    return nothing
end

function MOI.get(optimizer::Optimizer, ::MOI.TerminationStatus)
    return optimizer.status
end

function MOI.get(optimizer::Optimizer, ::MOI.VariablePrimal, index::MOI.VariableIndex)
    if optimizer.progressivehedging === nothing
        throw(StochasticProgram.UnloadedStructure{Optimizer}())
    end
    return decision(optimizer.progressivehedging, index)
end

function MOI.get(optimizer::Optimizer, ::MOI.ObjectiveValue)
    if optimizer.progressivehedging === nothing
        throw(StochasticProgram.UnloadedStructure{Optimizer}())
    end
    return objective_value(optimizer.progressivehedging)
end

function MOI.is_empty(optimizer::Optimizer)
    return optimizer.progressivehedging === nothing
end

MOI.supports(::Optimizer, ::MOI.Silent) = true
MOI.supports(::Optimizer, ::MOI.TimeLimitSec) = true
MOI.supports(::Optimizer, ::MOI.RawParameter) = true
MOI.supports(::Optimizer, ::AbstractStructuredOptimizerAttribute) = true
MOI.supports(::Optimizer, ::MasterOptimizer) = false
MOI.supports(::Optimizer, ::RelativeTolerance) = false
MOI.supports(::Optimizer, ::RawInstanceOptimizerParameter) = true
MOI.supports(::Optimizer, ::AbstractProgressiveHedgingAttribute) = true

# High-level attribute setting #
# ========================== #
function set_penalization_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, RawPenalizationParameter(String(name)), value)
end
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
