function MA.mutable_operate!(op::MA.AddSubMul, aff::DVAE, x::Union{JuMP.VariableRef, GAEV, DecisionRef, GAEDV}, c::Number)
    return MA.mutable_operate!(op, aff, c, x)
end
function MA.mutable_operate!(op::MA.AddSubMul, aff::DVAE, c::Number, x::Union{JuMP.VariableRef, GAEV})
    if !iszero(c)
        MA.mutable_operate!(op, aff.v, c, x)
    end
    return aff
end
function MA.mutable_operate!(op::MA.AddSubMul, aff::DVAE, c::Number, x::Union{DecisionRef, GAEDV})
    if !iszero(c)
        MA.mutable_operate!(op, aff.dv, c, x)
    end
    return aff
end
function MA.mutable_operate!(op::MA.AddSubMul, aff::DVAE, c::Number, x::Number)
    if !iszero(c) && !iszero(x)
        aff.v = MA.mutable_operate!(op, aff.v, c, x)
    end
    return aff
end

function JuMP.add_to_expression!(aff::DVAE, other::Number)
    JuMP.add_to_expression!(aff.v, other)
end
function JuMP.add_to_expression!(aff::DVAE, new_var::JuMP.VariableRef, new_coef)
    JuMP.add_to_expression!(aff.v, new_coef, new_var)
end
function JuMP.add_to_expression!(aff::DVAE, new_coef, new_var::JuMP.VariableRef)
    JuMP.add_to_expression!(aff.v, new_coef, new_var)
end
function JuMP.add_to_expression!(aff::DVAE, new_var::JuMP.VariableRef)
    JuMP.add_to_expression!(aff.v, new_var)
end
function JuMP.add_to_expression!(aff::DVAE, new_dvar::DecisionRef, new_coef)
    JuMP.add_to_expression!(aff.dv, new_coef, new_dvar)
end
function JuMP.add_to_expression!(aff::DVAE, new_dvar::DecisionRef)
    JuMP.add_to_expression!(aff.dv, new_dvar)
end
function JuMP.add_to_expression!(aff::DVAE, new_coef, new_dvar::DecisionRef)
    JuMP.add_to_expression!(aff.dv, new_coef, new_dvar)
end
function JuMP.add_to_expression!(lhs_aff::DVAE, rhs_aff::DVAE)
    JuMP.add_to_expression!(lhs_aff.dv, rhs_aff.dv)
    JuMP.add_to_expression!(lhs_aff.v, rhs_aff.v)
end
