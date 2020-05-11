const _Constant = JuMP._Constant
const GAE{C,V} = JuMP.GenericAffExpr{C,V}
const VariableAffExpr{C} = JuMP.GenericAffExpr{C,VariableRef}
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

# Base overrides #
# ========================== #
Base.iszero(aff::CombinedAffExpr) =
    iszero(aff.variables) &&
    iszero(aff.decisions) &&
    iszero(aff.knowns)
Base.zero(::Type{CombinedAffExpr{C}}) where C =
    CombinedAffExpr{C}(
        zero(VariableAffExpr{C}),
        zero(DecisionAffExpr{C}),
        zero(KnownAffExpr{C}))

Base.one(::Type{DecisionRef}) = one(DAE)
Base.one(::Type{KnownRef}) = one(KAE)
Base.one(::Type{CombinedAffExpr{C}}) where C = CombinedAffExpr{C}(one(VariableAffExpr{C}),
                                                                  zero(DecisionAffExpr{C}),
                                                                  zero(KnownAffExpr{C}))
Base.zero(aff::CombinedAffExpr) = zero(typeof(aff))
Base.one(aff::CombinedAffExpr) =  one(typeof(aff))
Base.copy(aff::CombinedAffExpr{C}) where C = CombinedAffExpr{C}(copy(aff.variables),
                                                                copy(aff.decisions),
                                                                copy(aff.knowns))
Base.broadcastable(aff::CombinedAffExpr) = Ref(aff)

Base.convert(::Type{CombinedAffExpr{C}}, v::VariableRef) where {C} = CombinedAffExpr{C}(VariableAffExpr{C}(zero(C), v => one(C)), zero(DecisionAffExpr{C}), zero(KnownAffExpr{C}))
Base.convert(::Type{CombinedAffExpr{C}}, dv::DecisionRef) where C = CombinedAffExpr{C}(zero(VariableAffExpr{C}), DecisionAffExpr{C}(zero(C), dv => one(C)), zero(KnownAffExpr{C}))
Base.convert(::Type{CombinedAffExpr{C}}, kv::KnownRef) where C = CombinedAffExpr{C}(zero(VariableAffExpr{C}), zero(DecisionAffExpr{C}), KnownAffExpr{C}(zero(C), kv => one(C)))
Base.convert(::Type{CombinedAffExpr{C}}, c::Number) where C = CombinedAffExpr{C}(VariableAffExpr{C}(convert(C, r)), zero(DecisionAffExpr{C}), zero(KnownAffExpr{C}))
Base.convert(::Type{CombinedAffExpr{C}}, aff::VariableAffExpr{C}) where C = CombinedAffExpr{C}(aff, zero(DecisionAffExpr{C}), zero(KnownAffExpr{C}))
Base.convert(::Type{CombinedAffExpr{C}}, aff::DecisionAffExpr{C}) where C = CombinedAffExpr{C}(zero(VariableAffExpr{C}), aff, zero(KnownAffExpr{C}))
Base.convert(::Type{CombinedAffExpr{C}}, aff::KnownAffExpr{C}) where C = CombinedAffExpr{C}(zero(VariableAffExpr{C}), zero(DecisionAffExpr{C}), aff)
function Base.convert(::Type{T}, aff::CombinedAffExpr{T}) where T
    if !isempty(aff.variables.terms) && !isempty(aff.decisions.terms) && !isempty(aff.knowns.terms)
        throw(InexactError(:convert, T, aff))
    end
    return convert(T, aff.variables.constant)
end

function Base.isequal(aff::CombinedAffExpr{C}, other::CombinedAffExpr{C}) where {C}
    return isequal(aff.variables, other.variables) &&
        isequal(aff.decisions, other.decisions) &&
        isequal(aff.knowns, other.knowns)
end

Base.hash(aff::CombinedAffExpr, h::UInt) =
    hash(aff.variables.constant,
         hash(aff.variables.terms, h),
         hash(aff.decisions.terms, h),
         hash(aff.knowns.terms, h))

# JuMP overrides #
# ========================== #
function JuMP.drop_zeros!(aff::CombinedAffExpr)
    JuMP.drop_zeros!(aff.variables)
    JuMP.drop_zeros!(aff.decisions)
    JuMP.drop_zeros!(aff.knowns)
    return nothing
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

function JuMP.value(aff::CombinedAffExpr, value::Function)
    return JuMP.value(aff.variables, value) +
        JuMP.value(aff.decisions, value) +
        JuMP.value(aff.knowns, value)
end

function JuMP.constant(aff::CombinedAffExpr)
    return aff.variables.constant
end

function SparseArrays.dropzeros(aff::CombinedAffExpr{C}) where C
    variables = SparseArrays.dropzeros(aff.variables)
    decisions = SparseArrays.dropzeros(aff.decisions)
    knowns = SparseArrays.dropzeros(aff.knowns)
    return CombinedAffExpr(variables, decisions, knowns)
end

function JuMP._assert_isfinite(aff::Union{DecisionAffExpr, KnownAffExpr})
    for (coef, dv) in linear_terms(aff)
        isfinite(coef) || error("Invalid coefficient $coef on decision $dv.")
    end
    return nothing
end

function JuMP._assert_isfinite(aff::CombinedAffExpr)
    JuMP._assert_isfinite(aff.variables)
    JuMP._assert_isfinite(aff.decisions)
    JuMP._assert_isfinite(aff.knowns)
    return nothing
end

function JuMP.check_belongs_to_model(aff::CombinedAffExpr, model::AbstractModel)
    JuMP.check_belongs_to_model(aff.variables, model)
    JuMP.check_belongs_to_model(aff.decisions, model)
    JuMP.check_belongs_to_model(aff.knowns, model)
    return nothing
end

function JuMP.function_string(mode, aff::CombinedAffExpr, show_constant=true)
    # Decisions
    ret = ""
    decision_terms = JuMP.function_string(mode, aff.decisions, false)
    if decision_terms != "0"
        ret = decision_terms
    end
    # Variables
    variable_terms = JuMP.function_string(mode, aff.variables, false)
    ret = _add_terms(ret, variable_terms)
    # Knowns
    known_terms = JuMP.function_string(mode, aff.knowns, false)
    ret = _add_terms(ret, known_terms)
    # Constant
    if !JuMP._is_zero_for_printing(aff.variables.constant) && show_constant
        ret = string(ret, JuMP._sign_string(aff.variables.constant),

                     JuMP._string_round(abs(aff.variables.constant)))
    end
    return ret
end

function _add_terms(ret::String, terms::String)
    if terms == ""
        return ret
    end
    if terms != "0"
        if ret == ""
            ret = terms
        else
            if terms[1] == '-'
                ret = ret * " - " * terms[2:end]
            else
                ret = ret * " + " * terms
            end
        end
    end
    return ret
end

# With one factor.
function JuMP.add_to_expression!(aff::CAE, other::Number)
    JuMP.add_to_expression!(aff.variables, other)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_var::VariableRef)
    JuMP.add_to_expression!(aff.variables, new_var)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_dvar::DecisionRef)
    JuMP.add_to_expression!(aff.decisions, new_dvar)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_kvar::KnownRef)
    JuMP.add_to_expression!(aff.knowns, new_kvar)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_vae::VAE)
    JuMP.add_to_expression!(aff.variables, new_vae)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_dae::DAE)
    JuMP.add_to_expression!(aff.decisions, new_dae)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_kae::KAE)
    JuMP.add_to_expression!(aff.knowns, new_kae)
    return aff
end

function JuMP.add_to_expression!(lhs_aff::CAE, rhs_aff::CAE)
    JuMP.add_to_expression!(lhs_aff.variables, rhs_aff.variables)
    JuMP.add_to_expression!(lhs_aff.decisions, rhs_aff.decisions)
    JuMP.add_to_expression!(lhs_aff.knowns, rhs_aff.knowns)
    return lhs_aff
end

# With two factors.
function JuMP.add_to_expression!(aff::CAE, new_coef::_Constant, new_var::VariableRef)
    JuMP.add_to_expression!(aff.variables, new_coef, new_var)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_var::VariableRef, new_coef::_Constant)
    JuMP.add_to_expression!(aff.variables, new_coef, new_var)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_coef::_Constant, new_dvar::DecisionRef)
    JuMP.add_to_expression!(aff.decisions, new_coef, new_dvar)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_dvar::DecisionRef, new_coef::_Constant)
    JuMP.add_to_expression!(aff.decisions, new_coef, new_dvar)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_coef::_Constant, new_kvar::KnownRef)
    JuMP.add_to_expression!(aff.knowns, new_coef, new_kvar)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_kvar::KnownRef, new_coef::_Constant)
    JuMP.add_to_expression!(aff.knowns, new_coef, new_kvar)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_coef::_Constant, new_vae::VAE)
    JuMP.add_to_expression!(aff.variables, new_coef, new_vae)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_vae::VAE, new_coef::_Constant)
    JuMP.add_to_expression!(aff.variables, new_coef, new_vae)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_coef::_Constant, new_dae::DAE)
    JuMP.add_to_expression!(aff.decisions, new_coef, new_dae)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_dae::DAE, new_coef)
    JuMP.add_to_expression!(aff.decisions, new_coef, new_dae)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_coef::_Constant, new_kae::KAE)
    JuMP.add_to_expression!(aff.knowns, new_coef, new_kae)
    return aff
end

function JuMP.add_to_expression!(aff::CAE, new_kae::KAE, new_coef::_Constant)
    JuMP.add_to_expression!(aff.knowns, new_coef, new_kae)
    return aff
end
