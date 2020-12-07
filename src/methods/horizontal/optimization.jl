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

function cache_solution!(stochasticprogram::StochasticProgram{2}, structure::HorizontalStructure{2}, optimizer::MOI.AbstractOptimizer)
    cache = solutioncache(stochasticprogram)
    # Cache main solution
    variables = decision_variables_at_stage(stochasticprogram, 1)
    constraints = decision_constraints_at_stage(stochasticprogram, 1)
    cache[:solution] = SolutionCache(optimizer, variables, constraints)
    # Cache first-stage solution
    cache[:node_solution_1] = SolutionCache(optimizer, variables, constraints)
    # Cache scenario-dependent solutions (Skip if more than 100 scenarios for performance)
    if num_scenarios(stochasticprogram) <= 100
        cache_solution!(cache, scenarioproblems(structure), optimizer, 2)
    end
    return nothing
end
