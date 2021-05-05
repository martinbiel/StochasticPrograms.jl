@with_kw mutable struct QuasiGradientData{T <: AbstractFloat}
    Q::T = 1e10
    master_objective::AffineDecisionFunction{T} = zero(AffineDecisionFunction{T})
    no_objective::Bool = false
    iterations::Int = 1
end

@with_kw mutable struct QuasiGradientParameters{T <: AbstractFloat}
    debug::Bool = false
    time_limit::T = Inf
    log::Bool = true
    keep::Bool = true
    offset::Int = 0
    indent::Int = 0
end

"""
    QuasiGradientAlgorithm

Functor object for the quasi-gradient algorithm.

...
# Algorithm parameters
- `log::Bool = true`: Specifices if quasi-gradient procedure should be logged on standard output or not.
...
"""
struct QuasiGradientAlgorithm{T <: AbstractFloat,
                              A <: AbstractVector,
                              ST <: VerticalStructure,
                              M <: MOI.AbstractOptimizer,
                              E <: AbstractQuasiGradientExecution,
                              P <: AbstractProximal,
                              S <: AbstractStep,
                              C <: AbstractTerminationCriterion,
                              Pr <: AbstractProgress} <: AbstractQuasiGradient
    structure::ST
    num_subproblems::Int
    data::QuasiGradientData{T}
    parameters::QuasiGradientParameters{T}

    # Master
    master::M
    decisions::DecisionMap
    x::A
    ξ::A
    c::A
    gradient::A
    Q_history::A

    # Execution
    execution::E

    # Prox
    prox::P

    # Step
    step::S

    # Termination
    criterion::C

    progress::Pr

    function QuasiGradientAlgorithm(structure::VerticalStructure,
                                    x₀::AbstractVector,
                                    _execution::AbstractExecution,
                                    subproblems::AbstractSubProblemState,
                                    _prox::AbstractProx,
                                    step::AbstractStepSize,
                                    _criterion::AbstractTermination; kw...)
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
        M = typeof(backend(structure.first_stage))
        # Prox
        prox = _prox(structure, x₀_, T)
        P = typeof(prox)
        # Step
        stepsize = step(T)
        S = typeof(stepsize)
        # Termination
        criterion = _criterion(T)
        C = typeof(criterion)
        # Execution policy
        execution = _execution(structure, x₀_, subproblems, T)
        E = typeof(execution)
        # Algorithm parameters
        params = QuasiGradientParameters{T}(; kw...)
        # Progress
        progress = Progress(criterion, "$(indentstr(params.indent))Quasi-gradient Progress ")
        Pr = typeof(progress)

        quasigradient = new{T,A,ST,M,E,P,S,C,Pr}(structure,
                                                 n,
                                                 QuasiGradientData{T}(),
                                                 params,
                                                 backend(structure.first_stage),
                                                 structure.decisions[1],
                                                 x₀_,
                                                 copy(x₀_),
                                                 zero(x₀_),
                                                 zero(x₀_),
                                                 A(),
                                                 execution,
                                                 prox,
                                                 stepsize,
                                                 criterion,
                                                 progress)
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
    quasigradient.progress.tinit = quasigradient.progress.tlast = time()
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
