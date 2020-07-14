function optimize!(structure::HorizontalStructure, optimizer::AbstractStructuredOptimizer, x₀::AbstractVector)
    # Sanity check
    supports_structure(optimizer, structure) || throw(UnsupportedStructure{typeof(optimizer), typeof(structure)}())
    # Load structure
    load_structure!(optimizer, structure, x₀)
    # Run structure-exploiting optimization procedure
    MOI.optimize!(optimizer)
    return nothing
end

function set_master_optimizer!(structure::HorizontalStructure, optimizer)
    return nothing
end

function set_master_optimizer_attribute!(::HorizontalStructure, ::MOI.AbstractOptimizerAttribute, value)
    return nothing
end

function set_subproblem_optimizer!(structure::HorizontalStructure, optimizer)
    set_optimizer!(scenarioproblems(structure), optimizer)
    return nothing
end

function set_subproblem_optimizer_attribute!(structure::HorizontalStructure, attr::MOI.AbstractOptimizerAttribute, value)
    MOI.set(scenarioproblems(structure), attr, value)
    return nothing
end
