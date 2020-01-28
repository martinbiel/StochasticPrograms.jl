"""
    ProgressiveHedgingSolver(qpsolver::AbstractMathProgSolver; <keyword arguments>)

Return a progressive-hedging algorithm object specified. Supply `qpsolver`, a MathProgBase solver capable of solving quadratic problems.

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
mutable struct ProgressiveHedgingSolver{S <: QPSolver,
                                        E <: Execution,
                                        P <: AbstractPenalizer,
                                        PT <: PenaltyTerm} <: AbstractStructuredSolver
    qpsolver::S
    execution::E
    penalty::P
    penaltyterm::PT
    crash::CrashMethod
    parameters::Dict{Symbol,Any}

    function ProgressiveHedgingSolver(qpsolver::QPSolver;
                                      execution::Execution = Serial(),
                                      penalty::AbstractPenalizer = Fixed(),
                                      penaltyterm::PenaltyTerm = Quadratic(),
                                      crash::CrashMethod = Crash.None(), kwargs...)
        S = typeof(qpsolver)
        E = typeof(execution)
        P = typeof(penalty)
        PT = typeof(penaltyterm)
        return new{S, E, P, PT}(qpsolver,
                                execution,
                                penalty,
                                penaltyterm,
                                crash,
                                Dict{Symbol,Any}(kwargs))
    end
end

function StructuredModel(stochasticprogram::StochasticProgram, solver::ProgressiveHedgingSolver)
    x₀ = solver.crash(stochasticprogram, solver.qpsolver)
    return ProgressiveHedging(stochasticprogram, solver.qpsolver, solver.execution, solver.penalty, solver.penaltyterm; solver.parameters...)
end

function add_params!(solver::ProgressiveHedgingSolver; kwargs...)
    push!(solver.parameters, kwargs...)
    for (k,v) in kwargs
        if k ∈ [:qpsolver, :execution, :penalty, :penaltyterms, :crash]
            setfield!(solver, k, v)
            delete!(solver.parameters, k)
        end
    end
    return nothing
end

function internal_solver(solver::ProgressiveHedgingSolver)
    return get_solver(solver.qpsolver)
end

function optimize_structured!(ph::AbstractProgressiveHedgingSolver)
    return ph()
end

function fill_solution!(stochasticprogram::StochasticProgram, ph::AbstractProgressiveHedgingSolver)
    # First stage
    first_stage = StochasticPrograms.get_stage_one(stochasticprogram)
    nrows, ncols = first_stage_dims(stochasticprogram)
    StochasticPrograms.set_decision!(stochasticprogram, ph.ξ)
    fill_first_stage!(ph, stochasticprogram, nrows, ncols)
    # Second stage
    fill_submodels!(ph, scenarioproblems(stochasticprogram), nrows, ncols)
end

function solverstr(solver::ProgressiveHedgingSolver)
    return "$(str(solver.execution))Progressive-hedging solver and $(str(solver.penalty))"
end
