@with_kw mutable struct ProgressiveHedgingData{T <: AbstractFloat}
    Q::T = 1e10
    δ::T = 1.0
    δ₁::T = 1.0
    δ₂::T = 1.0
    iterations::Int = 0
end

@with_kw mutable struct ProgressiveHedgingParameters{T <: AbstractFloat}
    τ::T = 1e-5
    log::Bool = true
    keep::Bool = true
    offset::Int = 0
    indent::Int = 0
end

"""
    ProgressiveHedging

Functor object for the progressive-hedging algorithm. Create using the `ProgressiveHedgingSolver` factory function and then pass to a `StochasticPrograms.jl` model.

...
# Parameters
- `τ::AbstractFloat = 1e-6`: Relative tolerance for convergence checks.
- `log::Bool = true`: Specifices if progressive-hedging procedure should be logged on standard output or not.
...
"""
struct ProgressiveHedging{T <: AbstractFloat,
                          A <: AbstractVector,
                          SP <: StochasticProgram,
                          S <: LQSolver,
                          PT <: PenaltyTerm,
                          E <: AbstractExecution,
                          P <: AbstractPenalization} <: AbstractProgressiveHedgingSolver
    stochasticprogram::SP
    data::ProgressiveHedgingData{T}
    parameters::ProgressiveHedgingParameters{T}

    # Estimate
    ξ::A
    Q_history::A
    dual_gaps::A

    # Subproblems
    nscenarios::Int

    # Execution
    execution::E

    penalization::P

    # Params
    progress::ProgressThresh{T}

    function ProgressiveHedging(stochasticprogram::StochasticProgram,
                                x₀::AbstractVector,
                                subsolver::MPB.AbstractMathProgSolver,
                                executer::Execution,
                                penalizer::AbstractPenalizer,
                                penaltyterm::PenaltyTerm; kw...)
        if nworkers() > 1 && executer isa Serial
            @warn "There are worker processes, consider using distributed version of algorithm"
        end
        executer = if nworkers() == 1 && !(executer isa Serial)
            @warn "There are no worker processes, defaulting to serial version of algorithm"
            Serial()
        else
            executer
        end
        first_stage = StochasticPrograms.get_stage_one(stochasticprogram)
        length(x₀) != first_stage.numCols && error("Incorrect length of starting guess, has ", length(x₀), " should be ", first_stage.numCols)

        T = promote_type(eltype(x₀), Float32)
        x₀_ = convert(AbstractVector{T}, copy(x₀))
        A = typeof(x₀_)
        SP = typeof(stochasticprogram)
        S = LQSolver{typeof(MPB.LinearQuadraticModel(subsolver)), typeof(subsolver)}
        PT = typeof(penaltyterm)
        n = StochasticPrograms.nscenarios(stochasticprogram)
        execution = executer(T,A,S,PT)
        E = typeof(execution)
        penalization = penalizer()
        P = typeof(penalization)
        params = ProgressiveHedgingParameters{T}(; kw...)

        ph = new{T,A,SP,S,PT,E,P}(stochasticprogram,
                                  ProgressiveHedgingData{T}(),
                                  params,
                                  x₀_,
                                  A(),
                                  A(),
                                  n,
                                  execution,
                                  penalization,
                                  ProgressThresh(1.0, 0.0, "$(indentstr(params.indent))Progressive Hedging"))
        # Initialize solver
        initialize!(ph, subsolver, penaltyterm)
        return ph
    end
end
ProgressiveHedging(stochasticprogram::StochasticProgram,
                   subsolver::MPB.AbstractMathProgSolver,
                   execution::Execution,
                   penalizer::AbstractPenalizer,
                   penaltyterm::PenaltyTerm; kw...) = ProgressiveHedging(stochasticprogram,
                                                                         rand(decision_length(stochasticprogram)),
                                                                         subsolver,
                                                                         execution,
                                                                         penalizer,
                                                                         penaltyterm; kw...)

function (ph::ProgressiveHedging)()
    # Reset timer
    ph.progress.tfirst = ph.progress.tlast = time()
    # Start workers (if any)
    start_workers!(ph)
    # Start procedure
    while true
        status = iterate!(ph)
        if status != :Valid
            close_workers!(ph)
            return status
        end
    end
end
