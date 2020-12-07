# Scenario-dependent attributes #
# ========================== #
struct ScenarioDependentOptimizerAttribute <: MOI.AbstractOptimizerAttribute
    stage::Int
    scenario_index::Int
    attr::MOI.AbstractOptimizerAttribute
end

struct ScenarioDependentModelAttribute <: MOI.AbstractModelAttribute
    stage::Int
    scenario_index::Int
    attr::MOI.AbstractModelAttribute
end

struct ScenarioDependentVariableAttribute <: MOI.AbstractVariableAttribute
    stage::Int
    scenario_index::Int
    attr::MOI.AbstractVariableAttribute
end

struct ScenarioDependentConstraintAttribute <: MOI.AbstractConstraintAttribute
    stage::Int
    scenario_index::Int
    attr::MOI.AbstractConstraintAttribute
end

const AnyScenarioDependentAttribute = Union{ScenarioDependentOptimizerAttribute,
                                            ScenarioDependentModelAttribute,
                                            ScenarioDependentVariableAttribute,
                                            ScenarioDependentConstraintAttribute}

MOI.is_set_by_optimize(attr::AnyScenarioDependentAttribute) = MOI.is_set_by_optimize(attr.attr)


is_structure_independent(attr::MOI.AnyAttribute) = true
is_structure_independent(::Union{MOI.ObjectiveFunction,
                                 MOI.ObjectiveFunctionType,
                                 MOI.ObjectiveSense}) = false
is_structure_independent(attr::AnyScenarioDependentAttribute) = is_structure_independent(attr.attr)
