const GAE{C,V} = JuMP.GenericAffExpr{C,V}
const VariableAffExpr{C} = JuMP.GenericAffExpr{C,JuMP.VariableRef}
const DecisionAffExpr{C} = JuMP.GenericAffExpr{C,DecisionRef}
const KnownAffExpr{C} = JuMP.GenericAffExpr{C,KnownRef}
const VAE = VariableAffExpr{Float64}
const DAE = DecisionAffExpr{Float64}
const KAE = KnownAffExpr{Float64}

mutable struct CombinedAffExpr{C} <: JuMP.AbstractJuMPScalar
    variables::VariableAffExpr{C}
    decisions::DecisionAffExpr{C}
    knowns::KnownAffExpr{C}
end
const CAE = CombinedAffExpr{Float64}

CAE() = zero(CAE{Float64})

function JuMP.value(aff::CombinedAffExpr, value::Function)
    return JuMP.value(aff.variables, value) +
        JuMP.value(aff.decisions, value) +
        JuMP.value(aff.knowns, value)
end

function JuMP.constant(aff::CombinedAffExpr)
    return aff.variables.constant
end

function JuMP._assert_isfinite(aff::DecisionAffExpr)
    for (coef, dv) in linear_terms(aff)
        isfinite(coef) || error("Invalid coefficient $coef on decision $dv.")
    end
end

function JuMP._assert_isfinite(aff::KnownAffExpr)
    for (coef, kv) in linear_terms(aff)
        isfinite(coef) || error("Invalid coefficient $coef on known variable $kv.")
    end
end

function JuMP._assert_isfinite(aff::CombinedAffExpr)
    JuMP._assert_isfinite(aff.variables)
    JuMP._assert_isfinite(aff.decisions)
    JuMP._assert_isfinite(aff.knowns)
end

function JuMP.check_belongs_to_model(aff::CombinedAffExpr, model::AbstractModel)
    JuMP.check_belongs_to_model(aff.variables, model)
    JuMP.check_belongs_to_model(aff.decisions, model)
    JuMP.check_belongs_to_model(aff.knowns, model)
end

function JuMP.function_string(mode, aff::CombinedAffExpr, show_constant=true)
    ret = ""
    decision_terms = JuMP.function_string(mode, aff.decisions, false)
    if decision_terms != "0"
        ret = decision_terms
    end
    variable_terms = JuMP.function_string(mode, aff.variables, false)
    if variable_terms != "0"
        if ret == ""
            ret = variable_terms
        else
            if variable_terms[1] == '-'
                ret = ret * " - " * variable_terms[2:end]
            else
                ret = ret * " + " * variable_terms
            end
        end
    end
    known_terms = JuMP.function_string(mode, aff.knowns, false)
    if known_terms != "0"
        if ret == ""
            ret = known_terms
        else
            if known_terms[1] == '-'
                ret = ret * " - " * known_terms[2:end]
            else
                ret = ret * " + " * known_terms
            end
        end
    end
    if !JuMP._is_zero_for_printing(aff.variables.constant) && show_constant
        ret = string(ret, JuMP._sign_string(aff.variables.constant),

                     JuMP._string_round(abs(aff.variables.constant)))
    end
    return ret
end

function JuMP._affine_coefficient(f::CombinedAffExpr, variable::VariableRef)
    return JuMP._affine_coefficient(f.variables, variable)
end
function JuMP._affine_coefficient(f::CombinedAffExpr, decision::DecisionRef)
    return JuMP._affine_coefficient(f.decisions, decision)
end
function JuMP._affine_coefficient(f::CombinedAffExpr, known::KnownRef)
    return JuMP._affine_coefficient(f.knowns, known)
end

function JuMP.map_coefficients_inplace!(f::Function, aff::CombinedAffExpr)
    JuMP.map_coefficients_inplace!(f, aff.variables)
    for (coef, dvar) in linear_terms(aff.decisions)
        aff.decisions.terms[dvar] = f(coef)
    end
    for (coef, kvar) in linear_terms(aff.knowns)
        aff.knowns.terms[kvar] = f(coef)
    end
    return aff
end

function JuMP.map_coefficients(f::Function, aff::CombinedAffExpr)
    return JuMP.map_coefficients_inplace!(f, copy(aff))
end

function Base.sizehint!(aff::CombinedAffExpr, n::Int)
    sizehint!(aff.variables.terms, n)
    sizehint!(aff.decisions.terms, n)
    sizehint!(aff.knowns.terms, n)
end

function Base.isequal(aff::CombinedAffExpr{C}, other::CombinedAffExpr{C}) where {C}
    return isequal(aff.variables, other.variables) &&
        isequal(aff.decisions, other.decisions) &&
        isequal(aff.knowns, other.knowns)
end

Base.hash(aff::CombinedAffExpr, h::UInt) = hash(aff.variables.constant,
                                                hash(aff.variables.terms, h),
                                                hash(aff.decisions.terms, h),
                                                hash(aff.knowns.terms, h))

function SparseArrays.dropzeros(aff::CombinedAffExpr{C}) where C
    variables = SparseArrays.dropzeros(aff.variables)
    decisions = SparseArrays.dropzeros(aff.decisions)
    knowns = SparseArrays.dropzeros(aff.knowns)
    return CombinedAffExpr{C}(variables, decisions, knowns)
end

Base.one(::Type{DecisionRef}) = one(DAE)
Base.one(::Type{KnownRef}) = one(KAE)
Base.iszero(aff::CombinedAffExpr) = iszero(aff.variables) &&
    iszero(aff.decisions) &&
    iszero(aff.knowns)
Base.zero(::Type{CombinedAffExpr{C}}) where C = CombinedAffExpr{C}(zero(VariableAffExpr{C}),
                                                                   zero(DecisionAffExpr{C}),
                                                                   zero(KnownAffExpr{C}))
Base.one(::Type{CombinedAffExpr{C}}) where C = CombinedAffExpr{C}(one(VariableAffExpr{C}),
                                                                  zero(DecisionAffExpr{C}),
                                                                  zero(KnownAffExpr{C}))
Base.zero(aff::CombinedAffExpr) = zero(typeof(aff))
Base.one(aff::CombinedAffExpr) =  one(typeof(aff))
Base.copy(aff::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(copy(aff.variables),
                                                                copy(aff.decisions),
                                                                copy(aff.knowns))
Base.broadcastable(aff::CombinedAffExpr) = Ref(aff)
Base.convert(::Type{CombinedAffExpr{C}}, v::JuMP.VariableRef) where {C} = CombinedAffExpr{C}(VariableAffExpr{C}(zero(C), v => one(C)), zero(DecisionAffExpr{C}), zero(KnownAffExpr{C}))
Base.convert(::Type{CombinedAffExpr{C}}, dv::DecisionRef) where C = CombinedAffExpr{C}(zero(VariableAffExpr{C}), DecisionAffExpr{C}(zero(C), dv => one(C)), zero(KnownAffExpr{C}))
Base.convert(::Type{CombinedAffExpr{C}}, kv::KnownRef) where C = CombinedAffExpr{C}(zero(VariableAffExpr{C}), zero(DecisionAffExpr{C}), KnownAffExpr{C}(zero(C), kv => one(C)))
Base.convert(::Type{CombinedAffExpr{C}}, c::Number) where C = CombinedAffExpr{C}(VariableAffExpr{C}(convert(C, r)), zero(DecisionAffExpr{C}), zero(KnownAffExpr{C}))
Base.convert(::Type{CombinedAffExpr{C}}, aff::VariableAffExpr{C}) where C = CombinedAffExpr{C}(aff, zero(DecisionAffExpr{C}), zero(KnownAffExpr{C}))
Base.convert(::Type{CombinedAffExpr{C}}, aff::DecisionAffExpr{C}) where C = CombinedAffExpr{C}(zero(VariableAffExpr{C}), aff, zero(KnownAffExpr{C}))
Base.convert(::Type{CombinedAffExpr{C}}, aff::KnownAffExpr{C}) where C = CombinedAffExpr{C}(zero(VariableAffExpr{C}), zero(DecisionAffExpr{C}), aff)
