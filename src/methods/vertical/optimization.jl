function optimize!(structure::VerticalStructure, optimizer::AbstractStructuredOptimizer, x₀::AbstractVector)
    # Sanity checks
    supports_structure(optimizer, structure) || throw(UnsupportedStructure{typeof(optimizer), typeof(structure)}())
    check_loadable(optimizer, structure)
    # Load structure
    load_structure!(optimizer, structure, x₀)
    # Run structure-exploiting optimization procedure
    MOI.optimize!(optimizer)
    return nothing
end

function set_master_optimizer!(structure::VerticalStructure, optimizer)
    set_optimizer(structure.first_stage, optimizer)
    return nothing
end

function set_master_optimizer_attribute!(structure::VerticalStructure, attr::MOI.AbstractOptimizerAttribute, value)
    MOI.set(backend(structure.first_stage), attr, value)
    return nothing
end

function set_subproblem_optimizer!(structure::VerticalStructure, optimizer)
    set_optimizer!(scenarioproblems(structure), optimizer)
    return nothing
end

function set_subproblem_optimizer_attribute!(structure::VerticalStructure, attr::MOI.AbstractOptimizerAttribute, value)
    MOI.set(scenarioproblems(structure), attr, value)
    return nothing
end
