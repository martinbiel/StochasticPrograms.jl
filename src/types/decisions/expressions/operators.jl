# _Constant--DecisionRef
Base.:(+)(lhs::_Constant, rhs::DecisionRef) = CAE(VAE(convert(Float64, lhs)), DAE(0.0, rhs => +one(Float64)), KAE(0.0))
Base.:(-)(lhs::_Constant, rhs::DecisionRef) = CAE(VAE(convert(Float64, lhs)), DAE(0.0, rhs => -one(Float64)), KAE(0.0))
Base.:(*)(lhs::_Constant, rhs::DecisionRef) = CAE(VAE(0.0), DAE(0.0, rhs => lhs), KAE(0.0))

# _Constant--KnownRef
Base.:(+)(lhs::_Constant, rhs::KnownRef) = CAE(VAE(convert(Float64, lhs)), DAE(0.0), KAE(0.0, rhs => +one(Float64)))
Base.:(-)(lhs::_Constant, rhs::KnownRef) = CAE(VAE(convert(Float64, lhs)), DAE(0.0), KAE(0.0, rhs => -one(Float64)))
Base.:(*)(lhs::_Constant, rhs::KnownRef) = CAE(VAE(0.0), DAE(0.0), KAE(0.0, rhs => lhs))

# _Constant--CombinedAffExpr{C}
Base.:(+)(lhs::_Constant, rhs::CombinedAffExpr{C}) where C =
    CombinedAffExpr(convert(C,lhs) + rhs.variables,
                    copy(rhs.decisions),
                    copy(rhs.knowns))
Base.:(-)(lhs::_Constant, rhs::CombinedAffExpr{C}) where C =
    CombinedAffExpr(convert(C,lhs) - rhs.variables,
                    -rhs.decisions,
                    -rhs.knowns)
Base.:(*)(lhs::_Constant, rhs::CombinedAffExpr{C}) where C =
    CombinedAffExpr(convert(C,lhs) * rhs.variables,
                    convert(C,lhs) * rhs.decisions,
                    convert(C,lhs) * rhs.knowns)

# _Constant--CombinedQuadExpr{C}
Base.:(+)(lhs::_Constant, rhs::CombinedQuadExpr{C}) where C =
    CombinedQuadExpr(convert(C,lhs) + rhs.variables,
                     copy(rhs.decisions),
                     copy(rhs.knowns),
                     copy(rhs.cross_terms),
                     copy(rhs.known_variable_terms),
                     copy(rhs.known_decision_terms))
Base.:(-)(lhs::_Constant, rhs::CombinedQuadExpr{C}) where C =
    CombinedQuadExpr(convert(C,lhs) - rhs.variables,
                     copy(rhs.decisions),
                     copy(rhs.knowns),
                     copy(rhs.cross_terms),
                     copy(rhs.known_variable_terms),
                     copy(rhs.known_decision_terms))
Base.:(*)(lhs::_Constant, rhs::CombinedQuadExpr{C}) where C =
    CombinedQuadExpr(convert(C,lhs) * rhs.variables,
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
Base.:(+)(lhs::VariableRef, rhs::DecisionRef) = CAE(VAE(0.0, lhs => 1.0), DAE(0.0, rhs =>  1.0), KAE(0.0))
Base.:(-)(lhs::VariableRef, rhs::DecisionRef) = CAE(VAE(0.0, lhs => 1.0), DAE(0.0, rhs => -1.0), KAE(0.0))
function Base.:(*)(lhs::VariableRef, rhs::DecisionRef)
    result = zero(CQE)
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# VariableRef--KnownRef
Base.:(+)(lhs::VariableRef, rhs::KnownRef) = CAE(VAE(0.0, lhs => 1.0), DAE(0.0), KAE(0.0, rhs =>  1.0))
Base.:(-)(lhs::VariableRef, rhs::KnownRef) = CAE(VAE(0.0, lhs => 1.0), DAE(0.0), KAE(0.0, rhs => -1.0))
function Base.:(*)(lhs::VariableRef, rhs::KnownRef)
    result = zero(CQE)
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# VariableRef--DecisionAffExpr{C}
Base.:(+)(lhs::VariableRef, rhs::DecisionAffExpr{C}) where C = CombinedAffExpr{C}(VariableAffExpr{C}(zero(C), lhs => 1.), copy(rhs), zero(KnownAffExpr{C}))
Base.:(-)(lhs::VariableRef, rhs::DecisionAffExpr{C}) where C = CombinedAffExpr{C}(VariableAffExpr{C}(zero(C), lhs => 1.), -rhs, zero(KnownAffExpr{C}))
function Base.:(*)(lhs::VariableRef, rhs::DecisionAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# VariableRef--DecisionQuadExpr{C}
function Base.:(+)(lhs::VariableRef, rhs::DecisionQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expressoin(result, rhs)
    return result
end
function Base.:(-)(lhs::VariableRef, rhs::DecisionQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# VariableRef--KnownAffExpr{C}
Base.:(+)(lhs::VariableRef, rhs::KnownAffExpr{C}) where C = CombinedAffExpr{C}(VariableAffExpr{C}(zero(C), lhs => 1.), zero(DecisionAffExpr{C}), copy(rhs))
Base.:(-)(lhs::VariableRef, rhs::KnownAffExpr{C}) where C = CombinedAffExpr{C}(VariableAffExpr{C}(zero(C), lhs => 1.), zero(DecisionAffExpr{C}), -rhs)
function Base.:(*)(lhs::VariableRef, rhs::KnownAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# VariableRef--KnownQuadExpr{C}
function Base.:(+)(lhs::VariableRef, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::VariableRef, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# VariableRef--CombinedAffExpr{C}
Base.:(+)(lhs::VariableRef, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(lhs + rhs.variables, copy(rhs.decisions), copy(rhs.knowns))
Base.:(-)(lhs::VariableRef, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(lhs - rhs.variables, -rhs.decisions, -rhs.knowns)
function Base.:(*)(lhs::VariableRef, rhs::CombinedAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end
Base.:/(lhs::VariableRef, rhs::CombinedAffExpr) = error("Cannot divide a variable by an affine expression")

# VariableRef--CombinedQuadExpr{C}
function Base.:(+)(lhs::VariableRef, rhs::CombinedQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::VariableRef, rhs::CombinedQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end
Base.:(*)(lhs::VariableRef, rhs::CombinedQuadExpr) = error("Cannot multiply a quadratic expression by a variable")

#=
    DecisionRef
=#

# DecisionRef
Base.:(-)(lhs::DecisionRef) = CAE(VAE(0.0), DAE(0.0, lhs => -1.0), KAE(0.0))

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
Base.:(+)(lhs::DecisionRef, rhs::DecisionRef) = CAE(VAE(0.0), DAE(0.0, lhs => 1.0, rhs => +1.0), KAE(0.0))
Base.:(-)(lhs::DecisionRef, rhs::DecisionRef) = CAE(VAE(0.0), DAE(0.0, lhs => 1.0, rhs => -1.0), KAE(0.0))
function Base.:(*)(lhs::DecisionRef, rhs::DecisionRef)
    result = zero(CQE)
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# DecisionRef--KnownRef
Base.:(+)(lhs::DecisionRef, rhs::KnownRef) = CAE(VAE(0.0), DAE(0.0, lhs => 1.0), KAE(0.0, rhs => +1.0))
Base.:(-)(lhs::DecisionRef, rhs::KnownRef) = CAE(VAE(0.0), DAE(0.0, lhs => 1.0), KAE(0.0, rhs => -1.0))
function Base.:(*)(lhs::DecisionRef, rhs::KnownRef)
    result = zero(CQE)
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# DecisionRef--VariableAffExpr{C}
Base.:(+)(lhs::DecisionRef, rhs::VariableAffExpr{C}) where C = CombinedAffExpr{C}(rhs, DecisionAffExpr{C}(zero(C), lhs => 1.), zero(KnownAffExpr{C}))
Base.:(-)(lhs::DecisionRef, rhs::VariableAffExpr{C}) where C = CombinedAffExpr{C}(-rhs, DecisionAffExpr{C}(zero(C), lhs => 1.), zero(KnownAffExpr{C}))
function Base.:(*)(lhs::DecisionRef, rhs::VariableAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# DecisionRef--VariableQuadExpr{C}
function Base.:(+)(lhs::DecisionRef, rhs::VariableQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::DecisionRef, rhs::VariableQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# DecisionRef--DecisionAffExpr{C}
Base.:(+)(lhs::DecisionRef, rhs::DecisionAffExpr{C}) where C = (+)(DecisionAffExpr{C}(zero(C), lhs => 1.0),  rhs)
Base.:(-)(lhs::DecisionRef, rhs::DecisionAffExpr{C}) where C = (+)(DecisionAffExpr{C}(zero(C), lhs => 1.0), -rhs)
function Base.:(*)(lhs::DecisionRef, rhs::DecisionAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# DecisionRef--DecisionQuadExpr{C}
function Base.:(+)(lhs::DecisionRef, rhs::DecisionQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expressoin(result, rhs)
    return result
end
function Base.:(-)(lhs::DecisionRef, rhs::DecisionQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expressoin(result, lhs)
    JuMP.add_to_expressoin(result, -1., rhs)
    return result
end

# DecisionRef--KnownAffExpr{C}
Base.:(+)(lhs::DecisionRef, rhs::KnownAffExpr{C}) where C = CombinedAffExpr{C}(zero(VariableAffExpr{C}), DecisionAffExpr{C}(zero(C), lhs => 1), copy(rhs))
Base.:(-)(lhs::DecisionRef, rhs::KnownAffExpr{C}) where C = CombinedAffExpr{C}(zero(VariableAffExpr{C}), DecisionAffExpr{C}(zero(C), lhs => 1.), -rhs)
function Base.:(*)(lhs::DecisionRef, rhs::KnownAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# DecisionRef--KnownQuadExpr{C}
function Base.:(+)(lhs::DecisionRef, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::DecisionRef, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# DecisionRef--CombinedAffExpr{C}
Base.:(+)(lhs::DecisionRef, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(copy(rhs.variables), lhs+rhs.decisions, copy(rhs.knowns))
Base.:(-)(lhs::DecisionRef, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(-rhs.variables, lhs-rhs.decisions, -rhs.knowns)
function Base.:(*)(lhs::DecisionRef, rhs::CombinedAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end
Base.:/(lhs::DecisionRef, rhs::CombinedAffExpr) = error("Cannot divide a decision by an affine expression")

# DecisionRef--CombinedQuadExpr{C}
function Base.:(+)(lhs::DecisionRef, rhs::CombinedQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::DecisionRef, rhs::CombinedQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end
Base.:(*)(lhs::DecisionRef, rhs::CombinedQuadExpr) = error("Cannot multiply a quadratic expression by a variable")


#=
    KnownRef
=#

# KnownRef
Base.:(-)(lhs::KnownRef) = CAE(VAE(0.0), DAE(0.0), KAE(0.0, lhs => -1.0))

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
Base.:(+)(lhs::KnownRef, rhs::KnownRef) = CAE(VAE(0.0), DAE(0.0), KAE(0.0, lhs => 1.0, rhs => +1.0))
Base.:(-)(lhs::KnownRef, rhs::KnownRef) = CAE(VAE(0.0), DAE(0.0), KAE(0.0, lhs => 1.0, rhs => -1.0))
function Base.:(*)(lhs::KnownRef, rhs::KnownRef)
    result = zero(CQE)
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# KnownRef--VariableAffExpr{C}
Base.:(+)(lhs::KnownRef, rhs::VariableAffExpr{C}) where C = CombinedAffExpr{C}(copy(rhs), zero(DecisionAffExpr{C}), KnownAffExpr{C}(zero(C), lhs => 1.))
Base.:(-)(lhs::KnownRef, rhs::VariableAffExpr{C}) where C = CombinedAffExpr{C}(-rhs, zero(DecisionAffExpr{C}), KnownAffExpr{C}(zero(C), lhs => 1.))
function Base.:(*)(lhs::KnownRef, rhs::VariableAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# KnownRef--VariableQuadExpr{C}
function Base.:(+)(lhs::KnownRef, rhs::VariableQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::KnownRef, rhs::VariableQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# KnownRef--DecisionAffExpr{C}
Base.:(+)(lhs::KnownRef, rhs::DecisionAffExpr{C}) where C = CombinedAffExpr{C}(zero(VariableAffExpr{C}), rhs, KnownAffExpr{C}(zero(C), lhs => 1.))
Base.:(-)(lhs::KnownRef, rhs::DecisionAffExpr{C}) where C = CombinedAffExpr{C}(zero(VariableAffExpr{C}), -rhs, KnownAffExpr{C}(zero(C), lhs => 1.))
function Base.:(*)(lhs::KnownRef, rhs::DecisionAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# KnownRef--DecisionQuadExpr{C}
function Base.:(+)(lhs::KnownRef, rhs::DecisionQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expressoin(result, rhs)
    return result
end
function Base.:(-)(lhs::KnownRef, rhs::DecisionQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expressoin(result, lhs)
    JuMP.add_to_expressoin(result, -1., rhs)
    return result
end

# KnownRef--KnownAffExpr{C}
Base.:(+)(lhs::KnownRef, rhs::KnownAffExpr{C}) where C = (+)(KnownAffExpr{C}(zero(C), lhs => 1.0),  rhs)
Base.:(-)(lhs::KnownRef, rhs::KnownAffExpr{C}) where C = (+)(KnownAffExpr{C}(zero(C), lhs => 1.0), -rhs)
function Base.:(*)(lhs::KnownRef, rhs::KnownAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# KnownRef--KnownQuadExpr{C}
function Base.:(+)(lhs::KnownRef, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::KnownRef, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# KnownRef--CombinedAffExpr{C}
Base.:(+)(lhs::KnownRef, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(copy(rhs.variables), copy(rhs.decisions), lhs+rhs.knowns)
Base.:(-)(lhs::KnownRef, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(-rhs.variables, -rhs.decisions, lhs-rhs.knowns)
function Base.:(*)(lhs::KnownRef, rhs::CombinedAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end
Base.:/(lhs::KnownRef, rhs::CombinedAffExpr) = error("Cannot divide a known decision by an affine expression")

# KnownRef--CombinedQuadExpr{C}
function Base.:(+)(lhs::KnownRef, rhs::CombinedQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::KnownRef, rhs::CombinedQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end
Base.:(*)(lhs::KnownRef, rhs::CombinedQuadExpr) = error("Cannot multiply a quadratic expression by a variable")

#=
    VariableAffExpr{C}
=#

# VariableAffExpr--DecisionRef/KnownRef
Base.:(+)(lhs::VariableAffExpr, rhs::Union{DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::VariableAffExpr, rhs::Union{DecisionRef, KnownRef}) = (+)(-rhs, lhs)
Base.:(*)(lhs::VariableAffExpr, rhs::Union{DecisionRef, KnownRef}) = (*)(rhs, lhs)

# VariableAffExpr{C}--DecisionAffExpr{C}
Base.:(+)(lhs::VariableAffExpr{C}, rhs::DecisionAffExpr{C}) where C = CombinedAffExpr{C}(copy(lhs), copy(rhs), zero(KnownAffExpr{C}))
Base.:(-)(lhs::VariableAffExpr{C}, rhs::DecisionAffExpr{C}) where C = CombinedAffExpr{C}(copy(lhs), -rhs, zero(KnownAffExpr{C}))
function Base.:(*)(lhs::VariableAffExpr{C}, rhs::DecisionAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# VariableAffExpr{C}--DecisionQuadExpr{C}
function Base.:(+)(lhs::VariableAffExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expressoin(result, rhs)
    return result
end
function Base.:(-)(lhs::VariableAffExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# VariableAffExpr{C}--KnownAffExpr{C}
Base.:(+)(lhs::VariableAffExpr{C}, rhs::KnownAffExpr{C}) where C = CombinedAffExpr{C}(copy(lhs), zero(DecisionAffExpr{C}), copy(rhs))
Base.:(-)(lhs::VariableAffExpr{C}, rhs::KnownAffExpr{C}) where C = CombinedAffExpr{C}(copy(lhs), zero(DecisionAffExpr{C}), -rhs)
function Base.:(*)(lhs::VariableAffExpr{C}, rhs::KnownAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# VariableAffExpr{C}--KnownQuadExpr{C}
function Base.:(+)(lhs::VariableAffExpr{C}, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::VariableAffExpr{C}, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end
Base.:(*)(lhs::VariableAffExpr, rhs::KnownQuadExpr) = error("Cannot multiply a quadratic expression by an affine expression")

# VariableRef{C}--CombinedAffExpr{C}
Base.:(+)(lhs::VariableAffExpr{C}, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(lhs+rhs.variables, copy(rhs.decisions), copy(rhs.knowns))
Base.:(-)(lhs::VariableAffExpr{C}, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(lhs-rhs.variables, -rhs.decisions, -rhs.knowns)
function Base.:(*)(lhs::VariableAffExpr{C}, rhs::CombinedAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# VariableAffExpr{C}--CombinedQuadExpr{C}
function Base.:(+)(lhs::VariableAffExpr{C}, rhs::CombinedQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::VariableAffExpr{C}, rhs::CombinedQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end
Base.:(*)(lhs::VariableAffExpr, rhs::CombinedQuadExpr) = error("Cannot multiply a quadratic expression by an affine expression")

#=
    DecisionAffExpr{C}
=#

# DecisionAffExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::DecisionAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (*)(rhs, lhs)

# DecisionAffExpr--VariableAffExpr
Base.:(+)(lhs::DecisionAffExpr, rhs::VariableAffExpr) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionAffExpr, rhs::VariableAffExpr) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionAffExpr, rhs::VariableAffExpr) = (*)(rhs, lhs)

# DecisionAffExpr{C}--VariableQuadExpr{C}
function Base.:(+)(lhs::DecisionAffExpr{C}, rhs::VariableQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::DecisionAffExpr{C}, rhs::VariableQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# DecisionAffExpr--KnownAffExpr
Base.:(+)(lhs::DecisionAffExpr, rhs::KnownAffExpr) = CombinedAffExpr{C}(zero(VariableAffExpr{C}), copy(lhs), copy(rhs))
Base.:(-)(lhs::DecisionAffExpr, rhs::KnownAffExpr) = CombinedAffExpr{C}(zero(VariableAffExpr{C}), copy(lhs), -rhs)
function Base.:(*)(lhs::DecisionAffExpr{C}, rhs::KnownAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# DecisionAffExpr{C}--KnownQuadExpr{C}
function Base.:(+)(lhs::DecisionAffExpr{C}, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::DecisionAffExpr{C}, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# DecisionAffExpr{C}--CombinedAffExpr{C}
Base.:(+)(lhs::DecisionAffExpr{C}, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(copy(rhs.variables), lhs+rhs.decisions, copy(rhs.knowns))
Base.:(-)(lhs::DecisionAffExpr{C}, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(-rhs.variables, lhs-rhs.decisions, -rhs.knowns)
function Base.:(*)(lhs::DecisionAffExpr{C}, rhs::CombinedAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# DecisionAffExpr{C}--CombinedQuadExpr{C}
function Base.:(+)(lhs::DecisionAffExpr{C}, rhs::CombinedQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::DecisionAffExpr{C}, rhs::CombinedQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end
Base.:(*)(lhs::DecisionAffExpr, rhs::CombinedQuadExpr) = error("Cannot multiply a quadratic expression by an affine expression")

#=
    KnownAffExpr{C}
=#

# KnownAffExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::KnownAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::KnownAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(-rhs, lhs)
Base.:(*)(lhs::KnownAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (*)(rhs, lhs)

# KnownAffExpr--VariableAffExpr
Base.:(+)(lhs::KnownAffExpr, rhs::VariableAffExpr) = (+)(rhs, lhs)
Base.:(-)(lhs::KnownAffExpr, rhs::VariableAffExpr) = (+)(-rhs, lhs)
Base.:(*)(lhs::KnownAffExpr, rhs::VariableAffExpr) = (*)(rhs, lhs)

# KnownAffExpr{C}--VariableQuadExpr{C}
function Base.:(+)(lhs::KnownAffExpr{C}, rhs::VariableQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::KnownAffExpr{C}, rhs::VariableQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# KnownAffExpr--DecisionAffExpr
Base.:(+)(lhs::KnownAffExpr, rhs::DecisionAffExpr) = (+)(rhs, lhs)
Base.:(-)(lhs::KnownAffExpr, rhs::DecisionAffExpr) = (+)(-rhs, lhs)
Base.:(*)(lhs::KnownAffExpr, rhs::DecisionAffExpr) = (*)(rhs, lhs)

# KnownAffExpr{C}--DecisionQuadExpr{C}
function Base.:(+)(lhs::KnownAffExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expressoin(result, rhs)
    return result
end
function Base.:(-)(lhs::KnownAffExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expressoin(result, lhs)
    JuMP.add_to_expressoin(result, -1., rhs)
    return result
end

# KnownAffExpr{C}--CombinedAffExpr{C}
Base.:(+)(lhs::KnownAffExpr{C}, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(copy(rhs.variables), copy(rhs.decisions), lhs+rhs.knowns)
Base.:(-)(lhs::KnownAffExpr{C}, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(-rhs.variables, -rhs.decisions, lhs-rhs.knowns)
function Base.:(*)(lhs::KnownAffExpr{C}, rhs::CombinedAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# KnownAffExpr{C}--CombinedQuadExpr{C}
function Base.:(+)(lhs::KnownAffExpr{C}, rhs::CombinedQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::KnownAffExpr{C}, rhs::CombinedQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end

#=
    CombinedAffExpr{C}
=#

Base.:(-)(lhs::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(-lhs.variables, -lhs.decisions, -lhs.knowns)

# CombinedAffExpr--_Constant
Base.:(+)(lhs::CombinedAffExpr, rhs::_Constant) = (+)(rhs, lhs)
Base.:(-)(lhs::CombinedAffExpr, rhs::_Constant) = (+)(-rhs, lhs)
Base.:(*)(lhs::CombinedAffExpr, rhs::_Constant) = (*)(rhs, lhs)
Base.:/(lhs::CombinedAffExpr, rhs::_Constant) = map_coefficients(c -> c/rhs, lhs)
function Base.:^(lhs::CombinedAffExpr{C}, rhs::Integer) where C
    if rhs == 2
        return lhs*lhs
    elseif rhs == 1
        return convert(CombinedQuadExpr{C}, lhs)
    elseif rhs == 0
        return one(GenericQuadExpr{C})
    else
        error("Only exponents of 0, 1, or 2 are currently supported.")
    end
end
Base.:^(lhs::CombinedAffExpr, rhs::_Constant) = error("Only exponents of 0, 1, or 2 are currently supported.")

# CombinedAffExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::CombinedAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::CombinedAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(-rhs, lhs)
Base.:(*)(lhs::CombinedAffExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (*)(rhs, lhs)
Base.:/(lhs::CombinedAffExpr, rhs::VariableRef) = error("Cannot divide affine expression by a variable")
Base.:/(lhs::CombinedAffExpr, rhs::DecisionRef) = error("Cannot divide affine expression by a decision")
Base.:/(lhs::CombinedAffExpr, rhs::KnownRef) = error("Cannot divide affine expression by a known decision s")

# CombinedAffExpr--VariableAffExpr/DecisionAffExpr/KnownAffExpr
Base.:(+)(lhs::CombinedAffExpr, rhs::Union{VariableAffExpr, DecisionAffExpr, KnownAffExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::CombinedAffExpr, rhs::Union{VariableAffExpr, DecisionAffExpr, KnownAffExpr}) = (+)(-rhs, lhs)
Base.:(*)(lhs::CombinedAffExpr, rhs::Union{VariableAffExpr, DecisionAffExpr, KnownAffExpr}) = (*)(rhs, lhs)

# CombinedAffExpr{C}--CombinedAffExpr{C}
Base.:(+)(lhs::CombinedAffExpr{C}, rhs::CombinedAffExpr{C}) where C =
    CombinedAffExpr{C}(lhs.variables+rhs.variables,
                       lhs.decisions+rhs.decisions,
                       lhs.knowns+rhs.knowns)
Base.:(-)(lhs::CombinedAffExpr{C}, rhs::CombinedAffExpr{C}) where C =
    CombinedAffExpr{C}(lhs.variables-rhs.variables,
                       lhs.decisions-rhs.decisions,
                       lhs.knowns-rhs.knowns)
function Base.:(*)(lhs::CombinedAffExpr{C}, rhs::CombinedAffExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs, rhs)
    return result
end

# CombinedAffExpr{C}--VariableQuadExpr{C}
function Base.:(+)(lhs::CombinedAffExpr{C}, rhs::VariableQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::CombinedAffExpr{C}, rhs::VariableQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# CombinedAffExpr{C}--DecisionQuadExpr{C}
function Base.:(+)(lhs::CombinedAffExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::CombinedAffExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# CombinedAffExpr{C}--KnownQuadExpr{C}
function Base.:(+)(lhs::CombinedAffExpr{C}, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::CombinedAffExpr{C}, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

Base.:(*)(lhs::CombinedAffExpr, rhs::Union{VariableQuadExpr, DecisionQuadExpr, KnownQuadExpr}) = error("Cannot multiply a quadratic expression by an affine expression")

# CombinedAffExpr{C}--CombinedQuadExpr{C}
function Base.:(+)(lhs::CombinedAffExpr{C}, rhs::CombinedQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::CombinedAffExpr{C}, rhs::CombinedQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end
Base.:(*)(lhs::CombinedAffExpr, rhs::CombinedQuadExpr) = error("Cannot multiply a quadratic expression by an affine expression")

#=
    VariableQuadExpr{C}
=#

# VariableQuadExpr--DecisionRef/KnownRef
Base.:(+)(lhs::VariableQuadExpr, rhs::Union{DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::VariableQuadExpr, rhs::Union{DecisionRef, KnownRef}) = (+)(-rhs, lhs)

# VariableQuadExpr--DecisionAffExpr/KnownAffExpr/CombinedAffExpr
Base.:(+)(lhs::VariableQuadExpr, rhs::Union{DecisionAffExpr, KnownAffExpr, CombinedAffExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::VariableQuadExpr, rhs::Union{DecisionAffExpr, KnownAffExpr, CombinedAffExpr}) = (+)(-rhs, lhs)
Base.:(*)(lhs::VariableQuadExpr, rhs::CombinedAffExpr) = error("Cannot multiply a quadratic expression by an affine expression")

# VariableQuadExpr{C}--DecisionQuadExpr{C}
function Base.:(+)(lhs::VariableQuadExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expressoin(result, rhs)
    return result
end
function Base.:(-)(lhs::VariableQuadExpr{C}, rhs::DecisionQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# VariableQuadExpr{C}--KnownQuadExpr{C}
function Base.:(+)(lhs::VariableQuadExpr{C}, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::VariableQuadExpr{C}, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# VariableQuadExpr{C}--CombinedQuadExpr{C}
function Base.:(+)(lhs::VariableQuadExpr{C}, rhs::CombinedQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::VariableQuadExpr{C}, rhs::CombinedQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end

#=
    DecisionQuadExpr{C}
=#

# DecisionQuadExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::DecisionQuadExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionQuadExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(-rhs, lhs)

# DecisionQuadExpr--VariableAffExpr
Base.:(+)(lhs::DecisionQuadExpr, rhs::Union{VariableAffExpr, DecisionAffExpr, KnownAffExpr, CombinedAffExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionQuadExpr, rhs::Union{VariableAffExpr, DecisionAffExpr, KnownAffExpr, CombinedAffExpr}) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionQuadExpr, rhs::CombinedAffExpr) = error("Cannot multiply a quadratic expression by an affine expression")

# DecisionQuadExpr{C}--VariableQuadExpr{C}
Base.:(+)(lhs::DecisionQuadExpr, rhs::VariableQuadExpr) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionQuadExpr, rhs::VariableQuadExpr) = (+)(-rhs, lhs)

# DecisionQuadExpr{C}--KnownQuadExpr{C}
function Base.:(+)(lhs::DecisionQuadExpr{C}, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, rhs)
    return result
end
function Base.:(-)(lhs::DecisionQuadExpr{C}, rhs::KnownQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
    JuMP.add_to_expression!(result, lhs)
    JuMP.add_to_expression!(result, -1., rhs)
    return result
end

# DecisionQuadExpr{C}--CombinedQuadExpr{C}
function Base.:(+)(lhs::DecisionQuadExpr{C}, rhs::CombinedQuadExpr{C}) where C
    result = copy(rhs)
    JuMP.add_to_expression!(result, lhs)
    return result
end
function Base.:(-)(lhs::DecisionQuadExpr{C}, rhs::CombinedQuadExpr{C}) where C
    result = -rhs
    JuMP.add_to_expression!(result, lhs)
    return result
end

#=
    KnownQuadExpr{C}
=#

# KnownQuadExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::KnownQuadExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::KnownQuadExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(-rhs, lhs)

# KnownQuadExpr--VariableAffExpr/DecisionAffExpr/KnownAffExpr/CombinedAffExpr
Base.:(+)(lhs::KnownQuadExpr, rhs::Union{VariableAffExpr, DecisionAffExpr, KnownAffExpr, CombinedAffExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::KnownQuadExpr, rhs::Union{VariableAffExpr, DecisionAffExpr, KnownAffExpr, CombinedAffExpr}) = (+)(-rhs, lhs)
Base.:(*)(lhs::KnownQuadExpr, rhs::CombinedAffExpr) = error("Cannot multiply a quadratic expression by an affine expression")

# KnownQuadExpr--VariableQuadExpr/DecisionQuadExpr
Base.:(+)(lhs::KnownQuadExpr, rhs::Union{VariableQuadExpr, DecisionQuadExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::KnownQuadExpr, rhs::Union{VariableQuadExpr, DecisionQuadExpr}) = (+)(-rhs, lhs)

# KnownQuadExpr{C}--CombinedQuadExpr{C}
Base.:(+)(lhs::KnownQuadExpr, rhs::CombinedQuadExpr) = (+)(rhs, lhs)
Base.:(-)(lhs::KnownQuadExpr, rhs::CombinedQuadExpr) = (+)(-rhs, lhs)

#=
    CombinedQuadExpr{C}
=#

function Base.:(-)(lhs::CombinedQuadExpr{C}) where C
    result = zero(CombinedQuadExpr{C})
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

# CombinedQuadExpr--_Constant
Base.:(+)(lhs::CombinedQuadExpr, rhs::_Constant) = (+)(rhs, lhs)
Base.:(-)(lhs::CombinedQuadExpr, rhs::_Constant) = (+)(-rhs, lhs)
Base.:(*)(lhs::CombinedQuadExpr, rhs::_Constant) = (*)(rhs, lhs)
Base.:(/)(lhs::CombinedQuadExpr, rhs::_Constant) = (*)(inv(rhs), lhs)

# CombinedQuadExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::CombinedQuadExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(rhs, lhs)
Base.:(-)(lhs::CombinedQuadExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = (+)(-rhs, lhs)
Base.:(/)(lhs::CombinedQuadExpr, rhs::Union{VariableRef, DecisionRef, KnownRef}) = error("Cannot divide a quadratic expression by a variable")

# CombinedQuadExpr--VariableAffExpr/DecisionAffExpr/KnownAffExpr
Base.:(+)(lhs::CombinedQuadExpr, rhs::Union{VariableAffExpr, DecisionAffExpr, KnownAffExpr, CombinedAffExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::CombinedQuadExpr, rhs::Union{VariableAffExpr, DecisionAffExpr, KnownAffExpr, CombinedAffExpr}) = (+)(-rhs, lhs)
Base.:(*)(lhs::CombinedQuadExpr, rhs::Union{VariableAffExpr, DecisionAffExpr, KnownAffExpr, CombinedAffExpr}) = error("Cannot multiply a quadratic expression by an affine expression")
Base.:(/)(lhs::CombinedQuadExpr, rhs::Union{GenericAffExpr, CombinedAffExpr}) = error("Cannot divide a quadratic expression by an affine expression")

# CombinedQuadExpr{C}--VariableQuadExpr/DecisionQuadExpr/KnownQuadExpr
Base.:(+)(lhs::CombinedQuadExpr, rhs::Union{VariableQuadExpr, DecisionQuadExpr, KnownQuadExpr}) = (+)(rhs, lhs)
Base.:(-)(lhs::CombinedQuadExpr, rhs::Union{VariableQuadExpr, DecisionQuadExpr, KnownQuadExpr}) = (+)(-rhs, lhs)

# CombinedQuadExpr{C}--CombinedQuadExpr{C}
function Base.:(+)(lhs::CombinedQuadExpr{C}, rhs::CombinedQuadExpr{C}) where C
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
function Base.:(-)(lhs::CombinedQuadExpr{C}, rhs::CombinedQuadExpr{C}) where C
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
Base.:(*)(lhs::CombinedQuadExpr, rhs::CombinedQuadExpr) = error("Cannot multiply a quadratic expression by a quadratic expression")
