# VectorOfDecisions #
# ========================== #
struct VectorDecisionConstraintBridge{T, S <: MOI.AbstractVectorSet} <: MOIB.Constraint.AbstractBridge
    constraint::CI{MOI.VectorOfVariables, S}
    fixing_constraints::Vector{FixingConstraint{T}}
    decisions::VectorOfDecisions
end

function MOIB.Constraint.bridge_constraint(::Type{VectorDecisionConstraintBridge{T,S}},
                                           model,
                                           f::VectorOfDecisions,
                                           set::S) where {T, S <: MOI.AbstractVectorSet}
    # Perform the bridge mapping manually
    mapped_variables = map(f.decisions) do decision
        bridged = MOIB.bridged_function(
            model,
            AffineDecisionFunction{T}(SingleDecision(decision)))
        bridged.decision_part.terms[1].variable_index
    end
    # Add the bridged constraint
    constraint = MOI.add_constraint(model,
                                    MOI.VectorOfVariables(mapped_variables),
                                    set)
    # Save the constraint indices and the decision to allow modifications
    return VectorDecisionConstraintBridge{T,S}(constraint, fill(FixingConstraint{T}(0), MOI.dimension(set)), f)
end

function MOI.supports_constraint(::Type{<:VectorDecisionConstraintBridge{T}},
                                 ::Type{VectorOfDecisions},
                                 ::Type{<:MOI.AbstractVectorSet}) where T
    return true
end
function MOIB.added_constrained_variable_types(::Type{<:VectorDecisionConstraintBridge})
    return Tuple{DataType}[]
end
function MOIB.added_constraint_types(::Type{<:VectorDecisionConstraintBridge{T,S}}) where {T,S}
    return [(MOI.VectorOfVariables, S), (MOI.ScalarAffineFunction{T}, MOI.EqualTo{T})]
end
function MOIB.Constraint.concrete_bridge_type(::Type{<:VectorDecisionConstraintBridge{T}},
                              ::Type{VectorOfDecisions},
                              S::Type{<:MOI.AbstractVectorSet}) where T
    return VectorDecisionConstraintBridge{T,S}
end

MOI.get(b::VectorDecisionConstraintBridge{T,S}, ::MOI.NumberOfConstraints{MOI.VectorOfVariables, S}) where {T,S} = 1
MOI.get(b::VectorDecisionConstraintBridge{T}, ::MOI.NumberOfConstraints{MOI.ScalarAffineFunction{T}, MOI.EqualTo{T}}) where T =
    count(fc -> fc.value != 0, b.fixing_constraints)
MOI.get(b::VectorDecisionConstraintBridge{T}, ::MOI.ListOfConstraintIndices{MOI.VectorOfVariables, S}) where {T,S} = [b.constraint]
MOI.get(b::VectorDecisionConstraintBridge{T}, ::MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{T}, MOI.EqualTo{T}}) where {T} =
    filter(fc -> fc.value != 0, b.fixing_constraints)

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintFunction,
                 bridge::VectorDecisionConstraintBridge)
    return bridge.decisions
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::VectorDecisionConstraintBridge)
    return MOI.get(model, MOI.ConstraintSet(), bridge.constraint)
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintPrimal,
                 bridge::VectorDecisionConstraintBridge)
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintDual,
                 bridge::VectorDecisionConstraintBridge)
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.delete(model::MOI.ModelLike, bridge::VectorDecisionConstraintBridge)
    MOI.delete(model, bridge.constraint)
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::VectorDecisionConstraintBridge{T,S}, change::S) where {T,S}
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint, change)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::VectorDecisionConstraintBridge{T,S}, change::DecisionStateChange) where {T,S}
    i = findfirst(d -> d.decision == change.decision, bridge.decisions.decisions)
    # Switch on state transition
    if change.new_state == NotTaken
        if bridge.fixing_constraints[i].value != 0
            # Remove the fixing constraint
            MOI.delete(model, bridge.fixing_constraints[i])
            bridge.fixing_constraints[i] = FixingConstraint{T}(0)
        end
    end
    if change.new_state == Taken
        if bridge.fixing_constraints[i].value != 0
            # Remove any existing fixing constraint
            MOI.delete(model, bridge.fixing_constraints[i])
        end
        # Perform the bridge mapping manually
        aff = MOIB.bridged_function(model, AffineDecisionFunction{T}(bridge.decisions.decisions[i]))
        f = MOI.ScalarAffineFunction{T}(MOI.SingleVariable(aff.decision_part.terms[1].variable_index))
        # Get the decision value
        set = MOI.EqualTo(aff.decision_part.constant)
        # Add a fixing constraint to ensure that fixed decision is feasible.
        bridge.fixing_constraints[i] = MOI.add_constraint(model, f, set)
    end
    return nothing
end
