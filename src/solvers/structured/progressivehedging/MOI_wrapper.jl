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
mutable struct Optimizer{E <: Execution,
                         P <: AbstractPenalizer,
                         PT <: PenaltyTerm} <: AbstractStructuredOptimizer
    optimizer
    execution::E
    penalization::P
    penaltyterm::PT
    parameters::Dict{Symbol,Any}

    status::MOI.TerminationStatusCode
    progressivehedging::Union{AbstractProgressiveHedging, Nothing}

    function Optimizer(optimizer;
                       execution::Execution = Serial(),
                       penalty::AbstractPenalizer = Fixed(),
                       penaltyterm::PenaltyTerm = Quadratic(),
                       kwargs...)
        E = typeof(execution)
        P = typeof(penalty)
        PT = typeof(penaltyterm)
        return new{E, P, PT}(optimizer,
                             execution,
                             penalty,
                             penaltyterm,
                             Dict{Symbol,Any}(kwargs),
                             MOI.OPTIMIZE_NOT_CALLED,
                             nothing)
    end
end

# Interface #
# ========================== #
function supports_structure(::Optimizer, ::HorizontalBlockStructure)
    return true
end

function default_structure(::UnspecifiedInstantiation, ::Optimizer)
    return BlockHorizontal()
end

function load_structure!(optimizer::Optimizer, structure::HorizontalBlockStructure, x₀::AbstractVector)
    restore_structure!(optimizer)
    optimizer.progressivehedging = ProgressiveHedgingAlgorithm(structure,
                                                               x₀,
                                                               optimizer.execution,
                                                               optimizer.penalization,
                                                               optimizer.penaltyterm;
                                                               optimizer.parameters...)
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
    optimizer.status = optimizer.progressivehedging()
    return nothing
end

function termination_status(optimizer::Optimizer)
    return optimizer.status
end

function optimizer_name(optimizer::Optimizer)
    return "$(str(optimizer.execution))Progressive-hedging with $(str(optimizer.penalization))"
end

function master_optimizer(optimizer::Optimizer)
    return optimizer.optimizer
end

function sub_optimizer(optimizer::Optimizer)
    return optimizer.optimizer
end

# MOI #
# ========================== #
function MOI.get(optimizer::Optimizer, ::MOI.TerminationStatus)
    return optimizer.status
end

function MOI.get(optimizer::Optimizer, ::MOI.ObjectiveValue)
    if optimizer.status == MOI.OPTIMIZE_NOT_CALLED
        throw(OptimizeNotCalled())
    end
    return objective_value(optimizer.progressivehedging)
end

function MOI.is_empty(optimizer::Optimizer)
    return optimizer.progressivehedging === nothing
end

# ========================== #
function add_params!(solver::Optimizer; kwargs...)
    push!(solver.parameters, kwargs...)
    for (k,v) in kwargs
        if k ∈ [:optimizer, :execution, :penalty, :penaltyterms]
            setfield!(solver, k, v)
            delete!(solver.parameters, k)
        end
    end
    return nothing
end
