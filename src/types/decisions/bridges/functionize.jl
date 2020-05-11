# Objective #
# ========================== #
struct FunctionizeDecisionObjectiveBridge{T} <: MOIB.Objective.AbstractBridge end

function MOIB.Objective.bridge_objective(::Type{FunctionizeDecisionObjectiveBridge{T}}, model::MOI.ModelLike,
                                         f::SingleDecision) where T
    F = AffineDecisionFunction{T}
    MOI.set(model, MOI.ObjectiveFunction{F}(), convert(F, f))
    return FunctionizeDecisionObjectiveBridge{T}()
end

function MOIB.Objective.supports_objective_function(
    ::Type{<:FunctionizeDecisionObjectiveBridge}, ::Type{SingleDecision})
    return true
end
MOIB.added_constrained_variable_types(::Type{<:FunctionizeDecisionObjectiveBridge}) = Tuple{DataType}[]
function MOIB.added_constraint_types(::Type{<:FunctionizeDecisionObjectiveBridge})
    return Tuple{DataType, DataType}[]
end
function MOIB.set_objective_function_type(::Type{FunctionizeDecisionObjectiveBridge{T}}) where T
    return AffineDecisionFunction{T}
end

# Attributes, Bridge acting as a model
function MOI.get(bridge::FunctionizeDecisionObjectiveBridge, ::MOI.NumberOfVariables)
    return 0
end
function MOI.get(bridge::FunctionizeDecisionObjectiveBridge, ::MOI.ListOfVariableIndices)
    return MOI.VariableIndex[]
end

# No variables or constraints are created in this bridge so there is nothing to
# delete.
function MOI.delete(model::MOI.ModelLike, bridge::FunctionizeDecisionObjectiveBridge) end

function MOI.set(::MOI.ModelLike, ::MOI.ObjectiveSense,
                 ::FunctionizeDecisionObjectiveBridge, ::MOI.OptimizationSense)
    # `FunctionizeDecisionObjectiveBridge` is sense agnostic, therefore, we don't need to change
    # anything.
    return nothing
end
function MOI.get(model::MOI.ModelLike,
                 attr::MOIB.ObjectiveFunctionValue{SingleDecision},
                 bridge::FunctionizeDecisionObjectiveBridge{T}) where T
    F = AffineDecisionFunction{T}
    return MOI.get(model, MOIB.ObjectiveFunctionValue{F}(attr.result_index))
end
function MOI.get(model::MOI.ModelLike, attr::MOI.ObjectiveFunction{SingleDecision},
                 bridge::FunctionizeDecisionObjectiveBridge{T}) where T
    F = AffineDecisionFunction{T}
    func = MOI.get(model, MOI.ObjectiveFunction{F}())
    return convert(SingleDecision, func)
end

# Modifications
function MOI.modify(model::MOI.ModelLike, bridge::FunctionizeDecisionObjectiveBridge{T},
                    change::Union{DecisionStateChange, DecisionsStateChange}) where T
    F = AffineDecisionFunction{T}
    MOI.modify(model, MOI.ObjectiveFunction{F}(), change)
end
