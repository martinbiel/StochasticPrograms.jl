# Number--DecisionRef
Base.:(+)(lhs::C, rhs::DecisionRef) where C<:Number = DVAE{C}(GAEV{C}(convert(C, lhs)), GAEDV{C}(zero(C), rhs => +one(C)))
Base.:(-)(lhs::C, rhs::DecisionRef) where C<:Number = DVAE{C}(GAEV{C}(convert(C, lhs)), GAEDV{C}(zero(C), rhs => -one(C)))
Base.:(*)(lhs::C, rhs::DecisionRef) where C<:Number = DVAE{C}(GAEV{C}(zero(C)), GAEDV{C}(zero(C), rhs => lhs))

# Number--DVAE
Base.:(+)(lhs::Number, rhs::DVAE{C}) where C<:Number = DVAE{C}(lhs+rhs.v, copy(rhs.dv))
Base.:(-)(lhs::Number, rhs::DVAE{C}) where C<:Number = DVAE{C}(lhs-rhs.v, -rhs.dv)
Base.:(*)(lhs::Number, rhs::DVAE{C}) where C<:Number = DVAE{C}(lhs*rhs.v, lhs*rhs.dv)

#=
    DecisionRef
=#

# AbstractJuMPScalar
Base.:(-)(lhs::DecisionRef) = DVAE{Float64}(GAEV{Float64}(0.0), GAEDV{Float64}(0.0, lhs => -1.0))

# DecisionRef--Number
Base.:(+)(lhs::DecisionRef, rhs::Number) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionRef, rhs::Number) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionRef, rhs::Number) = (*)(rhs, lhs)
Base.:(/)(lhs::DecisionRef, rhs::Number) = (*)(1.0 / rhs, lhs)

# DecisionRef--VariableRef
Base.:(+)(lhs::DecisionRef, rhs::JuMP.VariableRef) = DVAE{Float64}(GAEV{Float64}(0.0, rhs => +1.0), GAEDV{Float64}(0.0, lhs => 1.0))
Base.:(-)(lhs::DecisionRef, rhs::JuMP.VariableRef) = DVAE{Float64}(GAEV{Float64}(0.0, rhs => -1.0), GAEDV{Float64}(0.0, lhs => 1.0))

# DecisionRef--DecisionRef
Base.:(+)(lhs::DecisionRef, rhs::DecisionRef) = DVAE{Float64}(GAEV{Float64}(0.0), GAEDV{Float64}(0.0, lhs => 1.0, rhs => +1.0))
Base.:(-)(lhs::DecisionRef, rhs::DecisionRef) = DVAE{Float64}(GAEV{Float64}(0.0), GAEDV{Float64}(0.0, lhs => 1.0, rhs => -1.0))

# DecisionRef--GAEDV
Base.:(+)(lhs::DecisionRef, rhs::GAEDV{C}) where C = (+)(GAEDV{C}(zero(C), lhs => 1.0),  rhs)
Base.:(-)(lhs::DecisionRef, rhs::GAEDV{C}) where C = (+)(GAEDV{C}(zero(C), lhs => 1.0), -rhs)

# DecisionRef--GAEV/GenericAffExpr{C,VariableRef}
Base.:(+)(lhs::DecisionRef, rhs::GAEV{C}) where {C} = DVAE{C}(copy(rhs),GAEDV{C}(zero(C), lhs => 1.))
Base.:(-)(lhs::DecisionRef, rhs::GAEV{C}) where {C} = DVAE{C}(-rhs,GAEDV{C}(zero(C), lhs => 1.))

# DecisionRef--DVAE{C}
Base.:(+)(lhs::DecisionRef, rhs::DVAE{C}) where {C} = DVAE{C}(copy(rhs.v),lhs+rhs.dv)
Base.:(-)(lhs::DecisionRef, rhs::DVAE{C}) where {C} = DVAE{C}(-rhs.v,lhs-rhs.dv)

#=
    VariableRef
=#

# VariableRef--DecisionRef
Base.:(+)(lhs::JuMP.VariableRef, rhs::DecisionRef) = DVAE{Float64}(GAEV{Float64}(zero(Float64), lhs => 1.0),GAEDV{Float64}(zero(Float64), rhs =>  1.0))
Base.:(-)(lhs::JuMP.VariableRef, rhs::DecisionRef) = DVAE{Float64}(GAEV{Float64}(zero(Float64), lhs => 1.0),GAEDV{Float64}(zero(Float64), rhs => -1.0))

# VariableRef--GenericAffExpr{C,DecisionRef}
Base.:(+)(lhs::JuMP.VariableRef, rhs::GAEDV{C}) where {C} = DVAE{C}(GAEV{C}(zero(C), lhs => 1.),copy(rhs))
Base.:(-)(lhs::JuMP.VariableRef, rhs::GAEDV{C}) where {C} = DVAE{C}(GAEV{C}(zero(C), lhs => 1.),-rhs)

# VariableRef--DVAE{C}
Base.:(+)(lhs::JuMP.VariableRef, rhs::DVAE{C}) where {C} = DVAE{C}(lhs + rhs.v, copy(rhs.dv))
Base.:(-)(lhs::JuMP.VariableRef, rhs::DVAE{C}) where {C} = DVAE{C}(lhs - rhs.v, -rhs.dv)

#=
    GenericAffExpr{C,VariableRef}
=#

# GenericAffExpr{C,VariableRef}--DecisionRef
Base.:(+)(lhs::GAEV{C}, rhs::DecisionRef) where {C} = (+)(rhs,lhs)
Base.:(-)(lhs::GAEV{C}, rhs::DecisionRef) where {C} = (+)(-rhs,lhs)

# GenericAffExpr{C,VariableRef}--GenericAffExpr{C,DecisionRef}
Base.:(+)(lhs::GAEV{C}, rhs::GAEDV{C}) where {C} = DVAE{C}(copy(lhs),copy(rhs))
Base.:(-)(lhs::GAEV{C}, rhs::GAEDV{C}) where {C} = DVAE{C}(copy(lhs),-rhs)

# GenericAffExpr{C,VariableRef}--DVAE{C}
Base.:(+)(lhs::GAEV{C}, rhs::DVAE{C}) where {C} = DVAE{C}(lhs+rhs.v,copy(rhs.dv))
Base.:(-)(lhs::GAEV{C}, rhs::DVAE{C}) where {C} = DVAE{C}(lhs-rhs.v,-rhs.dv)

#=
    GenericAffExpr{C,DecisionRef}/GAEDV
=#

# GenericAffExpr{C,DecisionRef}--VariableRef
Base.:(+)(lhs::GAEDV{C}, rhs::JuMP.VariableRef) where {C} = (+)(rhs,lhs)
Base.:(-)(lhs::GAEDV{C}, rhs::JuMP.VariableRef) where {C} = (+)(-rhs,lhs)

# GenericAffExpr{C,DecisionRef}--GenericAffExpr{C,VariableRef}
Base.:(+)(lhs::GAEDV{C}, rhs::GAEV{C}) where {C} = (+)(rhs,lhs)
Base.:(-)(lhs::GAEDV{C}, rhs::GAEV{C}) where {C} = (+)(-rhs,lhs)

#=
    DVAE{C}
=#

Base.:(-)(lhs::DVAE{C}) where C = DVAE{C}(-lhs.v, -lhs.dv)

# Number--DVAE
Base.:(+)(lhs::DVAE, rhs::Number) = (+)(rhs,lhs)
Base.:(-)(lhs::DVAE, rhs::Number) = (+)(-rhs,lhs)
Base.:(*)(lhs::DVAE, rhs::Number) = (*)(rhs,lhs)

# DVAE{C}--DecisionRef
Base.:(+)(lhs::DVAE{C}, rhs::DecisionRef) where {C} = (+)(rhs,lhs)
Base.:(-)(lhs::DVAE{C}, rhs::DecisionRef) where {C} = (+)(-rhs,lhs)

# VariableRef--DVAE{C}
Base.:(+)(lhs::DVAE{C}, rhs::JuMP.VariableRef) where {C} = (+)(rhs,lhs)
Base.:(-)(lhs::DVAE{C}, rhs::JuMP.VariableRef) where {C} = (+)(-rhs,lhs)

# DVAE{C}--GenericAffExpr{C,VariableRef}
# DVAE{C}--GenericAffExpr{C,DecisionRef}
Base.:(+)(lhs::DVAE{C}, rhs::GAE{C,V}) where {C,V} = (+)(rhs,lhs)
Base.:(-)(lhs::DVAE{C}, rhs::GAE{C,V}) where {C,V} = (+)(-rhs,lhs)

# DVAE{C}--DVAE{C}
Base.:(+)(lhs::DVAE{C}, rhs::DVAE{C}) where {C} = DVAE{C}(lhs.v+rhs.v,lhs.dv+rhs.dv)
Base.:(-)(lhs::DVAE{C}, rhs::DVAE{C}) where {C} = DVAE{C}(lhs.v-rhs.v,lhs.dv-rhs.dv)
