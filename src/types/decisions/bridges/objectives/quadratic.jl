# Quadratic decision function #
# ========================== #
struct QuadraticDecisionObjectiveBridge{T} <: MOIB.Objective.AbstractBridge
    decision_function::QuadraticDecisionFunction{T}
end

function MOIB.Objective.bridge_objective(::Type{QuadraticDecisionObjectiveBridge{T}}, model::MOI.ModelLike,
                                         f::QuadraticDecisionFunction{T}) where T
    # All decisions have been mapped to either the decision part constant or the variable part terms
    # at this point.
    F = MOI.ScalarQuadraticFunction{T}
    # Set the bridged objective
    MOI.set(model, MOI.ObjectiveFunction{F}(),
            MOI.ScalarQuadraticFunction(f.variable_part.affine_terms,
                                        f.variable_part.quadratic_terms,
                                        zero(T)))
    # Save decision function to allow modifications
    return QuadraticDecisionObjectiveBridge{T}(f)
end

function MOIB.Objective.supports_objective_function(
    ::Type{<:QuadraticDecisionObjectiveBridge}, ::Type{<:QuadraticDecisionFunction})
    return true
end
MOIB.added_constrained_variable_types(::Type{<:QuadraticDecisionObjectiveBridge}) = Tuple{DataType}[]
function MOIB.added_constraint_types(::Type{<:QuadraticDecisionObjectiveBridge})
    return Tuple{DataType, DataType}[]
end
function MOIB.set_objective_function_type(::Type{QuadraticDecisionObjectiveBridge{T}}) where T
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
                 attr::MOIB.ObjectiveFunctionValue{F},
                 bridge::QuadraticDecisionObjectiveBridge{T}) where {T, F <: QuadraticDecisionFunction{T}}
    f = bridge.decision_function
    G = MOI.ScalarQuadraticFunction{T}
    obj_val = MOI.get(model, MOIB.ObjectiveFunctionValue{G}(attr.result_index))
    # Calculate and add constant
    constant = f.variable_part.constant +
        f.decision_part.constant +
        f.known_part.constant +
        f.known_decision_terms.constant
    return obj_val + constant
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ObjectiveFunction{F},
                 bridge::QuadraticDecisionObjectiveBridge{T}) where {T, F <: QuadraticDecisionFunction{T}}
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
        MOIU.filter_variables(v -> !from_decision(v), f.variable_part),
        copy(f.decision_part),
        copy(f.known_part),
        copy(f.cross_terms),
        copy(f.known_variable_terms),
        copy(f.known_decision_terms))
    return g
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T}, change::MOI.ScalarConstantChange) where T
    f = bridge.decision_function
    # Modify constant of variable part
    f.variable_part.constant = change.new_constant
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T}, change::MOI.ScalarCoefficientChange) where T
    f = bridge.decision_function
    # Update variable part
    modify_coefficient!(f.variable_part.affine_terms, change.variable, change.new_coefficient)
    # Modify decision part if variable originated from a decision
    i = something(findfirst(t -> t.variable_index == change.variable,
                            f.decision_part.affine_terms), 0)
    if !iszero(i)
        modify_coefficient!(f.decision_part.affine_terms, change.variable, change.new_coefficient)
    end
    # Complete rebridge required
    F = QuadraticDecisionFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), DecisionsStateChange())
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T}, change::DecisionCoefficientChange) where T
    f = bridge.decision_function
    # Update decision part
    modify_coefficient!(f.decision_part.affine_terms, change.decision, change.new_coefficient)
    # Complete rebridge required
    F = QuadraticDecisionFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), DecisionsStateChange())
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

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T}, ::DecisionStateChange) where T
    # Complete rebridge only option because quadratic coefficients cannot be modified
    F = QuadraticDecisionFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), DecisionsStateChange())
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T}, ::DecisionsStateChange) where T
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

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T}, change::KnownValuesChange) where T
    # f = bridge.decision_function
    # F = QuadraticDecisionFunction{T}
    # # Recalculate known constant
    # known_val = zero(T)
    # for term in f.known_part.affine_terms
    #     known_val += term.coefficient * MOI.get(model, MOI.VariablePrimal(), term.variable_index)
    # end
    # for term in f.known_part.quadratic_terms
    #     val_1 = MOI.get(model, MOI.VariablePrimal(), term.variable_index_1)
    #     val_2 = MOI.get(model, MOI.VariablePrimal(), term.variable_index_2)
    #     coeff = val_1 == val_2 ? term.coefficient / 2 : term.coefficient
    #     known_val += coeff * val_1 * val_2
    # end
    # cannot_modify = false
    # # Update known part of objective
    # f.known_part.constant = known_val
    # # Handle cross terms
    # for term in f.known_variable_terms.quadratic_terms
    #     coefficient = term.coefficient
    #     known_index = term.variable_index_1
    #     var_index = term.variable_index_2
    #     i = something(findfirst(t -> t.variable_index == var_index,
    #                             f.known_variable_terms.affine_terms), 0)
    #     old_coefficient = iszero(i) ? zero(T) : f.known_variable_terms.affine_terms[i].coefficient
    #     new_coefficient = coefficient * MOI.get(model, MOI.VariablePrimal(), known_index)
    #     # Update variable part
    #     j = something(findfirst(t -> t.variable_index == var_index,
    #                             f.variable_part.affine_terms), 0)
    #     if iszero(j) && !iszero(new_coefficient - old_coefficient)
    #         push!(f.variable_part.affine_terms,
    #               MOI.ScalarAffineTerm(new_coefficient - old_coefficient, var_index))
    #     else
    #         new_coeff = f.variable_part.affine_terms[j].coefficient +
    #             new_coefficient -
    #             old_coefficient
    #         if iszero(new_coeff)
    #             deleteat!(f.variable_part.affine_terms, j)
    #         else
    #             f.variable_part.affine_terms[j] =
    #                 MOI.ScalarAffineTerm(new_coeff, var_index)
    #         end
    #     end
    #     # Update cross term
    #     if iszero(i) && !iszero(new_coefficient)
    #         push!(f.known_variable_terms.affine_terms,
    #               MOI.ScalarAffineTerm(new_coefficient, var_index))
    #     else
    #         if iszero(new_coefficient)
    #             deleteat!(f.known_variable_terms.affine_terms, i)
    #         else
    #             f.known_variable_terms.affine_terms[i] =
    #                 MOI.ScalarAffineTerm(new_coefficient, var_index)
    #         end
    #     end
    # end
    # for term in f.known_decision_terms.quadratic_terms
    #     coefficient = term.coefficient
    #     known_index = term.variable_index_1
    #     dvar_index = term.variable_index_2
    #     i = something(findfirst(t -> t.variable_index == dvar_index,
    #                             f.known_decision_terms.affine_terms), 0)
    #     old_coefficient = iszero(i) ? zero(T) : f.known_decision_terms.affine_terms[i].coefficient
    #     new_coefficient = coefficient * MOI.get(model, MOI.VariablePrimal(), known_index)
    #     # Update cross term
    #     if iszero(i) && !iszero(new_coefficient)
    #         push!(f.known_decision_terms.affine_terms,
    #               MOI.ScalarAffineTerm(new_coefficient, dvar_index))
    #     else
    #         if iszero(new_coefficient)
    #             deleteat!(f.known_decision_terms.affine_terms, i)
    #         else
    #             f.known_decision_terms.affine_terms[i] =
    #                 MOI.ScalarAffineTerm(new_coefficient, dvar_index)
    #         end
    #     end
    # end
    # The objective must be rebridged to complete modification
    F = QuadraticDecisionFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), DecisionsStateChange())
    return nothing
end
