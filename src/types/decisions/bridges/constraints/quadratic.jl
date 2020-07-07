# Quadratic decision function #
# ========================== #
mutable struct QuadraticDecisionConstraintBridge{T, S, F, LQ} <: MOIB.Constraint.AbstractBridge
    constraint::CI{F, S}
    decision_function::QuadraticDecisionFunction{T, LQ}
    set::S
end

function MOIB.Constraint.bridge_constraint(::Type{QuadraticDecisionConstraintBridge{T,S,F,LQ}},
                                           model,
                                           f::QuadraticDecisionFunction{T, LQ},
                                           set::S) where {T, S, F <: MOI.ScalarAffineFunction{T}, LQ <: LinearPart{T}}
    # All decisions have been mapped to either the decision part constant
    # or the variable part terms at this point
    lq = f.linear_quadratic_terms
    # Calculate total constant
    constant = lq.variable_part.constant +
        lq.decision_part.constant +
        f.known_part.constant +
        f.known_decision_terms.constant
    # Add the bridged constraint
    constraint = MOI.add_constraint(model,
                                    MOI.ScalarAffineFunction(
                                        lq.variable_part.terms,
                                        zero(T)),
                                    MOIU.shift_constant(set, -constant))
    # Save the constraint index, the decision function, and the set, to allow modifications
    return QuadraticDecisionConstraintBridge{T, S, F, LQ}(constraint, f, set)
end

function MOIB.Constraint.bridge_constraint(::Type{QuadraticDecisionConstraintBridge{T,S,F,LQ}},
                                           model,
                                           f::QuadraticDecisionFunction{T, LQ},
                                           set::S) where {T, S, F <: MOI.ScalarQuadraticFunction{T}, LQ <: QuadraticPart{T}}
    # All decisions have been mapped to either the decision part constant
    # or the variable part terms at this point
    lq = f.linear_quadratic_terms
    # Calculate total constant
    constant = lq.variable_part.constant +
        lq.decision_part.constant +
        f.known_part.constant +
        f.known_decision_terms.constant
    # Add the bridged constraint
    constraint = MOI.add_constraint(model,
                                    MOI.ScalarQuadraticFunction(
                                        lq.variable_part.affine_terms,
                                        lq.variable_part.quadratic_terms,
                                        zero(T)),
                                    MOIU.shift_constant(set, -constant))
    # Save the constraint index, the decision function, and the set, to allow modifications
    return QuadraticDecisionConstraintBridge{T, S, F, LQ}(constraint, f, set)
end

function MOI.supports_constraint(::Type{<:QuadraticDecisionConstraintBridge{T}},
                                 ::Type{<:QuadraticDecisionFunction{T}},
                                 ::Type{<:MOI.AbstractScalarSet}) where T
    return true
end
function MOIB.added_constrained_variable_types(::Type{<:QuadraticDecisionConstraintBridge})
    return Tuple{DataType}[]
end
function MOIB.added_constraint_types(::Type{QuadraticDecisionConstraintBridge{T, S, F, LQ}}) where {T, S, F, LQ}
    return [(F, S)]
end
function MOIB.Constraint.concrete_bridge_type(::Type{<:QuadraticDecisionConstraintBridge{T}},
                                              ::Type{QuadraticDecisionFunction{T, LinearPart{T}}},
                                              S::Type{<:MOI.AbstractScalarSet}) where T
    return QuadraticDecisionConstraintBridge{T, S, MOI.ScalarAffineFunction{T}, LinearPart{T}}
end
function MOIB.Constraint.concrete_bridge_type(::Type{<:QuadraticDecisionConstraintBridge{T}},
                                              ::Type{QuadraticDecisionFunction{T, QuadraticPart{T}}},
                                              S::Type{<:MOI.AbstractScalarSet}) where T
    return QuadraticDecisionConstraintBridge{T, S, MOI.ScalarQuadraticFunction{T}, QuadraticPart{T}}
end

MOI.get(b::QuadraticDecisionConstraintBridge{T, S, F}, ::MOI.NumberOfConstraints{F, S}) where {T, S, F} = 1
MOI.get(b::QuadraticDecisionConstraintBridge{T, S, F}, ::MOI.ListOfConstraintIndices{F, S}) where {T, S, F} = [b.constraint]

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintFunction,
                 bridge::QuadraticDecisionConstraintBridge{T,S,MOI.ScalarAffineFunction{T}}) where {T,S}
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    # Remove mapped variables to properly unbridge
    from_decision(v) = begin
        result = any(t -> t.variable_index == v,
                     lq.decision_part.terms)
        result |= any(t -> t.variable_index == v,
                      f.known_decision_terms.affine_terms)
    end
    g = QuadraticDecisionFunction(
        LinearPart(
            MOIU.filter_variables(v -> !from_decision(v), lq.variable_part),
            copy(lq.decision_part)),
        copy(f.known_part),
        copy(f.known_variable_terms),
        copy(f.known_decision_terms))
    return g
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintFunction,
                 bridge::QuadraticDecisionConstraintBridge{T,S,MOI.ScalarQuadraticFunction{T}}) where {T,S}
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    # Remove mapped variables to properly unbridge
    from_decision(v) = begin
        result = any(t -> t.variable_index == v,
                     lq.decision_part.affine_terms)
        result |= any(t -> t.variable_index_1 == v || t.variable_index_2 == v,
                      lq.decision_part.quadratic_terms)
        result |= any(t -> t.variable_index_1 == v,
                      lq.cross_terms.affine_terms)
        result |= any(t -> t.variable_index == v,
                      f.known_decision_terms.affine_terms)
    end
    g = QuadraticDecisionFunction(
        QuadraticPart(
            MOIU.filter_variables(v -> !from_decision(v), lq.variable_part),
            copy(lq.decision_part),
            copy(lq.cross_terms)),
        copy(f.known_part),
        copy(f.known_variable_terms),
        copy(f.known_decision_terms))
    return g
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::QuadraticDecisionConstraintBridge{T,S}) where {T,S}
    return bridge.set
end

function MOI.get(model::MOI.ModelLike, attr::Union{MOI.ConstraintPrimal, MOI.ConstraintDual},
                 bridge::QuadraticDecisionConstraintBridge{T,S}) where {T,S}
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.delete(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge)
    MOI.delete(model, bridge.constraint)
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintFunction,
                 bridge::QuadraticDecisionConstraintBridge{T,S,F,LinearPart{T}},
                 f::QuadraticDecisionFunction{T,LinearPart{T}}) where {T,S,F}
    # Update bridge functions and function constant
    bridge.decision_function = f
    lq = f.linear_quadratic_terms
    # Change the function of the bridged constraints
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            MOI.ScalarAffineFunction(
                lq.variable_part.terms,
                zero(T)))
    # Recalculate total constant and shift constraint set
    constant = lq.variable_part.constant +
        lq.decision_part.constant +
        f.known_part.constant +
        f.known_decision_terms.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintFunction,
                 bridge::QuadraticDecisionConstraintBridge{T,S,F,QuadraticPart{T}},
                 f::QuadraticDecisionFunction{T,QuadraticPart{T}}) where {T,S,F}
    # Update bridge functions and function constant
    bridge.decision_function = f
    lq = f.linear_quadratic_terms
    # Change the function of the bridged constraints
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            MOI.ScalarQuadraticFunction(
                lq.variable_part.affine_terms,
                lq.variable_part.quadratic_terms,
                zero(T)))
    # Recalculate total constant and shift constraint set
    constant = lq.variable_part.constant +
        lq.decision_part.constant +
        f.known_part.constant +
        f.known_decision_terms.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::QuadraticDecisionConstraintBridge{T,S}, change::S) where {T,S}
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    bridge.set = change
    # Recalculate total constant and shift constraint set
    constant = lq.variable_part.constant +
        lq.decision_part.constant +
        f.known_part.constant +
        f.known_decision_terms.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge{T,S}, change::MOI.ScalarConstantChange) where {T,S}
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    # Modify constant of variable part
    lq.variable_part.constant = change.new_constant
    # Recalculate total constant and shift constraint set
    constant = lq.variable_part.constant +
        lq.decision_part.constant +
        f.known_part.constant +
        f.known_decision_terms.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge{T,S,MOI.ScalarAffineFunction{T}}, change::MOI.ScalarCoefficientChange) where {T,S}
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    # Update coefficient in variable part
    modify_coefficient!(lq.variable_part.terms, change.variable, change.new_coefficient)
    # Modify decision part if variable originated from a decision
    i = something(findfirst(t -> t.variable_index == change.variable,
                            lq.decision_part.terms), 0)
    if !iszero(i)
        modify_coefficient!(lq.decision_part.terms, change.variable, change.new_coefficient)
    end
    # Modify the variable part of the constraint as usual
    MOI.modify(model, bridge.constraint, change)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge{T,S,MOI.ScalarQuadraticFunction{T}}, change::MOI.ScalarCoefficientChange) where {T,S}
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    # Update variable part
    modify_coefficient!(lq.variable_part.affine_terms, change.variable, change.new_coefficient)
    # Modify decision part if variable originated from a decision
    i = something(findfirst(t -> t.variable_index == change.variable,
                            lq.decision_part.affine_terms), 0)
    if !iszero(i)
        modify_coefficient!(lq.decision_part.affine_terms, change.variable, change.new_coefficient)
    end
    # Complete rebridge required
    MOI.modify(model, bridge.constraint, DecisionsStateChange())
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge{T,S}, change::DecisionCoefficientChange) where {T,S}
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    variable_terms = lq isa LinearPart ? lq.variable_part.terms : lq.variable_part.affine_terms
    decision_terms = lq isa LinearPart ? lq.decision_part.terms : lq.decision_part.affine_terms
    # Check if decision has been mapped
    i = something(findfirst(t -> t.variable_index == change.decision,
                            variable_terms), 0)
    if !iszero(i)
        # Update mapped variable through ScalarCoefficientChange
        MOI.modify(model, bridge, MOI.ScalarCoefficientChange(change.decision, change.new_coefficient))
    else
        i = something(findfirst(t -> t.variable_index == change.decision,
                                decision_terms), 0)
        # Query the fixed decision value
        unbridged = MOIB.unbridged_variable_function(model, change.decision)::MOI.SingleVariable
        decision_value = MOI.get(model, MOI.VariablePrimal(), unbridged.variable)
        # Update decision part of constraint constant
        coefficient = iszero(i) ? zero(T) : decision_terms[i].coefficient
        lq.decision_part.constant +=
            (change.new_coefficient - coefficient) * decision_value
        # Recalculate total constant and shift constraint set
        constant = lq.variable_part.constant +
            lq.decision_part.constant +
            f.known_part.constant +
            f.known_decision_terms.constant
        MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
                MOIU.shift_constant(bridge.set, -constant))
    end
    # Update coefficient in decision part
    modify_coefficient!(decision_terms, change.decision, change.new_coefficient)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge{T,S}, change::KnownCoefficientChange) where {T,S}
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    i = something(findfirst(t -> t.variable_index == change.known,
                            f.known_part.affine_terms), 0)
    # Update known part of objective constant
    coefficient = iszero(i) ? zero(T) : f.known_part.affine_terms[i].coefficient
    known_value = MOI.get(model, MOI.VariablePrimal(), change.known)
    f.known_part.constant +=
        (change.new_coefficient - coefficient) * known_value
    # Update coefficient in known part
    modify_coefficient!(f.known_part.affine_terms, change.known, change.new_coefficient)
    # Recalculate total constant and shift constraint set
    constant = lq.variable_part.constant +
        lq.decision_part.constant +
        f.known_part.constant +
        f.known_decision_terms.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge{T,S,MOI.ScalarAffineFunction{T}}, ::DecisionStateChange) where {T, S}
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    # Switch on state transition
    if change.new_state == NotTaken
        # Check if decision is included in the decision part
        i = something(findfirst(t -> t.variable_index == change.decision,
                                lq.decision_part.terms), 0)
        if !iszero(i)
            # Get the decision coefficient
            coefficient = lq.decision_part.terms[i].coefficient
            # Update fixed decision value
            change.value_difference < 0 ||
                error("Decision value update should be negative when transitioning to NotTaken state.")
            lq.decision_part.constant +=
                coefficient * change.value_difference
            # Modify variable part
            push!(lq.variable_part.terms,
                  MOI.ScalarAffineTerm(coefficient, change.decision))
            # Modify the coefficient of the mapped variable
            MOI.modify(model, bridge.constraint,
                       MOI.ScalarCoefficientChange(change.decision, coefficient))
        end
        # Check if decision is included in the known decision part
        i = something(findfirst(t -> t.variable_index == change.decision,
                                f.known_decision_terms.affine_terms), 0)
        if !iszero(i)
            # Get the decision coefficient
            coefficient = f.known_decision_terms.affine_terms[i].coefficient
            # Update fixed decision value
            change.value_difference < 0 ||
                error("Decision value update should be negative when transitioning to NotTaken state.")
            f.known_decision_terms.constant +=
                coefficient * change.value_difference
            # Modify variable part
            add_term!(lq.variable_part.terms,
                      MOI.ScalarAffineTerm(coefficient, change.decision))
            # Get current coefficient in variable part
            i = something(findfirst(t -> t.variable_index == change.decision,
                                    lq.variable_part.terms), 0)
            coefficient = iszero(i) ? zero(T) : lq.variable_part.terms[i].coefficient
            # Modify the coefficient of the mapped variable
            MOI.modify(model, bridge.constraint,
                       MOI.ScalarCoefficientChange(change.decision, coefficient))
        end
    end
    if change.new_state == Taken
        # Check if decision is included in the decision part
        i = something(findfirst(t -> t.variable_index == change.decision,
                                lq.decision_part.terms), 0)
        if !iszero(i)
            # Update fixed decision value
            coefficient = lq.variable_part.terms[i].coefficient
            lq.decision_part.constant +=
                coefficient * change.value_difference
            # Modify variable part
            i = something(findfirst(t -> t.variable_index == change.decision,
                                lq.variable_part.terms), 0)
            !iszero(i) && deleteat!(lq.variable_part.terms, i)
            # Modify the coefficient of the mapped variable
            MOI.modify(model, bridge.constraint,
                       MOI.ScalarCoefficientChange(change.decision, zero(T)))
        end
        # Check if decision is included in the known decision part
        i = something(findfirst(t -> t.variable_index == change.decision,
                                f.known_decision_terms.affine_terms), 0)
        if !iszero(i)
            # Get the decision coefficient
            coefficient = f.known_decision_terms.affine_terms[i].coefficient
            # Update fixed decision value
            f.known_decision_terms.constant +=
                coefficient * change.value_difference
            # Modify variable part
            remove_term!(lq.variable_part.terms,
                         MOI.ScalarAffineTerm(coefficient, change.decision))
            # Get current coefficient in variable part
            i = something(findfirst(t -> t.variable_index == change.decision,
                                    lq.variable_part.terms), 0)
            coefficient = iszero(i) ? zero(T) : lq.variable_part.terms[i].coefficient
            # Modify the coefficient of the mapped variable
            MOI.modify(model, bridge.constraint,
                       MOI.ScalarCoefficientChange(change.decision, coefficient))
        end
    end
    # Recalculate total constant and shift constraint set
    constant = lq.variable_part.constant +
        lq.decision_part.constant +
        f.known_part.constant +
        f.known_decision_terms.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge{T,S,MOI.ScalarQuadraticFunction{T}}, ::DecisionStateChange) where {T, S}
    # Complete rebridge only option because quadratic coefficients cannot be modified
    F = QuadraticDecisionFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), DecisionsStateChange())
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge{T,S,MOI.ScalarAffineFunction{T}}, ::DecisionsStateChange) where {T, S}
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    # Unbridge the constraint function and cache
    # all occuring decisions.
    unbridged_func = zero(QuadraticDecisionFunction{T,LinearPart{T}})
    variables_to_remove = Vector{Int}()
    # Known/variable cross terms
    for term in f.known_variable_terms.affine_terms
        # Subtract any added variable/decision cross terms
        remove_term!(lq.variable_part.terms, term)
    end
    empty!(f.known_variable_terms.affine_terms)
    for (i, term) in enumerate(f.known_variable_terms.quadratic_terms)
        push!(unbridged_func.known_variable_terms.quadratic_terms, copy(term))
    end
    empty!(f.known_variable_terms.quadratic_terms)
    # Known/decision cross terms
    for term in f.known_decision_terms.affine_terms
        # Subtract any added variable/decision cross terms
        remove_term!(lq.variable_part.terms, term)
        remove_term!(lq.decision_part.terms, term)
    end
    empty!(f.known_decision_terms.affine_terms)
    for (i, term) in enumerate(f.known_decision_terms.quadratic_terms)
        unbridged = MOIB.unbridged_variable_function(model, term.variable_index_2)
        push!(unbridged_func.known_decision_terms.quadratic_terms,
              MOI.ScalarQuadraticTerm(term.coefficient,
                                      term.variable_index_1,
                                      unbridged.variable))
    end
    empty!(f.known_decision_terms.quadratic_terms)
    # Affine terms
    for (i,term) in enumerate(lq.decision_part.terms)
        unbridged = MOIB.unbridged_variable_function(model, term.variable_index)
        push!(unbridged_func.linear_quadratic_terms.decision_part.terms,
              MOI.ScalarAffineTerm(term.coefficient, unbridged.variable))
        # Check if a mapped variable exists and remove it as well if so
        j = something(findfirst(t -> t.variable_index == term.variable_index,
                                lq.variable_part.terms), 0)
        j != 0 && push!(variables_to_remove, j)
    end
    empty!(lq.decision_part.affine_terms)
    # Remove terms that come from bridged decisions
    deleteat!(f.variable_part.affine_terms, variables_to_remove)
    # Reset constants
    f.decision_part.constant = zero(T)
    f.known_decision_terms.constant = zero(T)
    # Rebridge
    MOIU.operate!(+, T, f, MOIB.bridged_function(model, unbridged_func))
    # All decisions have been mapped to either the decision part constant
    # or the variable part terms at this point.
    # Delete previous constraint
    MOI.delete(model, bridge.constraint)
    # Recalculate total constant and readd constraint
    constant = lq.variable_part.constant +
        lq.decision_part.constant +
        f.known_part.constant +
        f.known_decision_terms.constant
    bridge.constraint = MOI.add_constraint(model,
                                           MOI.ScalarQuadraticFunction(
                                               lq.variable_part.affine_terms,
                                               lq.variable_part.quadratic_terms,
                                               zero(T)),
                                           MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge{T,S,MOI.ScalarQuadraticFunction{T}}, ::DecisionsStateChange) where {T, S}
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    # Unbridge the constraint function and cache
    # all occuring decisions.
    unbridged_func = zero(QuadraticDecisionFunction{T,QuadraticPart{T}})
    aff_variables_to_remove = Vector{Int}()
    quad_variables_to_remove = Vector{Int}()
    # Cross terms
    for (i,term) in enumerate(lq.cross_terms.affine_terms)
        # Subtract any added variable/decision cross terms
        remove_term!(lq.variable_part.affine_terms, term)
    end
    empty!(lq.cross_terms.affine_terms)
    for (i, term) in enumerate(lq.cross_terms.quadratic_terms)
        unbridged = MOIB.unbridged_variable_function(model, term.variable_index_1)
        push!(unbridged_func.linear_quadratic_terms.cross_terms.quadratic_terms,
              MOI.ScalarQuadraticTerm(term.coefficient,
                                      unbridged.variable,
                                      term.variable_index_2))
        # Check if a mapped variable exists and remove it as well if so
        j = something(findfirst(t -> t.variable_index_2 == term.variable_index_2,
                                lq.variable_part.quadratic_terms), 0)
        j != 0 && push!(quad_variables_to_remove, j)
    end
    empty!(lq.cross_terms.quadratic_terms)
    # Known/variable cross terms
    for term in f.known_variable_terms.affine_terms
        # Subtract any added variable/decision cross terms
        remove_term!(lq.variable_part.affine_terms, term)
    end
    empty!(f.known_variable_terms.affine_terms)
    for (i, term) in enumerate(f.known_variable_terms.quadratic_terms)
        push!(unbridged_func.known_variable_terms.quadratic_terms, copy(term))
    end
    empty!(f.known_variable_terms.quadratic_terms)
    # Known/decision cross terms
    for term in f.known_decision_terms.affine_terms
        # Subtract any added variable/decision cross terms
        remove_term!(lq.variable_part.affine_terms, term)
        remove_term!(lq.decision_part.affine_terms, term)
    end
    empty!(f.known_decision_terms.affine_terms)
    for (i, term) in enumerate(f.known_decision_terms.quadratic_terms)
        unbridged = MOIB.unbridged_variable_function(model, term.variable_index_2)
        push!(unbridged_func.known_decision_terms.quadratic_terms,
              MOI.ScalarQuadraticTerm(term.coefficient,
                                      term.variable_index_1,
                                      unbridged.variable))
    end
    empty!(f.known_decision_terms.quadratic_terms)
    # Affine decision terms
    for (i,term) in enumerate(lq.decision_part.affine_terms)
        unbridged = MOIB.unbridged_variable_function(model, term.variable_index)
        push!(unbridged_func.linear_quadratic_terms.decision_part.affine_terms,
              MOI.ScalarAffineTerm(term.coefficient, unbridged.variable))
        # Check if a mapped variable exists and remove it as well if so
        j = something(findfirst(t -> t.variable_index == term.variable_index,
                                lq.variable_part.affine_terms), 0)
        j != 0 && push!(aff_variables_to_remove, j)
    end
    empty!(lq.decision_part.affine_terms)
    # Quadratic decision terms
    for (i,term) in enumerate(lq.decision_part.quadratic_terms)
        unbridged_1 = MOIB.unbridged_variable_function(model, term.variable_index_1)
        unbridged_2 = MOIB.unbridged_variable_function(model, term.variable_index_2)
        push!(unbridged_func.linear_quadratic_terms.decision_part.quadratic_terms,
              MOI.ScalarQuadraticTerm(term.coefficient,
                                      unbridged_1.variable,
                                      unbridged_2.variable))
        # Check if a mapped variable exists and remove it as well if so
        j = something(findfirst(t -> t.variable_index_1 == term.variable_index_1 ||
                                t.variable_index_2 == term.variable_index_2,
                                lq.variable_part.quadratic_terms), 0)
        j != 0 && push!(quad_variables_to_remove, j)
    end
    empty!(lq.decision_part.quadratic_terms)
    # Remove terms that come from bridged decisions
    deleteat!(lq.variable_part.affine_terms, aff_variables_to_remove)
    deleteat!(lq.variable_part.quadratic_terms, quad_variables_to_remove)
    # Reset constants
    lq.decision_part.constant = zero(T)
    f.known_decision_terms.constant = zero(T)
    # Rebridge
    MOIU.operate!(+, T, f, MOIB.bridged_function(model, unbridged_func))
    # All decisions have been mapped to either the decision part constant
    # or the variable part terms at this point.
    # Delete previous constraint
    MOI.delete(model, bridge.constraint)
    # Recalculate total constant and readd constraint
    constant = lq.variable_part.constant +
        lq.decision_part.constant +
        f.known_part.constant +
        f.known_decision_terms.constant
    bridge.constraint = MOI.add_constraint(model,
                                           MOI.ScalarQuadraticFunction(
                                               lq.variable_part.affine_terms,
                                               lq.variable_part.quadratic_terms,
                                               zero(T)),
                                           MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge{T}, ::KnownValueChange) where T
    # Complete rebridge only option because quadratic coefficients cannot be modified
    F = QuadraticDecisionFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), DecisionsStateChange())
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge{T,S,MOI.ScalarAffineFunction{T}}, change::KnownValuesChange) where {T, S}
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    F = QuadraticDecisionFunction{T}
    # Recalculate known constant
    known_val = zero(T)
    for term in f.known_part.affine_terms
        known_val += term.coefficient * MOI.get(model, MOI.VariablePrimal(), term.variable_index)
    end
    for term in f.known_part.quadratic_terms
        val_1 = MOI.get(model, MOI.VariablePrimal(), term.variable_index_1)
        val_2 = MOI.get(model, MOI.VariablePrimal(), term.variable_index_2)
        coeff = val_1 == val_2 ? term.coefficient / 2 : term.coefficient
        known_val += coeff * val_1 * val_2
    end
    # Update known part of objective
    f.known_part.constant = known_val
    # Handle cross terms
    for term in f.known_variable_terms.quadratic_terms
        coefficient = term.coefficient
        known_index = term.variable_index_1
        var_index = term.variable_index_2
        i = something(findfirst(t -> t.variable_index == var_index,
                                f.known_variable_terms.affine_terms), 0)
        old_coefficient = iszero(i) ? zero(T) : f.known_variable_terms.affine_terms[i].coefficient
        new_coefficient = coefficient * MOI.get(model, MOI.VariablePrimal(), known_index)
        # Update cross term
        add_term!(f.known_variable_terms.affine_terms,
                  MOI.ScalarAffineTerm(new_coefficient - old_coefficient, var_index))
        # Update variable part
        add_term!(lq.variable_part.terms,
                  MOI.ScalarAffineTerm(new_coefficient - old_coefficient, var_index))
        # Get current coefficient in variable part
        i = something(findfirst(t -> t.variable_index == var_index,
                                lq.variable_part.terms), 0)
        coefficient = iszero(i) ? zero(T) : lq.variable_part.terms[i].coefficient
        # Modify the coefficient of the mapped variable
        MOI.modify(model, bridge.constraint,
                   MOI.ScalarCoefficientChange(var_index, coefficient))
    end
    for term in f.known_decision_terms.quadratic_terms
        coefficient = term.coefficient
        known_index = term.variable_index_1
        dvar_index = term.variable_index_2
        i = something(findfirst(t -> t.variable_index == dvar_index,
                                f.known_decision_terms.affine_terms), 0)
        old_coefficient = iszero(i) ? zero(T) : f.known_decision_terms.affine_terms[i].coefficient
        new_coefficient = coefficient * MOI.get(model, MOI.VariablePrimal(), known_index)
        # Update cross term
        add_term!(f.known_decision_terms.affine_terms,
                  MOI.ScalarAffineTerm(new_coefficient - old_coefficient, dvar_index))
        # Update decision part
        add_term!(lq.decision_part.terms,
                  MOI.ScalarAffineTerm(new_coefficient - old_coefficient, dvar_index))
        # Get current coefficient in decision part
        i = something(findfirst(t -> t.variable_index == dvar_index,
                                lq.decision_part.terms), 0)
        coefficient = iszero(i) ? zero(T) : lq.decision_part.terms[i].coefficient
        # Proper decision modification
        unbridged = MOIB.unbridged_variable_function(model, dvar_index)::MOI.SingleVariable
        MOIB.modify_bridged_change(model, bridge,
                                   DecisionCoefficientChange(unbridged.variable, coefficient))
    end
    # Recalculate total constant and shift constraint set
    constant = lq.variable_part.constant +
        lq.decision_part.constant +
        f.known_part.constant +
        f.known_decision_terms.constant
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint,
            MOIU.shift_constant(bridge.set, -constant))
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionConstraintBridge{T,S,MOI.ScalarQuadraticFunction{T}}, change::KnownValuesChange) where {T, S}
    # Complete rebridge only option because quadratic coefficients cannot be modified
    MOI.modify(model, bridge, DecisionsStateChange())
    return nothing
end
