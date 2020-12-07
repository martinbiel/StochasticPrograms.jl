# _Constant--DecisionRef
Base.:(+)(lhs::_Constant, rhs::DecisionRef) = DAE(_VAE(convert(Float64, lhs)), _DAE(0.0, rhs => +one(Float64)), _KAE(0.0))
Base.:(-)(lhs::_Constant, rhs::DecisionRef) = DAE(_VAE(convert(Float64, lhs)), _DAE(0.0, rhs => -one(Float64)), _KAE(0.0))
Base.:(*)(lhs::_Constant, rhs::DecisionRef) = DAE(_VAE(0.0), _DAE(0.0, rhs => lhs), _KAE(0.0))

# _Constant--KnownRef
Base.:(+)(lhs::_Constant, rhs::KnownRef) = DAE(_VAE(convert(Float64, lhs)), _DAE(0.0), _KAE(0.0, rhs => +one(Float64)))
Base.:(-)(lhs::_Constant, rhs::KnownRef) = DAE(_VAE(convert(Float64, lhs)), _DAE(0.0), _KAE(0.0, rhs => -one(Float64)))
Base.:(*)(lhs::_Constant, rhs::KnownRef) = DAE(_VAE(0.0), _DAE(0.0), _KAE(0.0, rhs => lhs))

# _Constant--DecisionAffExpr{C}
Base.:(+)(lhs::_Constant, rhs::DecisionAffExpr{C}) where C =
    DecisionAffExpr(convert(C,lhs) + rhs.variables,
                    copy(rhs.decisions),
                    copy(rhs.knowns))
Base.:(-)(lhs::_Constant, rhs::DecisionAffExpr{C}) where C =
    DecisionAffExpr(convert(C,lhs) - rhs.variables,
                    -rhs.decisions,
                    -rhs.knowns)
Base.:(*)(lhs::_Constant, rhs::DecisionAffExpr{C}) where C =
    DecisionAffExpr(convert(C,lhs) * rhs.variables,
                    convert(C,lhs) * rhs.decisions,
                    convert(C,lhs) * rhs.knowns)

# _Constant--DecisionQuadExpr{C}
Base.:(+)(lhs::_Constant, rhs::DecisionQuadExpr{C}) where C =
    DecisionQuadExpr(convert(C,lhs) + rhs.variables,
                     copy(rhs.decisions),
                     copy(rhs.knowns),
                     copy(rhs.cross_terms),
                     copy(rhs.known_variable_terms),
                     copy(rhs.known_decision_terms))
Base.:(-)(lhs::_Constant, rhs::DecisionQuadExpr{C}) where C =
    DecisionQuadExpr(convert(C,lhs) - rhs.variables,
                     copy(rhs.decisions),
                     copy(rhs.knowns),
                     copy(rhs.cross_terms),
                     copy(rhs.known_variable_terms),
                     copy(rhs.known_decision_terms))
Base.:(*)(lhs::_Constant, rhs::DecisionQuadExpr{C}) where C =
    DecisionQuadExpr(convert(C,lhs) * rhs.variables,
                     convert(C,lhs) * rhs.decisions,
                     convert(C,lhs) * rhs.knowns,
                     _map_cross_terms(c -> convert(C,lhs) * c,
                                      copy(rhs.cross_terms)),
                     _map_cross_terms(c -> convert(C,lhs) * c,
                                      copy(rhs.known_variable_terms)),
                     _map_cross_terms(c -> convert(C,lhs) * c,
                                      copy(rhs.known_decision_terms)))

#=
    VariableRef
=#

# VariableRef--DecisionRef
Base.:(+)(lhs::VariableRef, rhs::DecisionRef) = DAE(_VAE(0.0, lhs => 1.0), _DAE(0.0, rhs =>  1.0), _KAE(0.0))
Base.:(-)(lhs::VariableRef, rhs::DecisionRef) = DAE(_VAE(0.0, lhs => 1.0), _DAE(0.0, rhs => -1.0), _KAE(0.0))
function Base.:(*)(lhs::VariableRef, rhs::DecisionRef)
    result = zero(DQE)
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# VariableRef--KnownRef
Base.:(+)(lhs::VariableRef, rhs::KnownRef) = DAE(_VAE(0.0, lhs => 1.0), _DAE(0.0), _KAE(0.0, rhs =>  1.0))
Base.:(-)(lhs::VariableRef, rhs::KnownRef) = DAE(_VAE(0.0, lhs => 1.0), _DAE(0.0), _KAE(0.0, rhs => -1.0))
function Base.:(*)(lhs::VariableRef, rhs::KnownRef)
    result = zero(DQE)
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# VariableRef--_DecisionAffExpr{C}
Base.:(+)(lhs::VariableRef, rhs::_DecisionAffExpr{C}) where C = DecisionAffExpr{C}(_VariableAffExpr{C}(zero(C), lhs => 1.), copy(rhs), zero(_KnownAffExpr{C}))
Base.:(-)(lhs::VariableRef, rhs::_DecisionAffExpr{C}) where C = DecisionAffExpr{C}(_VariableAffExpr{C}(zero(C), lhs => 1.), -rhs, zero(_KnownAffExpr{C}))
function Base.:(*)(lhs::VariableRef, rhs::_DecisionAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# VariableRef--_DecisionQuadExpr{C}
function Base.:(+)(lhs::VariableRef, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expressoin(result, rhs)
    return result
end
function Base.:(-)(lhs::VariableRef, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# VariableRef--_KnownAffExpr{C}
Base.:(+)(lhs::VariableRef, rhs::_KnownAffExpr{C}) where C = DecisionAffExpr{C}(_VariableAffExpr{C}(zero(C), lhs => 1.), zero(_DecisionAffExpr{C}), copy(rhs))
Base.:(-)(lhs::VariableRef, rhs::_KnownAffExpr{C}) where C = DecisionAffExpr{C}(_VariableAffExpr{C}(zero(C), lhs => 1.), zero(_DecisionAffExpr{C}), -rhs)
function Base.:(*)(lhs::VariableRef, rhs::_KnownAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# VariableRef--_KnownQuadExpr{C}
function Base.:(+)(lhs::VariableRef, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::VariableRef, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# VariableRef--DecisionAffExpr{C}
Base.:(+)(lhs::VariableRef, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(lhs + rhs.variables, copy(rhs.decisions), copy(rhs.knowns))
Base.:(-)(lhs::VariableRef, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(lhs - rhs.variables, -rhs.decisions, -rhs.knowns)
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
Base.:(-)(lhs::DecisionRef) = DAE(_VAE(0.0), _DAE(0.0, lhs => -1.0), _KAE(0.0))

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
Base.:(+)(lhs::DecisionRef, rhs::DecisionRef) = DAE(_VAE(0.0), _DAE(0.0, lhs => 1.0, rhs => +1.0), _KAE(0.0))
Base.:(-)(lhs::DecisionRef, rhs::DecisionRef) = DAE(_VAE(0.0), _DAE(0.0, lhs => 1.0, rhs => -1.0), _KAE(0.0))
function Base.:(*)(lhs::DecisionRef, rhs::DecisionRef)
    result = zero(DQE)
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# DecisionRef--KnownRef
Base.:(+)(lhs::DecisionRef, rhs::KnownRef) = DAE(_VAE(0.0), _DAE(0.0, lhs => 1.0), _KAE(0.0, rhs => +1.0))
Base.:(-)(lhs::DecisionRef, rhs::KnownRef) = DAE(_VAE(0.0), _DAE(0.0, lhs => 1.0), _KAE(0.0, rhs => -1.0))
function Base.:(*)(lhs::DecisionRef, rhs::KnownRef)
    result = zero(DQE)
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# DecisionRef--_VariableAffExpr{C}
Base.:(+)(lhs::DecisionRef, rhs::_VariableAffExpr{C}) where C = DecisionAffExpr{C}(rhs, _DecisionAffExpr{C}(zero(C), lhs => 1.), zero(_KnownAffExpr{C}))
Base.:(-)(lhs::DecisionRef, rhs::_VariableAffExpr{C}) where C = DecisionAffExpr{C}(-rhs, _DecisionAffExpr{C}(zero(C), lhs => 1.), zero(_KnownAffExpr{C}))
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

# DecisionRef--_KnownAffExpr{C}
Base.:(+)(lhs::DecisionRef, rhs::_KnownAffExpr{C}) where C = DecisionAffExpr{C}(zero(_VariableAffExpr{C}), _DecisionAffExpr{C}(zero(C), lhs => 1), copy(rhs))
Base.:(-)(lhs::DecisionRef, rhs::_KnownAffExpr{C}) where C = DecisionAffExpr{C}(zero(_VariableAffExpr{C}), _DecisionAffExpr{C}(zero(C), lhs => 1.), -rhs)
function Base.:(*)(lhs::DecisionRef, rhs::_KnownAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# DecisionRef--_KnownQuadExpr{C}
function Base.:(+)(lhs::DecisionRef, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::DecisionRef, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# DecisionRef--DecisionAffExpr{C}
Base.:(+)(lhs::DecisionRef, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(copy(rhs.variables), lhs+rhs.decisions, copy(rhs.knowns))
Base.:(-)(lhs::DecisionRef, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(-rhs.variables, lhs-rhs.decisions, -rhs.knowns)
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
    KnownRef
=#

# KnownRef
Base.:(-)(lhs::KnownRef) = DAE(_VAE(0.0), _DAE(0.0), _KAE(0.0, lhs => -1.0))

# KnownRef--_Constant
Base.:(+)(lhs::KnownRef, rhs::_Constant) = (+)(rhs, lhs)
Base.:(-)(lhs::KnownRef, rhs::_Constant) = (+)(-rhs, lhs)
Base.:(*)(lhs::KnownRef, rhs::_Constant) = (*)(rhs, lhs)
Base.:(/)(lhs::KnownRef, rhs::_Constant) = (*)(1.0 / rhs, lhs)

# KnownRef--VariableRef
Base.:(+)(lhs::KnownRef, rhs::VariableRef) = (+)(rhs, lhs)
Base.:(-)(lhs::KnownRef, rhs::VariableRef) = (+)(-rhs, lhs)
Base.:(*)(lhs::KnownRef, rhs::VariableRef) = (*)(rhs, lhs)

# KnownRef--DecisionRef
Base.:(+)(lhs::KnownRef, rhs::DecisionRef) = (+)(rhs, lhs)
Base.:(-)(lhs::KnownRef, rhs::DecisionRef) = (+)(-rhs, lhs)
Base.:(*)(lhs::KnownRef, rhs::DecisionRef) = (*)(rhs, lhs)

# KnownRef--KnownRef
Base.:(+)(lhs::KnownRef, rhs::KnownRef) = DAE(_VAE(0.0), _DAE(0.0), _KAE(0.0, lhs => 1.0, rhs => +1.0))
Base.:(-)(lhs::KnownRef, rhs::KnownRef) = DAE(_VAE(0.0), _DAE(0.0), _KAE(0.0, lhs => 1.0, rhs => -1.0))
function Base.:(*)(lhs::KnownRef, rhs::KnownRef)
    result = zero(DQE)
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# KnownRef--_VariableAffExpr{C}
Base.:(+)(lhs::KnownRef, rhs::_VariableAffExpr{C}) where C = DecisionAffExpr{C}(copy(rhs), zero(_DecisionAffExpr{C}), _KnownAffExpr{C}(zero(C), lhs => 1.))
Base.:(-)(lhs::KnownRef, rhs::_VariableAffExpr{C}) where C = DecisionAffExpr{C}(-rhs, zero(_DecisionAffExpr{C}), _KnownAffExpr{C}(zero(C), lhs => 1.))
function Base.:(*)(lhs::KnownRef, rhs::_VariableAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# KnownRef--_VariableQuadExpr{C}
function Base.:(+)(lhs::KnownRef, rhs::_VariableQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::KnownRef, rhs::_VariableQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# KnownRef--_DecisionAffExpr{C}
Base.:(+)(lhs::KnownRef, rhs::_DecisionAffExpr{C}) where C = DecisionAffExpr{C}(zero(_VariableAffExpr{C}), rhs, _KnownAffExpr{C}(zero(C), lhs => 1.))
Base.:(-)(lhs::KnownRef, rhs::_DecisionAffExpr{C}) where C = DecisionAffExpr{C}(zero(_VariableAffExpr{C}), -rhs, _KnownAffExpr{C}(zero(C), lhs => 1.))
function Base.:(*)(lhs::KnownRef, rhs::_DecisionAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# KnownRef--_DecisionQuadExpr{C}
function Base.:(+)(lhs::KnownRef, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expressoin(result, rhs)
    return result
end
function Base.:(-)(lhs::KnownRef, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expressoin(result, lhs)
    JuMP.add_to_expressoin(result, -1., rhs)
    return result
end

# KnownRef--_KnownAffExpr{C}
Base.:(+)(lhs::KnownRef, rhs::_KnownAffExpr{C}) where C = (+)(_KnownAffExpr{C}(zero(C), lhs => 1.0),  rhs)
Base.:(-)(lhs::KnownRef, rhs::_KnownAffExpr{C}) where C = (+)(_KnownAffExpr{C}(zero(C), lhs => 1.0), -rhs)
function Base.:(*)(lhs::KnownRef, rhs::_KnownAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# KnownRef--_KnownQuadExpr{C}
function Base.:(+)(lhs::KnownRef, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::KnownRef, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# KnownRef--DecisionAffExpr{C}
Base.:(+)(lhs::KnownRef, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(copy(rhs.variables), copy(rhs.decisions), lhs+rhs.knowns)
Base.:(-)(lhs::KnownRef, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(-rhs.variables, -rhs.decisions, lhs-rhs.knowns)
function Base.:(*)(lhs::KnownRef, rhs::DecisionAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end
Base.:/(lhs::KnownRef, rhs::DecisionAffExpr) = error("Cannot divide a known decision by an affine expression")

# KnownRef--DecisionQuadExpr{C}
function Base.:(+)(lhs::KnownRef, rhs::DecisionQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::KnownRef, rhs::DecisionQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end
Base.:(*)(lhs::KnownRef, rhs::DecisionQuadExpr) = error("Cannot multiply a quadratic expression by a variable")

#=
    _VariableAffExpr{C}
=#

# _VariableAffExpr--DecisionRef/KnownRef
Base.:(+)(lhs::_VariableAffExpr, rhs::Union{DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::_VariableAffExpr, rhs::Union{DecisionRef, KnownRef}) = (+)(-rhs, lhs)
Base.:(*)(lhs::_VariableAffExpr, rhs::Union{DecisionRef, KnownRef}) = (*)(rhs, lhs)

# _VariableAffExpr{C}--_DecisionAffExpr{C}
Base.:(+)(lhs::_VariableAffExpr{C}, rhs::_DecisionAffExpr{C}) where C = DecisionAffExpr{C}(copy(lhs), copy(rhs), zero(_KnownAffExpr{C}))
Base.:(-)(lhs::_VariableAffExpr{C}, rhs::_DecisionAffExpr{C}) where C = DecisionAffExpr{C}(copy(lhs), -rhs, zero(_KnownAffExpr{C}))
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

# _VariableAffExpr{C}--_KnownAffExpr{C}
Base.:(+)(lhs::_VariableAffExpr{C}, rhs::_KnownAffExpr{C}) where C = DecisionAffExpr{C}(copy(lhs), zero(_DecisionAffExpr{C}), copy(rhs))
Base.:(-)(lhs::_VariableAffExpr{C}, rhs::_KnownAffExpr{C}) where C = DecisionAffExpr{C}(copy(lhs), zero(_DecisionAffExpr{C}), -rhs)
function Base.:(*)(lhs::_VariableAffExpr{C}, rhs::_KnownAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# _VariableAffExpr{C}--_KnownQuadExpr{C}
function Base.:(+)(lhs::_VariableAffExpr{C}, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::_VariableAffExpr{C}, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end
Base.:(*)(lhs::_VariableAffExpr, rhs::_KnownQuadExpr) = error("Cannot multiply a quadratic expression by an affine expression")

# VariableRef{C}--DecisionAffExpr{C}
Base.:(+)(lhs::_VariableAffExpr{C}, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(lhs+rhs.variables, copy(rhs.decisions), copy(rhs.knowns))
Base.:(-)(lhs::_VariableAffExpr{C}, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(lhs-rhs.variables, -rhs.decisions, -rhs.knowns)
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

# _DecisionAffExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::_DecisionAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::_DecisionAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(-rhs, lhs)
Base.:(*)(lhs::_DecisionAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (*)(rhs, lhs)

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

# _DecisionAffExpr--_KnownAffExpr
Base.:(+)(lhs::_DecisionAffExpr{C}, rhs::_KnownAffExpr{C}) where C = DecisionAffExpr{C}(zero(_VariableAffExpr{C}), copy(lhs), copy(rhs))
Base.:(-)(lhs::_DecisionAffExpr{C}, rhs::_KnownAffExpr{C}) where C = DecisionAffExpr{C}(zero(_VariableAffExpr{C}), copy(lhs), -rhs)
function Base.:(*)(lhs::_DecisionAffExpr{C}, rhs::_KnownAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# _DecisionAffExpr{C}--_KnownQuadExpr{C}
function Base.:(+)(lhs::_DecisionAffExpr{C}, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::_DecisionAffExpr{C}, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# _DecisionAffExpr{C}--DecisionAffExpr{C}
Base.:(+)(lhs::_DecisionAffExpr{C}, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(copy(rhs.variables), lhs+rhs.decisions, copy(rhs.knowns))
Base.:(-)(lhs::_DecisionAffExpr{C}, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(-rhs.variables, lhs-rhs.decisions, -rhs.knowns)
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
    _KnownAffExpr{C}
=#

# _KnownAffExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::_KnownAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::_KnownAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(-rhs, lhs)
Base.:(*)(lhs::_KnownAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (*)(rhs, lhs)

# _KnownAffExpr--_VariableAffExpr
Base.:(+)(lhs::_KnownAffExpr, rhs::_VariableAffExpr) = (+)(rhs, lhs)
Base.:(-)(lhs::_KnownAffExpr, rhs::_VariableAffExpr) = (+)(-rhs, lhs)
Base.:(*)(lhs::_KnownAffExpr, rhs::_VariableAffExpr) = (*)(rhs, lhs)

# _KnownAffExpr{C}--_VariableQuadExpr{C}
function Base.:(+)(lhs::_KnownAffExpr{C}, rhs::_VariableQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::_KnownAffExpr{C}, rhs::_VariableQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# _KnownAffExpr--_DecisionAffExpr
Base.:(+)(lhs::_KnownAffExpr, rhs::_DecisionAffExpr) = (+)(rhs, lhs)
Base.:(-)(lhs::_KnownAffExpr, rhs::_DecisionAffExpr) = (+)(-rhs, lhs)
Base.:(*)(lhs::_KnownAffExpr, rhs::_DecisionAffExpr) = (*)(rhs, lhs)

# _KnownAffExpr{C}--_DecisionQuadExpr{C}
function Base.:(+)(lhs::_KnownAffExpr{C}, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expressoin(result, rhs)
    return result
end
function Base.:(-)(lhs::_KnownAffExpr{C}, rhs::_DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expressoin(result, lhs)
    JuMP.add_to_expressoin(result, -1., rhs)
    return result
end

# _KnownAffExpr{C}--DecisionAffExpr{C}
Base.:(+)(lhs::_KnownAffExpr{C}, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(copy(rhs.variables), copy(rhs.decisions), lhs+rhs.knowns)
Base.:(-)(lhs::_KnownAffExpr{C}, rhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(-rhs.variables, -rhs.decisions, lhs-rhs.knowns)
function Base.:(*)(lhs::_KnownAffExpr{C}, rhs::DecisionAffExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# _KnownAffExpr{C}--DecisionQuadExpr{C}
function Base.:(+)(lhs::_KnownAffExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::_KnownAffExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end

#=
    DecisionAffExpr{C}
=#

Base.:(-)(lhs::DecisionAffExpr{C}) where C = DecisionAffExpr{C}(-lhs.variables, -lhs.decisions, -lhs.knowns)

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

# DecisionAffExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::DecisionAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (*)(rhs, lhs)
Base.:/(lhs::DecisionAffExpr, rhs::VariableRef) = error("Cannot divide affine expression by a variable")
Base.:/(lhs::DecisionAffExpr, rhs::DecisionRef) = error("Cannot divide affine expression by a decision")
Base.:/(lhs::DecisionAffExpr, rhs::KnownRef) = error("Cannot divide affine expression by a known decision s")

# DecisionAffExpr--_VariableAffExpr/_DecisionAffExpr/_KnownAffExpr
Base.:(+)(lhs::DecisionAffExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, _KnownAffExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionAffExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, _KnownAffExpr}) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionAffExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, _KnownAffExpr}) = (*)(rhs, lhs)

# DecisionAffExpr{C}--DecisionAffExpr{C}
Base.:(+)(lhs::DecisionAffExpr{C}, rhs::DecisionAffExpr{C}) where C =
    DecisionAffExpr{C}(lhs.variables+rhs.variables,
                       lhs.decisions+rhs.decisions,
                       lhs.knowns+rhs.knowns)
Base.:(-)(lhs::DecisionAffExpr{C}, rhs::DecisionAffExpr{C}) where C =
    DecisionAffExpr{C}(lhs.variables-rhs.variables,
                       lhs.decisions-rhs.decisions,
                       lhs.knowns-rhs.knowns)
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

# DecisionAffExpr{C}--_KnownQuadExpr{C}
function Base.:(+)(lhs::DecisionAffExpr{C}, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::DecisionAffExpr{C}, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

Base.:(*)(lhs::DecisionAffExpr, rhs::Union{_VariableQuadExpr, _DecisionQuadExpr, _KnownQuadExpr}) = error("Cannot multiply a quadratic expression by an affine expression")

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

# _VariableQuadExpr--DecisionRef/KnownRef
Base.:(+)(lhs::_VariableQuadExpr, rhs::Union{DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::_VariableQuadExpr, rhs::Union{DecisionRef, KnownRef}) = (+)(-rhs, lhs)

# _VariableQuadExpr--_DecisionAffExpr/_KnownAffExpr/DecisionAffExpr
Base.:(+)(lhs::_VariableQuadExpr, rhs::Union{_DecisionAffExpr, _KnownAffExpr, DecisionAffExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::_VariableQuadExpr, rhs::Union{_DecisionAffExpr, _KnownAffExpr, DecisionAffExpr}) = (+)(-rhs, lhs)
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

# _VariableQuadExpr{C}--_KnownQuadExpr{C}
function Base.:(+)(lhs::_VariableQuadExpr{C}, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::_VariableQuadExpr{C}, rhs::_KnownQuadExpr{C}) where C
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

# _DecisionQuadExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::_DecisionQuadExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::_DecisionQuadExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(-rhs, lhs)

# _DecisionQuadExpr--_VariableAffExpr
Base.:(+)(lhs::_DecisionQuadExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, _KnownAffExpr, DecisionAffExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::_DecisionQuadExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, _KnownAffExpr, DecisionAffExpr}) = (+)(-rhs, lhs)
Base.:(*)(lhs::_DecisionQuadExpr, rhs::DecisionAffExpr) = error("Cannot multiply a quadratic expression by an affine expression")

# _DecisionQuadExpr{C}--_VariableQuadExpr{C}
Base.:(+)(lhs::_DecisionQuadExpr, rhs::_VariableQuadExpr) = (+)(rhs, lhs)
Base.:(-)(lhs::_DecisionQuadExpr, rhs::_VariableQuadExpr) = (+)(-rhs, lhs)

# _DecisionQuadExpr{C}--_KnownQuadExpr{C}
function Base.:(+)(lhs::_DecisionQuadExpr{C}, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::_DecisionQuadExpr{C}, rhs::_KnownQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

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
    _KnownQuadExpr{C}
=#

# _KnownQuadExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::_KnownQuadExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::_KnownQuadExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(-rhs, lhs)

# _KnownQuadExpr--_VariableAffExpr/_DecisionAffExpr/_KnownAffExpr/DecisionAffExpr
Base.:(+)(lhs::_KnownQuadExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, _KnownAffExpr, DecisionAffExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::_KnownQuadExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, _KnownAffExpr, DecisionAffExpr}) = (+)(-rhs, lhs)
Base.:(*)(lhs::_KnownQuadExpr, rhs::DecisionAffExpr) = error("Cannot multiply a quadratic expression by an affine expression")

# _KnownQuadExpr--_VariableQuadExpr/_DecisionQuadExpr
Base.:(+)(lhs::_KnownQuadExpr, rhs::Union{_VariableQuadExpr, _DecisionQuadExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::_KnownQuadExpr, rhs::Union{_VariableQuadExpr, _DecisionQuadExpr}) = (+)(-rhs, lhs)

# _KnownQuadExpr{C}--DecisionQuadExpr{C}
Base.:(+)(lhs::_KnownQuadExpr, rhs::DecisionQuadExpr) = (+)(rhs, lhs)
Base.:(-)(lhs::_KnownQuadExpr, rhs::DecisionQuadExpr) = (+)(-rhs, lhs)

#=
    DecisionQuadExpr{C}
=#

function Base.:(-)(lhs::DecisionQuadExpr{C}) where C
    result = zero(DecisionQuadExpr{C})
    JuMP.add_to_expression!(result, -1., lhs.variables)
    JuMP.add_to_expression!(result, -1., lhs.decisions)
    JuMP.add_to_expression!(result, -1., lhs.knowns)
    for (vars, coef) in lhs.cross_terms
        JuMP._add_or_set!(result.cross_terms, vars, -coef)
    end
    for (vars, coef) in lhs.known_variable_terms
        JuMP._add_or_set!(result.known_variable_terms, vars, -coef)
    end
    for (vars, coef) in lhs.known_decision_terms
        JuMP._add_or_set!(result.known_decision_terms, vars, -coef)
    end
    return result
end

# DecisionQuadExpr--_Constant
Base.:(+)(lhs::DecisionQuadExpr, rhs::_Constant) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionQuadExpr, rhs::_Constant) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionQuadExpr, rhs::_Constant) = (*)(rhs, lhs)
Base.:(/)(lhs::DecisionQuadExpr, rhs::_Constant) = (*)(inv(rhs), lhs)

# DecisionQuadExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::DecisionQuadExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionQuadExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(-rhs, lhs)
Base.:(/)(lhs::DecisionQuadExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = error("Cannot divide a quadratic expression by a variable")

# DecisionQuadExpr--_VariableAffExpr/_DecisionAffExpr/_KnownAffExpr
Base.:(+)(lhs::DecisionQuadExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, _KnownAffExpr, DecisionAffExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionQuadExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, _KnownAffExpr, DecisionAffExpr}) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionQuadExpr, rhs::Union{_VariableAffExpr, _DecisionAffExpr, _KnownAffExpr, DecisionAffExpr}) = error("Cannot multiply a quadratic expression by an affine expression")
Base.:(/)(lhs::DecisionQuadExpr, rhs::Union{GenericAffExpr, DecisionAffExpr}) = error("Cannot divide a quadratic expression by an affine expression")

# DecisionQuadExpr{C}--_VariableQuadExpr/_DecisionQuadExpr/_KnownQuadExpr
Base.:(+)(lhs::DecisionQuadExpr, rhs::Union{_VariableQuadExpr, _DecisionQuadExpr, _KnownQuadExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionQuadExpr, rhs::Union{_VariableQuadExpr, _DecisionQuadExpr, _KnownQuadExpr}) = (+)(-rhs, lhs)

# DecisionQuadExpr{C}--DecisionQuadExpr{C}
function Base.:(+)(lhs::DecisionQuadExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = copy(lhs)
    JuMP.add_to_expression!(result, rhs.variables)
    JuMP.add_to_expression!(result, rhs.decisions)
    JuMP.add_to_expression!(result, rhs.knowns)
    add_cross_terms!(result_terms, terms) = begin
        for (vars, coef) in terms
            JuMP._add_or_set!(result_terms, vars, coef)
        end
    end
    add_cross_terms!(result.cross_terms, rhs.cross_terms)
    add_cross_terms!(result.known_variable_terms, rhs.known_variable_terms)
    add_cross_terms!(result.known_decision_terms, rhs.known_decision_terms)
    return result
end
function Base.:(-)(lhs::DecisionQuadExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs.variables)
    JuMP.add_to_expression!(result, lhs.decisions)
    JuMP.add_to_expression!(result, lhs.knowns)
    add_cross_terms!(result_terms, terms) = begin
        for (vars, coef) in terms
            JuMP._add_or_set!(result_terms, vars, -coef)
        end
    end
    add_cross_terms!(result.cross_terms, lhs.cross_terms)
    add_cross_terms!(result.known_variable_terms, lhs.known_variable_terms)
    add_cross_terms!(result.known_decision_terms, lhs.known_decision_terms)
    return result
end
Base.:(*)(lhs::DecisionQuadExpr, rhs::DecisionQuadExpr) = error("Cannot multiply a quadratic expression by a quadratic expression")

Base.promote_rule(V::Type{DecisionRef}, R::Type{<:Real}) = DecisionAffExpr{T}
Base.promote_rule(V::Type{KnownRef}, R::Type{<:Real}) = DecisionAffExpr{T}
Base.promote_rule(V::Type{DecisionRef}, ::Type{<:DecisionAffExpr{T}}) where {T} = DecisionAffExpr{T}
Base.promote_rule(V::Type{KnownRef}, ::Type{<:DecisionAffExpr{T}}) where {T} = DecisionAffExpr{T}
Base.promote_rule(V::Type{DecisionRef}, ::Type{<:DecisionQuadExpr{T}}) where {T} = DecisionQuadExpr{T}
Base.promote_rule(V::Type{KnownRef}, ::Type{<:DecisionQuadExpr{T}}) where {T} = DecisionQuadExpr{T}
Base.promote_rule(::Type{<:DecisionAffExpr{S}}, R::Type{<:Real}) where S = DecisionAffExpr{promote_type(S, R)}
Base.promote_rule(::Type{<:DecisionAffExpr{S}}, ::Type{<:DecisionQuadExpr{T}}) where {S, T} = DecisionQuadExpr{promote_type(S, T)}
Base.promote_rule(::Type{<:DecisionQuadExpr{S}}, R::Type{<:Real}) where S = DecisionQuadExpr{promote_type(S, R)}
