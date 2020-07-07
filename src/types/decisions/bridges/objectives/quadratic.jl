# Quadratic decision function #
# ========================== #
struct QuadraticDecisionObjectiveBridge{T, LQ} <: MOIB.Objective.AbstractBridge
    decision_function::QuadraticDecisionFunction{T, LQ}
end

function MOIB.Objective.bridge_objective(::Type{QuadraticDecisionObjectiveBridge{T,LQ}}, model::MOI.ModelLike,
                                         f::QuadraticDecisionFunction{T, LQ}) where {T, LQ <: LinearPart{T}}
    # All decisions have been mapped to either the decision part constant or the variable part terms
    # at this point.
    F = MOI.ScalarAffineFunction{T}
    lq = f.linear_quadratic_terms
    # Set the bridged objective
    MOI.set(model, MOI.ObjectiveFunction{F}(),
            MOI.ScalarAffineFunction(
                lq.variable_part.terms,
                zero(T)))
    # Save decision function to allow modifications
    return QuadraticDecisionObjectiveBridge{T, LQ}(f)
end

function MOIB.Objective.bridge_objective(::Type{QuadraticDecisionObjectiveBridge{T,LQ}}, model::MOI.ModelLike,
                                         f::QuadraticDecisionFunction{T, LQ}) where {T, LQ <: QuadraticPart{T}}
    # All decisions have been mapped to either the decision part constant or the variable part terms
    # at this point.
    F = MOI.ScalarQuadraticFunction{T}
    lq = f.linear_quadratic_terms
    # Set the bridged objective
    MOI.set(model, MOI.ObjectiveFunction{F}(),
            MOI.ScalarQuadraticFunction(
                lq.variable_part.affine_terms,
                lq.variable_part.quadratic_terms,
                zero(T)))
    # Save decision function to allow modifications
    return QuadraticDecisionObjectiveBridge{T, LQ}(f)
end

function MOIB.Objective.supports_objective_function(
    ::Type{<:QuadraticDecisionObjectiveBridge}, ::Type{<:QuadraticDecisionFunction})
    return true
end
MOIB.added_constrained_variable_types(::Type{<:QuadraticDecisionObjectiveBridge}) = Tuple{DataType}[]
function MOIB.added_constraint_types(::Type{<:QuadraticDecisionObjectiveBridge})
    return Tuple{DataType, DataType}[]
end
function MOIB.Objective.concrete_bridge_type(::Type{<:QuadraticDecisionObjectiveBridge{T}},
                                             ::Type{QuadraticDecisionFunction{T, LinearPart{T}}}) where T
    return QuadraticDecisionObjectiveBridge{T, LinearPart{T}}
end
function MOIB.Objective.concrete_bridge_type(::Type{<:QuadraticDecisionObjectiveBridge{T}},
                                             ::Type{QuadraticDecisionFunction{T, QuadraticPart{T}}}) where T
    return QuadraticDecisionObjectiveBridge{T, QuadraticPart{T}}
end
function MOIB.set_objective_function_type(::Type{QuadraticDecisionObjectiveBridge{T,LinearPart{T}}}) where T
    return MOI.ScalarAffineFunction{T}
end
function MOIB.set_objective_function_type(::Type{QuadraticDecisionObjectiveBridge{T,QuadraticPart{T}}}) where T
    return MOI.ScalarQuadraticFunction{T}
end

function MOI.get(::QuadraticDecisionObjectiveBridge, ::MOI.NumberOfVariables)
    return 0
end

function MOI.get(::QuadraticDecisionObjectiveBridge, ::MOI.ListOfVariableIndices)
    return MOI.VariableIndex[]
end


function MOI.delete(::MOI.ModelLike, ::QuadraticDecisionObjectiveBridge)
    # Nothing to delete
    return nothing
end

function MOI.set(::MOI.ModelLike, ::MOI.ObjectiveSense,
                 ::QuadraticDecisionObjectiveBridge, ::MOI.OptimizationSense)
    # Nothing to handle if sense changes
    return nothing
end

function MOI.get(model::MOI.ModelLike,
                 attr::MOIB.ObjectiveFunctionValue{QuadraticDecisionFunction{T, LinearPart{T}}},
                 bridge::QuadraticDecisionObjectiveBridge{T, LinearPart{T}}) where T
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    G = MOI.ScalarAffineFunction{T}
    obj_val = MOI.get(model, MOIB.ObjectiveFunctionValue{G}(attr.result_index))
    # Calculate and add constant
    constant = lq.variable_part.constant +
        lq.decision_part.constant +
        f.known_part.constant +
        f.known_decision_terms.constant
    return obj_val + constant
end

function MOI.get(model::MOI.ModelLike,
                 attr::MOIB.ObjectiveFunctionValue{QuadraticDecisionFunction{T, QuadraticPart{T}}},
                 bridge::QuadraticDecisionObjectiveBridge{T, QuadraticPart{T}}) where T
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    G = MOI.ScalarQuadraticFunction{T}
    obj_val = MOI.get(model, MOIB.ObjectiveFunctionValue{G}(attr.result_index))
    # Calculate and add constant
    constant = lq.variable_part.constant +
        lq.decision_part.constant +
        f.known_part.constant +
        f.known_decision_terms.constant
    return obj_val + constant
end

function MOI.get(model::MOI.ModelLike,
                 attr::MOI.ObjectiveFunction{QuadraticDecisionFunction{T, LinearPart{T}}},
                 bridge::QuadraticDecisionObjectiveBridge{T, LinearPart{T}}) where T
    f = bridge.decision_function
    # Remove mapped variables to properly unbridge
    from_decision(v) = begin
        result = any(t -> t.variable_index == v,
                     f.decision_part.affine_terms)
        result |= any(t -> t.variable_index_1 == v || t.variable_index_2 == v,
                      f.decision_part.quadratic_terms)
        result |= any(t -> t.variable_index_1 == v,
                      f.cross_terms.affine_terms)
        result |= any(t -> t.variable_index == v,
                      f.known_decision_terms.affine_terms)
    end
    g = QuadraticDecisionFunction(
        LinearPart(
            MOIU.filter_variables(v -> !from_decision(v), f.variable_part),
            copy(f.decision_part)),
        copy(f.known_part),
        copy(f.known_variable_terms),
        copy(f.known_decision_terms))
    return g
end

function MOI.get(model::MOI.ModelLike,
                 attr::MOI.ObjectiveFunction{QuadraticDecisionFunction{T, QuadraticPart{T}}},
                 bridge::QuadraticDecisionObjectiveBridge{T, QuadraticPart{T}}) where T
    f = bridge.decision_function
    # Remove mapped variables to properly unbridge
    from_decision(v) = begin
        result = any(t -> t.variable_index == v,
                     f.decision_part.affine_terms)
        result |= any(t -> t.variable_index_1 == v || t.variable_index_2 == v,
                      f.decision_part.quadratic_terms)
        result |= any(t -> t.variable_index_1 == v,
                      f.cross_terms.affine_terms)
        result |= any(t -> t.variable_index == v,
                      f.known_decision_terms.affine_terms)
    end
    g = QuadraticDecisionFunction(
        QuadraticPart(
            MOIU.filter_variables(v -> !from_decision(v), f.variable_part),
            copy(f.decision_part),
            copy(f.cross_terms)),
        copy(f.known_part),
        copy(f.known_variable_terms),
        copy(f.known_decision_terms))
    return g
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T}, change::MOI.ScalarConstantChange) where T
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    # Modify constant of variable part
    lq.variable_part.constant = change.new_constant
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T,LinearPart{T}}, change::MOI.ScalarCoefficientChange) where T
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
    # Modify the variable part of the objective as usual
    F = MOI.ScalarAffineFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), change)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T,QuadraticPart{T}}, change::MOI.ScalarCoefficientChange) where T
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
    F = QuadraticDecisionFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), DecisionsStateChange())
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T}, change::DecisionCoefficientChange) where T
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    variable_terms = lq isa LinearPart ? lq.variable_part.terms : lq.variable_part.affine_terms
    decision_terms = lq isa LinearPart ? lq.decision_part.terms : lq.decision_part.affine_terms
    # Check if decision has been mapped
    i = something(findfirst(t -> t.variable_index == change.decision,
                            variable_terms), 0)
    if !iszero(i)
        # Update mapped variable through ScalarCoefficientChange
        F = QuadraticDecisionFunction{T}
        MOI.modify(model, MOI.ObjectiveFunction{F}(),
                   MOI.ScalarCoefficientChange(change.decision, change.new_coefficient))
    else
        i = something(findfirst(t -> t.variable_index == change.decision,
                                decision_terms), 0)
        # Query the fixed decision value
        unbridged = MOIB.unbridged_variable_function(model, change.decision)::MOI.SingleVariable
        decision_value = MOI.get(model, MOI.VariablePrimal(), unbridged.variable)
        # Update decision part of objective constant
        coefficient = iszero(i) ? zero(T) : decision_terms[i].coefficient
        lq.decision_part.constant +=
            (change.new_coefficient - coefficient) * decision_value
    end
    # Update coefficient in decision part
    modify_coefficient!(decision_terms, change.decision, change.new_coefficient)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T}, change::KnownCoefficientChange) where T
    f = bridge.decision_function
    i = something(findfirst(t -> t.variable_index == change.known,
                            f.known_part.affine_terms), 0)
    # Update known part of objective constant
    coefficient = iszero(i) ? zero(T) : f.known_part.affine_terms[i].coefficient
    known_value = MOI.get(model, MOI.VariablePrimal(), change.known)
    f.known_part.constant +=
        (change.new_coefficient - coefficient) * known_value
    modify_coefficient!(f.known_part.affine_terms, change.known, change.new_coefficient)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T,LinearPart{T}}, ::DecisionStateChange) where T
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    F = MOI.ScalarAffineFunction{T}
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
            MOI.modify(model, MOI.ObjectiveFunction{F},
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
            MOI.modify(model, MOI.ObjectiveFunction{F},
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
            MOI.modify(model, MOI.ObjectiveFunction{F},
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
            MOI.modify(model, MOI.ObjectiveFunction{F},
                       MOI.ScalarCoefficientChange(change.decision, coefficient))
        end
    end
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T,QuadraticPart{T}}, ::DecisionStateChange) where T
    # Complete rebridge only option because quadratic coefficients cannot be modified
    F = QuadraticDecisionFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), DecisionsStateChange())
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T,LinearPart{T}}, ::DecisionsStateChange) where T
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    # Unbridge the objective function and cache
    # all occuring decisions.
    unbridged_func = zero(QuadraticDecisionFunction{T,LinearPart{T}})
    # Known/variable cross terms
    for (i, term) in enumerate(f.known_variable_terms.quadratic_terms)
        push!(unbridged_func.known_variable_terms.quadratic_terms, copy(term))
    end
    empty!(f.known_variable_terms.quadratic_terms)
    # Known/decision cross terms
    for (i, term) in enumerate(f.known_decision_terms.quadratic_terms)
        unbridged = MOIB.unbridged_variable_function(model, term.variable_index_2)
        push!(unbridged_func.known_decision_terms.quadratic_terms,
              MOI.ScalarQuadraticTerm(term.coefficient,
                                      term.variable_index_1,
                                      unbridged.variable))
    end
    # Affine terms
    for (i,term) in enumerate(lq.decision_part.terms)
        unbridged = MOIB.unbridged_variable_function(model, term.variable_index)
        push!(unbridged_func.linear_quadratic_terms.decision_part.terms,
              MOI.ScalarAffineTerm(term.coefficient, unbridged.variable))
    end
    empty!(lq.decision_part.affine_terms)
    # Rebridge objective
    F = QuadraticDecisionFunction{T}
    MOI.set(model, MOI.ObjectiveFunction{F}(), unbridged_func)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T,QuadraticPart{T}}, ::DecisionsStateChange) where T
    f = bridge.decision_function
    # Remove mapped variables to properly unbridge
    from_decision(v) = begin
        result = any(t -> t.variable_index == v,
                     f.decision_part.affine_terms)
        result |= any(t -> t.variable_index_1 == v || t.variable_index_2 == v,
                      f.decision_part.quadratic_terms)
        result |= any(t -> t.variable_index_1 == v,
                      f.cross_terms.quadratic_terms)
    end
    # Unbridge the objective function and cache
    # all occuring decisions.
    unbridged_func = QuadraticDecisionFunction(
        MOIU.filter_variables(v -> !from_decision(v), f.variable_part),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        copy(f.known_part),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        copy(f.known_variable_terms),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
    # Affine terms
    unbridged_affine_terms = map(f.decision_part.affine_terms) do term
        unbridged = MOIB.unbridged_variable_function(model, term.variable_index)
        MOI.ScalarAffineTerm(term.coefficient, unbridged.variable)
    end
    append!(unbridged_func.decision_part.affine_terms, unbridged_affine_terms)
    # Quadratic terms
    unbridged_quad_terms = map(f.decision_part.quadratic_terms) do term
        unbridged_1 = MOIB.unbridged_variable_function(model, term.variable_index_1)
        unbridged_2 = MOIB.unbridged_variable_function(model, term.variable_index_2)
        MOI.ScalarQuadraticTerm(term.coefficient, unbridged_1.variable, unbridged_2.variable)
    end
    append!(unbridged_func.decision_part.quadratic_terms, unbridged_quad_terms)
    # Cross terms
    for term in f.cross_terms.affine_terms
        # Subtract any added variable/decision cross terms
        remove_term!(unbridged_func.variable_part.affine_terms, term)
    end
    # Add unbridged decision/variable cross terms for rebridge
    unbridged_cross_terms = map(f.cross_terms.quadratic_terms) do term
        unbridged = MOIB.unbridged_variable_function(model, term.variable_index_1)
        MOI.ScalarQuadraticTerm(term.coefficient, unbridged.variable, term.variable_index_2)
    end
    append!(unbridged_func.cross_terms.quadratic_terms, unbridged_cross_terms)
    # Known/variable cross terms
    for term in f.known_variable_terms.affine_terms
        # Subtract any added variable/decision cross terms
        remove_term!(unbridged_func.variable_part.affine_terms, term)
    end
    # Known/decision cross terms
    unbridged_known_decision_affine_terms = map(f.known_decision_terms.affine_terms) do term
        # Add unbridged decision/variable cross terms for rebridge
        unbridged = MOIB.unbridged_variable_function(model, term.variable_index)
        MOI.ScalarAffineTerm(term.coefficient, unbridged.variable)
    end
    append!(unbridged_func.known_decision_terms.affine_terms, unbridged_known_decision_affine_terms)
    # Add unbridged known/decision cross terms for rebridge
    unbridged_known_decision_quadratic_terms = map(f.known_decision_terms.quadratic_terms) do term
        unbridged = MOIB.unbridged_variable_function(model, term.variable_index_2)
        MOI.ScalarQuadraticTerm(term.coefficient, term.variable_index_1, unbridged.variable)
    end
    append!(unbridged_func.known_decision_terms.quadratic_terms, unbridged_known_decision_quadratic_terms)
    # Rebridge objective
    F = QuadraticDecisionFunction{T}
    MOI.set(model, MOI.ObjectiveFunction{F}(), unbridged_func)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T}, ::KnownValueChange) where T
    # Complete rebridge only option because quadratic coefficients cannot be modified
    F = QuadraticDecisionFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), DecisionsStateChange())
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T,LinearPart{T}}, change::KnownValuesChange) where T
    f = bridge.decision_function
    lq = f.linear_quadratic_terms
    F = MOI.ScalarAffineFunction{T}
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
        MOI.modify(model, MOI.ObjectiveFunction{F},
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
        MOIB.modify_bridged_change(model, MOI.ObjectiveFunction{F},
                                   DecisionCoefficientChange(unbridged.variable, coefficient))
    end
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T,QuadraticPart{T}}, change::KnownValuesChange) where T
    # The objective must be rebridged to complete modification
    F = QuadraticDecisionFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), DecisionsStateChange())
    return nothing
end
