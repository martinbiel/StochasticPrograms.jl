# _Constant--DecisionRef
Base.:(+)(lhs::_Constant, rhs::DecisionRef) = DAE(_VAE(convert(Float64, lhs)), _DAE(0.0, rhs => +one(Float64)))
Base.:(-)(lhs::_Constant, rhs::DecisionRef) = DAE(_VAE(convert(Float64, lhs)), _DAE(0.0, rhs => -one(Float64)))
Base.:(*)(lhs::_Constant, rhs::DecisionRef) = DAE(_VAE(0.0), _DAE(0.0, rhs => lhs))

# _Constant--DecisionAffExpr{C}
Base.:(+)(lhs::_Constant, rhs::DecisionAffExpr{C}) where C =
    DecisionAffExpr(convert(C,lhs) + rhs.variables,
                    copy(rhs.decisions))
Base.:(-)(lhs::_Constant, rhs::DecisionAffExpr{C}) where C =
    DecisionAffExpr(convert(C,lhs) - rhs.variables,
                    -rhs.decisions)
Base.:(*)(lhs::_Constant, rhs::DecisionAffExpr{C}) where C =
    DecisionAffExpr(convert(C,lhs) * rhs.variables,
                    convert(C,lhs) * rhs.decisions)

# _Constant--DecisionQuadExpr{C}
Base.:(+)(lhs::_Constant, rhs::DecisionQuadExpr{C}) where C =
    DecisionQuadExpr(convert(C,lhs) + rhs.variables,
                     copy(rhs.decisions),
                     copy(rhs.cross_terms))
Base.:(-)(lhs::_Constant, rhs::DecisionQuadExpr{C}) where C =
    DecisionQuadExpr(convert(C,lhs) - rhs.variables,
                     copy(rhs.decisions),
                     copy(rhs.cross_terms))
Base.:(*)(lhs::_Constant, rhs::DecisionQuadExpr{C}) where C =
    DecisionQuadExpr(convert(C,lhs) * rhs.variables,
                     convert(C,lhs) * rhs.decisions,
                     _map_cross_terms(c -> convert(C,lhs) * c,
                                      copy(rhs.cross_terms)))

#=
    VariableRef
=#

# VariableRef--DecisionRef
Base.:(+)(lhs::VariableRef, rhs::DecisionRef) = DAE(_VAE(0.0, lhs => 1.0), _DAE(0.0, rhs =>  1.0))
Base.:(-)(lhs::VariableRef, rhs::DecisionRef) = DAE(_VAE(0.0, lhs => 1.0), _DAE(0.0, rhs => -1.0))
function Base.:(*)(lhs::VariableRef, rhs::DecisionRef)
    result = zero(DQE)
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# VariableRef--_DecisionAffExpr{C}
Base.:(+)(lhs::VariableRef, rhs::_DecisionAffExpr{C}) where C = DecisionAffExpr{C}(_VariableAffExpr{C}(zero(C), lhs => 1.), copy(rhs))
Base.:(-)(lhs::VariableRef, rhs::_DecisionAffExpr{C}) where C = DecisionAffExpr{C}(_VariableAffExpr{C}(zero(C), lhs => 1.), -rhs)
function Base.:(*)(lhs::VariableRef, rhs::_DecisionAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# VariableRef--_DecisionQuadExpr{C}
function Base.:(+)(lhs::VariableRef, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::VariableRef, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# VariableRef--DecisionAffExpr{C}
Base.:(+)(lhs::VariableRef, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(lhs + rhs.variables, copy(rhs.decisions))
Base.:(-)(lhs::VariableRef, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(lhs - rhs.variables, -rhs.decisions)
function Base.:(*)(lhs::VariableRef, rhs::DecisionAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end
Base.:/(lhs::VariableRef, rhs::DecisionAffExpr) = error("Cannot divide a variable by an affine expression")

# VariableRef--DecisionQuadExpr{C}
function Base.:(+)(lhs::VariableRef, rhs::DecisionQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::VariableRef, rhs::DecisionQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end
Base.:(*)(lhs::VariableRef, rhs::DecisionQuadExpr) = error("Cannot multiply a quadratic expression by a variable")

#=
    DecisionRef
=#

# DecisionRef
Base.:(-)(lhs::DecisionRef) = DAE(_VAE(0.0), _DAE(0.0, lhs => -1.0))

# DecisionRef--_Constant
Base.:(+)(lhs::DecisionRef, rhs::_Constant) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionRef, rhs::_Constant) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionRef, rhs::_Constant) = (*)(rhs, lhs)
Base.:(/)(lhs::DecisionRef, rhs::_Constant) = (*)(1.0 / rhs, lhs)

# DecisionRef--VariableRef
Base.:(+)(lhs::DecisionRef, rhs::VariableRef) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionRef, rhs::VariableRef) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionRef, rhs::VariableRef) = (*)(rhs, lhs)

# DecisionRef--DecisionRef
Base.:(+)(lhs::DecisionRef, rhs::DecisionRef) = DAE(_VAE(0.0), _DAE(0.0, lhs => 1.0, rhs => +1.0))
Base.:(-)(lhs::DecisionRef, rhs::DecisionRef) = DAE(_VAE(0.0), _DAE(0.0, lhs => 1.0, rhs => -1.0))
function Base.:(*)(lhs::DecisionRef, rhs::DecisionRef)
    result = zero(DQE)
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# DecisionRef--_VariableAffExpr{C}
Base.:(+)(lhs::DecisionRef, rhs::_VariableAffExpr{C}) where C = DecisionAffExpr{C}(rhs, _DecisionAffExpr{C}(zero(C), lhs => 1.))
Base.:(-)(lhs::DecisionRef, rhs::_VariableAffExpr{C}) where C = DecisionAffExpr{C}(-rhs, _DecisionAffExpr{C}(zero(C), lhs => 1.))
function Base.:(*)(lhs::DecisionRef, rhs::_VariableAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# DecisionRef--_VariableQuadExpr{C}
function Base.:(+)(lhs::DecisionRef, rhs::_VariableQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::DecisionRef, rhs::_VariableQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# DecisionRef--_DecisionAffExpr{C}
Base.:(+)(lhs::DecisionRef, rhs::_DecisionAffExpr{C}) where C = (+)(_DecisionAffExpr{C}(zero(C), lhs => 1.0),  rhs)
Base.:(-)(lhs::DecisionRef, rhs::_DecisionAffExpr{C}) where C = (+)(_DecisionAffExpr{C}(zero(C), lhs => 1.0), -rhs)
function Base.:(*)(lhs::DecisionRef, rhs::_DecisionAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# DecisionRef--_DecisionQuadExpr{C}
function Base.:(+)(lhs::DecisionRef, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expressoin(result, rhs)
    return result
end
function Base.:(-)(lhs::DecisionRef, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expressoin(result, lhs)
    JuMP.add_to_expressoin(result, -1., rhs)
    return result
end

# DecisionRef--DecisionAffExpr{C}
Base.:(+)(lhs::DecisionRef, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(copy(rhs.variables), lhs+rhs.decisions)
Base.:(-)(lhs::DecisionRef, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(-rhs.variables, lhs-rhs.decisions)
function Base.:(*)(lhs::DecisionRef, rhs::DecisionAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end
Base.:/(lhs::DecisionRef, rhs::DecisionAffExpr) = error("Cannot divide a decision by an affine expression")

# DecisionRef--DecisionQuadExpr{C}
function Base.:(+)(lhs::DecisionRef, rhs::DecisionQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::DecisionRef, rhs::DecisionQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end
Base.:(*)(lhs::DecisionRef, rhs::DecisionQuadExpr) = error("Cannot multiply a quadratic expression by a variable")

#=
    _VariableAffExpr{C}
=#

# _VariableAffExpr--DecisionRef
Base.:(+)(lhs::_VariableAffExpr, rhs::DecisionRef) = (+)(rhs, lhs)
Base.:(-)(lhs::_VariableAffExpr, rhs::DecisionRef) = (+)(-rhs, lhs)
Base.:(*)(lhs::_VariableAffExpr, rhs::DecisionRef) = (*)(rhs, lhs)

# _VariableAffExpr{C}--_DecisionAffExpr{C}
Base.:(+)(lhs::_VariableAffExpr{C}, rhs::_DecisionAffExpr{C}) where C = DecisionAffExpr{C}(copy(lhs), copy(rhs))
Base.:(-)(lhs::_VariableAffExpr{C}, rhs::_DecisionAffExpr{C}) where C = DecisionAffExpr{C}(copy(lhs), -rhs)
function Base.:(*)(lhs::_VariableAffExpr{C}, rhs::_DecisionAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# _VariableAffExpr{C}--_DecisionQuadExpr{C}
function Base.:(+)(lhs::_VariableAffExpr{C}, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expressoin(result, rhs)
    return result
end
function Base.:(-)(lhs::_VariableAffExpr{C}, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# VariableRef{C}--DecisionAffExpr{C}
Base.:(+)(lhs::_VariableAffExpr{C}, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(lhs+rhs.variables, copy(rhs.decisions))
Base.:(-)(lhs::_VariableAffExpr{C}, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(lhs-rhs.variables, -rhs.decisions)
function Base.:(*)(lhs::_VariableAffExpr{C}, rhs::DecisionAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# _VariableAffExpr{C}--DecisionQuadExpr{C}
function Base.:(+)(lhs::_VariableAffExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::_VariableAffExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end
Base.:(*)(lhs::_VariableAffExpr, rhs::DecisionQuadExpr) = error("Cannot multiply a quadratic expression by an affine expression")

#=
    _DecisionAffExpr{C}
=#

# _DecisionAffExpr--VariableRef/DecisionRef
Base.:(+)(lhs::_DecisionAffExpr, rhs::Union{VariableRef, DecisionRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::_DecisionAffExpr, rhs::Union{VariableRef, DecisionRef}) = (+)(-rhs, lhs)
Base.:(*)(lhs::_DecisionAffExpr, rhs::Union{VariableRef, DecisionRef}) = (*)(rhs, lhs)

# _DecisionAffExpr--_VariableAffExpr
Base.:(+)(lhs::_DecisionAffExpr, rhs::_VariableAffExpr) = (+)(rhs, lhs)
Base.:(-)(lhs::_DecisionAffExpr, rhs::_VariableAffExpr) = (+)(-rhs, lhs)
Base.:(*)(lhs::_DecisionAffExpr, rhs::_VariableAffExpr) = (*)(rhs, lhs)

# _DecisionAffExpr{C}--_VariableQuadExpr{C}
function Base.:(+)(lhs::_DecisionAffExpr{C}, rhs::_VariableQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::_DecisionAffExpr{C}, rhs::_VariableQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# _DecisionAffExpr{C}--DecisionAffExpr{C}
Base.:(+)(lhs::_DecisionAffExpr{C}, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(copy(rhs.variables), lhs+rhs.decisions)
Base.:(-)(lhs::_DecisionAffExpr{C}, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(-rhs.variables, lhs-rhs.decisions)
function Base.:(*)(lhs::_DecisionAffExpr{C}, rhs::DecisionAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# _DecisionAffExpr{C}--DecisionQuadExpr{C}
function Base.:(+)(lhs::_DecisionAffExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::_DecisionAffExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end
Base.:(*)(lhs::_DecisionAffExpr, rhs::DecisionQuadExpr) = error("Cannot multiply a quadratic expression by an affine expression")

#=
    DecisionAffExpr{C}
=#

Base.:(-)(lhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(-lhs.variables, -lhs.decisions)

# DecisionAffExpr--_Constant
Base.:(+)(lhs::DecisionAffExpr, rhs::_Constant) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionAffExpr, rhs::_Constant) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionAffExpr, rhs::_Constant) = (*)(rhs, lhs)
Base.:/(lhs::DecisionAffExpr, rhs::_Constant) = map_coefficients(c -> c/rhs, lhs)
function Base.:^(lhs::DecisionAffExpr{C}, rhs::Integer) where C
    if rhs == 2
        return lhs*lhs
    elseif rhs == 1
        return convert(DecisionQuadExpr{C}, lhs)
    elseif rhs == 0
        return one(GenericQuadExpr{C})
    else
        error("Only exponents of 0, 1, or 2 are currently supported.")
    end
end
Base.:^(lhs::DecisionAffExpr, rhs::_Constant) = error("Only exponents of 0, 1, or 2 are currently supported.")

# DecisionAffExpr--VariableRef/DecisionRef
Base.:(+)(lhs::DecisionAffExpr, rhs::Union{VariableRef, DecisionRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionAffExpr, rhs::Union{VariableRef, DecisionRef}) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionAffExpr, rhs::Union{VariableRef, DecisionRef}) = (*)(rhs, lhs)
Base.:/(lhs::DecisionAffExpr, rhs::VariableRef) = error("Cannot divide affine expression by a variable")
Base.:/(lhs::DecisionAffExpr, rhs::DecisionRef) = error("Cannot divide affine expression by a decision")

# DecisionAffExpr--_VariableAffExpr/_DecisionAffExpr/
Base.:(+)(lhs::DecisionAffExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionAffExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr}) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionAffExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr}) = (*)(rhs, lhs)

# DecisionAffExpr{C}--DecisionAffExpr{C}
Base.:(+)(lhs::DecisionAffExpr{C}, rhs::DecisionAffExpr{C}) where C =
    DecisionAffExpr{C}(lhs.variables+rhs.variables,
                       lhs.decisions+rhs.decisions)
Base.:(-)(lhs::DecisionAffExpr{C}, rhs::DecisionAffExpr{C}) where C =
    DecisionAffExpr{C}(lhs.variables-rhs.variables,
                       lhs.decisions-rhs.decisions)
function Base.:(*)(lhs::DecisionAffExpr{C}, rhs::DecisionAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# DecisionAffExpr{C}--_VariableQuadExpr{C}
function Base.:(+)(lhs::DecisionAffExpr{C}, rhs::_VariableQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::DecisionAffExpr{C}, rhs::_VariableQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# DecisionAffExpr{C}--_DecisionQuadExpr{C}
function Base.:(+)(lhs::DecisionAffExpr{C}, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::DecisionAffExpr{C}, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

Base.:(*)(lhs::DecisionAffExpr, rhs::Union{_VariableQuadExpr, _DecisionQuadExpr}) = error("Cannot multiply a quadratic expression by an affine expression")

# DecisionAffExpr{C}--DecisionQuadExpr{C}
function Base.:(+)(lhs::DecisionAffExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::DecisionAffExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end
Base.:(*)(lhs::DecisionAffExpr, rhs::DecisionQuadExpr) = error("Cannot multiply a quadratic expression by an affine expression")

#=
    _VariableQuadExpr{C}
=#

# _VariableQuadExpr--DecisionRef
Base.:(+)(lhs::_VariableQuadExpr, rhs::DecisionRef) = (+)(rhs, lhs)
Base.:(-)(lhs::_VariableQuadExpr, rhs::DecisionRef) = (+)(-rhs, lhs)

# _VariableQuadExpr--_DecisionAffExpr/DecisionAffExpr
Base.:(+)(lhs::_VariableQuadExpr, rhs::Union{_DecisionAffExpr, DecisionAffExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::_VariableQuadExpr, rhs::Union{_DecisionAffExpr, DecisionAffExpr}) = (+)(-rhs, lhs)
Base.:(*)(lhs::_VariableQuadExpr, rhs::DecisionAffExpr) = error("Cannot multiply a quadratic expression by an affine expression")

# _VariableQuadExpr{C}--_DecisionQuadExpr{C}
function Base.:(+)(lhs::_VariableQuadExpr{C}, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expressoin(result, rhs)
    return result
end
function Base.:(-)(lhs::_VariableQuadExpr{C}, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# _VariableQuadExpr{C}--DecisionQuadExpr{C}
function Base.:(+)(lhs::_VariableQuadExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::_VariableQuadExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end

#=
    _DecisionQuadExpr{C}
=#

# _DecisionQuadExpr--VariableRef/DecisionRef
Base.:(+)(lhs::_DecisionQuadExpr, rhs::Union{VariableRef, DecisionRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::_DecisionQuadExpr, rhs::Union{VariableRef, DecisionRef}) = (+)(-rhs, lhs)

# _DecisionQuadExpr--_VariableAffExpr
Base.:(+)(lhs::_DecisionQuadExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, DecisionAffExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::_DecisionQuadExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, DecisionAffExpr}) = (+)(-rhs, lhs)
Base.:(*)(lhs::_DecisionQuadExpr, rhs::DecisionAffExpr) = error("Cannot multiply a quadratic expression by an affine expression")

# _DecisionQuadExpr{C}--_VariableQuadExpr{C}
Base.:(+)(lhs::_DecisionQuadExpr, rhs::_VariableQuadExpr) = (+)(rhs, lhs)
Base.:(-)(lhs::_DecisionQuadExpr, rhs::_VariableQuadExpr) = (+)(-rhs, lhs)

# _DecisionQuadExpr{C}--DecisionQuadExpr{C}
function Base.:(+)(lhs::_DecisionQuadExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::_DecisionQuadExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end

#=
    DecisionQuadExpr{C}
=#

function Base.:(-)(lhs::DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, -1., lhs.variables)
    JuMP.add_to_expression!(result, -1., lhs.decisions)
    for (vars, coef) in lhs.cross_terms
        JuMP._add_or_set!(result.cross_terms, vars, -coef)
    end
    return result
end

# DecisionQuadExpr--_Constant
Base.:(+)(lhs::DecisionQuadExpr, rhs::_Constant) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionQuadExpr, rhs::_Constant) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionQuadExpr, rhs::_Constant) = (*)(rhs, lhs)
Base.:(/)(lhs::DecisionQuadExpr, rhs::_Constant) = (*)(inv(rhs), lhs)

# DecisionQuadExpr--VariableRef/DecisionRef
Base.:(+)(lhs::DecisionQuadExpr, rhs::Union{VariableRef, DecisionRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionQuadExpr, rhs::Union{VariableRef, DecisionRef}) = (+)(-rhs, lhs)
Base.:(/)(lhs::DecisionQuadExpr, rhs::Union{VariableRef, DecisionRef}) = error("Cannot divide a quadratic expression by a variable")

# DecisionQuadExpr--_VariableAffExpr/_DecisionAffExpr/
Base.:(+)(lhs::DecisionQuadExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, DecisionAffExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionQuadExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, DecisionAffExpr}) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionQuadExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, DecisionAffExpr}) = error("Cannot multiply a quadratic expression by an affine expression")
Base.:(/)(lhs::DecisionQuadExpr, rhs::Union{GenericAffExpr, DecisionAffExpr}) = error("Cannot divide a quadratic expression by an affine expression")

# DecisionQuadExpr{C}--_VariableQuadExpr/_DecisionQuadExpr/
Base.:(+)(lhs::DecisionQuadExpr, rhs::Union{_VariableQuadExpr, _DecisionQuadExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionQuadExpr, rhs::Union{_VariableQuadExpr, _DecisionQuadExpr}) = (+)(-rhs, lhs)

# DecisionQuadExpr{C}--DecisionQuadExpr{C}
function Base.:(+)(lhs::DecisionQuadExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = copy(lhs)
    JuMP.add_to_expression!(result, rhs.variables)
    JuMP.add_to_expression!(result, rhs.decisions)
    add_cross_terms!(result_terms, terms) = begin
        for (vars, coef) in terms
            JuMP._add_or_set!(result_terms, vars, coef)
        end
    end
    add_cross_terms!(result.cross_terms, rhs.cross_terms)
    return result
end
function Base.:(-)(lhs::DecisionQuadExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs.variables)
    JuMP.add_to_expression!(result, lhs.decisions)
    add_cross_terms!(result_terms, terms) = begin
        for (vars, coef) in terms
            JuMP._add_or_set!(result_terms, vars, -coef)
        end
    end
    add_cross_terms!(result.cross_terms, lhs.cross_terms)
    return result
end
Base.:(*)(lhs::DecisionQuadExpr, rhs::DecisionQuadExpr) = error("Cannot multiply a quadratic expression by a quadratic expression")

Base.promote_rule(V::Type{DecisionRef}, R::Type{<:Real}) = DecisionAffExpr{T}
Base.promote_rule(V::Type{DecisionRef}, ::Type{<:DecisionAffExpr{T}}) where {T} = DecisionAffExpr{T}
Base.promote_rule(V::Type{DecisionRef}, ::Type{<:DecisionQuadExpr{T}}) where {T} = DecisionQuadExpr{T}
Base.promote_rule(::Type{<:DecisionAffExpr{S}}, R::Type{<:Real}) where S = DecisionAffExpr{promote_type(S, R)}
Base.promote_rule(::Type{<:DecisionAffExpr{S}}, ::Type{<:DecisionQuadExpr{T}}) where {S, T} = DecisionQuadExpr{promote_type(S, T)}
Base.promote_rule(::Type{<:DecisionQuadExpr{S}}, R::Type{<:Real}) where S = DecisionQuadExpr{promote_type(S, R)}
