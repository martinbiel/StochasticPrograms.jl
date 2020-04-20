struct DecisionObjectiveBridge{T} <: MOIB.Objective.AbstractBridge
    decision_function::AffineDecisionFunction{T}
end

function MOIB.Objective.bridge_objective(::Type{DecisionObjectiveBridge{T}}, model::MOI.ModelLike,
                                         f::AffineDecisionFunction{T}) where T
    # All decisions have been mapped to either the decision part constant or the variable part terms
    # at this point.
    F = MOI.ScalarAffineFunction{T}
    # Calculate total constant
    constant = f.variable_part.constant + f.decision_part.constant + f.known_part.constant
    # Set the bridged objective
    MOI.set(model, MOI.ObjectiveFunction{F}(), MOI.ScalarAffineFunction(f.variable_part.terms, constant))
    # Save decision function to allow modifications
    return DecisionObjectiveBridge{T}(f)
end

function MOIB.Objective.supports_objective_function(
    ::Type{<:DecisionObjectiveBridge}, ::Type{<:AffineDecisionFunction})
    return true
end
MOIB.added_constrained_variable_types(::Type{<:DecisionObjectiveBridge}) = Tuple{DataType}[]
function MOIB.added_constraint_types(::Type{<:DecisionObjectiveBridge})
    return Tuple{DataType, DataType}[]
end
function MOIB.set_objective_function_type(::Type{DecisionObjectiveBridge{T}}) where T
    return MOI.ScalarAffineFunction{T}
end

function MOI.get(::DecisionObjectiveBridge, ::MOI.NumberOfVariables)
    return 0
end

function MOI.get(::DecisionObjectiveBridge, ::MOI.ListOfVariableIndices)
    return MOI.VariableIndex[]
end


function MOI.delete(::MOI.ModelLike, ::DecisionObjectiveBridge)
    # Nothing to delete
    return nothing
end

function MOI.set(::MOI.ModelLike, ::MOI.ObjectiveSense,
                 ::DecisionObjectiveBridge, ::MOI.OptimizationSense)
    # Nothing to handle if sense changes
    return nothing
end

function MOI.get(model::MOI.ModelLike,
                 attr::MOIB.ObjectiveFunctionValue{F},
                 bridge::DecisionObjectiveBridge{T}) where {T, F  <: AffineDecisionFunction{T}}
    G = MOI.ScalarAffineFunction{T}
    return MOI.get(model, MOIB.ObjectiveFunctionValue{G}(attr.result_index))
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ObjectiveFunction{F},
                 bridge::DecisionObjectiveBridge{T}) where {T, F <: AffineDecisionFunction{T}}
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

function MOI.modify(model::MOI.ModelLike, bridge::DecisionObjectiveBridge{T}, change::MOI.ScalarConstantChange) where T
    # Modify constant of variable part
    bridge.decision_function.variable_part.constant = change.new_constant
    # Recalculate total constant and set total constant
    constant = bridge.decision_function.variable_part.constant +
        bridge.decision_function.decision_part.constant +
        bridge.decision_function.known_part.constant
    F = MOI.ScalarAffineFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(),
               ScalarConstantChange{T}(constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionObjectiveBridge{T}, change::MOI.ScalarCoefficientChange) where T
    # Modify variable part of decision function
     i = something(findfirst(t -> t.variable_index == change.variable,
                            bridge.decision_function.variable_part.terms), 0)
    if iszero(i)
        # The variable was not already in the objective
        if !iszero(change.new_coefficient)
            # Add it
            push!(bridge.decision_function.variable_part.terms,
                  MOI.ScalarAffineTerm(change.new_coefficient, change.variable))
        end
    else
        # The variable is in the objective
        if iszero(change.new_coefficient)
            # Remove it
            deleteat!(bridge.decision_function.variable_part.terms, i)
        else
            # Update coefficient
            bridge.decision_function.variable_part.terms[i].coefficient = change.new_coefficient
        end
    end
    # Modify the variable part mapped objective as well
    F = MOI.ScalarAffineFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), change)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionObjectiveBridge{T}, change::DecisionCoefficientChange) where T
    i = something(findfirst(t -> t.variable_index == change.decision,
                            bridge.decision_function.decision_part.terms), 0)
    # Query the fixed decision value
    unbridged = MOIB.unbridged_variable_function(model, change.decision)::SingleDecision
    decision_value = MOI.get(model, MOI.VariablePrimal(), unbridged.index)
    # Update decision part of objective
    coefficient = iszero(i) ? zero(T) : bridge.decision_function.decision_part.terms[i].coefficient
    bridge.decision_function.decision_part.constant +=
        (change.new_coefficient - coefficient) * decision_value
    # Update the decision coefficient
    if iszero(i)
        # The decision was not already in the objective
        if !iszero(change.new_coefficient)
            # Add it
            push!(bridge.decision_function.decision_part.terms,
                  MOI.ScalarAffineTerm(change.new_coefficient, change.decision))
        end
    else
        # The decision is in the objective
        if iszero(change.new_coefficient)
            # Remove it
            deleteat!(bridge.decision_function.decision_part.terms, i)
        else
            # Update the coefficient
            bridge.decision_function.decision_part.terms[i].coefficient = change.new_coefficient
        end
    end
    # Recalculate and set total constant
    constant = bridge.decision_function.variable_part.constant +
        bridge.decision_function.decision_part.constant +
        bridge.decision_function.known_part.constant
    F = MOI.ScalarAffineFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(),
               MOI.ScalarConstantChange{T}(constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionObjectiveBridge{T}, change::KnownCoefficientChange) where T
    i = something(findfirst(t -> t.variable_index == change.known,
                            bridge.decision_function.known_part.terms), 0)
    # Update decision part of objective
    coefficient = iszero(i) ? zero(T) : bridge.decision_function.known_part.terms[i].coefficient
    bridge.decision_function.known_part.constant +=
        (change.new_coefficient - coefficient) * change.known_value
    # Update the decision coefficient
    if iszero(i)
        # The decision was not already in the objective
        if !iszero(change.new_coefficient)
            # Add it
            push!(bridge.decision_function.known_part.terms,
                  MOI.ScalarAffineTerm(change.new_coefficient, change.known))
        end
    else
        # The decision is in the objective
        if iszero(change.new_coefficient)
            # Remove it
            deleteat!(bridge.decision_function.known_part.terms, i)
        else
            # Update the coefficient
            bridge.decision_function.known_part.terms[i].coefficient = change.new_coefficient
        end
    end
    # Recalculate and set total constant
    constant = bridge.decision_function.variable_part.constant +
        bridge.decision_function.decision_part.constant +
        bridge.decision_function.known_part.constant
    F = MOI.ScalarAffineFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(),
               MOI.ScalarConstantChange{T}(constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionObjectiveBridge{T}, change::DecisionStateChange) where T
    F = MOI.ScalarAffineFunction{T}
    # Switch on state transition
    if change.new_state == NotTaken
        # Get the decision coefficient
        i = something(findfirst(t -> t.variable_index == change.decision,
                                bridge.decision_function.decision_part.terms), 0)
        if iszero(i)
            # Decision not in objective, nothing to do
            return nothing
        end
        coefficient = bridge.decision_function.decision_part.terms[i].coefficient
        # Update fixed decision value
        change.value_difference < 0 || error("Decision value update should be negative when transitioning to NotTaken state.")
        bridge.decision_function.decision_part.constant +=
            coefficient * change.value_difference
        # Modify bridge functions
        push!(bridge.decision_function.variable_part.terms,
              MOI.ScalarAffineTerm(coefficient, change.decision))
        deleteat!(bridge.decision_function.decision_part.terms, i)
        # Modify the coefficient of the mapped variable
        MOI.modify(model, MOI.ObjectiveFunction{F}(),
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
        coefficient = bridge.decision_function.variable_part.terms[i].coefficient
        # Update fixed decision value
        bridge.decision_function.decision_part.constant +=
            coefficient * change.value_difference
        # Modify bridge function
        deleteat!(bridge.decision_function.variable_part.terms, i)
        push!(bridge.decision_function.decision_part.terms,
              MOI.ScalarAffineTerm(coefficient, change.decision))
        # Modify the coefficient of the mapped variable
        MOI.modify(model, MOI.ObjectiveFunction{F}(),
                   MOI.ScalarCoefficientChange(change.decision, zero(T)))
    end
    # Recalculate and set total constant
    constant = bridge.decision_function.variable_part.constant +
        bridge.decision_function.decision_part.constant +
        bridge.decision_function.known_part.constant
    F = MOI.ScalarAffineFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(),
               MOI.ScalarConstantChange{T}(constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionObjectiveBridge{T}, ::DecisionsStateChange) where T
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
    F = AffineDecisionFunction{T}
    # Set the bridged objective
    MOI.set(model, MOI.ObjectiveFunction{F}(), bridge.decision_function)
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionObjectiveBridge{T}, change::KnownValueChange) where T
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
    # Recalculate and set total constant
    constant = bridge.decision_function.variable_part.constant +
        bridge.decision_function.decision_part.constant +
        bridge.decision_function.known_part.constant
    F = MOI.ScalarAffineFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(),
               MOI.ScalarConstantChange{T}(constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::DecisionObjectiveBridge{T}, change::KnownValuesChange) where T
    known_value = zero(T)
    for term in bridge.decision_function.known_part.terms
        known_value += term.coefficient * known_value(change.known_decisions[term.variable_index])
    end
    # Update known part of objective
    bridge.decision_function.known_part.constant = known_value
    # Recalculate and set total constant
    constant = bridge.decision_function.variable_part.constant +
        bridge.decision_function.decision_part.constant +
        bridge.decision_function.known_part.constant
    F = MOI.ScalarAffineFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(),
               MOI.ScalarConstantChange{T}(constant))
    return nothing
end
