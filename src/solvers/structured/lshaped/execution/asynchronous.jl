@with_kw mutable struct AsynchronousData{T <: AbstractFloat}
    timestamp::Int = 1
    incumbent::Int = 1
    active::Int = 0
end

"""
    AsynchronousExecution

Functor object for using synchronous execution in an L-shaped algorithm (assuming multiple Julia cores are available). Create by supplying a [`Asynchronous`](@ref) object through `execution` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

"""
struct AsynchronousExecution{T <: AbstractFloat,
                             A <: AbstractVector,
                             F <: AbstractFeasibilityAlgorithm,
                             I <: AbstractIntegerAlgorithm} <: AbstractLShapedExecution
    data::AsynchronousData{T}
    subobjectives::Vector{A}
    model_objectives::Vector{A}
    finished::Vector{Int}
    subworkers::Vector{SubWorker{T,F,I}}
    decisions::Vector{DecisionChannel}
    work::Vector{Work}
    finalize::Vector{Work}
    metadata::MetaDataChannel
    remote_metadata::Vector{MetaDataChannel}
    iterates::RemoteIterates{A}
    cutqueue::CutQueue{T}
    active_workers::Vector{Future}
    triggered::Vector{Bool}
    added::Vector{Bool}
    max_active::Int
    κ::T

    function AsynchronousExecution(structure::VerticalStructure{2, 1, <:Tuple{DistributedScenarioProblems}},
                                   max_active::Int, κ::T,
                                   feasibility_strategy::AbstractFeasibilityStrategy,
                                   integer_strategy::AbstractIntegerStrategy,
                                   ::Type{T},
                                   ::Type{A}) where {T <: AbstractFloat,
                                                     A <: AbstractVector}
        F = worker_type(feasibility_strategy)
        I = worker_type(integer_strategy)
        execution = new{T,A,F,I}(AsynchronousData{T}(),
                                 Vector{A}(),
                                 Vector{A}(),
                                 Vector{Int}(),
                                 Vector{SubWorker{T,F,I}}(undef, nworkers()),
                                 scenarioproblems(structure).decisions,
                                 Vector{Work}(undef, nworkers()),
                                 Vector{Work}(undef, nworkers()),
                                 RemoteChannel(() -> MetaChannel()),
                                 Vector{MetaDataChannel}(undef, nworkers()),
                                 RemoteChannel(() -> IterateChannel(Dict{Int,A}())),
                                 RemoteChannel(() -> Channel{QCut{T}}(max_active * nworkers() * num_scenarios(structure))),
                                 Vector{Future}(undef, nworkers()),
                                 Vector{Bool}(),
                                 Vector{Bool}(),
                                 max_active,
                                 κ)
        # Start loading subproblems
        load_subproblems!(execution.subworkers,
                          scenarioproblems(structure, 2),
                          execution.decisions,
                          feasibility_strategy,
                          integer_strategy)
        return execution
    end
end

function finish_initilization!(lshaped::AbstractLShaped, execution::AsynchronousExecution)
    # Load initial decision
    put!(execution.iterates, 1, copy(lshaped.x))
    # Prepare memory
    push!(execution.subobjectives, fill(1e10, num_thetas(lshaped)))
    push!(execution.model_objectives, fill(-1e10, num_thetas(lshaped)))
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
        execution.remote_metadata[w-1] = RemoteChannel(() -> MetaChannel(), w)
        put!(execution.work[w-1], 1)
        put!(execution.remote_metadata[w-1], 1, :gap, Inf)
    end
    return nothing
end

function start_workers!(lshaped::AbstractLShaped, execution::AsynchronousExecution)
    for w in workers()
        worker_aggregator = remote_aggregator(lshaped.aggregation, scenarioproblems(lshaped.structure), w)
        execution.active_workers[w-1] = remotecall(work_on_subproblems!,
                                                   w,
                                                   execution.subworkers[w-1],
                                                   execution.decisions[w-1],
                                                   execution.work[w-1],
                                                   execution.finalize[w-1],
                                                   execution.cutqueue,
                                                   execution.iterates,
                                                   execution.metadata,
                                                   execution.remote_metadata[w-1],
                                                   worker_aggregator)
    end
    return nothing
end

function close_workers!(::AbstractLShaped, execution::AsynchronousExecution)
    t = execution.data.timestamp
    map((w, aw)->!isready(aw) && put!(w, t), execution.finalize, execution.active_workers)
    map((w, aw)->!isready(aw) && put!(w, -1), execution.work, execution.active_workers)
    map(wait, execution.active_workers)
    return nothing
end

function mutate_subproblems!(mutator::Function, execution::AsynchronousExecution)
    mutate_subproblems!(mutator, execution.subworkers)
    return nothing
end

function resolve_subproblems!(::AbstractLShaped, ::AsynchronousExecution)
    return nothing
end

function current_decision(lshaped::AbstractLShaped, execution::AsynchronousExecution)
    t = timestamp(lshaped)
    return fetch(execution.iterates, t)
end

function timestamp(::AbstractLShaped, execution::AsynchronousExecution)
    return execution.data.timestamp
end

function incumbent_decision(::AbstractLShaped, t::Integer, regularization::AbstractRegularization, execution::AsynchronousExecution)
    if t > 1
        return fetch(execution.iterates, regularization.incumbents[t])
    else
        return map(regularization.ξ) do ξᵢ
            return ξᵢ.value
        end
    end
end

function incumbent_decision(lshaped::AbstractLShaped, t::Integer, ::NoRegularization, execution::AsynchronousExecution)
    lshaped.x
end

function incumbent_objective(::AbstractLShaped, t::Integer, regularization::AbstractRegularization, ::AsynchronousExecution)
    return t > 1 ? regularization.Q̃_history[regularization.incumbents[t]] : regularization.data.Q̃
end

function incumbent_trustregion(::AbstractLShaped, t::Integer, rd::RegularizedDecomposition, ::AsynchronousExecution)
    return rd.σ_history[t]
end

function incumbent_trustregion(::AbstractLShaped, t::Integer, tr::TrustRegion, ::AsynchronousExecution)
    return tr.Δ_history[t]
end

function readd_cuts!(lshaped::AbstractLShaped, consolidation::Consolidation, execution::AsynchronousExecution)
    for i in eachindex(consolidation.cuts)
        for cut in consolidation.cuts[i]
            add_cut!(lshaped, cut, execution.model_objectives[i], execution.subobjectives[i], fetch(execution.iterates, i), check = false)
        end
        for cut in consolidation.feasibility_cuts[i]
            add_cut!(lshaped, cut, execution.model_objectives[i], execution.subobjectives[i], Inf)
        end
    end
    return nothing
end

function subobjectives(lshaped::AbstractLShaped, execution::AsynchronousExecution)
    t = timestamp(lshaped)
    return execution.subobjectives[t]
end

function set_subobjectives(lshaped::AbstractLShaped, Qs::AbstractVector, execution::AsynchronousExecution)
    t = timestamp(lshaped)
    execution.subobjectives[t] .= Qs
    return nothing
end

function model_objectives(lshaped::AbstractLShaped, execution::AsynchronousExecution)
    t = timestamp(lshaped)
    θs = t > 1 ? execution.model_objectives[t-1] : fill(-1e10, num_thetas(lshaped))
    return θs
end

function set_model_objectives(lshaped::AbstractLShaped, θs::AbstractVector, execution::AsynchronousExecution)
    t = timestamp(lshaped)
    ids = active_model_objectives(lshaped)
    execution.model_objectives[t][ids] .= θs[ids]
    return nothing
end

function restore_subproblems!(::AbstractLShaped, execution::AsynchronousExecution)
    restore_subproblems!(execution.subworkers)
    return nothing
end

function solve_master!(lshaped::AbstractLShaped, execution::AsynchronousExecution)
    try
        MOI.optimize!(lshaped.master)
    catch
        status = MOI.get(lshaped.master, MOI.TerminationStatus())
        # Master problem could not be solved for some reason.
        @unpack Q,θ = lshaped.data
        gap = abs(θ-Q)/(abs(Q)+1e-10)
        # Always print this warning
        @warn "Master problem could not be solved, solver returned status $status. The following relative tolerance was reached: $(@sprintf("%.1e",gap)). Aborting procedure."
        rethrow(err)
    end
    status = MOI.get(lshaped.master, MOI.TerminationStatus())
    if status == MOI.INFEASIBLE
        # Asynchronicity can sometimes yield an infeasible master. If so, try to continue
        if execution.max_active > 1 || execution.κ < 1.0
            # Ensure that there are still cuts to consider
            if isready(execution.cutqueue)
                # Return false OPTIMAL to continue procedure
                return MOI.OPTIMAL
            end
        end
    end
    # Otherwise, return status as usual
    return status
end

function iterate!(lshaped::AbstractLShaped, execution::AsynchronousExecution{T}) where T <: AbstractFloat
    wait(execution.cutqueue)
    while isready(execution.cutqueue)
        new_iterate = false
        # Add new cuts from subworkers
        t::Int, cut::SparseHyperPlane{T} = take!(execution.cutqueue)
        execution.data.timestamp = t
        # Break if any subproblem is infeasible or unbounded
        if infeasible(cut)
            @warn "Stochastic program is not second-stage feasible at the current decision. Rerun procedure with feasibility_cuts = true to use feasibility cuts."
            # Early termination log
            log!(lshaped; status = MOI.INFEASIBLE)
            return MOI.INFEASIBLE
        end
        if !bounded(cut)
            # Early termination log
            log!(lshaped; status = MOI.DUAL_INFEASIBLE)
            return MOI.DUAL_INFEASIBLE
        end
        # Otherwise, add new cut to master and update bookkeeping
        execution.added[t] |= add_cut!(lshaped, cut)
        execution.finished[t] += num_subproblems(cut)
        # Asynchronicity parameter should be 1 first iteration
        κ = t > 1 ? execution.κ : 1.0
        if execution.finished[t] == num_thetas(lshaped)
            # All work from iteration t complete
            lshaped.Q_history[t] = current_objective_value(lshaped)
            lshaped.data.Q = lshaped.Q_history[t]
            lshaped.data.θ = t > 1 ? lshaped.θ_history[t-1] : -1e10
            # Update incumbent (if applicable)
            take_step!(lshaped)
            # Early optimality check if using level sets
            if lshaped.regularization isa LevelSet && check_optimality(lshaped, true)
                # Resolve subproblems with optimal vector
                lshaped.x .= decision(lshaped)
                t = lshaped.data.iterations
                put!(execution.iterates, t+1, copy(lshaped.x))
                for w in workers()
                    if !isready(execution.active_workers[w-1])
                        put!(execution.work[w-1], t+1)
                        put!(execution.remote_metadata[w-1], t+1, :gap, gap(lshaped))
                    end
                end
                execution.data.timestamp = t + 1
                # Optimal, final log
                log!(lshaped; optimal = true)
                return MOI.OPTIMAL
            end
            # Optimal if no cuts were added and current decision
            # is not different from incumbent projection target
            if !execution.added[t] && norm(incumbent_decision(lshaped, t, lshaped.regularization, execution) - lshaped.x) <= sqrt(eps())
                # Optimal, final log
                log!(lshaped, t; optimal = true)
                return MOI.OPTIMAL
            end
            # Consolidate (if applicable)
            consolidate!(lshaped, lshaped.consolidation)
            # Decrease number of active iterations
            execution.data.active = max(0, execution.data.active - 1)
            # Determine if new iterate should be generated
            new_iterate |= !(lshaped.regularization isa NoRegularization && execution.triggered[t])
            new_iterate |= t == 1
        elseif execution.finished[t] >= κ * num_thetas(lshaped) &&
               !execution.triggered[t] &&
               execution.data.active < execution.max_active &&
               execution.added[t]
            execution.triggered[t] = true
            new_iterate = true
        else
            new_iterate = false
        end
        # Generate new candidate decision
        if new_iterate
            t = lshaped.data.iterations
            execution.data.timestamp = t
            # Resolve master
            status = solve_master!(lshaped)
            if !(status ∈ AcceptableTermination)
                # Early termination log
                log!(lshaped; status = status)
                return status
            end
            # Update master solution
            update_solution!(lshaped)
            θ = calculate_estimate(lshaped)
            lshaped.data.θ = θ
            lshaped.θ_history[t] = θ
            # Check if optimal
            if check_optimality(lshaped, true)
                # Optimal, final log
                log!(lshaped, t)
                return MOI.OPTIMAL
            end
            # Calculate time spent so far and check perform time limit check
            t = lshaped.progress.tlast - lshaped.progress.tfirst
            if t >= lshaped.parameters.time_limit
                log!(lshaped; status = MOI.TIME_LIMIT)
                return MOI.TIME_LIMIT
            end
            # Log progress at current timestamp
            log_regularization!(lshaped, t)
            # Update workers
            put!(execution.iterates, t+1, copy(lshaped.x))
            for w in workers()
                if !isready(execution.active_workers[w-1])
                    put!(execution.work[w-1], t+1)
                    put!(execution.remote_metadata[w-1], t+1, :gap, gap(lshaped))
                end
            end
            # New active iteration
            execution.data.active += 1
            # Prepare memory for next iteration
            push!(execution.subobjectives, fill(1e10, num_thetas(lshaped)))
            push!(execution.model_objectives, fill(-1e10, num_thetas(lshaped)))
            push!(execution.finished, 0)
            push!(execution.triggered, false)
            push!(execution.added, false)
            if lshaped.consolidation isa Consolidation
                allocate!(lshaped.consolidation)
            end
            # Log progress
            log!(lshaped)
            lshaped.θ_history[t+1] = -Inf
        end
    end
    # Dont return a status as procedure should continue
    return nothing
end

# API
# ------------------------------------------------------------
function (execution::Asynchronous)(structure::VerticalStructure{2, 1, <:Tuple{DistributedScenarioProblems}},
                                   feasibility_strategy::AbstractFeasibilityStrategy,
                                   integer_strategy::AbstractIntegerStrategy,
                                   ::Type{T},
                                   ::Type{A}) where {T <: AbstractFloat,
                                                     A <: AbstractVector}
    return AsynchronousExecution(structure,
                                 execution.max_active,
                                 execution.κ,
                                 feasibility_strategy,
                                 integer_strategy,
                                 T,
                                 A)
end

function str(::Asynchronous)
    return "Asynchronous "
end
