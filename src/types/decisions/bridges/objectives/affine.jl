# Affine decision function #
# ========================== #
struct AffineDecisionObjectiveBridge{T} <: MOIB.Objective.AbstractBridge
    decision_function::AffineDecisionFunction{T}
end

function MOIB.Objective.bridge_objective(::Type{AffineDecisionObjectiveBridge{T}}, model::MOI.ModelLike,
                                         f::AffineDecisionFunction{T}) where T
    # All decisions have been mapped to either the decision part constant or the variable part terms
    # at this point.
    F = MOI.ScalarAffineFunction{T}
    # Set the bridged objective
    MOI.set(model, MOI.ObjectiveFunction{F}(), MOI.ScalarAffineFunction(f.variable_part.terms, zero(T)))
    # Save decision function to allow modifications
    return AffineDecisionObjectiveBridge{T}(f)
end

function MOIB.Objective.supports_objective_function(
    ::Type{<:AffineDecisionObjectiveBridge}, ::Type{<:AffineDecisionFunction})
    return true
end
MOIB.added_constrained_variable_types(::Type{<:AffineDecisionObjectiveBridge}) = Tuple{DataType}[]
function MOIB.added_constraint_types(::Type{<:AffineDecisionObjectiveBridge})
    return Tuple{DataType, DataType}[]
end
function MOIB.set_objective_function_type(::Type{AffineDecisionObjectiveBridge{T}}) where T
    return MOI.ScalarAffineFunction{T}
end

function MOI.get(::AffineDecisionObjectiveBridge, ::MOI.NumberOfVariables)
    return 0
end

function MOI.get(::AffineDecisionObjectiveBridge, ::MOI.ListOfVariableIndices)
    return MOI.VariableIndex[]
end


function MOI.delete(::MOI.ModelLike, ::AffineDecisionObjectiveBridge)
    # Nothing to delete
    return nothing
end

function MOI.set(::MOI.ModelLike, ::MOI.ObjectiveSense,
                 ::AffineDecisionObjectiveBridge, ::MOI.OptimizationSense)
    # Nothing to handle if sense changes
    return nothing
end

function MOI.get(model::MOI.ModelLike,
                 attr::MOIB.ObjectiveFunctionValue{F},
                 bridge::AffineDecisionObjectiveBridge{T}) where {T, F <: AffineDecisionFunction{T}}
    f = bridge.decision_function
    G = MOI.ScalarAffineFunction{T}
    obj_val = MOI.get(model, MOIB.ObjectiveFunctionValue{G}(attr.result_index))
    # Calculate and add constant
    constant = f.variable_part.constant +
        f.decision_part.constant +
        f.known_part.constant
    return obj_val + constant
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ObjectiveFunction{F},
                 bridge::AffineDecisionObjectiveBridge{T}) where {T, F <: AffineDecisionFunction{T}}
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

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionObjectiveBridge{T}, change::MOI.ScalarConstantChange) where T
    f = bridge.decision_function
    # Modify constant of variable part
    f.variable_part.constant = change.new_constant
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionObjectiveBridge{T}, change::MOI.ScalarCoefficientChange) where T
    f = bridge.decision_function
    # Modify variable part of decision function
    modify_coefficient!(f.variable_part.terms, change.variable, change.new_coefficient)
    # Modify decision part if variable originated from a decision
    i = something(findfirst(t -> t.variable_index == change.variable,
                            f.decision_part.terms), 0)
    if !iszero(i)
        modify_coefficient!(f.decision_part.terms, change.variable, change.new_coefficient)
    end
    # Modify the variable part of the mapped objective as well
    F = MOI.ScalarAffineFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), change)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionObjectiveBridge{T}, change::DecisionCoefficientChange) where T
    f = bridge.decision_function
    i = something(findfirst(t -> t.variable_index == change.decision,
                            f.decision_part.terms), 0)
    # Query the fixed decision value
    unbridged = MOIB.unbridged_variable_function(model, change.decision)::MOI.SingleVariable
    decision_value = MOI.get(model, MOI.VariablePrimal(), unbridged.variable)
    # Update decision part of objective
    coefficient = iszero(i) ? zero(T) : f.decision_part.terms[i].coefficient
    f.decision_part.constant +=
        (change.new_coefficient - coefficient) * decision_value
    # Update the decision coefficient
    modify_coefficient!(f.decision_part.terms, change.decision, change.new_coefficient)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionObjectiveBridge{T}, change::KnownCoefficientChange) where T
    f = bridge.decision_function
    i = something(findfirst(t -> t.variable_index == change.known,
                            f.known_part.terms), 0)
    # Update known part of objective constant
    coefficient = iszero(i) ? zero(T) : f.known_part.terms[i].coefficient
    known_value = MOI.get(model, MOI.VariablePrimal(), change.known)
    f.known_part.constant +=
        (change.new_coefficient - coefficient) * known_value
    # Update the decision coefficient
    modify_coefficient!(f.known_part.terms, change.known, change.new_coefficient)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionObjectiveBridge{T}, change::DecisionStateChange) where T
    f = bridge.decision_function
    F = MOI.ScalarAffineFunction{T}
    # Switch on state transition
    if change.new_state == NotTaken
        i = something(findfirst(t -> t.variable_index == change.decision,
                                f.decision_part.terms), 0)
        if iszero(i)
            # Decision not in objective, nothing to do
            return nothing
        end
        # Get the decision coefficient
        coefficient = f.decision_part.terms[i].coefficient
        # Update fixed decision value
        change.value_difference < 0 || error("Decision value update should be negative when transitioning to NotTaken state.")
        f.decision_part.constant +=
            coefficient * change.value_difference
        # Modify bridge functions
        push!(f.variable_part.terms,
              MOI.ScalarAffineTerm(coefficient, change.decision))
        deleteat!(f.decision_part.terms, i)
        # Modify the coefficient of the mapped variable
        MOI.modify(model, MOI.ObjectiveFunction{F}(),
                   MOI.ScalarCoefficientChange(change.decision, coefficient))
    end
    if change.new_state == Taken
        i = something(findfirst(t -> t.variable_index == change.decision,
                                f.variable_part.terms), 0)
        if iszero(i)
            # Decision not in objective, nothing to do
            return nothing
        end
        # Get the decision coefficient
        coefficient = f.variable_part.terms[i].coefficient
        # Update fixed decision value
        f.decision_part.constant +=
            coefficient * change.value_difference
        # Modify bridge function
        deleteat!(f.variable_part.terms, i)
        push!(f.decision_part.terms,
              MOI.ScalarAffineTerm(coefficient, change.decision))
        # Modify the coefficient of the mapped variable
        MOI.modify(model, MOI.ObjectiveFunction{F}(),
                   MOI.ScalarCoefficientChange(change.decision, zero(T)))
    end
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionObjectiveBridge{T}, ::DecisionsStateChange) where T
    f = bridge.decision_function
    # Remove mapped variables to properly unbridge
    from_decision(v) = begin
        result = any(t -> t.variable_index == v, f.decision_part.terms)
    end
    unbridged_func = AffineDecisionFunction{T}(
        MOIU.filter_variables(v -> !from_decision(v), f.variable_part),
        convert(MOI.ScalarAffineFunction{T}, zero(T)),
        copy(f.known_part))
    # Unbridge the objective function and cache
    # all occuring decisions.
    unbridged_terms = map(f.decision_part.terms) do term
        unbridged = MOIB.unbridged_variable_function(model, term.variable_index)
        MOI.ScalarAffineTerm(term.coefficient, unbridged.variable)
    end
    append!(unbridged_func.decision_part.terms, unbridged_terms)
    # Rebridge objective
    F = AffineDecisionFunction{T}
    MOI.set(model, MOI.ObjectiveFunction{F}(), unbridged_func)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionObjectiveBridge{T}, change::KnownValueChange) where T
    f = bridge.decision_function
    i = something(findfirst(t -> t.variable_index == change.known,
                            f.known_part.terms), 0)
    if iszero(i)
        # Known value not in objective, nothing to do
        return nothing
    end
    # Update known part of objective constant
    coefficient = f.known_part.terms[i].coefficient
    f.known_part.constant +=
        coefficient * change.value_difference
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::AffineDecisionObjectiveBridge{T}, change::KnownValuesChange) where T
    f = bridge.decision_function
    # Update known value
    known_val = zero(T)
    for term in f.known_part.terms
        known_val += term.coefficient * MOI.get(model, MOI.VariablePrimal(), term.variable_index)
    end
    # Update known part of objective constant
    f.known_part.constant = known_val
    return nothing
end
