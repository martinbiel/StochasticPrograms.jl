@with_kw mutable struct DistributedLShapedData{T <: Real}
    Q::T = 1e10
    θ::T = -1e10
    timestamp::Int = 1
    incumbent::Int = 1
    ncuts::Int = 0
    iterations::Int = 0
    consolidations::Int = 0
end

@with_kw mutable struct DistributedLShapedParameters{T <: Real}
    κ::T = 0.6
    τ::T = 1e-6
    cut_scaling::T = 1.0
    debug::Bool = false
    log::Bool = true
    keep::Bool = true
    offset::Int = 0
    indent::Int = 0
end

"""
    DistributedLShaped

Functor object for the distributed L-shaped algorithm. Create by supplying `:dls` to the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model, assuming there are available worker cores.

...
# Algorithm parameters
- `κ::Real = 0.6`: Amount of cutting planes, relative to the total number of scenarios, required to generate a new iterate in master procedure.
- `τ::Real = 1e-6`: Relative tolerance for convergence checks.
- `debug::Bool = false`: Specifies if extra information should be saved for debugging purposes. Defaults to false for memory efficiency.
- `log::Bool = true`: Specifices if L-shaped procedure should be logged on standard output or not.
...
"""
struct DistributedLShaped{T <: AbstractFloat,
                          A <: AbstractVector,
                          SP <: StochasticProgram,
                          M <: LQSolver,
                          S <: LQSolver,
                          F <: AbstractFeasibility,
                          R <: AbstractRegularization,
                          Agg <: AbstractAggregation,
                          C <: AbstractConsolidation} <: AbstractLShapedSolver
    stochasticprogram::SP
    data::DistributedLShapedData{T}
    parameters::DistributedLShapedParameters{T}

    # Master
    mastersolver::M
    mastervector::A
    c::A
    x::A
    Q_history::A

    # Subproblems
    nscenarios::Int
    subobjectives::Vector{A}
    finished::Vector{Int}

    # Workers
    subworkers::Vector{SubWorker{F,T,A,S}}
    work::Vector{Work}
    metadata::Vector{MetaData}
    decisions::Decisions{A}
    cutqueue::CutQueue{T}
    active_workers::Vector{Future}

    # Feasibility
    feasibility::F

    # Regularization
    regularizer::R

    # Cuts
    θs::A
    cuts::Vector{AnySparseOptimalityCut{T}}
    aggregation::Agg
    consolidation::C
    θ_history::A
    added::Vector{Bool}

    progress::ProgressThresh{T}

    function DistributedLShaped(stochasticprogram::StochasticProgram,
                                x₀::AbstractVector,
                                mastersolver::MPB.AbstractMathProgSolver,
                                subsolver::SubSolver,
                                complete_recourse::Bool,
                                regularizer::AbstractRegularizer,
                                aggregator::AbstractAggregator,
                                consolidator::AbstractConsolidator; kw...)
        if nworkers() == 1
            @warn "There are no worker processes, defaulting to serial version of algorithm"
            d = Dict(kw...)
            delete!(d, :κ)
            return LShaped(stochasticprogram, x₀, mastersolver, get_solver(subsolver), complete_recourse, regularizer, aggregator, consolidator; d...)
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
        solver_instance = get_solver(subsolver)
        S = LQSolver{typeof(MPB.LinearQuadraticModel(solver_instance)),typeof(solver_instance)}
        n = StochasticPrograms.nscenarios(stochasticprogram)
        feasibility = complete_recourse ? IgnoreFeasibility() : HandleFeasibility(T)
        F = typeof(feasibility)
        subworkers = Vector{SubWorker{F,T,A,S}}(undef,nworkers())
        load_subproblems!(subworkers, scenarioproblems(stochasticprogram), x₀_, subsolver)
        regularization = regularizer(x₀_)
        R = typeof(regularization)
        aggregation = aggregator(n, T)
        Agg = typeof(aggregation)
        consolidation = consolidator(T)
        C = typeof(consolidation)
        params = DistributedLShapedParameters{T}(; kw...)

        lshaped = new{T,A,SP,M,S,F,R,Agg,C}(stochasticprogram,
                                            DistributedLShapedData{T}(),
                                            params,
                                            msolver,
                                            mastervector,
                                            c_,
                                            x₀_,
                                            A(),
                                            n,
                                            Vector{A}(),
                                            Vector{Int}(),
                                            subworkers,
                                            Vector{Work}(undef,nworkers()),
                                            Vector{MetaData}(undef,nworkers()),
                                            RemoteChannel(() -> DecisionChannel(Dict{Int,A}())),
                                            RemoteChannel(() -> Channel{QCut{T}}(4*nworkers()*n)),
                                            Vector{Future}(undef,nworkers()),
                                            feasibility,
                                            regularization,
                                            A(),
                                            Vector{SparseHyperPlane{T}}(),
                                            aggregation,
                                            consolidation,
                                            A(),
                                            Vector{Bool}(),
                                            ProgressThresh(1.0, 0.0, "$(indentstr(params.indent))Distributed L-Shaped Gap "))
        # Initialize solver
        init!(lshaped)
        return lshaped
    end
end
DisributedLShaped(stochasticprogram::StochasticProgram,
                  mastersolver::MPB.AbstractMathProgSolver,
                  subsolver::SubSolver,
                  complete_recourse::Bool,
                  regularizer::AbstractRegularizer,
                  aggregator::AbstractAggregator,
                  consolidator::AbstractConsolidator; kw...) = DistributedLShaped(stochasticprogram,
                                                                                  rand(decision_length(stochasticprogram)),
                                                                                  mastersolver,
                                                                                  subsolver,
                                                                                  complete_recourse,
                                                                                  regularizer,
                                                                                  aggregator,
                                                                                  consolidator; kw...)

function init_solver!(lshaped::DistributedLShaped)
    @unpack κ = lshaped.parameters
    # Load initial decision
    put!(lshaped.decisions, 1, copy(lshaped.x))
    # Prepare memory
    push!(lshaped.subobjectives, zeros(nthetas(lshaped)))
    push!(lshaped.finished, 0)
    push!(lshaped.added, false)
    log_val = lshaped.parameters.log
    lshaped.parameters.log = false
    log!(lshaped)
    lshaped.parameters.log = log_val
    # Prepare work channels
    for w in workers()
        lshaped.work[w-1] = RemoteChannel(() -> Channel{Int}(10), w)
        lshaped.metadata[w-1] = RemoteChannel(() -> MetaChannel(), w)
        put!(lshaped.work[w-1], 1)
        put!(lshaped.metadata[w-1], 1, :gap, Inf)
    end
    return lshaped
end

function load_subproblems!(subworkers::Vector{SubWorker{F,T,A,S}},
                           scenarioproblems::AbstractScenarioProblems,
                           x::AbstractVector,
                           subsolver::SubSolver) where {F <: AbstractFeasibility,
                                                        T <: AbstractFloat,
                                                        A <: AbstractVector,
                                                        S <: LQSolver}
    # Create subproblems on worker processes
    @sync begin
        for w in workers()
            subworkers[w-1] = RemoteChannel(() -> Channel{Vector{SubProblem{F,T,A,S}}}(1), w)
            @async load_worker!(scenarioproblems, w, subworkers[w-1], x, subsolver)
        end
    end
end

function init_workers!(lshaped::DistributedLShaped)
    for w in workers()
        worker_aggregator = remote_aggregator(lshaped.aggregation, scenarioproblems(lshaped.stochasticprogram), w)
        lshaped.active_workers[w-1] = remotecall(work_on_subproblems!,
                                                 w,
                                                 lshaped.subworkers[w-1],
                                                 lshaped.work[w-1],
                                                 lshaped.cutqueue,
                                                 lshaped.decisions,
                                                 lshaped.metadata[w-1],
                                                 worker_aggregator)
    end
    return nothing
end

function close_workers!(lshaped::DistributedLShaped)
    map((w)->close(w), lshaped.work)
    map(wait, lshaped.active_workers)
    return nothing
end

function nthetas(lshaped::DistributedLShaped)
    return nthetas(lshaped.nscenarios, lshaped.aggregation, scenarioproblems(lshaped.stochasticprogram))
end

function timestamp(lshaped::DistributedLShaped)
    return lshaped.data.timestamp
end

function incumbent_decision(lshaped::DistributedLShaped, t::Integer, regularizer::AbstractRegularization)
    return t > 1 ? fetch(lshaped.decisions, regularizer.incumbents[t]) : regularizer.ξ
end

function incumbent_objective(::DistributedLShaped, t::Integer, regularizer::AbstractRegularization)
    return t > 1 ? regularizer.Q̃_history[regularizer.incumbents[t]] : regularizer.data.Q̃
end

function incumbent_trustregion(::DistributedLShaped, t::Integer, rd::RegularizedDecomposition)
    return rd.σ_history[t]
end

function incumbent_trustregion(::DistributedLShaped, t::Integer, tr::TrustRegion)
    return tr.Δ_history[t]
end

function calculate_objective_value(lshaped::DistributedLShaped, x::AbstractVector)
    Qs = Vector{Float64}(undef, nworkers())
    @sync begin
        for (w,worker) in enumerate(lshaped.subworkers)
            @async Qs[w] = remotecall_fetch(calculate_subobjective, w+1, worker, x)
        end
    end
    return lshaped.c⋅x + sum(Qs)
end


function fill_submodels!(lshaped::DistributedLShaped, scenarioproblems::ScenarioProblems)
    j = 0
    @sync begin
        for w in workers()
            n = remotecall_fetch((sw)->length(fetch(sw)), w, lshaped.subworkers[w-1])
            for i = 1:n
                k = i+j
                @async fill_submodel!(scenarioproblems.problems[k],remotecall_fetch((sw,i,x)->begin
                    sp = fetch(sw)[i]
                    sp(x)
                    get_solution(sp)
                end,
                w,
                lshaped.subworkers[w-1],
                i,
                decision(lshaped))...)
            end
            j += n
        end
    end
    return nothing
end

function fill_submodels!(lshaped::DistributedLShaped, scenarioproblems::DScenarioProblems)
    @sync begin
        for w in workers()
            @async remotecall_fetch(fill_submodels!,
                                    w,
                                    lshaped.subworkers[w-1],
                                    decision(lshaped),
                                    scenarioproblems[w-1])
        end
    end
    return nothing
end

function add_cut!(lshaped::DistributedLShaped, t::Integer, cut::AbstractHyperPlane, Q::Real)
    added = add_cut!(lshaped, cut, lshaped.subobjectives[t], Q)
    lshaped.added[t] |= added
    update_objective!(lshaped, cut)
    lshaped.finished[t] += nsubproblems(cut)
    added && add_cut!(lshaped, lshaped.consolidation, t, cut)
    return nothing
end

# Consolidation functions
# ------------------------------------------------------------
function readd_cuts!(lshaped::DistributedLShaped, consolidation::Consolidation)
    for i in eachindex(consolidation.cuts)
        for cut in consolidation.cuts[i]
            add_cut!(lshaped, cut, lshaped.subobjectives[i], sum(lshaped.subobjectives[i]), check = false)
        end
        for cut in consolidation.feasibility_cuts[i]
            add_cut!(lshaped, cut, lshaped.subobjectives[i], Inf)
        end
    end
    return nothing
end

function for_loadbalance(lshaped::DistributedLShaped, τ, miniter)
    nsubconstraints = remotecall_fetch((sp)->length(fetch(sp).problems[1].linconstr), 2, scenarioproblems(lshaped.stochasticprogram).scenarioproblems[1])
    return lshaped.data.iterations >= (lshaped.data.consolidations+1)*miniter && (sqrt(nscenarios(lshaped))*nsubconstraints/nworkers())/ncutconstraints(lshaped) <= τ
end
# ------------------------------------------------------------

function iterate!(lshaped::DistributedLShaped{T}) where T <: AbstractFloat
    wait(lshaped.cutqueue)
    while isready(lshaped.cutqueue)
        # Add new cuts from subworkers
        t::Int, Q::T, cut::SparseHyperPlane{T} = take!(lshaped.cutqueue)
        if Q == Inf && !handle_feasibility(lshaped.feasibility)
            @warn "Stochastic program is not second-stage feasible at the current decision. Rerun procedure with complete_recourse = false to use feasibility cuts."
            return :Infeasible
        end
        if !bounded(cut)
            map((w,aw)->!isready(aw) && put!(w,-1), lshaped.work, lshaped.active_workers)
            return :Unbounded
        end
        add_cut!(lshaped, t, cut, Q)
        if lshaped.finished[t] == nthetas(lshaped)
            lshaped.data.timestamp = t
            lshaped.x .= fetch(lshaped.decisions, t)
            lshaped.Q_history[t] = current_objective_value(lshaped, lshaped.subobjectives[t])
            lshaped.data.Q = lshaped.Q_history[t]
            lshaped.data.θ = t > 1 ? lshaped.θ_history[t-1] : -1e10
            take_step!(lshaped)
            lshaped.data.θ = lshaped.θ_history[t]
            # Check if optimal
            if check_optimality(lshaped) || (lshaped.regularizer isa NoRegularization && !lshaped.added[t])
                # Optimal, tell workers to stop
                map((w,aw)->!isready(aw) && put!(w,t), lshaped.work, lshaped.active_workers)
                map((w,aw)->!isready(aw) && put!(w,-1), lshaped.work, lshaped.active_workers)
                # Final log
                log!(lshaped, lshaped.data.iterations)
                return :Optimal
            end
            # Consolidate (if applicable)
            consolidate!(lshaped, lshaped.consolidation)
        end
    end
    t = lshaped.data.iterations
    κ = t > 1 ? lshaped.parameters.κ : 1.0
    if lshaped.finished[t] >= κ*nthetas(lshaped)
        # Resolve master
        status = solve_master!(lshaped)
        if status != :Optimal
            map((w,aw)->!isready(aw) && put!(w,-1), lshaped.work, lshaped.active_workers)
            return status
        end
        # Update master solution
        update_solution!(lshaped)
        θ = calculate_estimate(lshaped)
        # if t > 1 && abs(θ-lshaped.θ_history[t-1]) <= 10*lshaped.parameters.τ*abs(1e-10+θ) && lshaped.finished[t] != nthetas(lshaped)
        #     # Not enough new information in master. Repeat iterate
        #     return :Valid
        # end
        lshaped.data.θ = θ
        lshaped.θ_history[t] = θ
        # Project (if applicable)
        project!(lshaped)
        # If all work is finished at this timestamp, check optimality
        if lshaped.finished[t] == nthetas(lshaped)
            # Check if optimal
            if check_optimality(lshaped) || (lshaped.regularizer isa NoRegularization && !lshaped.added[t])
                # Optimal, tell workers to stop
                map((w,aw)->!isready(aw) && put!(w,t), lshaped.work, lshaped.active_workers)
                map((w,aw)->!isready(aw) && put!(w,-1), lshaped.work, lshaped.active_workers)
                # Final log
                log!(lshaped, t)
                return :Optimal
            end
        end
        # Log progress at current timestamp
        log_regularization!(lshaped, t)
        # Update workers
        put!(lshaped.decisions, t+1, copy(lshaped.x))
        for w in workers()
            if !isready(lshaped.active_workers[w-1])
                put!(lshaped.work[w-1], t+1)
                put!(lshaped.metadata[w-1], t+1, :gap, gap(lshaped))
            end
        end
        # Prepare memory for next iteration
        push!(lshaped.subobjectives, zeros(nthetas(lshaped)))
        push!(lshaped.finished, 0)
        push!(lshaped.added, false)
        # Log progress
        log!(lshaped)
        lshaped.θ_history[t+1] = -Inf
    end
    # Just return a valid status for this iteration
    return :Valid
end

function (lshaped::DistributedLShaped)()
    # Reset timer
    lshaped.progress.tfirst = lshaped.progress.tlast = time()
    # Start workers
    init_workers!(lshaped)
    # Start procedure
    while true
        status = iterate!(lshaped)
        if status != :Valid
            close_workers!(lshaped)
            return status
        end
    end
end
