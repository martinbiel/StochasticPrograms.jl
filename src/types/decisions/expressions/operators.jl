# Number--DecisionRef
Base.:(+)(lhs::Number, rhs::DecisionRef) = CAE(VAE(convert(Float64, lhs)), DAE(0.0, rhs => +one(Float64)), KAE(0.0))
Base.:(-)(lhs::Number, rhs::DecisionRef) = CAE(VAE(convert(Float64, lhs)), DAE(0.0, rhs => -one(Float64)), KAE(0.0))
Base.:(*)(lhs::Number, rhs::DecisionRef) = CAE(VAE(0.0), DAE(0.0, rhs => lhs), KAE(0.0))

# Number--KnownRef
Base.:(+)(lhs::Number, rhs::KnownRef) = CAE(VAE(convert(Float64, lhs)), DAE(0.0), KAE(0.0, rhs => +one(Float64)))
Base.:(-)(lhs::Number, rhs::KnownRef) = CAE(VAE(convert(Float64, lhs)), DAE(0.0), KAE(0.0, rhs => -one(Float64)))
Base.:(*)(lhs::Number, rhs::KnownRef) = CAE(VAE(0.0), DAE(0.0), KAE(0.0, rhs => lhs))

# Number--CombinedAffExpr{C}
Base.:(+)(lhs::Number, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr(convert(C,lhs)+rhs.variables, copy(rhs.decisions), copy(rhs.knowns))
Base.:(-)(lhs::Number, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr(convert(C,lhs)-rhs.variables, -rhs.decisions, -rhs.knowns)
Base.:(*)(lhs::Number, rhs::CombinedAffExpr{C}) where C = CombinedAffExpr(convert(C,lhs)*rhs.variables,
                                                                          convert(C,lhs)*rhs.decisions,
                                                                          convert(C,lhs)*rhs.knowns)

#=
    VariableRef
=#

# VariableRef--DecisionRef
Base.:(+)(lhs::JuMP.VariableRef, rhs::DecisionRef) = CAE(VAE(0.0, lhs => 1.0), DAE(0.0, rhs =>  1.0), KAE(0.0))
Base.:(-)(lhs::JuMP.VariableRef, rhs::DecisionRef) = CAE(VAE(0.0, lhs => 1.0), DAE(0.0, rhs => -1.0), KAE(0.0))

# VariableRef--KnownRef
Base.:(+)(lhs::JuMP.VariableRef, rhs::KnownRef) = CAE(VAE(0.0, lhs => 1.0), DAE(0.0), KAE(0.0, rhs =>  1.0))
Base.:(-)(lhs::JuMP.VariableRef, rhs::KnownRef) = CAE(VAE(0.0, lhs => 1.0), DAE(0.0), KAE(0.0, rhs => -1.0))

# VariableRef--DecisionAffExpr{C}
Base.:(+)(lhs::JuMP.VariableRef, rhs::DecisionAffExpr{C}) where {C} = CombinedAffExpr{C}(VariableAffExpr{C}(zero(C), lhs => 1.), copy(rhs), zero(KnownAffExpr{C}))
Base.:(-)(lhs::JuMP.VariableRef, rhs::DecisionAffExpr{C}) where {C} = CombinedAffExpr{C}(VariableAffExpr{C}(zero(C), lhs => 1.), -rhs, zero(KnownAffExpr{C}))

# VariableRef--KnownAffExpr{C}
Base.:(+)(lhs::JuMP.VariableRef, rhs::KnownAffExpr{C}) where {C} = CombinedAffExpr{C}(VariableAffExpr{C}(zero(C), lhs => 1.), zero(DecisionAffExpr{C}), copy(rhs))
Base.:(-)(lhs::JuMP.VariableRef, rhs::KnownAffExpr{C}) where {C} = CombinedAffExpr{C}(VariableAffExpr{C}(zero(C), lhs => 1.), zero(DecisionAffExpr{C}), -rhs)

# VariableRef--CombinedAffExpr{C}
Base.:(+)(lhs::JuMP.VariableRef, rhs::CombinedAffExpr{C}) where {C} = CombinedAffExpr{C}(lhs + rhs.variables, copy(rhs.decisions), copy(rhs.knowns))
Base.:(-)(lhs::JuMP.VariableRef, rhs::CombinedAffExpr{C}) where {C} = CombinedAffExpr{C}(lhs - rhs.variables, -rhs.decisions, -rhs.knowns)

#=
    DecisionRef
=#

# DecisionRef
Base.:(-)(lhs::DecisionRef) = CAE(VAE(0.0), DAE(0.0, lhs => -1.0), KAE(0.0))

# DecisionRef--Number
Base.:(+)(lhs::DecisionRef, rhs::Number) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionRef, rhs::Number) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionRef, rhs::Number) = (*)(rhs, lhs)
Base.:(/)(lhs::DecisionRef, rhs::Number) = (*)(1.0 / rhs, lhs)

# DecisionRef--VariableRef
Base.:(+)(lhs::DecisionRef, rhs::JuMP.VariableRef) = CAE(VAE(0.0, rhs => +1.0), DAE(0.0, lhs => 1.0), KAE(0.0))
Base.:(-)(lhs::DecisionRef, rhs::JuMP.VariableRef) = CAE(VAE(0.0, rhs => -1.0), DAE(0.0, lhs => 1.0), KAE(0.0))

# DecisionRef--DecisionRef
Base.:(+)(lhs::DecisionRef, rhs::DecisionRef) = CAE(VAE(0.0), DAE(0.0, lhs => 1.0, rhs => +1.0), KAE(0.0))
Base.:(-)(lhs::DecisionRef, rhs::DecisionRef) = CAE(VAE(0.0), DAE(0.0, lhs => 1.0, rhs => -1.0), KAE(0.0))

# DecisionRef--KnownRef
Base.:(+)(lhs::DecisionRef, rhs::KnownRef) = CAE(VAE(0.0), DAE(0.0, lhs => 1.0), KAE(0.0, rhs => +1.0))
Base.:(-)(lhs::DecisionRef, rhs::KnownRef) = CAE(VAE(0.0), DAE(0.0, lhs => 1.0), KAE(0.0, rhs => -1.0))

# DecisionRef--VariableAffExpr{C}
Base.:(+)(lhs::DecisionRef, rhs::VariableAffExpr{C}) where {C} = CombinedAffExpr{C}(rhs, DecisionAffExpr{C}(zero(C), lhs => 1.), zero(KnownAffExpr{C}))
Base.:(-)(lhs::DecisionRef, rhs::VariableAffExpr{C}) where {C} = CombinedAffExpr{C}(-rhs, DecisionAffExpr{C}(zero(C), lhs => 1.), zero(KnownAffExpr{C}))

# DecisionRef--DecisionAffExpr{C}
Base.:(+)(lhs::DecisionRef, rhs::DecisionAffExpr{C}) where C = (+)(DecisionAffExpr{C}(zero(C), lhs => 1.0),  rhs)
Base.:(-)(lhs::DecisionRef, rhs::DecisionAffExpr{C}) where C = (+)(DecisionAffExpr{C}(zero(C), lhs => 1.0), -rhs)

# DecisionRef--KnownAffExpr{C}
Base.:(+)(lhs::DecisionRef, rhs::KnownAffExpr{C}) where {C} = CombinedAffExpr{C}(zero(VariableAffExpr{C}), DecisionAffExpr{C}(zero(C), lhs => 1), copy(rhs))
Base.:(-)(lhs::DecisionRef, rhs::KnownAffExpr{C}) where {C} = CombinedAffExpr{C}(zero(VariableAffExpr{C}), DecisionAffExpr{C}(zero(C), lhs => 1.), -rhs)

# DecisionRef--CombinedAffExpr{C}
Base.:(+)(lhs::DecisionRef, rhs::CombinedAffExpr{C}) where {C} = CombinedAffExpr{C}(copy(rhs.variables), lhs+rhs.decisions, copy(rhs.knowns))
Base.:(-)(lhs::DecisionRef, rhs::CombinedAffExpr{C}) where {C} = CombinedAffExpr{C}(-rhs.variables, lhs-rhs.decisions, -rhs.knowns)


#=
    KnownRef
=#

# KnownRef
Base.:(-)(lhs::KnownRef) = CAE(VAE(0.0), DAE(0.0, lhs => -1.0))

# KnownRef--Number
Base.:(+)(lhs::KnownRef, rhs::Number) = (+)(rhs, lhs)
Base.:(-)(lhs::KnownRef, rhs::Number) = (+)(-rhs, lhs)
Base.:(*)(lhs::KnownRef, rhs::Number) = (*)(rhs, lhs)
Base.:(/)(lhs::KnownRef, rhs::Number) = (*)(1.0 / rhs, lhs)

# KnownRef--VariableRef
Base.:(+)(lhs::KnownRef, rhs::JuMP.VariableRef) = CAE(VAE(0.0, rhs => +1.0), DAE(0.0), KAE(0.0, lhs => 1.0))
Base.:(-)(lhs::KnownRef, rhs::JuMP.VariableRef) = CAE(VAE(0.0, rhs => -1.0), DAE(0.0), KAE(0.0, lhs => 1.0))

# KnownRef--KnownRef
Base.:(+)(lhs::KnownRef, rhs::KnownRef) = CAE(VAE(0.0), DAE(0.0), KAE(0.0, lhs => 1.0, rhs => +1.0))
Base.:(-)(lhs::KnownRef, rhs::KnownRef) = CAE(VAE(0.0), DAE(0.0), KAE(0.0, lhs => 1.0, rhs => -1.0))

# KnownRef--VariableAffExpr{C}
Base.:(+)(lhs::KnownRef, rhs::VariableAffExpr{C}) where {C} = CombinedAffExpr{C}(copy(rhs), zero(DecisionAffExpr{C}), KnownAffExpr{C}(zero(C), lhs => 1.))
Base.:(-)(lhs::KnownRef, rhs::VariableAffExpr{C}) where {C} = CombinedAffExpr{C}(-rhs, zero(DecisionAffExpr{C}), KnownAffExpr{C}(zero(C), lhs => 1.))

# KnownRef--DecisionAffExpr{C}
Base.:(+)(lhs::KnownRef, rhs::DecisionAffExpr{C}) where {C} = CombinedAffExpr{C}(zero(VariableAffExpr{C}), rhs, KnownAffExpr{C}(zero(C), lhs => 1.))
Base.:(-)(lhs::KnownRef, rhs::DecisionAffExpr{C}) where {C} = CombinedAffExpr{C}(zero(VariableAffExpr{C}), -rhs, KnownAffExpr{C}(zero(C), lhs => 1.))

# KnownRef--KnownAffExpr{C}
Base.:(+)(lhs::KnownRef, rhs::KnownAffExpr{C}) where C = (+)(KnownAffExpr{C}(zero(C), lhs => 1.0),  rhs)
Base.:(-)(lhs::KnownRef, rhs::KnownAffExpr{C}) where C = (+)(KnownAffExpr{C}(zero(C), lhs => 1.0), -rhs)

# KnownRef--CombinedAffExpr{C}
Base.:(+)(lhs::KnownRef, rhs::CombinedAffExpr{C}) where {C} = CombinedAffExpr{C}(copy(rhs.variables), copy(rhs.decisions), lhs+rhs.knowns)
Base.:(-)(lhs::KnownRef, rhs::CombinedAffExpr{C}) where {C} = CombinedAffExpr{C}(-rhs.variables, -rhs.decisions, lhs-rhs.knowns)

#=
    VariableAffExpr{C}
=#

# VariableAffExpr{C}--DecisionRef/KnownRef
Base.:(+)(lhs::VariableAffExpr, rhs::Union{DecisionRef, KnownRef}) = (+)(rhs,lhs)
Base.:(-)(lhs::VariableAffExpr, rhs::Union{DecisionRef, KnownRef}) = (+)(-rhs,lhs)

# VariableAffExpr{C}--DecisionAffExpr{C}
Base.:(+)(lhs::VariableAffExpr{C}, rhs::DecisionAffExpr{C}) where {C} = CombinedAffExpr{C}(copy(lhs), copy(rhs), zero(KnownAffExpr{C}))
Base.:(-)(lhs::VariableAffExpr{C}, rhs::DecisionAffExpr{C}) where {C} = CombinedAffExpr{C}(copy(lhs), -rhs, zero(KnownAffExpr{C}))

# VariableAffExpr{C}--DecisionAffExpr{C}
Base.:(+)(lhs::VariableAffExpr{C}, rhs::KnownAffExpr{C}) where {C} = CombinedAffExpr{C}(copy(lhs), zero(DecisionAffExpr{C}), copy(rhs))
Base.:(-)(lhs::VariableAffExpr{C}, rhs::KnownAffExpr{C}) where {C} = CombinedAffExpr{C}(copy(lhs), zero(DecisionAffExpr{C}), -rhs)

# VariableRef{C}--CombinedAffExpr{C}
Base.:(+)(lhs::VariableAffExpr{C}, rhs::CombinedAffExpr{C}) where {C} = CombinedAffExpr{C}(lhs+rhs.variables, copy(rhs.decisions), copy(rhs.knowns))
Base.:(-)(lhs::VariableAffExpr{C}, rhs::CombinedAffExpr{C}) where {C} = CombinedAffExpr{C}(lhs-rhs.variables, -rhs.decisions, -rhs.knowns)

#=
    DecisionAffExpr{C}
=#

# DecisionAffExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::DecisionAffExpr, rhs::Union{JuMP.VariableRef, DecisionRef, KnownRef}) = (+)(rhs,lhs)
Base.:(-)(lhs::DecisionAffExpr, rhs::Union{JuMP.VariableRef, DecisionRef, KnownRef}) = (+)(-rhs,lhs)

# DecisionAffExpr--VariableAffExpr
Base.:(+)(lhs::DecisionAffExpr, rhs::VariableAffExpr) = (+)(rhs,lhs)
Base.:(-)(lhs::DecisionAffExpr, rhs::VariableAffExpr) = (+)(-rhs,lhs)

# DecisionAffExpr--KnownAffExpr
Base.:(+)(lhs::DecisionAffExpr, rhs::KnownAffExpr) = CombinedAffExpr{C}(zero(VariableAffExpr{C}), copy(lhs), copy(rhs))
Base.:(-)(lhs::DecisionAffExpr, rhs::KnownAffExpr) = CombinedAffExpr{C}(zero(VariableAffExpr{C}), copy(lhs), -rhs)

# DecisionAffExpr{C}--CombinedAffExpr{C}
Base.:(+)(lhs::DecisionAffExpr{C}, rhs::CombinedAffExpr{C}) where {C} = CombinedAffExpr{C}(copy(rhs.variables), lhs+rhs.decisions, copy(rhs.knowns))
Base.:(-)(lhs::DecisionAffExpr{C}, rhs::CombinedAffExpr{C}) where {C} = CombinedAffExpr{C}(-rhs.variables, lhs-rhs.decisions, -rhs.knowns)

#=
    KnownAffExpr{C}
=#

# KnownAffExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::KnownAffExpr, rhs::Union{JuMP.VariableRef, DecisionRef, KnownRef}) = (+)(rhs,lhs)
Base.:(-)(lhs::KnownAffExpr, rhs::Union{JuMP.VariableRef, DecisionRef, KnownRef}) = (+)(-rhs,lhs)

# KnownAffExpr--VariableAffExpr
Base.:(+)(lhs::KnownAffExpr, rhs::VariableAffExpr) = (+)(rhs,lhs)
Base.:(-)(lhs::KnownAffExpr, rhs::VariableAffExpr) = (+)(-rhs,lhs)

# KnownAffExpr--DecisionAffExpr
Base.:(+)(lhs::KnownAffExpr, rhs::DecisionAffExpr) = (+)(rhs, lhs)
Base.:(-)(lhs::KnownAffExpr, rhs::DecisionAffExpr) = (+)(-rhs, lhs)

# KnownAffExpr{C}--CombinedAffExpr{C}
Base.:(+)(lhs::KnownAffExpr{C}, rhs::CombinedAffExpr{C}) where {C} = CombinedAffExpr{C}(copy(rhs.variables), copy(rhs.decisions), lhs+rhs.knowns)
Base.:(-)(lhs::KnownAffExpr{C}, rhs::CombinedAffExpr{C}) where {C} = CombinedAffExpr{C}(-rhs.variables, -rhs.decisions, lhs-rhs.knowns)

#=
    CombinedAffExpr{C}
=#

Base.:(-)(lhs::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(-lhs.variables, -lhs.decisions, -lhs.knowns)

# CombinedAffExpr--Number
Base.:(+)(lhs::CombinedAffExpr, rhs::Number) = (+)(rhs,lhs)
Base.:(-)(lhs::CombinedAffExpr, rhs::Number) = (+)(-rhs,lhs)
Base.:(*)(lhs::CombinedAffExpr, rhs::Number) = (*)(rhs,lhs)

# CombinedAffExpr--VariableRef/DecisionRef/KnownRef
Base.:(+)(lhs::CombinedAffExpr, rhs::Union{JuMP.VariableRef, DecisionRef, KnownRef}) = (+)(rhs,lhs)
Base.:(-)(lhs::CombinedAffExpr, rhs::Union{JuMP.VariableRef, DecisionRef, KnownRef}) = (+)(-rhs,lhs)

# CombinedAffExpr--VariableAffExpr/DecisionAffExpr/KnownAffExpr
Base.:(+)(lhs::CombinedAffExpr, rhs::Union{VariableAffExpr, DecisionAffExpr, KnownAffExpr}) = (+)(rhs,lhs)
Base.:(-)(lhs::CombinedAffExpr, rhs::Union{VariableAffExpr, DecisionAffExpr, KnownAffExpr}) = (+)(-rhs,lhs)

# CombinedAffExpr{C}--CombinedAffExpr{C}
Base.:(+)(lhs::CombinedAffExpr{C}, rhs::CombinedAffExpr{C}) where {C} = CombinedAffExpr{C}(lhs.variables+rhs.variables,
                                                                                           lhs.decisions+rhs.decisions,
                                                                                           lhs.knowns+rhs.knowns)
Base.:(-)(lhs::CombinedAffExpr{C}, rhs::CombinedAffExpr{C}) where {C} = CombinedAffExpr{C}(lhs.variables-rhs.variables,
                                                                                           lhs.decisions-rhs.decisions,
                                                                                           lhs.knowns-rhs.knowns)
