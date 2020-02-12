const GAE{C,V} = JuMP.GenericAffExpr{C,V}
const GAEV{C} = JuMP.GenericAffExpr{C,JuMP.VariableRef}
const GAEDV{C} = JuMP.GenericAffExpr{C,DecisionRef}

mutable struct DecisionVariableAffExpr{C} <: JuMP.AbstractJuMPScalar
    v::JuMP.GenericAffExpr{C, JuMP.VariableRef}
    dv::JuMP.GenericAffExpr{C, DecisionRef}
end
const DVAE{C} = DecisionVariableAffExpr{C}

DVAE{C}() where {C} = zero(DVAE{C})

function JuMP.value(aff::DecisionVariableAffExpr, value::Function)
    return JuMP.value(aff.v, value) + JuMP.value(aff.dv, value)
end

function JuMP.constant(aff::DVAE)
    return aff.v.constant
end

function JuMP._assert_isfinite(aff::DecisionVariableAffExpr)
    JuMP._assert_isfinite(aff.v)
    for (coef, dv) in linear_terms(aff.dv)
        isfinite(coef) || error("Invalid coefficient $coef on decision variable $dv.")
    end
end

function JuMP.check_belongs_to_model(aff::DecisionVariableAffExpr, model::AbstractModel)
    JuMP.check_belongs_to_model(aff.v, model)
    JuMP.check_belongs_to_model(aff.dv, model)
end

function JuMP.function_string(mode, aff::DecisionVariableAffExpr, show_constant=true)
    variable_terms = JuMP.function_string(mode, aff.v, false)
    decision_terms = JuMP.function_string(mode, aff.dv, false)
    first_decision_term_coef = first(linear_terms(aff.dv))[1]
    ret = string(variable_terms, JuMP._sign_string(first_decision_term_coef), decision_terms)
    if !JuMP._is_zero_for_printing(aff.v.constant) && show_constant
        ret = string(ret, JuMP._sign_string(aff.v.constant),

                     JuMP._string_round(abs(aff.v.constant)))
    end
    return ret
end

function JuMP.map_coefficients_inplace!(f::Function, aff::DecisionVariableAffExpr)
    JuMP.map_coefficients_inplace!(f, aff.v)
    for (coef, dvar) in linear_terms(aff.dv)
        aff.dv.terms[dvar] = f(coef)
    end
    return aff
end

function JuMP.map_coefficients(f::Function, aff::DecisionVariableAffExpr)
    return JuMP.map_coefficients_inplace!(f, copy(aff))
end

function Base.sizehint!(aff::DecisionVariableAffExpr, n::Int)
    sizehint!(aff.v.terms, n)
    sizehint!(aff.dv.terms, n)
end

function Base.isequal(aff::DVAE{C}, other::DVAE{C}) where {C}
    return isequal(aff.v, other.dv) && isequal(aff.dv, other.dv)
end

Base.hash(aff::DVAE, h::UInt) = hash(aff.v.constant, hash(aff.v.terms, h), hash(aff.dv.terms, h))

function SparseArrays.dropzeros(aff::DVAE{C}) where {C}
    v = SparseArrays.dropzeros(aff.v)
    dv = SparseArrays.dropzeros(aff.dv)
    return DVAE{C}(v,dv)
end

Base.one(::Type{DecisionRef}) = one(GAEDV{Float64})
Base.iszero(aff::DVAE) = iszero(aff.v) && iszero(aff.dv)
Base.zero(::Type{DVAE{C}}) where {C} = DVAE{C}(zero(GAEV{C}), zero(GAEDV{C}))
Base.one(::Type{DVAE{C}}) where {C} = DVAE{C}(one(GAEV{C}), zero(GAEDV{C}))
Base.zero(aff::DVAE) = zero(typeof(aff))
Base.one(aff::DVAE) =  one(typeof(aff))
Base.copy(aff::DVAE{C}) where {C}  = DVAE{C}(copy(aff.v), copy(aff.dv))
Base.broadcastable(expr::DVAE) = Ref(expr)
Base.convert(::Type{DVAE{C}}, v::JuMP.VariableRef) where {C} = DVAE{C}(GAEV{C}(zero(C), v => one(C)), zero(GAEDV{C}))
Base.convert(::Type{DVAE{C}}, dv::DecisionRef) where {C} = DVAE{C}(zero(GAEV{C}), GAEDV{C}(zero(C), dv => one(C)))
Base.convert(::Type{DVAE{C}}, r::AbstractFloat) where {C} = DVAE{C}(GAEV{C}(convert(C, r)), zero(GAEDV{C}))
Base.convert(::Type{DVAE{C}}, aff::GAEV{C}) where {C} = DVAE{C}(aff, GAEDV{C}(zero(C)))
