function optimize!(structure::HorizontalBlockStructure, optimizer::AbstractStructuredOptimizer)
    # Sanity check
    supports_structure(optimizer, typeof(structure)) || throw(UnsupportedStructure{typeof(optimizer), typeof(structure)}())
    # Ensure that no decisions are fixed in the subproblems
    untake_decisions!(structure)
    # Load structure
    load_structure!(optimizer, dep)
    # Run structure-exploiting optimization procedure
    MOI.optimize!(optimizer)
    return nothing
end
