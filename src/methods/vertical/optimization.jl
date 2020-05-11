function optimize!(structure::VerticalBlockStructure, optimizer::AbstractStructuredOptimizer, x₀::AbstractVector)
    # Sanity check
    supports_structure(optimizer, structure) || throw(UnsupportedStructure{typeof(optimizer), typeof(structure)}())
    # Ensure that no decisions are fixed in the first stage
    untake_decisions!(structure.first_stage, all_decision_variables(structure.first_stage))
    # Load structure
    load_structure!(optimizer, structure, x₀)
    # Run structure-exploiting optimization procedure
    MOI.optimize!(optimizer)
    return nothing
end

function set_optimizer!(structure::VerticalBlockStructure, optimizer::AbstractStructuredOptimizer)
    set_optimizer(structure.first_stage, master_optimizer(optimizer))
    set_optimizer!(scenarioproblems(structure), sub_optimizer(optimizer))
end
