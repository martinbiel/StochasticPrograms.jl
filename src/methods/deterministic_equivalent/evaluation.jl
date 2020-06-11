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

function statistically_evaluate_decision(structure::DeterministicEquivalent{2}, decision::AbstractVector)
    # Update decisions (checks handled by structure model)
    take_decisions!(structure.model, structure.decision_variables[1], decision)
    # Optimize model
    optimize!(structure.model)
    # Get sense-correted objective value
    status = termination_status(structure.model)
    Q̂ = if status != MOI.OPTIMAL
        Q̂ = if status == MOI.INFEASIBLE
            return objective_sense(structure.model) == MOI.MAX_SENSE ? (-Inf, 0) : (Inf, 0)
        elseif status == MOI.DUAL_INFEASIBLE
            return objective_sense(structure.model) == MOI.MAX_SENSE ? (Inf, 0) : (-Inf, 0)
        else
            error("Deterministically equivalent model could not be solved, returned status: $status")
        end
    else
        objective_value(structure.model)
    end
    # Calculate subobjectives
    N = num_scenarios(structure)
    Q = Vector{Float64}(undef, N)
    for (i, sub_objective) in enumerate(structure.sub_objectives[1])
        Qᵢ = MOIU.eval_variables(sub_objective) do idx
            return MOI.get(backend(structure.model), MOI.VariablePrimal(), idx)
        end
        Q[i] = Qᵢ
    end
    probabilities = map(1:num_scenarios(structure)) do i
        probability(structure, i)
    end
    weights = Distributions.StatsBase.ProbabilityWeights(probabilities)
    σ = std(Q, weights, corrected = true)
    return Q̂, σ
end
