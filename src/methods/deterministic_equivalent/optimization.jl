function optimize!(dep::DeterministicEquivalent, optimizer::MOI.AbstractOptimizer)
    # Sanity check
    backend(dep.model) === optimizer || error("Stochastic program optimizer has not been connected to the deterministically equivalent problem.")
    # Ensure that no decisions are fixed
    untake_decisions!(dep.model, dep.decision_variables[1])
    # Run standard MOI optimization procedure
    MOI.optimize!(optimizer)
    return nothing
end

function optimize!(dep::DeterministicEquivalent, optimizer::AbstractStructuredOptimizer)
    # Sanity check
    supports_structure(optimizer, typeof(structure)) || throw(UnsupportedStructure{typeof(optimizer), typeof(structure)}())
    # Ensure that no decisions are fixed in the first stage
    untake_decisions!(dep.model, dep.decision_variables[1])
    # Load structure
    load_structure!(optimizer, dep)
    # Run structure-exploiting optimization procedure
    MOI.optimize!(optimizer)
    return nothing
end
