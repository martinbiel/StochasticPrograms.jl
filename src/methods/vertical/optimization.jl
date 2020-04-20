function optimize!(structure::VerticalBlockStructure, optimizer::AbstractStructuredOptimizer)
    # Sanity check
    supports_structure(optimizer, typeof(structure)) || throw(UnsupportedStructure{typeof(optimizer), typeof(structure)}())
    # Ensure that no decisions are fixed in the first stage
    untake_decisions!(structure.first_stage, all_decision_variables(structure.first_stage))
    # Load structure
    load_structure!(optimizer, structure)
    # Run structure-exploiting optimization procedure
    MOI.optimize!(optimizer)
    return nothing
end
