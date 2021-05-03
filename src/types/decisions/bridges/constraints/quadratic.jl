# Quadratic decision function #
# ========================== #
mutable struct QuadraticDecisionConstraintBridge{T, S} <: MOIB.Constraint.AbstractBridge
    constraint::CI{MOI.ScalarQuadraticFunction{T}, S}
    decision_function::QuadraticDecisionFunction{T}
    set::S
end

function MOIB.Constraint.bridge_constraint(::Type{QuadraticDecisionConstraintBridge{T,S}},
                                           model,
                                           f::QuadraticDecisionFunction{T},
                                           set::S) where {T, S}
    # All decisions have been mapped to the
    # variable part terms at this point.
    # Add the bridged constraint
    constraint = MOI.add_constraint(model,
                                    MOI.ScalarQuadraticFunction(
                                        f.variable_part.affine_terms,
                                        f.variable_part.quadratic_terms,
                                        zero(T)),
                                    MOIU.shift_constant(set, -f.variable_part.constant))
    # Save the constraint index, the decision function, and the set, to allow modifications
    return QuadraticDecisionConstraintBridge{T, S}(constraint, f, set)
end

function MOI.supports_constraint(::Type{<:QuadraticDecisionConstraintBridge{T}},
                                 ::Type{<:QuadraticDecisionFunction{T}},
                                 ::Type{<:MOI.AbstractScalarSet}) where T
    return true
end
function MOIB.added_constrained_variable_types(::Type{<:QuadraticDecisionConstraintBridge})
    return Tuple{DataType}[]
end
function MOIB.added_constraint_types(::Type{QuadraticDecisionConstraintBridge{T, S}}) where {T, S}
    return [(MOI.ScalarQuadraticFunction{T}, S)]
end
function MOIB.Constraint.concrete_bridge_type(::Type{<:QuadraticDecisionConstraintBridge{T}},
                                              ::Type{QuadraticDecisionFunction{T}},
                                              S::Type{<:MOI.AbstractScalarSet}) where T
    return QuadraticDecisionConstraintBridge{T, S}
end

MOI.get(b::QuadraticDecisionConstraintBridge{T, S}, ::MOI.NumberOfConstraints{MOI.ScalarQuadraticFunction{T}, S}) where {T, S} = 1
MOI.get(b::QuadraticDecisionConstraintBridge{T, S}, ::MOI.ListOfConstraintIndices{MOI.ScalarQuadraticFunction{T}, S}) where {T, S} = [b.constraint]

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintFunction,
                 bridge::QuadraticDecisionConstraintBridge{T,S}) where {T,S}
    return bridge.decision_function
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::QuadraticDecisionConstraintBridge{T,S}) where {T,S}
    return bridge.set
end

function MOI.get(model::MOI.ModelLike, attr::Union{MOI.ConstraintPrimal, MOI.ConstraintDual},
                 bridge::QuadraticDecisionConstraintBridge{T,S}) where {T,S}
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.get(model::MOI.ModelLike, ::DecisionIndex,
                 bridge::QuadraticDecisionConstraintBridge{T}) where T
    return bridge.constraint
end

function MOI.delete(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge)
    MOI.delete(model, bridge.constraint)
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintFunction,
                 bridge::QuadraticDecisionConstraintBridge{T,S},
                 f::QuadraticDecisionFunction{T}) where {T,S,F}
    # Update bridge functions and function constant
    bridge.decision_function = f
    # Change the function of the bridged constraints
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            MOI.ScalarQuadraticFunction(
                f.variable_part.affine_terms,
                f.variable_part.quadratic_terms,
                zero(T)))
    # Shift constraint set
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -f.variable_part.constant))
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::QuadraticDecisionConstraintBridge{T,S}, change::S) where {T,S}
    f = bridge.decision_function
    bridge.set = change
    # Shift constraint set
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -f.variable_part.constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge{T,S}, change::MOI.ScalarConstantChange) where {T,S}
    f = bridge.decision_function
    # Modify constant of variable part
    lq.variable_part.constant = change.new_constant
    # Shift constraint set
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -f.variable_part.constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge{T,S}, change::MOI.ScalarCoefficientChange) where {T,S}
    f = bridge.decision_function
    # Update variable part
    modify_coefficient!(f.variable_part.affine_terms, change.variable, change.new_coefficient)
    # Modify variable part of objective as usual
    F = MOI.ScalarQuadraticFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), change)
    return nothing
end
