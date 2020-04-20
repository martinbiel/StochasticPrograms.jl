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

# Constraint #
# ========================== #
struct FunctionizeDecisionConstraintBridge{T, S} <: MOIB.Constraint.AbstractFunctionConversionBridge{MOI.ScalarAffineFunction{T}, S}
    constraint::MOI.ConstraintIndex{AffineDecisionFunction{T}, S}
end
function MOIB.Constraint.bridge_constraint(::Type{FunctionizeDecisionConstraintBridge{T, S}},
                                           model,
                                           f::SingleDecision,
                                           s::S) where {T, S}
    constraint = MOI.add_constraint(model, AffineDecisionFunction{T}(f), s)
    return FunctionizeDecisionConstraintBridge{T, S}(constraint)
end

# start allowing everything (scalar)
MOI.supports_constraint(::Type{FunctionizeDecisionConstraintBridge{T}},
                        ::Type{<:SingleDecision},
                        ::Type{<:MOI.AbstractScalarSet}) where {T} = true
MOIB.added_constrained_variable_types(::Type{<:FunctionizeDecisionConstraintBridge}) = Tuple{DataType}[]
function MOIB.added_constraint_types(::Type{FunctionizeDecisionConstraintBridge{T, S}}) where {T, S}
    return [(AffineDecisionFunction{T}, S)]
end
function MOIB.Constraint.concrete_bridge_type(::Type{<:FunctionizeDecisionConstraintBridge{T}},
                                              ::Type{SingleDecision},
                                              S::Type{<:MOI.AbstractScalarSet}) where T
    return FunctionizeDecisionConstraintBridge{T, S}
end

# Attributes, Bridge acting as a model
MOI.get(b::FunctionizeDecisionConstraintBridge{T, S}, ::MOI.NumberOfConstraints{AffineDecisionFunction{T}, S}) where {T, S} = 1
MOI.get(b::FunctionizeDecisionConstraintBridge{T, S}, ::MOI.ListOfConstraintIndices{AffineDecisionFunction{T}, S}) where {T, S} = [b.constraint]

# Indices
function MOI.delete(model::MOI.ModelLike, c::FunctionizeDecisionConstraintBridge)
    MOI.delete(model, c.constraint)
    return
end

# Constraints
function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintFunction,
                 c::FunctionizeDecisionConstraintBridge{T}, f::SingleDecision) where {T}
    MOI.set(model, MOI.ConstraintFunction(), c.constraint, AffineDecisionFunction{T}(f))
end
function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintFunction,
                 b::FunctionizeDecisionConstraintBridge{T}) where T
    f = MOIU.canonical(MOI.get(model, attr, b.constraint))
    # A taken decision might have a value here, so zero out the constant
    f.decision_part.constant = zero(T)
    return convert(SingleDecision, f)
end

# Modifications
function MOI.modify(model::MOI.ModelLike, bridge::FunctionizeDecisionConstraintBridge{T},
                    change::Union{DecisionStateChange, DecisionsStateChange}) where T
    MOI.modify(model, bridge.constraint, change)
end
