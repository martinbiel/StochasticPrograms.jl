struct DecisionVariableBridge{T, S} <: MOIB.Constraint.AbstractBridge
    constraint::MOI.ConstraintIndex{MOI.ScalarAffineFunction{T}, S}
end

function MOIB.Constraint.bridge_constraint(::Type{DecisionVariableBridge{T, S}},
                                           model,
                                           f::MOI.ScalarAffineFunction{T},
                                           dvar_set::DecisionVariableSet{T,S}) where {T, S}
    dvar_value = JuMP.value(dvar_set.decision_variables, JuMP.value)
    set = MOIU.shift_constant(dvar_set.set, convert(T, -dvar_value))
    constraint = MOI.add_constraint(model, f, set)
    return DecisionVariableBridge{T, S}(constraint)
end

function MOI.supports_constraint(::Type{<:DecisionVariableBridge{T}},
                                 ::Type{<:MOI.ScalarAffineFunction},
                                 ::Type{<:DecisionVariableSet}) where {T}
    return true
end
function MOIB.added_constrained_variable_types(::Type{<:DecisionVariableBridge})
    return Tuple{DataType}[]
end
function MOIB.added_constraint_types(::Type{<:DecisionVariableBridge{T, S}}) where {T, S}
    return [(MOI.ScalarAffineFunction{T}, S)]
end
function MOIB.Constraint.concrete_bridge_type(::Type{<:DecisionVariableBridge},
                              ::Type{<:MOI.ScalarAffineFunction},
                              ::Type{<:DecisionVariableSet{T,S}}) where {T,S}
    return DecisionVariableBridge{T, S}
end

MOI.get(b::DecisionVariableBridge{T, S}, ::MOI.NumberOfConstraints{MOI.ScalarAffineFunction{T}, S}) where {T, S} = 1
MOI.get(b::DecisionVariableBridge{T, S}, ::MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{T}, S}) where {T, S} = [b.constraint]

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::DecisionVariableBridge{T, S}, change::S) where {T, S}
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint, change)
end

function MOI.delete(model::MOI.ModelLike, c::DecisionVariableBridge)
    MOI.delete(model, c.constraint)
    return
end
