const _Constant = JuMP._Constant
const _VariableAffExpr{C} = GenericAffExpr{C, VariableRef}
const _DecisionAffExpr{C} = GenericAffExpr{C, DecisionRef}
const _VAE = _VariableAffExpr{Float64}
const _DAE = _DecisionAffExpr{Float64}

mutable struct DecisionAffExpr{C} <: JuMP.AbstractJuMPScalar
    variables::GenericAffExpr{C, VariableRef}
    decisions::GenericAffExpr{C, DecisionRef}
end
const DAE = DecisionAffExpr{Float64}

DAE() = zero(DAE{Float64})

is_decision_type(::Type{<:DecisionAffExpr}) = true

# Base overrides #
# ========================== #
function Base.iszero(aff::DecisionAffExpr)
    return iszero(aff.variables) && iszero(aff.decisions)
end
function Base.zero(::Type{DecisionAffExpr{C}}) where C
    return DecisionAffExpr{C}(
        zero(_VariableAffExpr{C}),
        zero(_DecisionAffExpr{C}))
end
function Base.one(::Type{DecisionAffExpr{C}}) where C
    return DecisionAffExpr{C}(one(_VariableAffExpr{C}),
                              zero(_DecisionAffExpr{C}))
end
function Base.zero(aff::DecisionAffExpr)
    return zero(typeof(aff))
end
function Base.one(aff::DecisionAffExpr)
    return one(typeof(aff))
end
function Base.copy(aff::DecisionAffExpr{C}) where C
    return DecisionAffExpr{C}(copy(aff.variables),
                              copy(aff.decisions))
end
function Base.broadcastable(aff::DecisionAffExpr)
    return Ref(aff)
end

function Base.convert(::Type{DecisionAffExpr{C}}, v::VariableRef) where C
    return DecisionAffExpr{C}(_VariableAffExpr{C}(zero(C), v => one(C)),
                              zero(_DecisionAffExpr{C}))
end
function Base.convert(::Type{DecisionAffExpr{C}}, dv::DecisionRef) where C
    return DecisionAffExpr{C}(zero(_VariableAffExpr{C}),
                              _DecisionAffExpr{C}(zero(C), dv => one(C)))
end
function Base.convert(::Type{DecisionAffExpr{C}}, c::Number) where C
    return DecisionAffExpr{C}(_VariableAffExpr{C}(convert(C, c)),
                              zero(_DecisionAffExpr{C}))
end
function Base.convert(::Type{DecisionAffExpr{C}}, aff::_VariableAffExpr{C}) where C
    return DecisionAffExpr{C}(aff,
                              zero(_DecisionAffExpr{C}))
end
function Base.convert(::Type{DecisionAffExpr{C}}, aff::_DecisionAffExpr{C}) where C
    return DecisionAffExpr{C}(zero(_VariableAffExpr{C}),
                              aff)
end

function Base.convert(::Type{T}, aff::DecisionAffExpr{T}) where T
    if !isempty(aff.variables.terms) && !isempty(aff.decisions.terms)
        throw(InexactError(:convert, T, aff))
    end
    return convert(T, aff.variables.constant)
end

function Base.isequal(aff::DecisionAffExpr{C}, other::DecisionAffExpr{C}) where {C}
    return isequal(aff.variables, other.variables) && isequal(aff.decisions, other.decisions)
end

function JuMP.isequal_canonical(aff::DecisionAffExpr{C}, other::DecisionAffExpr{C}) where {C}
    return JuMP.isequal_canonical(aff.variables, other.variables) && JuMP.isequal_canonical(aff.decisions, other.decisions)
end

function Base.hash(aff::DecisionAffExpr, h::UInt)
    return hash(aff.variables.constant,
                hash(aff.variables.terms, h),
                hash(aff.decisions.terms, h))
end

# JuMP overrides #
# ========================== #
function JuMP.drop_zeros!(aff::DecisionAffExpr)
    JuMP.drop_zeros!(aff.variables)
    JuMP.drop_zeros!(aff.decisions)
    return nothing
end

function JuMP._affine_coefficient(f::DecisionAffExpr, variable::VariableRef)
    return JuMP._affine_coefficient(f.variables, variable)
end
function JuMP._affine_coefficient(f::DecisionAffExpr, decision::DecisionRef)
    return JuMP._affine_coefficient(f.decisions, decision)
end
function JuMP._affine_coefficient(f::_VariableAffExpr{C}, decision::DecisionRef) where C
    return zero(C)
end

function JuMP.map_coefficients_inplace!(f::Function, aff::DecisionAffExpr)
    JuMP.map_coefficients_inplace!(f, aff.variables)
    for (coef, dvar) in linear_terms(aff.decisions)
        aff.decisions.terms[dvar] = f(coef)
    end
    return aff
end

function JuMP.map_coefficients(f::Function, aff::DecisionAffExpr)
    return JuMP.map_coefficients_inplace!(f, copy(aff))
end

function JuMP.value(aff::DecisionAffExpr, value::Function)
    return JuMP.value(aff.variables, value) + JuMP.value(aff.decisions, value)
end

function JuMP.constant(aff::DecisionAffExpr)
    return aff.variables.constant
end

function SparseArrays.dropzeros(aff::DecisionAffExpr{C}) where C
    variables = SparseArrays.dropzeros(aff.variables)
    decisions = SparseArrays.dropzeros(aff.decisions)
    return DecisionAffExpr(variables, decisions)
end

function JuMP._assert_isfinite(aff::_DecisionAffExpr)
    for (coef, dv) in linear_terms(aff)
        isfinite(coef) || error("Invalid coefficient $coef on decision $dv.")
    end
    return nothing
end

function JuMP._assert_isfinite(aff::DecisionAffExpr)
    JuMP._assert_isfinite(aff.variables)
    JuMP._assert_isfinite(aff.decisions)
    return nothing
end

function JuMP.check_belongs_to_model(aff::DecisionAffExpr, model::AbstractModel)
    JuMP.check_belongs_to_model(aff.variables, model)
    JuMP.check_belongs_to_model(aff.decisions, model)
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
function JuMP.add_to_expression!(aff::DAE, new_vae::_VAE)
    JuMP.add_to_expression!(aff.variables, new_vae)
    return aff
end
function JuMP.add_to_expression!(aff::DAE, new_dae::_DAE)
    JuMP.add_to_expression!(aff.decisions, new_dae)
    return aff
end
function JuMP.add_to_expression!(lhs_aff::DAE, rhs_aff::DAE)
    JuMP.add_to_expression!(lhs_aff.variables, rhs_aff.variables)
    JuMP.add_to_expression!(lhs_aff.decisions, rhs_aff.decisions)
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
function JuMP.add_to_expression!(lhs_aff::DAE, new_coef::_Constant, rhs_aff::DAE)
    JuMP.add_to_expression!(lhs_aff, new_coef, rhs_aff.variables)
    JuMP.add_to_expression!(lhs_aff, new_coef, rhs_aff.decisions)
    return lhs_aff
end
function JuMP.add_to_expression!(lhs_aff::DAE, rhs_aff::DAE, new_coef::_Constant)
    JuMP.add_to_expression!(lhs_aff, rhs_aff.variables, new_coef)
    JuMP.add_to_expression!(lhs_aff, rhs_aff.decisions, new_coef)
    return lhs_aff
end
