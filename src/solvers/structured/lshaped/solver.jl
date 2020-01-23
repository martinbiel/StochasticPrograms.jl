@with_kw mutable struct LShapedData{T <: AbstractFloat}
    Q::T = 1e10
    θ::T = -1e10
    ncuts::Int = 0
    iterations::Int = 1
    consolidations::Int = 0
end

@with_kw mutable struct LShapedParameters{T <: AbstractFloat}
    τ::T = 1e-6
    cut_scaling::T = 1.0
    debug::Bool = false
    log::Bool = true
    keep::Bool = true
    offset::Int = 0
    indent::Int = 0
end

"""
    LShaped

Functor object for the L-shaped algorithm. Create using the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

...
# Algorithm parameters
- `τ::AbstractFloat = 1e-6`: Relative tolerance for convergence checks.
- `debug::Bool = false`: Specifies if extra information should be saved for debugging purposes. Defaults to false for memory efficiency.
- `log::Bool = true`: Specifices if L-shaped procedure should be logged on standard output or not.
...
"""
struct LShaped{T <: AbstractFloat,
               A <: AbstractVector,
               SP <: StochasticProgram,
               M <: LQSolver,
               S <: LQSolver,
               E <: AbstractExecution,
               F <: AbstractFeasibility,
               R <: AbstractRegularization,
               Agg <: AbstractAggregation,
               C <: AbstractConsolidation} <: AbstractLShapedSolver
    stochasticprogram::SP
    data::LShapedData{T}
    parameters::LShapedParameters{T}

    # Master
    mastersolver::M
    mastervector::A
    c::A
    x::A
    Q_history::A

    # Subproblems
    nscenarios::Int

    # Execution
    execution::E

    # Feasibility
    feasibility::F

    # Regularization
    regularization::R

    # Cuts
    θs::A
    cuts::Vector{AnySparseOptimalityCut{T}}
    aggregation::Agg
    consolidation::C
    θ_history::A

    progress::ProgressThresh{T}

    function LShaped(stochasticprogram::StochasticProgram,
                     x₀::AbstractVector,
                     mastersolver::MPB.AbstractMathProgSolver,
                     subsolver::MPB.AbstractMathProgSolver,
                     feasibility_cuts::Bool,
                     executer::Execution,
                     regularizer::AbstractRegularizer,
                     aggregator::AbstractAggregator,
                     consolidator::AbstractConsolidator; kw...)
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
        c_ = convert(AbstractVector{T}, JuMP.prepAffObjective(first_stage))
        c_ *= first_stage.objSense == :Min ? 1 : -1
        x₀_ = convert(AbstractVector{T}, copy(x₀))
        mastervector = convert(AbstractVector{T}, copy(x₀))
        A = typeof(x₀_)
        SP = typeof(stochasticprogram)
        msolver = LQSolver(first_stage, mastersolver)
        M = typeof(msolver)
        S = LQSolver{typeof(MPB.LinearQuadraticModel(subsolver)),typeof(subsolver)}
        n = StochasticPrograms.nscenarios(stochasticprogram)
        # Feasibility
        feasibility = feasibility_cuts ? HandleFeasibility(T) : IgnoreFeasibility()
        F = typeof(feasibility)
        # Execution policy
        execution = executer(n,F,T,A,S)
        E = typeof(execution)
        # Regularization policy
        regularization = regularizer(x₀_)
        R = typeof(regularization)
        # Aggregation policy
        aggregation = aggregator(n, T)
        Agg = typeof(aggregation)
        # Consolidation policy
        consolidation = consolidator(T)
        C = typeof(consolidation)
        # Algorithm parameters
        params = LShapedParameters{T}(; kw...)

        lshaped = new{T,A,SP,M,S,E,F,R,Agg,C}(stochasticprogram,
                                              LShapedData{T}(),
                                              params,
                                              msolver,
                                              mastervector,
                                              c_,
                                              x₀_,
                                              A(),
                                              n,
                                              execution,
                                              feasibility,
                                              regularization,
                                              A(),
                                              Vector{SparseOptimalityCut{T}}(),
                                              aggregation,
                                              consolidation,
                                              A(),
                                              ProgressThresh(T(1.0), 0.0, "$(indentstr(params.indent))L-Shaped Gap "))
        # Initialize solver
        initialize!(lshaped, subsolver)
        return lshaped
    end
end
LShaped(stochasticprogram::StochasticProgram,
        mastersolver::MPB.AbstractMathProgSolver,
        subsolver::MPB.AbstractMathProgSolver,
        feasibility_cuts::Bool,
        executer::Execution,
        regularizer::AbstractRegularizer,
        aggregator::AbstractAggregator,
        consolidator::AbstractConsolidator; kw...) = LShaped(stochasticprogram,
                                                             rand(decision_length(stochasticprogram)),
                                                             mastersolver,
                                                             subsolver,
                                                             feasibility_cuts,
                                                             executer,
                                                             regularizer,
                                                             aggregator,
                                                             consolidator; kw...)

function show(io::IO, lshaped::LShaped)
    println(io, typeof(lshaped).name.name)
    println(io, "State:")
    show(io, lshaped.data)
    println(io, "Parameters:")
    show(io, lshaped.parameters)
end

function show(io::IO, ::MIME"text/plain", lshaped::LShaped)
    show(io, lshaped)
end

function (lshaped::LShaped)()
    # Reset timer
    lshaped.progress.tfirst = lshaped.progress.tlast = time()
    # Start workers (if any)
    start_workers!(lshaped)
    # Start procedure
    while true
        status = iterate!(lshaped)
        if status != :Valid
            close_workers!(lshaped)
            return status
        end
    end
end
