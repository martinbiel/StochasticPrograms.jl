struct DecisionVariableSet{C, S <: Union{MOI.LessThan,MOI.GreaterThan,MOI.EqualTo}} <: MOI.AbstractScalarSet
    decision_variables::JuMP.GenericAffExpr{C, DecisionRef}
    set::S
end

function update_decision_variable_constraints(model::JuMP.Model)
    F = GAEV{Float64}
    for set_type in [MOI.EqualTo{Float64}, MOI.LessThan{Float64}, MOI.GreaterThan{Float64}]
        S = DecisionVariableSet{Float64, set_type}
        for cref in all_constraints(model, F, S)
            _update_decision_variables_constraint(cref)
        end
    end
end

function _update_decision_variables_constraint(cref::ConstraintRef)
    _update_decision_variables_constraint(backend(owner_model(cref)), cref.index)
end

function _update_decision_variables_constraint(model::MOI.ModelLike, ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{T}, DecisionVariableSet{T,S}}) where {T,S}
    dvar_set = MOI.get(model, MOI.ConstraintSet(), ci)
    dvar_value = JuMP.value(dvar_set.decision_variables, JuMP.value)
    set = MOIU.shift_constant(dvar_set.set, convert(T, dvar_value))
    MOI.set(model, MOI.ConstraintSet(), ci, set)
    return
end

function JuMP.build_constraint(_error::Function, aff::DecisionVariableAffExpr, set::S) where S <: Union{MOI.LessThan,MOI.GreaterThan,MOI.EqualTo}
    offset = constant(aff.v)
    add_to_expression!(aff.v, -offset)
    shifted_set = MOIU.shift_constant(set, -offset)
    parameterized_set = DecisionVariableSet(-aff.dv, shifted_set)
    constraint = JuMP.ScalarConstraint(aff.v, parameterized_set)
    return JuMP.BridgeableConstraint(constraint, DecisionVariableBridge)
end

function JuMP.build_constraint(_error::Function, aff::DecisionVariableAffExpr, lb, ub)
    JuMP.build_constraint(_error, aff, MOI.Interval(lb, ub))
end

function JuMP.constraint_string(print_mode, constraint_object::ScalarConstraint{F, <:DecisionVariableSet}) where F
    f = constraint_object.func - constraint_object.set.decision_variables
    s = constraint_object.set.set
    return JuMP.constraint_string(print_mode, ScalarConstraint(f, s))
end
