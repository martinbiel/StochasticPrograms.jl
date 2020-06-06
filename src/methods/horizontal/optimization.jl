function optimize!(structure::HorizontalBlockStructure, optimizer::AbstractStructuredOptimizer, x₀::AbstractVector)
    # Sanity check
    supports_structure(optimizer, structure) || throw(UnsupportedStructure{typeof(optimizer), typeof(structure)}())
    # Ensure that no decisions are fixed in the subproblems
    untake_decisions!(structure)
    # Load structure
    load_structure!(optimizer, structure, x₀)
    # Run structure-exploiting optimization procedure
    MOI.optimize!(optimizer)
    return nothing
end

function set_master_optimizer!(structure::HorizontalBlockStructure, optimizer)
    return nothing
end

function set_subproblem_optimizer!(structure::HorizontalBlockStructure, optimizer)
    set_optimizer!(scenarioproblems(structure), optimizer)
    return nothing
end
