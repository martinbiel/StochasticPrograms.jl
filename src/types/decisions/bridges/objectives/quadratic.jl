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
    return bridge.decision_function
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
    # Modify variable part of objective as usual
    F = MOI.ScalarQuadraticFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), change)
    return nothing
end
