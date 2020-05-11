# SingleDecision #
# ========================== #
const FixingConstraint{T} = CI{MOI.ScalarAffineFunction{T}, MOI.EqualTo{T}}
mutable struct SingleDecisionConstraintBridge{T, S <: MOI.AbstractScalarSet} <: MOIB.Constraint.AbstractBridge
    constraint::CI{MOI.SingleVariable, S}
    fixing_constraint::FixingConstraint{T}
    decision::SingleDecision
end

function MOIB.Constraint.bridge_constraint(::Type{SingleDecisionConstraintBridge{T,S}},
                                           model,
                                           f::SingleDecision,
                                           set::S) where {T, S <: MOI.AbstractScalarSet}
    # Perform the bridge mapping manually
    bridged = MOIB.bridged_function(
        model,
        AffineDecisionFunction{T}(f))
    mapped_variable = bridged.decision_part.terms[1].variable_index
    # Add the bridged constraint
    constraint = MOI.add_constraint(model,
                                    MOI.SingleVariable(mapped_variable),
                                    set)
    # Save the constraint index and the decision to allow modifications
    return SingleDecisionConstraintBridge{T,S}(constraint, FixingConstraint{T}(0), f)
end

function MOI.supports_constraint(::Type{<:SingleDecisionConstraintBridge{T}},
                                 ::Type{SingleDecision},
                                 ::Type{<:MOI.AbstractScalarSet}) where T
    return true
end
function MOIB.added_constrained_variable_types(::Type{<:SingleDecisionConstraintBridge})
    return Tuple{DataType}[]
end
function MOIB.added_constraint_types(::Type{<:SingleDecisionConstraintBridge{T,S}}) where {T,S}
    return [(MOI.SingleVariable, S), (MOI.ScalarAffineFunction{T}, MOI.EqualTo{T})]
end
function MOIB.Constraint.concrete_bridge_type(::Type{<:SingleDecisionConstraintBridge{T}},
                              ::Type{SingleDecision},
                              S::Type{<:MOI.AbstractScalarSet}) where T
    return SingleDecisionConstraintBridge{T,S}
end

MOI.get(b::SingleDecisionConstraintBridge{T,S}, ::MOI.NumberOfConstraints{MOI.SingleVariable, S}) where {T,S} = 1
MOI.get(b::SingleDecisionConstraintBridge{T}, ::MOI.NumberOfConstraints{MOI.ScalarAffineFunction{T}, MOI.EqualTo{T}}) where T =
    b.fixing_constraint.value == 0 ? 0 : 1
MOI.get(b::SingleDecisionConstraintBridge{T}, ::MOI.ListOfConstraintIndices{MOI.SingleVariable, S}) where {T,S} = [b.constraint]
MOI.get(b::SingleDecisionConstraintBridge{T}, ::MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{T}, MOI.EqualTo{T}}) where {T} =
    b.fixing_constraint.value == 0 ? FixingConstraint{T}[] : [b.fixing_constraint]

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintFunction,
                 bridge::SingleDecisionConstraintBridge)
    return bridge.decision
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::SingleDecisionConstraintBridge)
    return MOI.get(model, MOI.ConstraintSet(), bridge.constraint)
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintPrimal,
                 bridge::SingleDecisionConstraintBridge)
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintDual,
                 bridge::SingleDecisionConstraintBridge)
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.delete(model::MOI.ModelLike, bridge::SingleDecisionConstraintBridge)
    MOI.delete(model, bridge.constraint)
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::SingleDecisionConstraintBridge{T,S}, change::S) where {T, S <: MOI.AbstractScalarSet}
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint, change)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::SingleDecisionConstraintBridge{T,S}, change::DecisionStateChange) where {T,S}
    if bridge.decision != change.decision
        # Decision not in constraint, nothing to do
        return nothing
    end
    # Switch on state transition
    if change.new_state == NotTaken
        if bridge.fixing_constraint.value != 0
            # Remove the fixing constraint
            MOI.delete(model, bridge.fixing_constraint)
            bridge.fixing_constraint = FixingConstraint{T}(0)
        end
    end
    if change.new_state == Taken
        if bridge.fixing_constraint.value != 0
            # Remove any existing fixing constraint
            MOI.delete(model, bridge.fixing_constraint)
        end
        # Perform the bridge mapping manually
        aff = MOIB.bridged_function(model, AffineDecisionFunction{T}(bridge.decision))
        f = MOI.ScalarAffineFunction{T}(MOI.SingleVariable(aff.decision_part.terms[1].variable_index))
        # Get the decision value
        set = MOI.EqualTo(aff.decision_part.constant)
        # Add a fixing constraint to ensure that fixed decision is feasible.
        bridge.fixing_constraint = MOI.add_constraint(model, f, set)
    end
    return nothing
end
