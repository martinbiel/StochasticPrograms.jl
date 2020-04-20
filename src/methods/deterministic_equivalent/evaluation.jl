function evaluate_decision(dep::DeterministicEquivalent{2}, decision::AbstractVector)
    # Update decisions (checks handled by dep model)
    take_decisions!(dep.model, dep.decision_variables[1], decision)
    # Optimize model
    optimize!(dep.model)
    # Return result
    status = termination_status(dep.model)
    if status != MOI.OPTIMAL
        if status == MOI.INFEASIBLE
            return objective_sense(dep.model) == MOI.MAX_SENSE ? -Inf : Inf
        elseif status == MOI.DUAL_INFEASIBLE
            return objective_sense(dep.model) == MOI.MAX_SENSE ? Inf : -Inf
        else
            error("Deterministically equivalent model could not be solved, returned status: $status")
        end
    end
    return objective_value(dep.model)
end

function statistically_evalute_decision(dep::DeterministicEquivalent{2}, decision::AbstractVector)
    # Update decisions (checks handled by dep model)
    take_decisions!(dep.model, dep.decision_variables[1], decision)
    # Optimize model
    optimize!(dep.model)
    # Return result
    status = termination_status(dep.model)
    if status != MOI.OPTIMAL
        if status == MOI.INFEASIBLE
            return objective_sense(dep.model) == MOI.MAX_SENSE ? (-Inf, 0) : (Inf, 0)
        elseif status == MOI.DUAL_INFEASIBLE
            return objective_sense(dep.model) == MOI.MAX_SENSE ? (Inf, 0) : (-Inf, 0)
        else
            error("Deterministically equivalent model could not be solved, returned status: $status")
        end
    end
end
