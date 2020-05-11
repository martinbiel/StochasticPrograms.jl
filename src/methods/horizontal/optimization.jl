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

function set_optimizer!(structure::HorizontalBlockStructure, optimizer::AbstractStructuredOptimizer)
    set_optimizer!(scenarioproblems(structure), sub_optimizer(optimizer))
end
