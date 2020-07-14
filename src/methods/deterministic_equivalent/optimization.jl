function optimize!(structure::DeterministicEquivalent, optimizer::MOI.AbstractOptimizer, x₀::AbstractVector)
    # Sanity check
    backend(structure.model) === optimizer || error("Stochastic program optimizer has not been connected to the deterministically equivalent problem.")
    # Crash if supported
    if MOI.supports(optimizer, MOI.VariablePrimalStart(), MOI.VariableIndex)
        for (i, idx) in enumerate(all_decisions(structure))
            MOI.set(optimizer, MOI.VariablePrimalStart(), idx, x₀[i])
        end
    end
    # Run standard MOI optimization procedure
    MOI.optimize!(optimizer)
    return nothing
end

function supports_structure(::MOI.AbstractOptimizer, ::DeterministicEquivalent)
    return true
end

function check_loadable(::MOI.AbstractOptimizer, ::DeterministicEquivalent)
    return nothing
end

function set_master_optimizer!(structure::DeterministicEquivalent, optimizer)
    # Ensure decision bridges are added
    for bridge_type in structure.model.bridge_types
        JuMP._moi_add_bridge(structure.model.moi_backend, bridge_type)
    end
    return nothing
end

function set_master_optimizer_attribute!(structure::DeterministicEquivalent, attr::MOI.AbstractOptimizerAttribute, value)
    MOI.set(backend(structure.model), attr, value)
    return nothing
end

function set_subproblem_optimizer!(structure::DeterministicEquivalent, optimizer)
    return nothing
end

function set_subproblem_optimizer_attribute!(::DeterministicEquivalent, ::MOI.AbstractOptimizerAttribute, value)
    return nothing
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
