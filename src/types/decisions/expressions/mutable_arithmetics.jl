# Affine expression #
# ========================== #
function MA.mutable_operate!(op::MA.AddSubMul, aff::CAE, x::Union{JuMP.VariableRef, VAE, DecisionRef, DAE, KnownRef, KAE}, c::Number)
    return MA.mutable_operate!(op, aff, c, x)
end
function MA.mutable_operate!(op::MA.AddSubMul, aff::CAE, c::Number, x::Union{JuMP.VariableRef, VAE})
    if !iszero(c)
        MA.mutable_operate!(op, aff.variables, c, x)
    end
    return aff
end
function MA.mutable_operate!(op::MA.AddSubMul, aff::CAE, c::Number, x::Union{DecisionRef, DAE})
    if !iszero(c)
        MA.mutable_operate!(op, aff.decisions, c, x)
    end
    return aff
end
function MA.mutable_operate!(op::MA.AddSubMul, aff::CAE, c::Number, x::Union{KnownRef, KAE})
    if !iszero(c)
        MA.mutable_operate!(op, aff.knowns, c, x)
    end
    return aff
end
function MA.mutable_operate!(op::MA.AddSubMul, aff::CAE, c::Number, x::Number)
    if !iszero(c) && !iszero(x)
        aff.variables = MA.mutable_operate!(op, aff.variables, c, x)
    end
    return aff
end

function JuMP.add_to_expression!(aff::CAE, other::Number)
    JuMP.add_to_expression!(aff.variables, other)
end
function JuMP.add_to_expression!(aff::CAE, new_var::JuMP.VariableRef, new_coef)
    JuMP.add_to_expression!(aff.variables, new_coef, new_var)
end
function JuMP.add_to_expression!(aff::CAE, new_coef, new_var::JuMP.VariableRef)
    JuMP.add_to_expression!(aff.variables, new_coef, new_var)
end
function JuMP.add_to_expression!(aff::CAE, new_var::JuMP.VariableRef)
    JuMP.add_to_expression!(aff.variables, new_var)
end
function JuMP.add_to_expression!(aff::CAE, new_dvar::DecisionRef, new_coef)
    JuMP.add_to_expression!(aff.decisions, new_coef, new_dvar)
end
function JuMP.add_to_expression!(aff::CAE, new_dvar::DecisionRef)
    JuMP.add_to_expression!(aff.decisions, new_dvar)
end
function JuMP.add_to_expression!(aff::CAE, new_coef, new_dvar::DecisionRef)
    JuMP.add_to_expression!(aff.decisions, new_coef, new_dvar)
end
function JuMP.add_to_expression!(aff::CAE, new_kvar::KnownRef, new_coef)
    JuMP.add_to_expression!(aff.knowns, new_coef, new_kvar)
end
function JuMP.add_to_expression!(aff::CAE, new_kvar::KnownRef)
    JuMP.add_to_expression!(aff.knowns, new_kvar)
end
function JuMP.add_to_expression!(aff::CAE, new_coef, new_kvar::KnownRef)
    JuMP.add_to_expression!(aff.knowns, new_coef, new_kvar)
end
function JuMP.add_to_expression!(lhs_aff::CAE, rhs_aff::CAE)
    JuMP.add_to_expression!(lhs_aff.variables, rhs_aff.variables)
    JuMP.add_to_expression!(lhs_aff.decisions, rhs_aff.decisions)
    JuMP.add_to_expression!(lhs_aff.knowns, rhs_aff.knowns)
end
