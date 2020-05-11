function evaluate_decision(structure::DeterministicEquivalent{2}, decision::AbstractVector)
    # Update decisions (checks handled by structure model)
    take_decisions!(structure.model, structure.decision_variables[1], decision)
    # Optimize model
    optimize!(structure.model)
    # Return result
    status = termination_status(structure.model)
    if status != MOI.OPTIMAL
        if status == MOI.INFEASIBLE
            return objective_sense(structure.model) == MOI.MAX_SENSE ? -Inf : Inf
        elseif status == MOI.DUAL_INFEASIBLE
            return objective_sense(structure.model) == MOI.MAX_SENSE ? Inf : -Inf
        else
            error("Deterministically equivalent model could not be solved, returned status: $status")
        end
    end
    return objective_value(structure.model)
end

function statistically_evalute_decision(structure::DeterministicEquivalent{2}, decision::AbstractVector)
    # Update decisions (checks handled by structure model)
    take_decisions!(structure.model, structure.decision_variables[1], decision)
    # Optimize model
    optimize!(structure.model)
    # Return result
    status = termination_status(structure.model)
    if status != MOI.OPTIMAL
        if status == MOI.INFEASIBLE
            return objective_sense(structure.model) == MOI.MAX_SENSE ? (-Inf, 0) : (Inf, 0)
        elseif status == MOI.DUAL_INFEASIBLE
            return objective_sense(structure.model) == MOI.MAX_SENSE ? (Inf, 0) : (-Inf, 0)
        else
            error("Deterministically equivalent model could not be solved, returned status: $status")
        end
    end
end
