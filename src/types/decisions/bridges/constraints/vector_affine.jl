# VectorAffineDecisionFunction #
# ========================== #
mutable struct VectorAffineDecisionConstraintBridge{T, S} <: MOIB.Constraint.AbstractBridge
    constraint::CI{MOI.VectorAffineFunction{T}, S}
    decision_function::VectorAffineDecisionFunction{T}
    set::S
end

function MOIB.Constraint.bridge_constraint(::Type{VectorAffineDecisionConstraintBridge{T, S}},
                                           model,
                                           f::VectorAffineDecisionFunction{T},
                                           set::S) where {T, S}
    # All decisions have been mapped to either the decision part constant or the variable part terms
    # at this point.
    F = MOI.VectorAffineFunction{T}
    # Calculate total constant
    constants = f.variable_part.constants +
        f.decision_part.constants +
        f.known_part.constants
    # Add the bridged constraint
    constraint = MOI.add_constraint(model,
                                    MOI.VectorAffineFunction(f.variable_part.terms, constants),
                                    set)
    # Save the constraint index, the decision function, and the set, to allow modifications
    return VectorAffineDecisionConstraintBridge{T, S}(constraint, f, set)
end

function MOI.supports_constraint(::Type{<:VectorAffineDecisionConstraintBridge{T}},
                                 ::Type{<:VectorAffineDecisionFunction{T}},
                                 ::Type{<:MOI.AbstractVectorSet}) where {T}
    return true
end
function MOIB.added_constrained_variable_types(::Type{<:VectorAffineDecisionConstraintBridge})
    return Tuple{DataType}[]
end
function MOIB.added_constraint_types(::Type{<:VectorAffineDecisionConstraintBridge{T, S}}) where {T, S}
    return [(MOI.VectorAffineFunction{T}, S)]
end
function MOIB.Constraint.concrete_bridge_type(::Type{<:VectorAffineDecisionConstraintBridge{T}},
                              ::Type{<:VectorAffineDecisionFunction{T}},
                              S::Type{<:MOI.AbstractVectorSet}) where T
    return VectorAffineDecisionConstraintBridge{T, S}
end

MOI.get(b::VectorAffineDecisionConstraintBridge{T, S}, ::MOI.NumberOfConstraints{MOI.VectorAffineFunction{T}, S}) where {T, S} = 1
MOI.get(b::VectorAffineDecisionConstraintBridge{T, S}, ::MOI.ListOfConstraintIndices{MOI.VectorAffineFunction{T}, S}) where {T, S} = [b.constraint]

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintFunction,
                 bridge::VectorAffineDecisionConstraintBridge{T}) where T
    f = bridge.decision_function
    # Remove mapped variables to properly unbridge
    from_decision(v) = begin
        result = any(t -> t.variable_index == v, f.decision_part.terms)
    end
    g = VectorAffineDecisionFunction(
        MOIU.filter_variables(v -> !from_decision(v), f.variable_part),
        copy(f.decision_part),
        copy(f.known_part))
    return g
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::VectorAffineDecisionConstraintBridge{T}) where T
    return bridge.set
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintPrimal,
                 bridge::VectorAffineDecisionConstraintBridge{T}) where T
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintDual,
                 bridge::VectorAffineDecisionConstraintBridge{T}) where T
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.delete(model::MOI.ModelLike, bridge::VectorAffineDecisionConstraintBridge)
    MOI.delete(model, bridge.constraint)
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintFunction,
                 bridge::VectorAffineDecisionConstraintBridge{T,S},
                 f::VectorAffineDecisionFunction{T}) where {T,S}
    # Update bridge functions and function constant
    bridge.decision_function = f
    # Recalculate total constants and modify constraint function
    constants = f.variable_part.constants +
        f.decision_part.constants +
        f.known_part.constants
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            MOI.VectorAffineFunction(f.variable_part.terms, constants))
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::VectorAffineDecisionConstraintBridge{T,S}, change::S) where {T,S}
    f = bridge.decision_function
    bridge.set = change
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint, change)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::VectorAffineDecisionConstraintBridge{T,S}, change::MOI.VectorConstantChange) where {T,S}
    f = bridge.decision_function
    # Modify variable part of decision function
    f.variable_part.constants .= change.new_constant
    # Recalculate total constants and modify constraint function
    constants = f.variable_part.constants +
        f.decision_part.constants +
        f.known_part.constants
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            MOI.VectorAffineFunction(f.variable_part.terms, constants))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::VectorAffineDecisionConstraintBridge{T,S}, change::MOI.MultirowChange) where {T,S}
    f = bridge.decision_function
    # Modify variable part of decision function
    modify_coefficients!(f.variable_part.terms, change.decision, change.new_coefficients)
    # Modify decision part if variable originated from a decision
    if !isempty(findall(t -> t.scalar_term.variable_index == change.variable, f.decision_part.terms))
        modify_coefficients!(f.decision_part.terms, change.variable, change.new_coefficients)
    end
    # Modify the variable part of the constraint as usual
    MOI.modify(model, bridge.constraint, change)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::VectorAffineDecisionConstraintBridge{T,S}, change::DecisionMultirowChange) where {T,S}
    f = bridge.decision_function
    # Query the fixed decision value
    unbridged = MOIB.unbridged_variable_function(model, change.decision)::MOI.SingleVariable
    decision_value = MOI.get(model, MOI.VariablePrimal(), unbridged.variable)
    seen = Int[]
    for i in findall(t -> t.scalar_term.variable_index == change.decision, f.decision_part.terms)
        # Update decision part of constraint constant
        coefficient = f.decision_part.terms[i].scalar_term.coefficient
        f.decision_part.constants[i] +=
            (change.new_coefficient - coefficient) * decision_value
        push!(seen, i)
    end
    for i in filter(i -> i ∉ seen, collect(1:MOI.output_dimension(f)))
        f.decision_part.constants[i] += change.new_coefficient * decision_value
    end
    # Update the decision coefficient
    modify_coefficients!(f.decision_part.terms, change.decision, change.new_coefficients)
    # Recalculate total constants and shift constraint set
    constants = f.variable_part.constants +
        f.decision_part.constants +
        f.known_part.constants
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            MOI.VectorAffineFunction(f.variable_part.terms, constants))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::VectorAffineDecisionConstraintBridge{T,S}, change::KnownCoefficientChange) where {T,S}
    f = bridge.decision_function
    # Query known value
    known_value = MOI.get(model, MOI.VariablePrimal(), change.known)
    seen = Int[]
    for i in findall(t -> t.scalar_term.variable_index == change.decision, f.known_part.terms)
        # Update known part of constraint constant
        coefficient = f.known_part.terms[i].scalar_term.coefficient
        f.known_part.constants[i] +=
            (change.new_coefficient - coefficient) * known_value
        push!(seen, i)
    end
    for i in filter(i -> i ∉ seen, collect(1:MOI.output_dimension(f)))
        f.known_part.constants[i] += change.new_coefficient * known_value
    end
    # Update the known decision coefficient
    modify_coefficients!(f.known_part.terms, change.known, change.new_coefficients)
    # Recalculate total constants and modify constraint function
    constants = f.variable_part.constants +
        f.decision_part.constants +
        f.known_part.constants
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            MOI.VectorAffineFunction(f.variable_part.terms, constants))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::VectorAffineDecisionConstraintBridge{T,S}, change::DecisionStateChange) where {T,S}
    f = bridge.decision_function
    # Switch on state transition
    new_coefficients = Vector{Tuple{Int64, T}}()
    if change.new_state == NotTaken
        for i in findall(t -> t.scalar_term.variable_index == change.decision, f.decision_part.terms)
            output_index = f.decision_part.terms[i].output_index
            coefficient = f.decision_part.terms[i].scalar_term.coefficient
            # Update fixed decision value
            change.value_difference < 0 ||
                error("Decision value update should be negative when transitioning to NotTaken state.")
            f.decision_part.constants[i] +=
                coefficient * change.value_difference
            # Modify bridge functions
            push!(f.variable_part.terms,
                  MOI.VectorAffineTerm(output_index,
                                       MOI.ScalarAffineTerm(coefficient, change.decision)))
            deleteat!(f.decision_part.terms, i)
            push!(new_coefficients, (output_index, coefficient))
        end
        # Modify the coefficients of the mapped variable
        MOI.modify(model, bridge.constraint,
                   MOI.MultirowChange(change.decision, new_coefficients))
    end
    if change.new_state == Taken
        for i in findall(t -> t.scalar_term.variable_index == change.decision, f.decision_part.terms)
            output_index = f.decision_part.terms[i].output_index
            coefficient = f.decision_part.terms[i].scalar_term.coefficient
            # Update fixed decision value
            f.decision_part.constants[i] +=
                coefficient * change.value_difference
            # Modify bridge functions
            deleteat!(f.variable_part.terms, i)
            push!(f.decision_part.terms,
                  MOI.VectorAffineTerm(output_index,
                                       MOI.ScalarAffineTerm(coefficient, change.decision)))
            push!(new_coefficients, (output_index, zero(T)))
        end
        # Modify the coefficients of the mapped variable
        MOI.modify(model, bridge.constraint,
                   MOI.MultirowChange(change.decision, new_coefficients))
    end
    # Recalculate total constants and modify constraint function
    constants = f.variable_part.constants +
        f.decision_part.constants +
        f.known_part.constants
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            MOI.VectorAffineFunction(f.variable_part.terms, constants))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::VectorAffineDecisionConstraintBridge{T}, ::DecisionsStateChange) where T
    f = bridge.decision_function
    unbridged_func = zero(VectorAffineDecisionFunction{T})
    variables_to_remove = Vector{Int}()
    decisions_to_remove = Vector{Int}()
    # First, unbridge the objective function and cache
    # all occuring decisions.
    for (i,term) in enumerate(f.decision_part.terms)
        unbridged = MOIB.unbridged_variable_function(model, term.scalar_term.variable_index)
        push!(decisions_to_remove, i)
        push!(unbridged_func.decision_part.terms,
              MOI.VectorAffineTerm(term.output_index,
                                   MOI.ScalarAffineTerm(term.scalar_term.coefficient, unbridged.variable)))
        # Check if a mapped variable exists and remove it as well if so
        for j in findall(t -> t.variable_index == term.scalar_term.variable_index, f.variable_part.terms)
            j != 0 && push!(variables_to_remove, j)
        end
    end
    # Remove terms that come from bridged decisions
    deleteat!(f.variable_part.terms, variables_to_remove)
    deleteat!(f.decision_part.terms, decisions_to_remove)
    # Reset decision constant
    f.decision_part.constant = zero(T)
    # Rebridge
    MOIU.operate!(+, T, f, MOIB.bridged_function(model, unbridged_func))
    # All decisions have been mapped to either the decision part constant
    # or the variable part terms at this point.
    # Recalculate total constants and update constraint function
    constants = f.variable_part.constants +
        f.decision_part.constants +
        f.known_part.constants
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            MOI.VectorAffineFunction(f.variable_part.terms, constants))
end

function MOI.modify(model::MOI.ModelLike, bridge::VectorAffineDecisionConstraintBridge{T,S}, change::KnownValueChange) where {T,S}
    f = bridge.decision_function
    seen = Int[]
    for i in findall(t -> t.scalar_term.variable_index == change.known, f.known_part.terms)
        # Update known part of constraint constant
        coefficient = f.decision_part.terms[i].scalar_term.coefficient
        f.known_part.constants[i] +=
            coefficient * change.value_difference
    end
    # Recalculate total constant and shift constraint set
    constant = f.variable_part.constant +
        f.decision_part.constant +
        f.known_part.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::VectorAffineDecisionConstraintBridge{T,S}, change::KnownValuesChange) where {T,S}
    f = bridge.decision_function
    known_vals = zeros(T, MOI.output_dimension(f))
    for term in f.known_part.terms
        i = term.output_index
        scalar_term = term.scalar_term
        known_vals[i] += scalar_term.coefficient * MOI.get(model, MOI.VariablePrimal(), scalar_term.variable_index)
    end
    # Update known part of objective
    f.known_part.constants .= known_vals
    # Recalculate total constants and modify constraint function
    constants = f.variable_part.constants +
        f.decision_part.constants +
        f.known_part.constants
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            MOI.VectorAffineFunction(f.variable_part.terms, constants))
    return nothing
end
