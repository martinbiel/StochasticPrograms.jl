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
    variable = if set.constraint isa NoSpecifiedConstraint
        variable = MOI.add_variable(model)
    else
        variable, constraint = MOI.add_constrained_variable(model, set.constraint)
        variable
    end
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
function MOI.delete(model::MOI.ModelLike, bridge::DecisionBridge)
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

function MOI.set(model::MOI.ModelLike, attr::MOI.VariablePrimalStart,
                 bridge::DecisionBridge{T}, value) where T
    MOI.set(model, attr, bridge.variable, value)
end

function MOI.set(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::DecisionBridge{T}, new_set::SingleDecisionSet{T}) where T
    bridge.decision = new_set.decision
end

function MOIB.bridged_function(bridge::DecisionBridge{T}) where T
    if bridge.decision.state == NotTaken
        # Use mapped variable as standard MOI variable.
        return MOI.ScalarAffineFunction{T}(MOI.SingleVariable(bridge.variable))
    else
        # Give mapped variable as dummy decision to be held by objective/constraint bridges
        # in order to unbridge properly. Give the value of the taken decision in the
        # decision part constant given to the objective/constraint bridges
        return MOI.ScalarAffineFunction{T}([MOI.ScalarAffineTerm(one(T), bridge.variable)],
                                        bridge.decision.value)
    end
end

function MOIB.Variable.unbridged_map(bridge::DecisionBridge, vi::MOI.VariableIndex)
    return (bridge.variable => MOI.SingleVariable(vi),)
end

# Single known decision #
# ========================== #
mutable struct KnownBridge{T} <: MOIB.Variable.AbstractBridge
    known::Decision{T}

    function KnownBridge(known::Decision{T}) where T
        return new{T}(known)
    end
end

function MOIB.Variable.bridge_constrained_variable(::Type{KnownBridge{T}},
                                                   model::MOI.ModelLike,
                                                   set::SingleKnownSet{T}) where T
    return KnownBridge(set.known)
end

function MOIB.Variable.supports_constrained_variable(
    ::Type{KnownBridge{T}}, ::Type{SingleKnownSet{T}}) where T
    return true
end

function MOIB.added_constrained_variable_types(::Type{<:KnownBridge})
    return Tuple{DataType}[]
end
function MOIB.added_constraint_types(::Type{<:KnownBridge})
    return Tuple{DataType, DataType}[]
end

# Attributes, Bridge acting as a model
MOI.get(bridge::KnownBridge, ::MOI.NumberOfVariables) = 0
function MOI.get(bridge::KnownBridge, ::MOI.ListOfVariableIndices)
    return MOI.VariableIndex[]
end

# References
function MOI.delete(::MOI.ModelLike, bridge::KnownBridge)
    # Nothing to do
    return nothing
end

# Attributes, Bridge acting as a constraint
function MOI.get(::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::KnownBridge)
    return SingleKnownSet(bridge.known)
end

function MOI.get(model::MOI.ModelLike, ::MOI.ConstraintPrimal,
                 bridge::KnownBridge{T}) where T
    return bridge.known.value
end

function MOI.get(model::MOI.ModelLike, attr::Union{MOI.VariablePrimal, MOI.VariablePrimalStart},
                 bridge::KnownBridge{T}) where T
    return bridge.known.value
end

function MOI.set(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::KnownBridge{T}, new_set::SingleKnownSet{T}) where T
    bridge.known = new_set.known
    return nothing
end

function MOIB.bridged_function(bridge::KnownBridge{T}) where T
    # Give the value of the known decision in the
    # known part constant given to the objective/constraint bridges
    return convert(MOI.ScalarAffineFunction{T}, bridge.known.value)
end

function MOIB.Variable.unbridged_map(bridge::KnownBridge, vi::MOI.VariableIndex)
    # Ignore unbridging without errors
    return (vi => MOI.SingleVariable(vi),)
end

# Multiple decisions #
# ========================== #
struct DecisionsBridge{T} <: MOIB.Variable.AbstractBridge
    decisions::Vector{Decision{T}}
    variables::Vector{MOI.VariableIndex}
end

function MOIB.Variable.bridge_constrained_variable(::Type{DecisionsBridge{T}},
                                                   model::MOI.ModelLike,
                                                   set::MultipleDecisionSet{T}) where T
    variables = if set.constraint isa NoSpecifiedConstraint
        variables = MOI.add_variables(model, length(set.decisions))
    else
        variables, constraints = MOI.add_constrained_variables(model, set.constraint)
        variables
    end
    return DecisionsBridge(set.decisions, variables)
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

function MOI.set(model::MOI.ModelLike, attr::MOI.VariablePrimalStart,
                 bridge::DecisionsBridge{T}, val, i::MOIB.Variable.IndexInVector) where T
    MOI.set(model, attr, bridge.variables[i.value], val)
end

function MOI.set(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::DecisionsBridge{T}, new_set::MultipleDecisionSet{T}) where T
    bridge.decisions .= new_set.decisions
end

function MOIB.bridged_function(bridge::DecisionsBridge{T}, i::MOIB.Variable.IndexInVector) where T
    decision = bridge.decisions[i.value]
    if decision.state == NotTaken
        # Use mapped variable as standard MOI variable.
        return MOI.ScalarAffineFunction{T}(MOI.SingleVariable(bridge.variables[i.value]))
    else
        # Give mapped variable as dummy decision to be held by objective/constraint bridges
        # in order to unbridge properly. Give the value of the taken decision in the
        # decision part constant given to the objective/constraint bridges
        return MOI.ScalarAffineFunction{T}([MOI.ScalarAffineTerm(one(T), bridge.variables[i.value])],
                                           decision.value)
    end
end
function MOIB.Variable.unbridged_map(bridge::DecisionsBridge, vi::MOI.VariableIndex, i::MOIB.Variable.IndexInVector)
    return (bridge.variables[i.value] => MOI.SingleVariable(vi),)
end

# Multiple knowns #
# ========================== #
struct KnownsBridge{T} <: MOIB.Variable.AbstractBridge
    knowns::Vector{Decision{T}}
end

function MOIB.Variable.bridge_constrained_variable(::Type{KnownsBridge{T}},
                                                   model::MOI.ModelLike,
                                                   set::MultipleKnownSet{T}) where T
    return KnownsBridge(set.knowns)
end

function MOIB.Variable.supports_constrained_variable(
    ::Type{KnownsBridge{T}}, ::Type{MultipleKnownSet{T}}) where T
    return true
end

function MOIB.added_constrained_variable_types(::Type{<:KnownsBridge})
    return Tuple{DataType}[]
end
function MOIB.added_constraint_types(::Type{<:KnownsBridge})
    return Tuple{DataType, DataType}[]
end

# Attributes, Bridge acting as a model
MOI.get(bridge::KnownsBridge, ::MOI.NumberOfVariables) = 0
function MOI.get(bridge::KnownsBridge, ::MOI.ListOfVariableIndices)
    return MOI.VariableIndex[]
end

# References
function MOI.delete(model::MOI.ModelLike, bridge::KnownsBridge)
    # Nothing to do
    return nothing
end

function MOI.delete(model::MOI.ModelLike, bridge::KnownsBridge, i::MOIB.Variable.IndexInVector)
    # Nothing to do
    return nothing
end

# Attributes, Bridge acting as a constraint
function MOI.get(::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::KnownsBridge)
    return MultipleKnownSet(bridge.knowns)
end

function MOI.get(model::MOI.ModelLike, ::MOI.ConstraintPrimal,
                 bridge::KnownsBridge{T}) where T
    return map(bridge.knowns) do known
        known.value
    end
end

function MOI.get(model::MOI.ModelLike,
                 attr::Union{MOI.VariablePrimal, MOI.VariablePrimalStart},
                 bridge::KnownsBridge, i::MOIB.Variable.IndexInVector)
    return bridge.knowns[i.value].value
end

function MOI.set(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::KnownsBridge{T}, new_set::MultipleDecisionSet{T}) where T
    bridge.knowns .= new_set.knowns
end

function MOIB.bridged_function(bridge::KnownsBridge{T}, i::MOIB.Variable.IndexInVector) where T
    known = bridge.knowns[i.value]
    # Give the value of the known decision in the
    # known part constant given to the objective/constraint bridges
    return convert(MOI.ScalarAffineFunction{T}, known.value)
end
function MOIB.Variable.unbridged_map(bridge::KnownsBridge, vi::MOI.VariableIndex, i::MOIB.Variable.IndexInVector)
    # Ignore unbridging without errors
    return (vi => MOI.SingleVariable(vi),)
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
                         change::Union{DecisionStateChange, DecisionsStateChange,
                                       KnownCoefficientChange, KnownMultirowChange,
                                       KnownValueChange, KnownValuesChange})
    # These modifications should not be handled by the variable bridges
    return false
end

function MOIB.modify_bridged_change(b::MOIB.AbstractBridgeOptimizer, obj,
                                    change::DecisionCoefficientChange)
    f = MOIB.bridged_variable_function(b, change.decision)
    # Continue modification with mapped variable
    MOI.modify(b, obj, DecisionCoefficientChange(only(f.terms).variable_index, change.new_coefficient))
    return nothing
end

function MOIB.modify_bridged_change(b::MOIB.AbstractBridgeOptimizer, obj,
                                    change::DecisionMultirowChange)
    f = MOIB.bridged_variable_function(b, change.decision)
    # Continue modification with mapped variable
    MOI.modify(b, obj, DecisionMultirowChange(only(f.terms).variable_index, change.new_coefficients))
    return nothing
end
