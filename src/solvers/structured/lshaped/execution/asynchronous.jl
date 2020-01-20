@with_kw mutable struct AsynchronousData{T <: AbstractFloat}
    timestamp::Int = 1
    incumbent::Int = 1
    active::Int = 0
end

"""
    AsynchronousExecution

Functor object for using synchronous execution in an L-shaped algorithm (assuming multiple Julia cores are available). Create by supplying a [`Asynchronous`](@ref) object through `execution` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

"""
struct AsynchronousExecution{F <: AbstractFeasibility,
                             T <: AbstractFloat,
                             A <: AbstractVector,
                             S <: LQSolver} <: AbstractExecution
    data::AsynchronousData{T}
    subobjectives::Vector{A}
    model_objectives::Vector{A}
    finished::Vector{Int}
    subworkers::Vector{SubWorker{F,T,A,S}}
    work::Vector{Work}
    finalize::Vector{Work}
    metadata::Vector{MetaData}
    decisions::Decisions{A}
    cutqueue::CutQueue{T}
    active_workers::Vector{Future}
    triggered::Vector{Bool}
    added::Vector{Bool}
    max_active::Int
    κ::T

    function AsynchronousExecution(nscenarios::Integer, max_active::Int, κ::T, ::Type{F}, ::Type{T}, ::Type{A}, ::Type{S}) where {F <: AbstractFeasibility, T <: AbstractFloat, A <: AbstractVector, S <: LQSolver}
        return new{F,T,A,S}(AsynchronousData{T}(),
                            Vector{A}(),
                            Vector{A}(),
                            Vector{Int}(),
                            Vector{SubWorker{F,T,A,S}}(undef, nworkers()),
                            Vector{Work}(undef,nworkers()),
                            Vector{Work}(undef,nworkers()),
                            Vector{MetaData}(undef,nworkers()),
                            RemoteChannel(() -> DecisionChannel(Dict{Int,A}())),
                            RemoteChannel(() -> Channel{QCut{T}}(max_active*nworkers()*nscenarios)),
                            Vector{Future}(undef,nworkers()),
                            Vector{Bool}(),
                            Vector{Bool}(),
                            max_active,
                            κ)
    end
end

function initialize_subproblems!(execution::AsynchronousExecution,
                                 scenarioproblems::AbstractScenarioProblems,
                                 x::AbstractVector,
                                 subsolver::MPB.AbstractMathProgSolver)
    load_subproblems!(execution.subworkers, scenarioproblems, x, subsolver)
    return nothing
end

function finish_initilization!(lshaped::AbstractLShapedSolver, execution::AsynchronousExecution)
    # Load initial decision
    put!(execution.decisions, 1, copy(lshaped.x))
    # Prepare memory
    push!(execution.subobjectives, zeros(nthetas(lshaped)))
    push!(execution.model_objectives, zeros(nthetas(lshaped)))
    push!(execution.finished, 0)
    push!(execution.triggered, false)
    push!(execution.added, false)
    push!(lshaped.Q_history, Inf)
    push!(lshaped.θ_history, -Inf)
    log_regularization!(lshaped)

    # Prepare work channels
    for w in workers()
        execution.work[w-1] = RemoteChannel(() -> Channel{Int}(execution.max_active+1), w)
        execution.finalize[w-1] = RemoteChannel(() -> Channel{Int}(1), w)
        execution.metadata[w-1] = RemoteChannel(() -> MetaChannel(), w)
        put!(execution.work[w-1], 1)
        put!(execution.metadata[w-1], 1, :gap, Inf)
    end
    return nothing
end

function start_workers!(lshaped::AbstractLShapedSolver, execution::AsynchronousExecution)
    for w in workers()
        worker_aggregator = remote_aggregator(lshaped.aggregation, scenarioproblems(lshaped.stochasticprogram), w)
        execution.active_workers[w-1] = remotecall(work_on_subproblems!,
                                                   w,
                                                   execution.subworkers[w-1],
                                                   execution.work[w-1],
                                                   execution.finalize[w-1],
                                                   execution.cutqueue,
                                                   execution.decisions,
                                                   execution.metadata[w-1],
                                                   worker_aggregator)
    end
    return nothing
end

function close_workers!(::AbstractLShapedSolver, execution::AsynchronousExecution)
    t = execution.data.timestamp
    map((w,aw)->!isready(aw) && put!(w,t), execution.finalize, execution.active_workers)
    map((w,aw)->!isready(aw) && put!(w,-1), execution.work, execution.active_workers)
    map(wait, execution.active_workers)
    return nothing
end

function resolve_subproblems!(::AbstractLShapedSolver, ::AsynchronousExecution)
    return nothing
end

function calculate_objective_value(lshaped::AbstractLShapedSolver, execution::AsynchronousExecution)
    return lshaped.c⋅decision(lshaped) + eval_second_stage(execution.subworkers, decision(lshaped))
end

function current_decision(lshaped::AbstractLShapedSolver, execution::AsynchronousExecution)
    t = timestamp(lshaped)
    return fetch(execution.decisions, t)
end

function timestamp(::AbstractLShapedSolver, execution::AsynchronousExecution)
    return execution.data.timestamp
end

function incumbent_decision(::AbstractLShapedSolver, t::Integer, regularizer::AbstractRegularization, execution::AsynchronousExecution)
    return t > 1 ? fetch(execution.decisions, regularizer.incumbents[t]) : regularizer.ξ
end

function incumbent_objective(::AbstractLShapedSolver, t::Integer, regularizer::AbstractRegularization, ::AsynchronousExecution)
    return t > 1 ? regularizer.Q̃_history[regularizer.incumbents[t]] : regularizer.data.Q̃
end

function incumbent_trustregion(::AbstractLShapedSolver, t::Integer, rd::RegularizedDecomposition, ::AsynchronousExecution)
    return rd.σ_history[t]
end

function incumbent_trustregion(::AbstractLShapedSolver, t::Integer, tr::TrustRegion, ::AsynchronousExecution)
    return tr.Δ_history[t]
end

function readd_cuts!(lshaped::AbstractLShapedSolver, consolidation::Consolidation, execution::AsynchronousExecution)
    for i in eachindex(consolidation.cuts)
        for cut in consolidation.cuts[i]
            add_cut!(lshaped, cut, execution.θs[i], execution.subobjectives[i], sum(execution.subobjectives[i]), fetch(execution.decisions, i), check = false)
        end
        for cut in consolidation.feasibility_cuts[i]
            add_cut!(lshaped, cut, execution.θs[i], execution.subobjectives[i], Inf)
        end
    end
    return nothing
end

function subobjectives(lshaped::AbstractLShapedSolver, execution::AsynchronousExecution)
    t = timestamp(lshaped)
    return execution.subobjectives[t]
end

function set_subobjectives(lshaped::AbstractLShapedSolver, Qs::AbstractVector, execution::AsynchronousExecution)
    t = timestamp(lshaped)
    execution.subobjectives[t] .= Qs
    return nothing
end

function model_objectives(lshaped::AbstractLShapedSolver, execution::AsynchronousExecution)
    t = niterations(lshaped)
    θs = t > 1 ? execution.model_objectives[t-1] : fill(-1e10, nthetas(lshaped))
    return θs
end

function set_model_objectives(lshaped::AbstractLShapedSolver, θs::AbstractVector, execution::AsynchronousExecution)
    t = timestamp(lshaped)
    execution.model_objectives[t] .= θs
    return nothing
end

function fill_submodels!(lshaped::AbstractLShapedSolver, scenarioproblems, execution::AsynchronousExecution)
    return fill_submodels!(execution.subworkers, decision(lshaped), scenarioproblems)
end

function iterate!(lshaped::AbstractLShapedSolver, execution::AsynchronousExecution{F,T}) where {F <: AbstractFeasibility, T <: AbstractFloat}
    wait(execution.cutqueue)
    while isready(execution.cutqueue)
        newiterate = false
        # Add new cuts from subworkers
        t::Int, cut::SparseHyperPlane{T} = take!(execution.cutqueue)
        execution.data.timestamp = t
        # Break if any subproblem is infeasible or unbounded
        if infeasible(cut)
            @warn "Stochastic program is not second-stage feasible at the current decision. Rerun procedure with complete_recourse = false to use feasibility cuts."
            return :Infeasible
        end
        if !bounded(cut)
            return :Unbounded
        end
        # Otherwise, add new cut to master and update bookkeeping
        lshaped.execution.added[t] |= add_cut!(lshaped, cut)
        lshaped.execution.finished[t] += nsubproblems(cut)
        # Asynchronicity parameter should be 1 first iteration
        κ = t > 1 ? execution.κ : 1.0
        if execution.finished[t] == nthetas(lshaped)
            # All work from iteration t complete
            lshaped.Q_history[t] = current_objective_value(lshaped)
            lshaped.data.Q = lshaped.Q_history[t]
            lshaped.data.θ = t > 1 ? lshaped.θ_history[t-1] : -1e10
            # Update incumbent (if applicable)
            lshaped.x .= fetch(execution.decisions, t)
            take_step!(lshaped)
            # Optimal if not using regularization and no cuts were added
            if lshaped.regularizer isa NoRegularization && !execution.added[t]
                # Optimal, final log
                log!(lshaped, t; optimal = true)
                return :Optimal
            end
            # Consolidate (if applicable)
            consolidate!(lshaped, lshaped.consolidation)
            # Decrease number of active iterations
            execution.data.active = max(0, execution.data.active-1)
            newiterate |= !(lshaped.regularizer isa NoRegularization && execution.triggered[t])
            newiterate |= t == 1
        elseif execution.finished[t] >= κ*nthetas(lshaped) && !execution.triggered[t] && execution.data.active < execution.max_active && execution.added[t]
            execution.triggered[t] = true
            newiterate |= true
        else
            newiterate |= false
        end
        # Generate new candidate decision
        if newiterate
            t = lshaped.data.iterations
            execution.data.timestamp = t
            # Resolve master
            status = solve_master!(lshaped)
            if status != :Optimal
                return status
            end
            # Update master solution
            update_solution!(lshaped, lshaped.mastersolver)
            θ = lshaped.c⋅lshaped.x + sum(execution.model_objectives[t])
            lshaped.data.θ = θ
            lshaped.θ_history[t] = θ
            # Check if optimal
            if check_optimality(lshaped)
                # Optimal, final log
                log!(lshaped, t)
                return :Optimal
            end
            # Project (if applicable)
            project!(lshaped)
            # Log progress at current timestamp
            log_regularization!(lshaped, t)
            # Update workers
            put!(execution.decisions, t+1, copy(lshaped.x))
            for w in workers()
                if !isready(execution.active_workers[w-1])
                    put!(execution.work[w-1], t+1)
                    put!(execution.metadata[w-1], t+1, :gap, gap(lshaped))
                end
            end
            # New active iteration
            execution.data.active += 1
            # Prepare memory for next iteration
            push!(execution.subobjectives, zeros(nthetas(lshaped)))
            push!(execution.model_objectives, zeros(nthetas(lshaped)))
            push!(execution.finished, 0)
            push!(execution.triggered, false)
            push!(execution.added, false)
            # Log progress
            log!(lshaped)
            lshaped.θ_history[t+1] = -Inf
        end
    end
    # Just return a valid status for this iteration
    return :Valid
end

# API
# ------------------------------------------------------------
function (execution::Asynchronous)(nscenarios::Integer, ::Type{F}, ::Type{T}, ::Type{A}, ::Type{S}) where {F <: AbstractFeasibility, T <: AbstractFloat, A <: AbstractVector, S <: LQSolver}
    return AsynchronousExecution(nscenarios, execution.max_active, execution.κ, F, T, A, S)
end

function str(::Asynchronous)
    return "Asynchronous "
end
