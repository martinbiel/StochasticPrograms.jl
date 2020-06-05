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
    ProgressiveHedgingAlgorithm

Functor object for the progressive-hedging algorithm. Create using the `ProgressiveHedgingSolver` factory function and then pass to a `StochasticPrograms.jl` model.

...
# Parameters
- `τ::AbstractFloat = 1e-6`: Relative tolerance for convergence checks.
- `log::Bool = true`: Specifices if progressive-hedging procedure should be logged on standard output or not.
...
"""
struct ProgressiveHedgingAlgorithm{T <: AbstractFloat,
                                   A <: AbstractVector,
                                   ST <: HorizontalBlockStructure,
                                   S <: MOI.AbstractOptimizer,
                                   E <: AbstractExecution,
                                   P <: AbstractPenalization,
                                   PT <: PenaltyTerm} <: AbstractProgressiveHedging
    structure::ST
    data::ProgressiveHedgingData{T}
    parameters::ProgressiveHedgingParameters{T}

    # Estimate
    ξ::A
    decisions::Decisions
    Q_history::A
    dual_gaps::A

    # Execution
    execution::E

    penalization::P

    # Params
    progress::ProgressThresh{T}

    function ProgressiveHedgingAlgorithm(structure::HorizontalBlockStructure,
                                         x₀::AbstractVector,
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
        # Sanity checks
        length(x₀) != num_decisions(structure) && error("Incorrect length of starting guess, has ", length(x₀), " should be ", num_decisions(structure))
        num_subproblems == 0 && error("No subproblems in stochastic program. Cannot run progressive-hedging procedure.")
        n = num_subproblems(structure)
        # Float types
        T = promote_type(eltype(x₀), Float32)
        x₀_ = convert(AbstractVector{T}, copy(x₀))
        A = typeof(x₀_)
        # Structure
        ST = typeof(structure)
        S = typeof(backend(subproblem(structure, 1)))
        # Penalty term
        PT = typeof(penaltyterm)
        # Execution policy
        execution = executer(T,A,S,PT)
        E = typeof(execution)
        # Penalization policy
        penalization = penalizer()
        P = typeof(penalization)
        # Algorithm parameters
        params = ProgressiveHedgingParameters{T}(; kw...)

        ph = new{T,A,ST,S,E,P,PT}(structure,
                                  ProgressiveHedgingData{T}(),
                                  params,
                                  x₀_,
                                  structure.decisions[1],
                                  A(),
                                  A(),
                                  execution,
                                  penalization,
                                  ProgressThresh(T(1.0), 0.0, "$(indentstr(params.indent))Progressive Hedging"))
        # Initialize solver
        initialize!(ph, penaltyterm)
        return ph
    end
end

function show(io::IO, ph::ProgressiveHedgingAlgorithm)
    println(io, typeof(ph).name.name)
    println(io, "State:")
    show(io, ph.data)
    println(io, "Parameters:")
    show(io, ph.parameters)
end

function show(io::IO, ::MIME"text/plain", ph::ProgressiveHedgingAlgorithm)
    show(io, ph)
end

function (ph::ProgressiveHedgingAlgorithm)()
    # Reset timer
    ph.progress.tfirst = ph.progress.tlast = time()
    # Start workers (if any)
    start_workers!(ph)
    # Start procedure
    while true
        status = iterate!(ph)
        if status !== nothing
            close_workers!(ph)
            return status
        end
    end
end
