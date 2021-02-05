@with_kw mutable struct QuasiGradientData{T <: AbstractFloat}
    Q::T = 1e10
    master_objective::AffineDecisionFunction{T} = zero(AffineDecisionFunction{T})
    no_objective::Bool = false
    iterations::Int = 1
end

@with_kw mutable struct QuasiGradientParameters{T <: AbstractFloat}
    τ::T = 1e-6
    maximum_iterations::Int = 1000
    debug::Bool = false
    time_limit::T = Inf
    log::Bool = true
    keep::Bool = true
    offset::Int = 0
    indent::Int = 0
end

"""
    QuasiGradientAlgorithm

Functor object for the L-shaped algorithm.

...
# Algorithm parameters
- `τ::AbstractFloat = 1e-6`: Relative tolerance for convergence checks.
- `debug::Bool = false`: Specifies if extra information should be saved for debugging purposes. Defaults to false for memory efficiency.
- `maximum_iterations::Int = 1000`: Number of iterations.
- `log::Bool = true`: Specifices if L-shaped procedure should be logged on standard output or not.
...
"""
struct QuasiGradientAlgorithm{T <: AbstractFloat,
                              A <: AbstractVector,
                              ST <: VerticalStructure,
                              E <: AbstractQuasiGradientExecution,
                              P <: AbstractProximal,
                              S <: AbstractStep} <: AbstractQuasiGradient
    structure::ST
    num_subproblems::Int
    data::QuasiGradientData{T}
    parameters::QuasiGradientParameters{T}

    # Iterate
    decisions::Decisions
    x::A
    c::A
    subgradient::A
    Q_history::A

    # Execution
    execution::E

    # Prox
    prox::P

    # Step
    step::S

    progress::Progress

    function QuasiGradientAlgorithm(structure::VerticalStructure,
                                    x₀::AbstractVector,
                                    _execution::AbstractExecution,
                                    _prox::AbstractProx,
                                    step::AbstractStepSize; kw...)
        # Sanity checks
        length(x₀) != num_decisions(structure, 1) && error("Incorrect length of starting guess, has ", length(x₀), " should be ", num_decisions(structure, 1))
        n = num_subproblems(structure, 2)
        n == 0 && error("No subproblems in stochastic program. Cannot run L-shaped procedure.")
        # Float types
        T = promote_type(eltype(x₀), Float32)
        x₀_ = convert(AbstractVector{T}, copy(x₀))
        A = typeof(x₀_)
        # Structure
        ST = typeof(structure)
        # Prox
        prox = _prox(structure, x₀_, T)
        P = typeof(prox)
        # Step
        stepsize = step()
        S = typeof(stepsize)
        # Execution policy
        execution = _execution(structure, T, A)
        E = typeof(execution)
        # Algorithm parameters
        params = QuasiGradientParameters{T}(; kw...)

        quasigradient = new{T,A,ST,E,P,S}(structure,
                                          n,
                                          QuasiGradientData{T}(),
                                          params,
                                          structure.decisions[1],
                                          x₀_,
                                          zero(x₀_),
                                          zero(x₀_),
                                          A(),
                                          execution,
                                          prox,
                                          stepsize,
                                          Progress(params.maximum_iterations, "$(indentstr(params.indent))Quasi-gradient Progress "))
        # Initialize solver
        initialize!(quasigradient)
        return quasigradient
    end
end

function show(io::IO, quasigradient::QuasiGradientAlgorithm)
    println(io, typeof(quasigradient).name.name)
    println(io, "State:")
    show(io, quasigradient.data)
    println(io, "Parameters:")
    show(io, quasigradient.parameters)
end

function show(io::IO, ::MIME"text/plain", quasigradient::QuasiGradientAlgorithm)
    show(io, quasigradient)
end

function (quasigradient::QuasiGradientAlgorithm)()
    # Reset timer
    quasigradient.progress.tfirst = quasigradient.progress.tlast = time()
    # Start workers (if any)
    start_workers!(quasigradient)
    # Start procedure
    while true
        status = iterate!(quasigradient)
        if status !== nothing
            close_workers!(quasigradient)
            return status
        end
    end
end
