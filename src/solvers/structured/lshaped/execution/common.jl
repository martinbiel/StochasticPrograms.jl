function nthetas(lshaped::AbstractLShapedSolver, ::AbstractExecution)
    return nthetas(lshaped.nscenarios, lshaped.aggregation, scenarioproblems(lshaped.stochasticprogram))
end

function timestamp(lshaped::AbstractLShapedSolver, ::AbstractExecution)
    return lshaped.data.iterations
end

function current_decision(lshaped::AbstractLShapedSolver, ::AbstractExecution)
    return lshaped.x
end

function incumbent_decision(::AbstractLShapedSolver, ::Integer, regularizer::AbstractRegularization, ::AbstractExecution)
    return regularizer.ξ
end

function incumbent_objective(::AbstractLShapedSolver, ::Integer, regularizer::AbstractRegularization, ::AbstractExecution)
    return regularizer.data.Q̃
end

function incumbent_trustregion(::AbstractLShapedSolver, ::Integer, rd::RegularizedDecomposition, ::AbstractExecution)
    return rd.data.σ
end

function incumbent_trustregion(::AbstractLShapedSolver, ::Integer, tr::TrustRegion, ::AbstractExecution)
    return tr.data.Δ
end

function start_workers!(::AbstractLShapedSolver, ::AbstractExecution)
    return nothing
end

function close_workers!(::AbstractLShapedSolver, ::AbstractExecution)
    return nothing
end

function readd_cuts!(lshaped::AbstractLShapedSolver, consolidation::Consolidation, ::AbstractExecution)
    for i in eachindex(consolidation.cuts)
        for cut in consolidation.cuts[i]
            add_cut!(lshaped, cut; consider_consolidation = false, check = false)
        end
        for cut in consolidation.feasibility_cuts[i]
            add_cut!(lshaped, cut; consider_consolidation = false, check = false)
        end
    end
    return nothing
end

function subobjectives(lshaped::AbstractLShapedSolver, execution::AbstractExecution)
    return execution.subobjectives
end

function set_subobjectives(lshaped::AbstractLShapedSolver, Qs::AbstractVector, execution::AbstractExecution)
    execution.subobjectives .= Qs
    return nothing
end

function model_objectives(lshaped::AbstractLShapedSolver, execution::AbstractExecution)
    return execution.model_objectives
end

function set_model_objectives(lshaped::AbstractLShapedSolver, θs::AbstractVector, execution::AbstractExecution)
    execution.model_objectives .= θs
    return nothing
end

function iterate!(lshaped::AbstractLShapedSolver, ::AbstractExecution)
    # Resolve all subproblems at the current optimal solution
    Q, added = resolve_subproblems!(lshaped)
    if Q == Inf && !handle_feasibility(lshaped.feasibility)
        @warn "Stochastic program is not second-stage feasible at the current decision. Rerun procedure with complete_recourse = false to use feasibility cuts."
        return :Infeasible
    end
    if Q == -Inf
        return :Unbounded
    end
    lshaped.data.Q = Q
    # Update incumbent (if applicable)
    take_step!(lshaped)
    # Resolve master
    status = solve_master!(lshaped)
    if status != :Optimal
        return status
    end
    # Update master solution
    update_solution!(lshaped, lshaped.mastersolver)
    lshaped.data.θ = calculate_estimate(lshaped)
    # Log progress
    log!(lshaped)
    # Check optimality
    if check_optimality(lshaped) || (lshaped.regularizer isa NoRegularization && !added)
        # Optimal
        lshaped.data.Q = calculate_objective_value(lshaped)
        push!(lshaped.Q_history,lshaped.data.Q)
        # Final log
        log!(lshaped; optimal = true)
        return :Optimal
    end
    # Project (if applicable)
    project!(lshaped)
    # Consolidate (if applicable)
    consolidate!(lshaped, lshaped.consolidation)
    # Just return a valid status for this iteration
    return :Valid
end
