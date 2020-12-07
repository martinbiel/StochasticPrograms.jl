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

function load_structure!(::MOI.AbstractOptimizer, ::DeterministicEquivalent, ::AbstractVector)
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

function cache_solution!(stochasticprogram::StochasticProgram{2}, structure::DeterministicEquivalent{2}, optimizer::MOI.AbstractOptimizer)
    cache = solutioncache(stochasticprogram)
    # Cache main solution
    variables = decision_variables_at_stage(stochasticprogram, 1)
    constraints = decision_constraints_at_stage(stochasticprogram, 1)
    cache[:solution] = SolutionCache(backend(structure.model), variables, constraints)
    # Cache first-stage solution
    cache[:node_solution_1] = SolutionCache(backend(structure.model), variables, constraints)
    try
        Q = MOIU.eval_variables(structure.sub_objectives[1][1][2]) do idx
            return MOI.get(backend(structure.model), MOI.VariablePrimal(), idx)
        end
        cache[:node_solution_1].modattr[MOI.ObjectiveValue()] = Q
        cache[:node_solution_1].modattr[MOI.DualObjectiveValue()] = Q
    catch
    end
    # Cache scenario-dependent solutions
    variables = decision_variables_at_stage(stochasticprogram, 2)
    constraints = decision_constraints_at_stage(stochasticprogram, 2)
    for i in 1:num_scenarios(stochasticprogram, 2)
        key = Symbol(:node_solution_2_, i)
        cache[key] = SolutionCache(backend(structure.model))
        cache_model_attributes!(cache[key], backend(structure.model))
        cache_variable_attributes!(cache[key], backend(structure.model), variables) do index
            structure.variable_map[(index, i)]
        end
        cache_constraint_attributes!(cache[key], backend(structure.model), constraints) do ci
            if ci isa CI{SingleDecision}
                return typeof(ci)(structure.variable_map[(MOI.VariableIndex(ci.value), i)].value)
            else
                return structure.constraint_map[(ci, i)]
            end
        end
        # Cache subobjective
        if cache[key].modattr[MOI.TerminationStatus()] == MOI.OPTIMAL
            Q = 0.0
            try
                Qᵢ = MOIU.eval_variables(structure.sub_objectives[1][i][2]) do idx
                    return MOI.get(backend(structure.model), MOI.VariablePrimal(), idx)
                end
                cache[key].modattr[MOI.ObjectiveValue()] = Qᵢ
                cache[key].modattr[MOI.DualObjectiveValue()] = Qᵢ
                Q += Qᵢ
            catch
            end
            # Correct first-stage objective
            cache[:node_solution_1].modattr[MOI.ObjectiveValue()] -= Q
        end
    end
    return nothing
end
