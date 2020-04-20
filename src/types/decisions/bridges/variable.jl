# Single decision #
# ========================== #
mutable struct DecisionBridge{T} <: MOIB.Variable.AbstractBridge
    decision::Decision{T}
    variable::MOI.VariableIndex

    function DecisionBridge(decision::Decision{T},
                            variable::MOI.VariableIndex) where T
        return new{T}(decision, variable)
    end
end

function MOIB.Variable.bridge_constrained_variable(::Type{DecisionBridge{T}},
                                                   model::MOI.ModelLike,
                                                   set::SingleDecisionSet{T}) where T
    variable = MOI.add_variable(model)
    return DecisionBridge(set.decision, variable)
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
function MOI.delete(::MOI.ModelLike, bridge::DecisionBridge)
    MOI.delete(bridge.variable)
end

# Attributes, Bridge acting as a constraint
function MOI.get(::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::DecisionBridge)
    return SingleDecisionSet(bridge.decision)
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

function MOI.set(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::DecisionBridge{T}, new_set::SingleDecisionSet{T}) where T
    bridge.decision = new_set.decision
end

function MOIB.bridged_function(bridge::DecisionBridge{T}) where T
    if bridge.decision.state == NotTaken
        # Use mapped variable as standard MOI variable. Also give a dummy decision to be
        # held by objective/constraint bridges in order to unbridge properly.
        return AffineDecisionFunction{T}(
            MOI.ScalarAffineFunction{T}(MOI.SingleVariable(bridge.variable)),
            MOI.ScalarAffineFunction{T}(MOI.SingleVariable(bridge.variable)),
            convert(MOI.ScalarAffineFunction{T}, zero(T)))
    else
        # Give mapped variable as dummy decision to be held by objective/constraint bridges
        # in order to unbridge properly. Give the value of the taken decision in the
        # decision part constant given to the objective/constraint bridges
        return AffineDecisionFunction{T}(
            convert(MOI.ScalarAffineFunction{T}, zero(T)),
            MOI.ScalarAffineFunction{T}([MOI.ScalarAffineTerm(one(T), bridge.variable)],
                                        bridge.decision.value),
            convert(MOI.ScalarAffineFunction{T}, zero(T)))
    end
end

function MOIB.Variable.unbridged_map(bridge::DecisionBridge, vi::MOI.VariableIndex)
    return (bridge.variable => MOI.SingleVariable(vi),)
end

# Multiple decisions #
# ========================== #
struct DecisionsBridge{T} <: MOIB.Variable.AbstractBridge
    decisions::Vector{Decision{T}}
    variables::Vector{MOI.VariableIndex}
end

function MOIB.Variable.bridge_constrained_variable(::Type{DecisionsBridge{T}},
                                                   model::MOI.ModelLike,
                                                   set::MultipleDecisionsSet{T}) where T
    variables = [MOI.add_variable(model) for _ in 1:length(set.decisions)]
    return DecisionsBridge(set.decisions, variables)
end

function MOIB.Variable.supports_constrained_variable(
    ::Type{DecisionsBridge{T}}, ::Type{MultipleDecisionsSet{T}}) where T
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
function MOI.delete(model::MOI.ModelLike, bridge::DecisionsBridge)
    MOI.delete(model, bridge.variables)
end

function MOI.delete(model::MOI.ModelLike, bridge::DecisionsBridge, i::MOIB.Variable.IndexInVector)
    MOI.delete(model, bridge.variables[i.value])
    deleteat!(bridge.variables, i.value)
end

# Attributes, Bridge acting as a constraint
function MOI.get(::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::DecisionsBridge)
    return MultipleDecisions(bridge.decisions)
end

function MOI.get(model::MOI.ModelLike, ::MOI.ConstraintPrimal,
                 bridge::DecisionsBridge{T}) where T
    return [decision.state == Taken ? decision.value :
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

function MOI.set(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::DecisionsBridge{T}, new_set::MultipleDecisionsSet{T}) where T
    bridge.decisions .= new_set.decisions
end

function MOIB.bridged_function(bridge::DecisionsBridge{T}, i::MOIB.Variable.IndexInVector) where T
    decision = bridge.decisions[i.value]
    if decision.state == NotTaken
        # Use mapped variable as standard MOI variable. Also give a dummy decision to be
        # held by objective/constraint bridges in order to unbridge properly.
        return AffineDecisionFunction{T}(
            MOI.ScalarAffineFunction{T}(MOI.SingleVariable(bridge.variables[i.value])),
            MOI.ScalarAffineFunction{T}(MOI.SingleVariable(bridge.variables[i.value])),
            convert(MOI.ScalarAffineFunction{T}, zero(T)))
    else
        # Give mapped variable as dummy decision to be held by objective/constraint bridges
        # in order to unbridge properly. Give the value of the taken decision in the
        # decision part constant given to the objective/constraint bridges
        return AffineDecisionFunction{T}(
            convert(MOI.ScalarAffineFunction{T}, zero(T)),
            MOI.ScalarAffineFunction{T}([MOI.ScalarAffineTerm(one(T), bridge.variables[i.value])],
                                        decision.value),
            convert(MOI.ScalarAffineFunction{T}, zero(T)))
    end
end
function MOIB.Variable.unbridged_map(bridge::DecisionsBridge, vi::MOI.VariableIndex, i::MOIB.Variable.IndexInVector)
    return (bridge.variables[i.value] => MOI.SingleVariable(vi),)
end

# Modifications #
# ========================== #
# To enable certain modifications (decision coefficient changes and decision state updates)
# a few methods must be added to MathOptInterface

function MOIB.is_bridged(b::MOIB.AbstractBridgeOptimizer,
                         change::DecisionCoefficientChange)
    # This modification should always be handled by modify_bridged_change
    return true
end

function MOIB.is_bridged(b::MOIB.AbstractBridgeOptimizer,
                         change::Union{DecisionsStateChange,
                                       KnownValueChange, KnownValuesChange})
    # These modifications should not be handled by the variable bridges
    return false
end

function MOIB.is_bridged(b::MOIB.AbstractBridgeOptimizer,
                         change::Union{DecisionStateChange})
    return MOIB.is_bridged(b, change.decision)
end

function MOIB.modify_bridged_change(b::MOIB.AbstractBridgeOptimizer, obj,
                                    change::DecisionCoefficientChange)
    f = MOIB.bridged_variable_function(b, change.decision)::AffineDecisionFunction
    # Variable part
    for term in f.variable_part.terms
        # Decision has been mapped to a MOI variable, so
        # fallback to a ScalarCoefficientChange.
        MOI.modify(b, obj, MOI.ScalarCoefficientChange(term.variable_index, change.new_coefficient))
    end
    # Decision part
    for term in f.decision_part.terms
        # Decision has been mapped to a fixed value, so
        # modification is handled in obj bridge
        MOI.modify(b, obj, DecisionCoefficientChange(term.variable_index, change.new_coefficient))
    end
    return nothing
end

function MOIB.modify_bridged_change(b::MOIB.AbstractBridgeOptimizer, obj,
                                    change::DecisionStateChange{T}) where T
    f = convert(AffineDecisionFunction{T}, MOIB.bridged_variable_function(b, change.decision))
    if change.new_state == NotTaken
        # State transition is from Taken to NotTaken.
        isempty(f.variable_part.terms) && error("Decision transition to NotTaken state not consistent with bridged variable function $f")
        for term in f.variable_part.terms
            # Let bridge for obj handle rest of state update
            MOI.modify(b, obj, DecisionStateChange(term.variable_index, NotTaken, change.value_difference))
        end
    end
    if change.new_state == Taken
        # State transition is from Taken to NotTaken.
        isempty(f.decision_part.terms) && error("Decision transition to Taken state not consistent with bridged variable function $f")
        for term in f.decision_part.terms
            # Let bridge for obj handle rest of state update
            MOI.modify(b, obj, DecisionStateChange(term.variable_index, Taken, change.value_difference))
        end
    end
    return nothing
end
