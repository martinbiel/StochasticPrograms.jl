const _Constant = JuMP._Constant
const _VariableAffExpr{C} = GenericAffExpr{C, VariableRef}
const _DecisionAffExpr{C} = GenericAffExpr{C, DecisionRef}
const _KnownAffExpr{C} = GenericAffExpr{C, KnownRef}
const _VAE = _VariableAffExpr{Float64}
const _DAE = _DecisionAffExpr{Float64}
const _KAE = _KnownAffExpr{Float64}

mutable struct DecisionAffExpr{C} <: JuMP.AbstractJuMPScalar
    variables::GenericAffExpr{C, VariableRef}
    decisions::GenericAffExpr{C, DecisionRef}
    knowns::GenericAffExpr{C, KnownRef}
end
const DAE = DecisionAffExpr{Float64}

DAE() = zero(DAE{Float64})

# Base overrides #
# ========================== #
Base.iszero(aff::DecisionAffExpr) =
    iszero(aff.variables) &&
    iszero(aff.decisions) &&
    iszero(aff.knowns)
Base.zero(::Type{DecisionAffExpr{C}}) where C =
    DecisionAffExpr{C}(
        zero(_VariableAffExpr{C}),
        zero(_DecisionAffExpr{C}),
        zero(_KnownAffExpr{C}))
Base.one(::Type{DecisionAffExpr{C}}) where C =
    DecisionAffExpr{C}(one(_VariableAffExpr{C}),
                       zero(_DecisionAffExpr{C}),
                       zero(_KnownAffExpr{C}))
Base.zero(aff::DecisionAffExpr) = zero(typeof(aff))
Base.one(aff::DecisionAffExpr) =  one(typeof(aff))
Base.copy(aff::DecisionAffExpr{C}) where C =
    DecisionAffExpr{C}(copy(aff.variables),
                       copy(aff.decisions),
                       copy(aff.knowns))
Base.broadcastable(aff::DecisionAffExpr) = Ref(aff)

Base.convert(::Type{DecisionAffExpr{C}}, v::VariableRef) where {C} =
    DecisionAffExpr{C}(_VariableAffExpr{C}(zero(C), v => one(C)),
                       zero(_DecisionAffExpr{C}),
                       zero(_KnownAffExpr{C}))
Base.convert(::Type{DecisionAffExpr{C}}, dv::DecisionRef) where C =
    DecisionAffExpr{C}(zero(_VariableAffExpr{C}),
                       _DecisionAffExpr{C}(zero(C), dv => one(C)),
                       zero(_KnownAffExpr{C}))
Base.convert(::Type{DecisionAffExpr{C}}, kv::KnownRef) where C =
    DecisionAffExpr{C}(zero(_VariableAffExpr{C}),
                       zero(_DecisionAffExpr{C}),
                       GenericAffExpr{C, KnownRef}(zero(C), kv => one(C)))
Base.convert(::Type{DecisionAffExpr{C}}, c::Number) where C =
    DecisionAffExpr{C}(_VariableAffExpr{C}(convert(C, r)),
                       zero(_DecisionAffExpr{C}),
                       zero(_KnownAffExpr{C}))
Base.convert(::Type{DecisionAffExpr{C}}, aff::_VariableAffExpr{C}) where C =
    DecisionAffExpr{C}(aff,
                       zero(_DecisionAffExpr{C}),
                       zero(_KnownAffExpr{C}))
Base.convert(::Type{DecisionAffExpr{C}}, aff::_DecisionAffExpr{C}) where C =
    DecisionAffExpr{C}(zero(_VariableAffExpr{C}),
                       aff,
                       zero(_KnownAffExpr{C}))
Base.convert(::Type{DecisionAffExpr{C}}, aff::_KnownAffExpr{C}) where C =
    DecisionAffExpr{C}(zero(_VariableAffExpr{C}),
                       zero(_DecisionAffExpr{C}),
                       aff)
function Base.convert(::Type{T}, aff::DecisionAffExpr{T}) where T
    if !isempty(aff.variables.terms) && !isempty(aff.decisions.terms) && !isempty(aff.knowns.terms)
        throw(InexactError(:convert, T, aff))
    end
    return convert(T, aff.variables.constant)
end

function Base.isequal(aff::DecisionAffExpr{C}, other::DecisionAffExpr{C}) where {C}
    return isequal(aff.variables, other.variables) &&
        isequal(aff.decisions, other.decisions) &&
        isequal(aff.knowns, other.knowns)
end

Base.hash(aff::DecisionAffExpr, h::UInt) =
    hash(aff.variables.constant,
         hash(aff.variables.terms, h),
         hash(aff.decisions.terms, h),
         hash(aff.knowns.terms, h))

# JuMP overrides #
# ========================== #
function JuMP.drop_zeros!(aff::DecisionAffExpr)
    JuMP.drop_zeros!(aff.variables)
    JuMP.drop_zeros!(aff.decisions)
    JuMP.drop_zeros!(aff.knowns)
    return nothing
end

function JuMP._affine_coefficient(f::DecisionAffExpr, variable::VariableRef)
    return JuMP._affine_coefficient(f.variables, variable)
end
function JuMP._affine_coefficient(f::DecisionAffExpr, decision::DecisionRef)
    return JuMP._affine_coefficient(f.decisions, decision)
end
function JuMP._affine_coefficient(f::DecisionAffExpr, known::KnownRef)
    return JuMP._affine_coefficient(f.knowns, known)
end
function JuMP._affine_coefficient(f::_VariableAffExpr{C}, decision::DecisionRef) where C
    return zero(C)
end
function JuMP._affine_coefficient(f::_VariableAffExpr{C}, known::KnownRef) where C
    return zero(C)
end

function JuMP.map_coefficients_inplace!(f::Function, aff::DecisionAffExpr)
    JuMP.map_coefficients_inplace!(f, aff.variables)
    for (coef, dvar) in linear_terms(aff.decisions)
        aff.decisions.terms[dvar] = f(coef)
    end
    for (coef, kvar) in linear_terms(aff.knowns)
        aff.knowns.terms[kvar] = f(coef)
    end
    return aff
end

function JuMP.map_coefficients(f::Function, aff::DecisionAffExpr)
    return JuMP.map_coefficients_inplace!(f, copy(aff))
end

function JuMP.value(aff::DecisionAffExpr, value::Function)
    return JuMP.value(aff.variables, value) +
        JuMP.value(aff.decisions, value) +
        JuMP.value(aff.knowns, value)
end

function JuMP.constant(aff::DecisionAffExpr)
    return aff.variables.constant
end

function SparseArrays.dropzeros(aff::DecisionAffExpr{C}) where C
    variables = SparseArrays.dropzeros(aff.variables)
    decisions = SparseArrays.dropzeros(aff.decisions)
    knowns = SparseArrays.dropzeros(aff.knowns)
    return DecisionAffExpr(variables, decisions, knowns)
end

function JuMP._assert_isfinite(aff::Union{_DecisionAffExpr, _KnownAffExpr})
    for (coef, dv) in linear_terms(aff)
        isfinite(coef) || error("Invalid coefficient $coef on decision $dv.")
    end
    return nothing
end

function JuMP._assert_isfinite(aff::DecisionAffExpr)
    JuMP._assert_isfinite(aff.variables)
    JuMP._assert_isfinite(aff.decisions)
    JuMP._assert_isfinite(aff.knowns)
    return nothing
end

function JuMP.check_belongs_to_model(aff::DecisionAffExpr, model::AbstractModel)
    JuMP.check_belongs_to_model(aff.variables, model)
    JuMP.check_belongs_to_model(aff.decisions, model)
    JuMP.check_belongs_to_model(aff.knowns, model)
    return nothing
end

function JuMP.function_string(mode, aff::DecisionAffExpr, show_constant=true)
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
function JuMP.add_to_expression!(aff::DAE, other::Number)
    JuMP.add_to_expression!(aff.variables, other)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_var::VariableRef)
    JuMP.add_to_expression!(aff.variables, new_var)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_dvar::DecisionRef)
    JuMP.add_to_expression!(aff.decisions, new_dvar)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_kvar::KnownRef)
    JuMP.add_to_expression!(aff.knowns, new_kvar)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_vae::_VAE)
    JuMP.add_to_expression!(aff.variables, new_vae)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_dae::_DAE)
    JuMP.add_to_expression!(aff.decisions, new_dae)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_kae::_KAE)
    JuMP.add_to_expression!(aff.knowns, new_kae)
    return aff
end

function JuMP.add_to_expression!(lhs_aff::DAE, rhs_aff::DAE)
    JuMP.add_to_expression!(lhs_aff.variables, rhs_aff.variables)
    JuMP.add_to_expression!(lhs_aff.decisions, rhs_aff.decisions)
    JuMP.add_to_expression!(lhs_aff.knowns, rhs_aff.knowns)
    return lhs_aff
end

# With two factors.
function JuMP.add_to_expression!(aff::DAE, new_coef::_Constant, new_var::VariableRef)
    JuMP.add_to_expression!(aff.variables, new_coef, new_var)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_var::VariableRef, new_coef::_Constant)
    JuMP.add_to_expression!(aff.variables, new_coef, new_var)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_coef::_Constant, new_dvar::DecisionRef)
    JuMP.add_to_expression!(aff.decisions, new_coef, new_dvar)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_dvar::DecisionRef, new_coef::_Constant)
    JuMP.add_to_expression!(aff.decisions, new_coef, new_dvar)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_coef::_Constant, new_kvar::KnownRef)
    JuMP.add_to_expression!(aff.knowns, new_coef, new_kvar)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_kvar::KnownRef, new_coef::_Constant)
    JuMP.add_to_expression!(aff.knowns, new_coef, new_kvar)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_coef::_Constant, new_vae::_VAE)
    JuMP.add_to_expression!(aff.variables, new_coef, new_vae)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_vae::_VAE, new_coef::_Constant)
    JuMP.add_to_expression!(aff.variables, new_coef, new_vae)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_coef::_Constant, new_dae::_DAE)
    JuMP.add_to_expression!(aff.decisions, new_coef, new_dae)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_dae::_DAE, new_coef)
    JuMP.add_to_expression!(aff.decisions, new_coef, new_dae)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_coef::_Constant, new_kae::_KAE)
    JuMP.add_to_expression!(aff.knowns, new_coef, new_kae)
    return aff
end

function JuMP.add_to_expression!(aff::DAE, new_kae::_KAE, new_coef::_Constant)
    JuMP.add_to_expression!(aff.knowns, new_coef, new_kae)
    return aff
end

function JuMP.add_to_expression!(lhs_aff::DAE, new_coef::_Constant, rhs_aff::DAE)
    JuMP.add_to_expression!(lhs_aff, new_coef, rhs_aff.variables)
    JuMP.add_to_expression!(lhs_aff, new_coef, rhs_aff.decisions)
    JuMP.add_to_expression!(lhs_aff, new_coef, rhs_aff.knowns)
    return lhs_aff
end

function JuMP.add_to_expression!(lhs_aff::DAE, rhs_aff::DAE, new_coef::_Constant)
    JuMP.add_to_expression!(lhs_aff, rhs_aff.variables, new_coef)
    JuMP.add_to_expression!(lhs_aff, rhs_aff.decisions, new_coef)
    JuMP.add_to_expression!(lhs_aff, rhs_aff.knowns, new_coef)
    return lhs_aff
end
