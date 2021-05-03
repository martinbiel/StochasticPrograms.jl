# Single decision #
# ========================== #
const FixingConstraint{T} = CI{MOI.ScalarAffineFunction{T}, MOI.EqualTo{T}}
mutable struct DecisionBridge{T} <: MOIB.Variable.AbstractBridge
    decision::Decision{T}
    variable::MOI.VariableIndex
    fixing_constraint::FixingConstraint{T}

    function DecisionBridge(decision::Decision{T},
                            variable::MOI.VariableIndex,
                            fixing_constraint::FixingConstraint{T}) where T
        return new{T}(decision, variable, fixing_constraint)
    end
end

function MOIB.Variable.bridge_constrained_variable(::Type{DecisionBridge{T}},
                                                   model::MOI.ModelLike,
                                                   set::SingleDecisionSet{T}) where T
    if set.constraint isa NoSpecifiedConstraint
        variable = MOI.add_variable(model)
    else
        variable, constraint = MOI.add_constrained_variable(model, set.constraint)
    end
    # Check state of decision
    if state(set.decision) == NotTaken
        fixing_constraint = FixingConstraint{T}(0)
    else
        # Decision initially fixed
        fixing_constraint =
            MOI.add_constraint(model,
                               MOI.ScalarAffineFunction{T}([MOI.ScalarAffineTerm(one(T), variable)], zero(T)),
                               MOI.EqualTo(set.decision.value))
    end
    return DecisionBridge(set.decision, variable, fixing_constraint)
end

function MOIB.Variable.supports_constrained_variable(
    ::Type{DecisionBridge{T}}, ::Type{SingleDecisionSet{T}}) where T
    return true
end

function MOIB.added_constrained_variable_types(::Type{<:DecisionBridge})
    return Tuple{DataType}[]
end
function MOIB.added_constraint_types(::Type{<:DecisionBridge})
    return Tuple{DataType, DataType}[]
end

# Attributes, Bridge acting as a model
MOI.get(bridge::DecisionBridge, ::MOI.NumberOfVariables) = 1

function MOI.get(bridge::DecisionBridge, ::MOI.ListOfVariableIndices)
    return [bridge.variable]
end

# References
function MOI.delete(model::MOI.ModelLike, bridge::DecisionBridge{T}) where T
    if bridge.fixing_constraint.value != 0
        # Remove the fixing constraint
        MOI.delete(model, bridge.fixing_constraint)
        bridge.fixing_constraint = FixingConstraint{T}(0)
    end
    MOI.delete(model, bridge.variable)
end

# Attributes, Bridge acting as a constraint
function MOI.get(::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::DecisionBridge)
    return SingleDecisionSet(1, bridge.decision)
end

function MOI.get(model::MOI.ModelLike, ::MOI.ConstraintPrimal,
                 bridge::DecisionBridge{T}) where T
    if bridge.decision.state == Taken
        return bridge.decision.value
    end
    return MOI.get(model, MOI.VariablePrimal(), bridge.variable)
end

function MOI.get(model::MOI.ModelLike, attr::Union{MOI.VariablePrimal, MOI.VariablePrimalStart},
                 bridge::DecisionBridge{T}) where T
    if bridge.decision.state == Taken
        return bridge.decision.value
    end
    return MOI.get(model, attr, bridge.variable)
end

function MOI.get(model::MOI.ModelLike, ::DecisionIndex,
                 bridge::DecisionBridge{T}) where T
    return bridge.variable
end

function MOI.set(model::MOI.ModelLike, attr::MOI.VariablePrimalStart,
                 bridge::DecisionBridge{T}, value) where T
    MOI.set(model, attr, bridge.variable, value)
end

function MOI.set(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::DecisionBridge{T}, new_set::SingleDecisionSet{T}) where T
    bridge.decision = new_set.decision
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionBridge{T}, change::DecisionStateChange) where T
    # Switch on state transition
    if change.new_state == NotTaken
        if bridge.fixing_constraint.value != 0
            # Remove the fixing constraint
            MOI.delete(model, bridge.fixing_constraint)
            bridge.fixing_constraint = FixingConstraint{T}(0)
        end
    else
        set = MOI.EqualTo(bridge.decision.value)
        if bridge.fixing_constraint.value != 0
            # Update existing
            MOI.set(model.model, MOI.ConstraintSet(), bridge.fixing_constraint, set)
        else
            # Add new fixing constraint
            bridge.fixing_constraint = MOI.add_constraint(model,
                                                          MOI.ScalarAffineFunction{T}([MOI.ScalarAffineTerm(one(T), bridge.variable)], zero(T)),
                                                          set)
        end
    end
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionBridge{T}, ::KnownValuesChange) where T
    # Update fixing constraint if decision is known
    if state(bridge.decision) == Known
        set = MOI.EqualTo(bridge.decision.value)
        MOI.set(model.model, MOI.ConstraintSet(), bridge.fixing_constraint, set)
    end
    return nothing
end

function MOIB.bridged_function(bridge::DecisionBridge{T}) where T
    # Return mapped variable
    return MOI.ScalarAffineFunction{T}(MOI.SingleVariable(bridge.variable))
end

function MOIB.Variable.unbridged_map(bridge::DecisionBridge, vi::MOI.VariableIndex)
    return (bridge.variable => SingleDecision(vi),)
    return (bridge.variable => MOI.SingleVariable(vi),)
end

# Multiple decisions #
# ========================== #
struct DecisionsBridge{T} <: MOIB.Variable.AbstractBridge
    decisions::Vector{Decision{T}}
    variables::Vector{MOI.VariableIndex}
    fixing_constraints::Vector{FixingConstraint{T}}
end

function MOIB.Variable.bridge_constrained_variable(::Type{DecisionsBridge{T}},
                                                   model::MOI.ModelLike,
                                                   set::MultipleDecisionSet{T}) where T
    if set.constraint isa NoSpecifiedConstraint
        variables = MOI.add_variables(model, length(set.decisions))
    else
        variables, constraints = MOI.add_constrained_variables(model, set.constraint)
    end
    fixing_constraints = FixingConstraint{T}[]
    # Check decision states
    for (variable, decision) in zip(variables, set.decisions)
        if state(decision) == NotTaken
            push!(fixing_constraints, FixingConstraint{T}(0))
        else
            # Decision initially fixed
            fixing_constraint =
                MOI.add_constraint(model,
                                   MOI.ScalarAffineFunction{T}([MOI.ScalarAffineTerm(one(T), variable)], zero(T)),
                                   MOI.EqualTo(decision.value))
            push!(fixing_constraints, fixing_constraint)
        end
    end
    return DecisionsBridge(set.decisions, variables, fixing_constraints)
end

function MOIB.Variable.supports_constrained_variable(
    ::Type{DecisionsBridge{T}}, ::Type{MultipleDecisionSet{T}}) where T
    return true
end

function MOIB.added_constrained_variable_types(::Type{<:DecisionsBridge})
    return Tuple{DataType}[]
end
function MOIB.added_constraint_types(::Type{<:DecisionsBridge})
    return Tuple{DataType, DataType}[]
end

# Attributes, Bridge acting as a model
MOI.get(bridge::DecisionsBridge, ::MOI.NumberOfVariables) = length(bridge.variables)

function MOI.get(bridge::DecisionsBridge, ::MOI.ListOfVariableIndices)
    return bridge.variables
end

# References
function MOI.delete(model::MOI.ModelLike, bridge::DecisionsBridge{T}) where T
    for (i,fixing_constraint) in enumerate(bridge.fixing_constraints)
        if fixing_constraint.value != 0
            # Remove the fixing constraint
            MOI.delete(model, fixing_constraint)
            bridge.fixing_constraints[i] = FixingConstraint{T}(0)
        end
    end
    MOI.delete(model, bridge.variables)
end

function MOI.delete(model::MOI.ModelLike, bridge::DecisionsBridge{T}, i::MOIB.Variable.IndexInVector) where T
    if bridge.fixing_constraints[i].value != 0
        # Remove the fixing constraint
        MOI.delete(model, bridge.fixing_constraints[i])
        bridge.fixing_constraints[i] = FixingConstraint{T}(0)
    end
    MOI.delete(model, bridge.variables[i.value])
    deleteat!(bridge.variables, i.value)
end

# Attributes, Bridge acting as a constraint
function MOI.get(::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::DecisionsBridge)
    return MultipleDecisionSet(bridge.decisions)
end

function MOI.get(model::MOI.ModelLike, ::MOI.ConstraintPrimal,
                 bridge::DecisionsBridge{T}) where T
    return [decision.state == Taken ? decision_value.(bridge.decisions) :
            MOI.get(model,
                    MOI.VariablePrimal(),
                    bridge.variables[i]) for (i,decision) in bridge.decisions]
end

function MOI.get(model::MOI.ModelLike,
                 attr::Union{MOI.VariablePrimal, MOI.VariablePrimalStart},
                 bridge::DecisionsBridge, i::MOIB.Variable.IndexInVector)
    decision = bridge.decisions[i.value]
    if decision.state == Taken
        return decision.value
    else
        return MOI.get(model, attr, bridge.variables[i.value])
    end
end

function MOI.get(model::MOI.ModelLike, ::DecisionIndex,
                 bridge::DecisionBridge{T}, i::MOIB.Variable.IndexInVector) where T
    return bridge.variables[i]
end

function MOI.set(model::MOI.ModelLike, attr::MOI.VariablePrimalStart,
                 bridge::DecisionsBridge{T}, val, i::MOIB.Variable.IndexInVector) where T
    MOI.set(model, attr, bridge.variables[i.value], val)
end

function MOI.set(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::DecisionsBridge{T}, new_set::MultipleDecisionSet{T}) where T
    bridge.decisions .= new_set.decisions
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionsBridge{T}, change::DecisionStateChange) where T
    # Switch on state transition
    if change.new_state == NotTaken
        if bridge.fixing_constraints[change.index].value != 0
            # Remove the fixing constraint
            MOI.delete(model, bridge.fixing_constraints[change.index])
            bridge.fixing_constraints[change.index] = FixingConstraint{T}(0)
        end
    else
        set = MOI.EqualTo(bridge.decisions[change.index].value)
        if bridge.fixing_constraints[change.index].value != 0
            # Update existing
            MOI.set(model.model, MOI.ConstraintSet(), bridge.fixing_constraints[change.index], set)
        else
            # Add new fixing constraint
            bridge.fixing_constraints[change.index] = MOI.add_constraint(model,
                                                                         MOI.ScalarAffineFunction{T}([MOI.ScalarAffineTerm(one(T), bridge.variables[change.index])], zero(T)),
                                                                         set)
        end
    end
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionsBridge{T}, ::KnownValuesChange) where T
    # Update fixing constraints of known decisions
    for (decision,fixing_constraint) in zip(bridge.decisions, bridge.fixing_constraints)
        if state(decision) == Known
            set = MOI.EqualTo(decision.value)
            MOI.set(model.model, MOI.ConstraintSet(), fixing_constraint, set)
        end
    end
    return nothing
end

function MOIB.bridged_function(bridge::DecisionsBridge{T}, i::MOIB.Variable.IndexInVector) where T
    # Return mapped variable
    return MOI.ScalarAffineFunction{T}(MOI.SingleVariable(bridge.variables[i.value]))
end
function MOIB.Variable.unbridged_map(bridge::DecisionsBridge, vi::MOI.VariableIndex, i::MOIB.Variable.IndexInVector)
    return (bridge.variables[i.value] => MOI.SingleVariable(vi),)
end

# Modifications #
# ========================== #
# To enable certain modifications (decision coefficient changes and decision state updates)
# a few methods must be added to MathOptInterface
function MOIB.is_bridged(b::MOIB.AbstractBridgeOptimizer,
                         change::Union{DecisionCoefficientChange, DecisionMultirowChange})
    return MOIB.is_bridged(b, change.decision)
end

function MOIB.is_bridged(b::MOIB.AbstractBridgeOptimizer,
                         change::Union{DecisionStateChange, KnownValuesChange})
    # These modifications should not be handled by the variable bridges
    return false
end

function MOIB.modify_bridged_change(b::MOIB.AbstractBridgeOptimizer, obj,
                                    change::DecisionCoefficientChange)
    f = MOIB.bridged_variable_function(b, change.decision)
    # Continue modification with mapped variable
    MOI.modify(b, obj, MOI.ScalarCoefficientChange(only(f.terms).variable_index, change.new_coefficient))
    return nothing
end

function MOIB.modify_bridged_change(b::MOIB.AbstractBridgeOptimizer, obj,
                                    change::DecisionMultirowChange)
    f = MOIB.bridged_variable_function(b, change.decision)
    # Continue modification with mapped variable
    MOI.modify(b, obj, MOI.MultirowChange(only(f.terms).variable_index, change.new_coefficients))
    return nothing
end
