@with_kw mutable struct ProgressiveHedgingData{T <: AbstractFloat}
    Q::T = 1e10
    δ₁::T = 1.0
    δ₂::T = 1.0
    iterations::Int = 0
end

@with_kw mutable struct ProgressiveHedgingParameters{T <: AbstractFloat}
    ϵ₁::T = 1e-5
    ϵ₂::T = 1e-5
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
                                   ST <: HorizontalStructure,
                                   E <: AbstractProgressiveHedgingExecution,
                                   P <: AbstractPenalization,
                                   PT <: AbstractPenaltyTerm} <: AbstractProgressiveHedging
    structure::ST
    data::ProgressiveHedgingData{T}
    parameters::ProgressiveHedgingParameters{T}

    # Estimate
    ξ::A
    decisions::Decisions
    Q_history::A
    primal_gaps::A
    dual_gaps::A

    # Execution
    execution::E

    penalization::P

    # Params
    progress::ProgressThresh{T}

    function ProgressiveHedgingAlgorithm(structure::HorizontalStructure,
                                         x₀::AbstractVector,
                                         executer::AbstractExecution,
                                         penalizer::AbstractPenalizer,
                                         penaltyterm::AbstractPenaltyTerm; kw...)
        # Sanity checks
        length(x₀) != num_decisions(structure) && error("Incorrect length of starting guess, has ", length(x₀), " should be ", num_decisions(structure))
        num_subproblems == 0 && error("No subproblems in stochastic program. Cannot run progressive-hedging procedure.")
        n = num_subproblems(structure, 2)
        # Float types
        T = promote_type(eltype(x₀), Float32)
        x₀_ = convert(AbstractVector{T}, copy(x₀))
        A = typeof(x₀_)
        # Structure
        ST = typeof(structure)
        # Penalty term
        PT = typeof(penaltyterm)
        # Execution policy
        execution = executer(T, A, PT)
        E = typeof(execution)
        # Penalization policy
        penalization = penalizer()
        P = typeof(penalization)
        # Algorithm parameters
        params = ProgressiveHedgingParameters{T}(; kw...)

        ph = new{T,A,ST,E,P,PT}(structure,
                                ProgressiveHedgingData{T}(),
                                params,
                                x₀_,
                                structure.decisions[1],
                                A(),
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
