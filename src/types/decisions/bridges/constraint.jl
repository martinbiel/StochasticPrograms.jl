mutable struct DecisionConstraintBridge{T, S} <: MOIB.Constraint.AbstractBridge
    constraint::CI{MOI.ScalarAffineFunction{T}, S}
    decision_function::AffineDecisionFunction{T}
    set::S
end

function MOIB.Constraint.bridge_constraint(::Type{DecisionConstraintBridge{T, S}},
                                           model,
                                           f::AffineDecisionFunction{T},
                                           set::S) where {T, S}
    # All decisions have been mapped to either the decision part constant or the variable part terms
    # at this point.
    F = MOI.ScalarAffineFunction{T}
    # Calculate total constant
    constant = f.variable_part.constant + f.decision_part.constant + f.known_part.constant
    # Add the bridged constraint
    constraint = MOI.add_constraint(model,
                                    MOI.ScalarAffineFunction(f.variable_part.terms, zero(T)),
                                    MOIU.shift_constant(set, -constant))
    # Save the constraint index, the decision function, and the set, to allow modifications
    return DecisionConstraintBridge{T, S}(constraint, f, set)
end

function MOI.supports_constraint(::Type{<:DecisionConstraintBridge{T}},
                                 ::Type{<:AffineDecisionFunction{T}},
                                 ::Type{<:MOI.AbstractScalarSet}) where {T}
    return true
end
function MOIB.added_constrained_variable_types(::Type{<:DecisionConstraintBridge})
    return Tuple{DataType}[]
end
function MOIB.added_constraint_types(::Type{<:DecisionConstraintBridge{T, S}}) where {T, S}
    return [(MOI.ScalarAffineFunction{T}, S)]
end
function MOIB.Constraint.concrete_bridge_type(::Type{<:DecisionConstraintBridge{T}},
                              ::Type{<:AffineDecisionFunction{T}},
                              S::Type{<:MOI.AbstractScalarSet}) where T
    return DecisionConstraintBridge{T, S}
end

MOI.get(b::DecisionConstraintBridge{T, S}, ::MOI.NumberOfConstraints{MOI.ScalarAffineFunction{T}, S}) where {T, S} = 1
MOI.get(b::DecisionConstraintBridge{T, S}, ::MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{T}, S}) where {T, S} = [b.constraint]

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintFunction,
                 bridge::DecisionConstraintBridge{T}) where T
    to_remove = Vector{Int}()
    f = copy(bridge.decision_function)
    for (i,term) in enumerate(f.variable_part.terms)
        if any(t -> t.variable_index == term.variable_index, f.decision_part.terms)
            push!(to_remove, i)
        end
    end
    deleteat!(f.variable_part.terms, to_remove)
    return f
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::DecisionConstraintBridge{T}) where T
    return bridge.set
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintPrimal,
                 bridge::DecisionConstraintBridge{T}) where T
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintDual,
                 bridge::DecisionConstraintBridge{T}) where T
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.delete(model::MOI.ModelLike, bridge::DecisionConstraintBridge)
    MOI.delete(model, bridge.constraint)
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintFunction,
                 bridge::DecisionConstraintBridge{T,S},
                 f::AffineDecisionFunction{T}) where {T,S}
    # Update bridge functions and function constant
    bridge.decision_function = f
    # Change the function of the bridged constraints
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            MOI.ScalarAffineFunction(f.variable_part.terms, zero(T)))
    # Recalculate total constant and shift constraint set
    constant = f.variable_part.constant +
        f.decision_part.constant +
        f.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::DecisionConstraintBridge{T,S}, change::S) where {T,S}
    bridge.set = change
    # Recalculate total constant and shift constraint set
    constant = bridge.decision_function.variable_part.constant +
        bridge.decision_function.decision_part.constant +
        bridge.decision_function.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(change, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionConstraintBridge{T,S}, change::MOI.ScalarConstantChange) where {T,S}
    # Modify variable part of decision function
    bridge.decision_function.variable_part.constant = change.new_constant
    # Recalculate total constant and shift constraint set
    constant = bridge.decision_function.variable_part.constant +
        bridge.decision_function.decision_part.constant +
        bridge.decision_function.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionConstraintBridge{T,S}, change::MOI.ScalarCoefficientChange) where {T,S}
    # Modify variable part of decision function
    i = something(findfirst(t -> t.variable_index == change.variable,
                            bridge.decision_function.variable_part.terms), 0)
    if iszero(i)
        # The variable was not already in the constraint
        if !iszero(change.new_coefficient)
            # Add it
            push!(bridge.decision_function.variable_part.terms,
                  MOI.ScalarAffineTerm(change.new_coefficient, change.variable))
        end
    else
        # The variable is in the constraint
        if iszero(change.new_coefficient)
            # Remove it
            deleteat!(bridge.decision_function.variable_part.terms, i)
        else
            # Update coefficient
            bridge.decision_function.variable_part.terms[i].coefficient = change.new_coefficient
        end
    end
    # Modify the variable part of the constraint as usual
    MOI.modify(model, bridge.constraint, change)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionConstraintBridge{T,S}, change::DecisionCoefficientChange) where {T,S}
    i = something(findfirst(t -> t.variable_index == change.decision,
                            bridge.decision_function.decision_part.terms), 0)
    # Query the fixed decision value
    unbridged = MOIB.unbridged_variable_function(model, change.decision)::SingleDecision
    decision_value = MOI.get(model, MOI.VariablePrimal(), unbridged.index)
    # Update decision part of constraint
    coefficient = iszero(i) ? zero(T) : bridge.decision_function.decision_part.terms[i].coefficient
    bridge.decision_function.decision_part.constant +=
        (change.new_coefficient - coefficient) * decision_value
    # Update the decision coefficient
    if iszero(i)
        # The decision was not already in the constraint
        if !iszero(change.new_coefficient)
            # Add it
            push!(bridge.decision_function.decision_part.terms,
                  MOI.ScalarAffineTerm(change.new_coefficient, change.decision))
        end
    else
        # The decision is in the constraint
        if iszero(change.new_coefficient)
            # Remove it
            deleteat!(bridge.decision_function.decision_part.terms, i)
        else
            # Update the coefficient
            bridge.decision_function.decision_part.terms[i].coefficient = change.new_coefficient
        end
    end
    # Recalculate total constant and shift constraint set
    constant = bridge.decision_function.variable_part.constant +
        bridge.decision_function.decision_part.constant +
        bridge.decision_function.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionConstraintBridge{T,S}, change::KnownCoefficientChange) where {T,S}
    i = something(findfirst(t -> t.variable_index == change.known,
                            bridge.decision_function.known_part.terms), 0)
    # Update decision part of constraint
    coefficient = iszero(i) ? zero(T) : bridge.decision_function.known_part.terms[i].coefficient
    bridge.decision_function.known_part.constant +=
        (change.new_coefficient - coefficient) * change.known_value
    # Update the decision coefficient
    if iszero(i)
        # The decision was not already in the constraint
        if !iszero(change.new_coefficient)
            # Add it
            push!(bridge.decision_function.known_part.terms,
                  MOI.ScalarAffineTerm(change.new_coefficient, change.known))
        end
    else
        # The decision is in the constraint
        if iszero(change.new_coefficient)
            # Remove it
            deleteat!(bridge.decision_function.known_part.terms, i)
        else
            # Update the coefficient
            bridge.decision_function.known_part.terms[i].coefficient = change.new_coefficient
        end
    end
    # Recalculate total constant and shift constraint set
    constant = bridge.decision_function.variable_part.constant +
        bridge.decision_function.decision_part.constant +
        bridge.decision_function.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionConstraintBridge{T,S}, change::DecisionStateChange) where {T,S}
    # Switch on state transition
    if change.new_state == NotTaken
        # Get the decision coefficient
        i = something(findfirst(t -> t.variable_index == change.decision,
                                bridge.decision_function.decision_part.terms), 0)
        if iszero(i)
            # Decision not in constraint, nothing to do
            return nothing
        end
        coefficient = bridge.decision_function.decision_part.terms[i].coefficient
        # Update fixed decision value
        change.value_difference < 0 ||
            error("Decision value update should be negative when transitioning to NotTaken state.")
        bridge.decision_function.decision_part.constant +=
            coefficient * change.value_difference
        # Modify bridge functions
        push!(bridge.decision_function.variable_part.terms,
              MOI.ScalarAffineTerm(coefficient, change.decision))
        deleteat!(bridge.decision_function.decision_part.terms, i)
        # Modify the coefficient of the mapped variable
        MOI.modify(model, bridge.constraint,
                   MOI.ScalarCoefficientChange(change.decision, coefficient))
    end
    if change.new_state == Taken
        # Get the decision coefficient
        i = something(findfirst(t -> t.variable_index == change.decision,
                                bridge.decision_function.variable_part.terms), 0)
        if iszero(i)
            # Decision not in objective, nothing to do
            return nothing
        end
        # Update fixed decision value
        coefficient = bridge.decision_function.variable_part.terms[i].coefficient
        bridge.decision_function.decision_part.constant +=
            coefficient * change.value_difference
        # Modify bridge functions
        deleteat!(bridge.decision_function.variable_part.terms, i)
        push!(bridge.decision_function.decision_part.terms,
              MOI.ScalarAffineTerm(coefficient, change.decision))
        # Modify the coefficient of the mapped variable
        MOI.modify(model, bridge.constraint,
                   MOI.ScalarCoefficientChange(change.decision, zero(T)))
    end
    # Recalculate total constant and shift constraint set
    constant = bridge.decision_function.variable_part.constant +
        bridge.decision_function.decision_part.constant +
        bridge.decision_function.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionConstraintBridge{T}, ::DecisionsStateChange) where T
    unbridged_func = zero(AffineDecisionFunction{T})
    variables_to_remove = Vector{Int}()
    decisions_to_remove = Vector{Int}()
    # First, unbridge the objective function and cache
    # all occuring decisions.
    for (i,term) in enumerate(bridge.decision_function.decision_part.terms)
        unbridged = MOIB.unbridged_variable_function(model, term.variable_index)
        push!(decisions_to_remove, i)
        push!(unbridged_func.decision_part.terms,
              MOI.ScalarAffineTerm(term.coefficient, unbridged.variable))
        # Check if a mapped variable exists and remove it as well if so
        j = something(findfirst(t -> t.variable_index == term.variable_index,
                                bridge.decision_function.variable_part.terms), 0)
        j != 0 && push!(variables_to_remove, j)
    end
    # Remove terms that come from bridged decisions
    deleteat!(bridge.decision_function.variable_part.terms, variables_to_remove)
    deleteat!(bridge.decision_function.decision_part.terms, decisions_to_remove)
    # Reset decision constant
    bridge.decision_function.decision_part.constant = zero(T)
    # Rebridge
    MOIU.operate!(+, T, bridge.decision_function, MOIB.bridged_function(model, unbridged_func))
    # All decisions have been mapped to either the decision part constant
    # or the variable part terms at this point.
    # Update constraint function
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            MOI.ScalarAffineFunction(bridge.decision_function.variable_part.terms, zero(T)))
    # Recalculate total constant and shift constraint set
    constant = bridge.decision_function.variable_part.constant +
        bridge.decision_function.decision_part.constant +
        bridge.decision_function.known_part.constant
    MOI.set(model.model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionConstraintBridge{T,S}, change::KnownValueChange) where {T,S}
    i = something(findfirst(t -> t.variable_index == change.known,
                            bridge.decision_function.known_part.terms), 0)
    if iszero(i)
        # Known value not in objective, nothing to do
        return nothing
    end
    # Update known part of objective
    coefficient = bridge.decision_function.known_part.terms[i].coefficient
    bridge.decision_function.known_part.constant +=
        coefficient * change.value_difference
    # Recalculate total constant and shift constraint set
    constant = bridge.decision_function.variable_part.constant +
        bridge.decision_function.decision_part.constant +
        bridge.decision_function.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionConstraintBridge{T,S}, change::KnownValuesChange) where {T,S}
    known_val = zero(T)
    for term in bridge.decision_function.known_part.terms
        known_val += term.coefficient * known_value(change.known_decisions[term.variable_index])
    end
    # Update known part of objective
    bridge.decision_function.known_part.constant = known_val
    # Recalculate total constant and shift constraint set
    constant = bridge.decision_function.variable_part.constant +
        bridge.decision_function.decision_part.constant +
        bridge.decision_function.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end
