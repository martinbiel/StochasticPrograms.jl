function iterate_nominal!(ph::AbstractProgressiveHedgingSolver, ::AbstractExecution)
    # Resolve all subproblems at the current optimal solution
    Q = resolve_subproblems!(ph)
    if Q == Inf
        return :Infeasible
    elseif Q == -Inf
        return :Unbounded
    end
    ph.data.Q = Q
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
    ph.data.δ = sqrt(δ₁ + δ₂)/(1e-10+norm(ph.ξ,2))
    # Log progress
    log!(ph)
    # Check optimality
    if check_optimality(ph)
        # Optimal
        return :Optimal
    end
    # Just return a valid status for this iteration
    return :Valid
end

function start_workers!(::AbstractProgressiveHedgingSolver, ::AbstractExecution)
    return nothing
end

function close_workers!(::AbstractProgressiveHedgingSolver, ::AbstractExecution)
    return nothing
end
