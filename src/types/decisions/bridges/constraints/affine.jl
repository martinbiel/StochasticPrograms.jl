# Affine decision function #
# ========================== #
mutable struct AffineDecisionConstraintBridge{T, S} <: MOIB.Constraint.AbstractBridge
    constraint::CI{MOI.ScalarAffineFunction{T}, S}
    decision_function::AffineDecisionFunction{T}
    set::S
end

function MOIB.Constraint.bridge_constraint(::Type{AffineDecisionConstraintBridge{T, S}},
                                           model,
                                           f::AffineDecisionFunction{T},
                                           set::S) where {T, S}
    # All decisions have been mapped to the variable part terms
    # at this point.
    F = MOI.ScalarAffineFunction{T}
    # Add the bridged constraint
    constraint = MOI.add_constraint(model,
                                    MOI.ScalarAffineFunction(f.variable_part.terms, zero(T)),
                                    MOIU.shift_constant(set, -f.variable_part.constant))
    # Save the constraint index, the decision function, and the set, to allow modifications
    return AffineDecisionConstraintBridge{T, S}(constraint, f, set)
end

function MOI.supports_constraint(::Type{<:AffineDecisionConstraintBridge{T}},
                                 ::Type{<:AffineDecisionFunction{T}},
                                 ::Type{<:MOI.AbstractScalarSet}) where {T}
    return true
end
function MOIB.added_constrained_variable_types(::Type{<:AffineDecisionConstraintBridge})
    return Tuple{DataType}[]
end
function MOIB.added_constraint_types(::Type{<:AffineDecisionConstraintBridge{T, S}}) where {T, S}
    return [(MOI.ScalarAffineFunction{T}, S)]
end
function MOIB.Constraint.concrete_bridge_type(::Type{<:AffineDecisionConstraintBridge{T}},
                                              ::Type{<:AffineDecisionFunction{T}},
                                              S::Type{<:MOI.AbstractScalarSet}) where T
    return AffineDecisionConstraintBridge{T, S}
end

MOI.get(b::AffineDecisionConstraintBridge{T, S}, ::MOI.NumberOfConstraints{MOI.ScalarAffineFunction{T}, S}) where {T, S} = 1
MOI.get(b::AffineDecisionConstraintBridge{T, S}, ::MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{T}, S}) where {T, S} = [b.constraint]

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintFunction,
                 bridge::AffineDecisionConstraintBridge{T}) where T
    f = bridge.decision_function
    # Remove mapped variables to properly unbridge
    from_decision(v) = begin
        result = any(t -> t.variable_index == v, f.decision_part.terms)
    end
    g = AffineDecisionFunction(
        MOIU.filter_variables(v -> !from_decision(v), f.variable_part),
        copy(f.decision_part))
    return g
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::AffineDecisionConstraintBridge{T}) where T
    return bridge.set
end

function MOI.get(model::MOI.ModelLike, attr::MOI.AbstractConstraintAttribute,
                 bridge::AffineDecisionConstraintBridge{T}) where T
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.get(model::MOI.ModelLike, ::DecisionIndex,
                 bridge::AffineDecisionConstraintBridge{T}) where T
    return bridge.constraint
end

function MOI.delete(model::MOI.ModelLike, bridge::AffineDecisionConstraintBridge)
    MOI.delete(model, bridge.constraint)
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintFunction,
                 bridge::AffineDecisionConstraintBridge{T,S},
                 f::AffineDecisionFunction{T}) where {T,S}
    # Update bridge functions and function constant
    bridge.decision_function = f
    # Change the function of the bridged constraints
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            MOI.ScalarAffineFunction(f.variable_part.terms, zero(T)))
    # Shift constraint set
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -f.variable_part.constant))
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::AffineDecisionConstraintBridge{T,S}, change::S) where {T,S}
    f = bridge.decision_function
    bridge.set = change
    # Shift constraint set
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(change, -f.variable_part.constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionConstraintBridge{T,S}, change::MOI.ScalarConstantChange) where {T,S}
    f = bridge.decision_function
    # Modify variable part of decision function
    f.variable_part.constant = change.new_constant
    # Shift constraint set
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -f.variable_part.constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionConstraintBridge{T,S}, change::MOI.ScalarCoefficientChange) where {T,S}
    f = bridge.decision_function
    # Update coefficient in variable part
    modify_coefficient!(f.variable_part.terms, change.variable, change.new_coefficient)
    # Modify the variable part of the constraint as usual
    MOI.modify(model, bridge.constraint, change)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionConstraintBridge{T,S}, change::DecisionCoefficientChange) where {T,S}
    f = bridge.decision_function
    # Update coefficient in decision part
    modify_coefficient!(f.decision_part.terms, change.decision, change.new_coefficient)
    # Update mapped variable through ScalarCoefficientChange
    MOI.modify(model, bridge, MOI.ScalarCoefficientChange(change.decision, change.new_coefficient))
    return nothing
end
