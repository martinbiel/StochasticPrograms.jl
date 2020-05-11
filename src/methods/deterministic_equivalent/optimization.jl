function optimize!(structure::DeterministicEquivalent, optimizer::MOI.AbstractOptimizer, x₀::AbstractVector)
    # Sanity check
    backend(structure.model) === optimizer || error("Stochastic program optimizer has not been connected to the deterministically equivalent problem.")
    # Crash if supported
    if MOI.supports(optimizer, MOI.VariablePrimalStart(), MOI.VariableIndex)
        for (i,dvar) in enumerate(all_decision_variables(structure))
            MOI.set(optimizer, MOI.VariablePrimalStart(), index(dvar), x₀[i])
        end
    end
    # Ensure that no decisions are fixed
    untake_decisions!(structure.model, structure.decision_variables[1])
    # Run standard MOI optimization procedure
    MOI.optimize!(optimizer)
    return nothing
end

function set_optimizer!(structure::DeterministicEquivalent, optimizer::MOI.AbstractOptimizer)
    structure.model.moi_backend = optimizer
    for bridge_type in structure.model.bridge_types
        JuMP._moi_add_bridge(optimizer, bridge_type)
    end
end

function optimize!(structure::DeterministicEquivalent, optimizer::AbstractStructuredOptimizer)
    # Sanity check
    supports_structure(optimizer, typeof(structure)) || throw(UnsupportedStructure{typeof(optimizer), typeof(structure)}())
    # Ensure that no decisions are fixed in the first stage
    untake_decisions!(structure.model, structure.decision_variables[1])
    # Load structure
    load_structure!(optimizer, structure)
    # Run structure-exploiting optimization procedure
    MOI.optimize!(optimizer)
    return nothing
end
