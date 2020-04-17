function evaluate_decision(dep::DeterministicEquivalent, decision::AbstractVector)
    update_decision_variables!(decision_variables(dep, 1), decision)
end
