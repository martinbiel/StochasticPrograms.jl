# Quadratic decision function #
# ========================== #
struct QuadraticDecisionObjectiveBridge{T} <: MOIB.Objective.AbstractBridge
    decision_function::QuadraticDecisionFunction{T}
end

function MOIB.Objective.bridge_objective(::Type{QuadraticDecisionObjectiveBridge{T}}, model::MOI.ModelLike,
                                         f::QuadraticDecisionFunction{T}) where T
    # All decisions have been mapped to the variable part terms
    # at this point.
    F = MOI.ScalarQuadraticFunction{T}
    # Set the bridged objective
    MOI.set(model, MOI.ObjectiveFunction{F}(),
            MOI.ScalarQuadraticFunction(
                f.variable_part.affine_terms,
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
function MOIB.Objective.concrete_bridge_type(::Type{<:QuadraticDecisionObjectiveBridge{T}},
                                             ::Type{QuadraticDecisionFunction{T}}) where T
    return QuadraticDecisionObjectiveBridge{T}
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
                 attr::MOIB.ObjectiveFunctionValue{QuadraticDecisionFunction{T}},
                 bridge::QuadraticDecisionObjectiveBridge{T}) where T
    f = bridge.decision_function
    G = MOI.ScalarQuadraticFunction{T}
    obj_val = MOI.get(model, MOIB.ObjectiveFunctionValue{G}(attr.result_index))
    # Calculate and add constant
    constant = f.variable_part.constant +
        f.decision_part.constant
    return obj_val + f.variable_part.constant
end

function MOI.get(model::MOI.ModelLike,
                 attr::MOI.ObjectiveFunction{QuadraticDecisionFunction{T}},
                 bridge::QuadraticDecisionObjectiveBridge{T}) where T
    f = bridge.decision_function
    # Remove mapped variables to properly unbridge
    from_decision(v) = begin
        result = any(t -> t.variable_index == v,
                     f.decision_part.affine_terms)
        result |= any(t -> t.variable_index_1 == v || t.variable_index_2 == v,
                      f.decision_part.quadratic_terms)
        result |= any(t -> t.variable_index_1 == v,
                      f.cross_terms.affine_terms)
    end
    g = QuadraticDecisionFunction(
        MOIU.filter_variables(v -> !from_decision(v), f.variable_part),
        copy(f.decision_part),
        copy(f.cross_terms))
    return g
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T}, change::MOI.ScalarConstantChange) where T
    f = bridge.decision_function
    f = f.linear_quadratic_terms
    # Modify constant of variable part
    lq.variable_part.constant = change.new_constant
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
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::QuadraticDecisionObjectiveBridge{T}, change::DecisionCoefficientChange) where T
    f = bridge.decision_function
    variable_terms = f.variable_part.affine_terms
    decision_terms = f.decision_part.affine_terms
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
