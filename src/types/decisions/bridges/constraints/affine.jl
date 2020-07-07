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
    # All decisions have been mapped to either the decision part constant or the variable part terms
    # at this point.
    F = MOI.ScalarAffineFunction{T}
    # Calculate total constant
    constant = f.variable_part.constant +
        f.known_part.constant
    # Add the bridged constraint
    constraint = MOI.add_constraint(model,
                                    MOI.ScalarAffineFunction(f.variable_part.terms, zero(T)),
                                    MOIU.shift_constant(set, -constant))
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
        copy(f.decision_part),
        copy(f.known_part))
    return g
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::AffineDecisionConstraintBridge{T}) where T
    return bridge.set
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintPrimal,
                 bridge::AffineDecisionConstraintBridge{T}) where T
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintDual,
                 bridge::AffineDecisionConstraintBridge{T}) where T
    return MOI.get(model, attr, bridge.constraint)
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
    # Recalculate total constant and shift constraint set
    constant = f.variable_part.constant +
        f.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::AffineDecisionConstraintBridge{T,S}, change::S) where {T,S}
    f = bridge.decision_function
    bridge.set = change
    # Recalculate total constant and shift constraint set
    constant = f.variable_part.constant +
        f.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(change, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionConstraintBridge{T,S}, change::MOI.ScalarConstantChange) where {T,S}
    f = bridge.decision_function
    # Modify variable part of decision function
    f.variable_part.constant = change.new_constant
    # Recalculate total constant and shift constraint set
    constant = f.variable_part.constant +
        f.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
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

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionConstraintBridge{T,S}, change::KnownCoefficientChange) where {T,S}
    f = bridge.decision_function
    i = something(findfirst(t -> t.variable_index == change.known,
                            f.known_part.terms), 0)
    # Update known part of constraint constant
    coefficient = iszero(i) ? zero(T) : f.known_part.terms[i].coefficient
    known_value = MOI.get(model, MOI.VariablePrimal(), change.known)
    f.known_part.constant +=
        (change.new_coefficient - coefficient) * known_value
    # Update coefficient in known part
    modify_coefficient!(f.known_part.terms, change.known, change.new_coefficient)
    # Recalculate total constant and shift constraint set
    constant = f.variable_part.constant +
        f.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionConstraintBridge{T,S}, change::KnownValueChange) where {T,S}
    f = bridge.decision_function
    i = something(findfirst(t -> t.variable_index == change.known,
                            f.known_part.terms), 0)
    if iszero(i)
        # Known value not in objective, nothing to do
        return nothing
    end
    # Update known part of constraint constant
    coefficient = f.known_part.terms[i].coefficient
    f.known_part.constant +=
        coefficient * change.value_difference
    # Recalculate total constant and shift constraint set
    constant = f.variable_part.constant +
        f.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionConstraintBridge{T,S}, change::KnownValuesChange) where {T,S}
    f = bridge.decision_function
    known_val = zero(T)
    for term in f.known_part.terms
        known_val += term.coefficient * MOI.get(model, MOI.VariablePrimal(), term.variable_index)
    end
    # Update known part of constraint constant
    f.known_part.constant = known_val
    # Recalculate total constant and shift constraint set
    constant = f.variable_part.constant +
        f.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end
