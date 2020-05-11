function iterate!(ph::AbstractProgressiveHedging, ::AbstractExecution)
    # Resolve all subproblems at the current optimal solution
    Q = resolve_subproblems!(ph)
    if Q.status != MOI.OPTIMAL
        # Early termination log
        log!(ph; status = Q.status)
        return Q.status
    end
    ph.data.Q = Q.value
    # Update iterate
    update_iterate!(ph)
    # Update subproblems
    update_subproblems!(ph)
    # Get dual gap
    update_dual_gap!(ph)
    # Update penalty (if applicable)
    update_penalty!(ph)
    # Update progress
    @unpack δ₁, δ₂ = ph.data
    ph.data.δ = sqrt(δ₁ + δ₂) / (1e-10 + norm(ph.ξ, 2))
    # Log progress
    log!(ph)
    # Check optimality
    if check_optimality(ph)
        # Final log
        log!(ph; optimal = true)
        # Optimal
        return MOI.OPTIMAL
    end
    # Dont return a status as procedure should continue
    return nothing
end

function start_workers!(::AbstractProgressiveHedging, ::AbstractExecution)
    return nothing
end

function close_workers!(::AbstractProgressiveHedging, ::AbstractExecution)
    return nothing
end
