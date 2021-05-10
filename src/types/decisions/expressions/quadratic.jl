const GQE{C,V} = GenericQuadExpr{C,V}
const _VariableQuadExpr{C} = GenericQuadExpr{C, VariableRef}
const _DecisionQuadExpr{C} = GenericQuadExpr{C, DecisionRef}
const _VQE = _VariableQuadExpr{Float64}
const _DQE = _DecisionQuadExpr{Float64}

struct DecisionCrossTerm
    decision::DecisionRef
    variable::VariableRef
end
Base.first(t::DecisionCrossTerm) = t.decision
Base.last(t::DecisionCrossTerm) = t.variable
Base.hash(t::DecisionCrossTerm, h::UInt) = hash(hash(t.decision) + hash(t.variable), h)
function Base.isequal(t1::DecisionCrossTerm, t2::DecisionCrossTerm)
    return (t1.decision == t2.decision && t1.variable == t2.variable)
end

mutable struct DecisionQuadExpr{C} <: JuMP.AbstractJuMPScalar
    variables::GenericQuadExpr{C, VariableRef}
    decisions::GenericQuadExpr{C, DecisionRef}
    cross_terms::OrderedDict{DecisionCrossTerm, C}
end
const DQE = DecisionQuadExpr{Float64}

DQE() = zero(DQE{Float64})

is_decision_type(::Type{<:DecisionQuadExpr}) = true

# Base overrides #
# ========================== #
function Base.iszero(quad::DecisionQuadExpr)
    return iszero(quad.variables) && iszero(quad.decisions)
end
function Base.zero(::Type{DecisionQuadExpr{C}}) where C
    return DecisionQuadExpr{C}(
        zero(_VariableQuadExpr{C}),
        zero(_DecisionQuadExpr{C}),
        OrderedDict{DecisionCrossTerm, C}())
end
function Base.one(::Type{DecisionQuadExpr{C}}) where C
    return DecisionQuadExpr{C}(
        one(_VariableQuadExpr{C}),
        zero(_DecisionQuadExpr{C}),
        OrderedDict{DecisionCrossTerm, C}())
end
function Base.zero(quad::DecisionQuadExpr)
    return zero(typeof(quad))
end
function Base.one(quad::DecisionQuadExpr)
    return one(typeof(quad))
end
function Base.copy(quad::DecisionQuadExpr{C}) where C
    return DecisionQuadExpr{C}(
        copy(quad.variables),
        copy(quad.decisions),
        copy(quad.cross_terms))
end
Base.broadcastable(quad::DecisionQuadExpr) = Ref(quad)

function Base.convert(::Type{DecisionQuadExpr{C}}, c::Number) where C
    return convert(DecisionQuadExpr{C}, convert(DecisionAffExpr{C}, c))
end
function Base.convert(::Type{DecisionQuadExpr{C}}, expr::Union{VariableRef, _VariableAffExpr}) where C
    return convert(DecisionQuadExpr{C}, convert(DecisionAffExpr{C}, expr))
end
function Base.convert(::Type{DecisionQuadExpr{C}}, expr::_VariableQuadExpr) where C
    return DecisionQuadExpr{C}(
        expr,
        zero(_DecisionQuadExpr{C}),
        OrderedDict{DecisionCrossTerm, C}())
end
function Base.convert(::Type{DecisionQuadExpr{C}}, expr::Union{DecisionRef, _DecisionAffExpr}) where C
    return convert(DecisionQuadExpr{C}, convert(DecisionAffExpr{C}, expr))
end
function Base.convert(::Type{DecisionQuadExpr{C}}, expr::_DecisionQuadExpr) where C
    return DecisionQuadExpr{C}(
        zero(_VariableQuadExpr{C}),
        expr,
        OrderedDict{DecisionCrossTerm, C}())
end
function Base.convert(::Type{DecisionQuadExpr{C}}, aff::DecisionAffExpr{C}) where C
    return DecisionQuadExpr{C}(
        convert(_VariableQuadExpr{C}, aff.variables),
        convert(_DecisionQuadExpr{C}, aff.decisions),
        OrderedDict{DecisionCrossTerm, C}())
end

function Base.isequal(quad::DecisionQuadExpr{C}, other::DecisionQuadExpr{C}) where C
    return isequal(quad.variables, other.variables) &&
        isequal(quad.decisions, other.decisions) &&
        isequal(quad.cross_terms, other.cross_terms)
end

function JuMP.isequal_canonical(quad::DecisionQuadExpr{C}, other::DecisionQuadExpr{C}) where {C}
    return isequal_canonical(quad.variables, other.variables) &&
        isequal_canonical(quad.decisions, other.decisions) &&
        isequal(quad.cross_terms, other.cross_terms)
end

function Base.hash(quad::DecisionQuadExpr, h::UInt)
    return hash(hash(quad.variables, h),
                hash(quad.decisions, h),
                hash(quad.cross_terms, h))
end

function sizehint!(quad::DecisionQuadExpr, n::Int, ::Type{_VAE})
    Base.sizehint!(quad.variables.aff, n)
end
function sizehint!(quad::DecisionQuadExpr, n::Int, ::Type{_DAE})
    Base.sizehint!(quad.decisions.aff, n)
end

# JuMP overrides #
# ========================== #
function JuMP.drop_zeros!(quad::DecisionQuadExpr)
    JuMP.drop_zeros!(quad.variables)
    JuMP.drop_zeros!(quad.decisions)
    dropzeros!(terms) = begin
        for (key, coef) in terms
            if iszero(coef)
                delete!(terms, key)
            end
        end
    end
    dropzeros!(quad.cross_terms)
    return nothing
end

function JuMP.coefficient(quad::DecisionQuadExpr{C}, v1::VariableRef, v2::VariableRef) where C
    return JuMP.coefficient(quad.variables, v1, v2)
end
function JuMP.coefficient(quad::DecisionQuadExpr{C}, v1::DecisionRef, v2::DecisionRef) where C
    return JuMP.coefficient(quad.decisions, v1, v2)
end
function JuMP.coefficient(quad::DecisionQuadExpr{C}, v1::VariableRef, v2::DecisionRef) where C
    return get(quad.cross_terms, DecisionCrossTerm(v2, v1), zero(C))
end
function JuMP.coefficient(quad::DecisionQuadExpr{C}, v1::DecisionRef, v2::VariableRef) where C
    return get(quad.cross_terms, DecisionCrossTerm(v1, v2), zero(C))
end

function JuMP.coefficient(quad::DecisionQuadExpr{C}, var::VariableRef) where C
    return JuMP.coefficient(quad.variables, var)
end
function JuMP.coefficient(quad::DecisionQuadExpr{C}, dvar::DecisionRef) where C
    return JuMP.coefficient(quad.decisions, dvar)
end

function JuMP._affine_coefficient(f::DecisionQuadExpr, variable::VariableRef)
    return JuMP._affine_coefficient(f.variables, variable)
end
function JuMP._affine_coefficient(f::DecisionQuadExpr, decision::DecisionRef)
    return JuMP._affine_coefficient(f.decisions, decision)
end

function JuMP.map_coefficients_inplace!(f::Function, quad::DecisionQuadExpr)
    JuMP.map_coefficients_inplace!(f, quad.variables)
    JuMP.map_coefficients_inplace!(f, quad.decisions)
    _map_cross_terms!(f, quad.cross_terms)
    return quad
end

function _map_cross_terms!(f::Function, terms)
    for (key, value) in terms
        terms[key] = f(value)
    end
    return nothing
end

function _map_cross_terms(f::Function, terms)
    res = copy(terms)
    _map_cross_terms!(f, res)
    return res
end

function JuMP.map_coefficients(f::Function, quad::DecisionQuadExpr)
    return JuMP.map_coefficients_inplace!(f, copy(quad))
end

function JuMP.value(quad::DecisionQuadExpr, value_func::Function)
    varvalue = JuMP.value(quad.variables, value_func)
    dvarvalue = JuMP.value(quad.decisions, value_func)
    T = promote_type(typeof(varvalue), typeof(dvarvalue))
    ret = convert(T, varvalue) + convert(T, dvarvalue)
    val(terms, T) = begin
        ret = zero(T)
        for (vars, coef) in quad.cross_terms
            ret += coef * value_func(vars.a) * value_func(vars.b)
        end
        ret
    end
    ret += val(quad.cross_terms, T)
    return ret
end

function JuMP.constant(quad::DecisionQuadExpr)
    return quad.variables.constant
end

function JuMP.linear_terms(quad::DecisionQuadExpr, ::Type{_VAE})
    JuMP.linear_terms(quad.variables)
end
function JuMP.linear_terms(quad::DecisionQuadExpr, ::Type{_DAE})
    JuMP.linear_terms(quad.decisions)
end

function SparseArrays.dropzeros(quad::DecisionQuadExpr{C}) where C
    variables = SparseArrays.dropzeros(quad.variables)
    decisions = SparseArrays.dropzeros(quad.decisions)
    dropzeros!(terms) = begin
        for (key, value) in terms
            if iszero(value)
                delete!(terms, key)
            end
        end
    end
    cross_terms = copy(quad.cross_terms)
    dropzeros!(cross_terms)
    return DecisionQuadExpr(variables, decisions, cross_terms)
end

function JuMP._assert_isfinite(quad::_DecisionQuadExpr)
    JuMP._assert_isfinite(quad.aff)
    for (coef, var1, var2) in quad_terms(quad)
        isfinite(coef) || error("Invalid coefficient $coef on quadratic term $var1*$var2.")
    end
    return nothing
end

function JuMP._assert_isfinite(terms::OrderedDict{DecisionCrossTerm, C}) where C
    for (vars, coef) in terms
        isfinite(coef) || error("Invalid coefficient $coef on quadratic cross term $first(vars)*$last(vars).")
    end
    return nothing
end

function JuMP._assert_isfinite(quad::DecisionQuadExpr)
    JuMP._assert_isfinite(quad.variables)
    JuMP._assert_isfinite(quad.decisions)
    JuMP._assert_isfinite(quad.cross_terms)
    return nothing
end

function JuMP.check_belongs_to_model(terms::OrderedDict{DecisionCrossTerm, C}) where C
    for variable_pair in keys(terms)
        JuMP.check_belongs_to_model(first(variable_pair), model)
        JuMP.check_belongs_to_model(last(variable_pair), model)
    end
    return nothing
end

function JuMP.check_belongs_to_model(quad::DecisionQuadExpr, model::AbstractModel)
    JuMP.check_belongs_to_model(quad.variables, model)
    JuMP.check_belongs_to_model(quad.decisions, model)
    check_belongs_to_model(quad.cross_terms)
    return nothing
end

function JuMP.function_string(mode, quad::DecisionQuadExpr, show_constant=true)
    # Decisions
    ret = ""
    decision_terms = JuMP.function_string(mode, quad.decisions)
    if decision_terms != "0"
        ret = decision_terms
    end
    cross_terms = _cross_terms_function_string(mode, quad.cross_terms)
    ret = _add_terms(ret, cross_terms)
    # Variables
    variable_terms = JuMP.function_string(mode, quad.variables)
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
    else
        if ret == ""
            return variable_terms
        end
    end
    return ret
end

function _cross_terms_function_string(mode, terms)
    term_str = Array{String}(undef, 2 * length(terms))
    elm = 1
    if length(term_str) > 0
        for (vars, coef) in terms
            pre = JuMP._is_one_for_printing(coef) ? "" : JuMP._string_round(abs(coef)) * " "

            x = function_string(mode, first(vars))
            y = function_string(mode, last(vars))

            term_str[2 * elm - 1] = JuMP._sign_string(coef)
            term_str[2 * elm] = "$pre$x"
            term_str[2 * elm] *= string(JuMP._math_symbol(mode, :times), y)
            if elm == 1
                # Correction for first term as there is no space
                # between - and variable coefficient/name
                term_str[1] = coef < zero(coef) ? "-" : ""
            end
            elm += 1
        end
    end
    ret = join(term_str[1 : 2 * (elm - 1)])
    return ret
end

# With one factor.
function JuMP.add_to_expression!(quad::DQE, other::Number)
    JuMP.add_to_expression!(quad.variables, other)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_var::VariableRef)
    JuMP.add_to_expression!(quad.variables, new_var)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_dvar::DecisionRef)
    JuMP.add_to_expression!(quad.decisions, new_dvar)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_vae::_VAE)
    JuMP.add_to_expression!(quad.variables, new_vae)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_dae::_DAE)
    JuMP.add_to_expression!(quad.decisions, new_dae)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_vqe::_VQE)
    JuMP.add_to_expression!(quad.variables, new_vqe)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_dqe::_DQE)
    JuMP.add_to_expression!(quad.decisions, new_dqe)
    return quad
end
function JuMP.add_to_expression!(lhs_quad::DQE, rhs_aff::DAE)
    JuMP.add_to_expression!(lhs_quad.variables, rhs_aff.variables)
    JuMP.add_to_expression!(lhs_quad.decisions, rhs_aff.decisions)
    return lhs_quad
end
function JuMP.add_to_expression!(lhs_quad::DQE, rhs_quad::DQE)
    JuMP.add_to_expression!(lhs_quad.variables, rhs_quad.variables)
    JuMP.add_to_expression!(lhs_quad.decisions, rhs_quad.decisions)
    add_cross_terms!(terms, other) = begin
        for (key, term_coef) in other
            JuMP._add_or_set!(terms, key, term_coef)
        end
    end
    add_cross_terms!(lhs_quad.cross_terms, rhs_quad.cross_terms)
    return lhs_quad
end

# With two factors.
function JuMP.add_to_expression!(quad::DQE, new_coef::_Constant, new_var::VariableRef)
    JuMP.add_to_expression!(quad.variables, new_coef, new_var)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_var::VariableRef, new_coef::_Constant)
    JuMP.add_to_expression!(quad.variables, new_coef, new_var)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_coef::_Constant, new_dvar::DecisionRef)
    JuMP.add_to_expression!(quad.decisions, new_coef, new_dvar)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_dvar::DecisionRef, new_coef::_Constant)
    JuMP.add_to_expression!(quad.decisions, new_coef, new_dvar)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_coef::_Constant, new_vae::_VAE)
    JuMP.add_to_expression!(quad.variables, new_coef, new_vae)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_vae::_VAE, new_coef::_Constant)
    JuMP.add_to_expression!(quad.variables, new_coef, new_vae)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_coef::_Constant, new_dae::_DAE)
    JuMP.add_to_expression!(quad.decisions, new_coef, new_dae)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_dae::_DAE, new_coef::_Constant)
    JuMP.add_to_expression!(quad.decisions, new_coef, new_dae)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_coef::_Constant, new_vqe::_VQE)
    JuMP.add_to_expression!(quad.variables, new_coef, new_vqe)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_vqe::_VQE, new_coef::_Constant)
    JuMP.add_to_expression!(quad.variables, new_coef, new_vqe)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_coef::_Constant, new_dqe::_DQE)
    JuMP.add_to_expression!(quad.decisions, new_coef, new_dqe)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_dqe::_DQE, new_coef::_Constant)
    JuMP.add_to_expression!(quad.decisions, new_coef, new_dqe)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, coef::_Constant, other::DQE)
    JuMP.add_to_expression!(quad.variables, coef, other.variables)
    JuMP.add_to_expression!(quad.decisions, coef, other.decisions)
    add_cross_terms!(terms, other) = begin
        for (key, term_coef) in other
            JuMP._add_or_set!(terms, key, coef * term_coef)
        end
    end
    add_cross_terms!(quad.cross_terms, other.cross_terms)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, other::DQE, coef::_Constant)
    JuMP.add_to_expression!(quad, coef, other)
    return quad
end
function JuMP.add_to_expression!(quad::DQE,
                                 var_1::VariableRef,
                                 var_2::Union{VariableRef,DecisionRef})
    return JuMP.add_to_expression!(quad, 1.0, var_1, var_2)
end
function JuMP.add_to_expression!(quad::DQE,
                                 var_1::DecisionRef,
                                 var_2::Union{VariableRef,DecisionRef})
    return JuMP.add_to_expression!(quad, 1.0, var_1, var_2)
end
function JuMP.add_to_expression!(quad::DQE,
                                 var::VariableRef,
                                 aff::_VAE)
    JuMP.add_to_expression!(quad.variables, var, aff)
    return quad
end
function JuMP.add_to_expression!(quad::DQE,
                                 dvar::DecisionRef,
                                 aff::_VAE)
    for (coef, term_var) in linear_terms(aff)
        key = DecisionCrossTerm(dvar, term_var)
        JuMP._add_or_set!(quad.cross_terms, key, coef)
    end
    return quad
end
function JuMP.add_to_expression!(quad::DQE,
                                 var::VariableRef,
                                 aff::_DAE)
    for (coef, term_dvar) in linear_terms(aff)
        key = DecisionCrossTerm(term_dvar, var)
        JuMP._add_or_set!(quad.cross_terms, key, coef)
    end
    return quad
end
function JuMP.add_to_expression!(quad::DQE,
                                 dvar::DecisionRef,
                                 aff::_DAE)
    JuMP.add_to_expression!(quad.decisions, dvar, aff)
    return quad
end
function JuMP.add_to_expression!(quad::DQE,
                                 var::Union{VariableRef, DecisionRef},
                                 aff::DAE)
    JuMP.add_to_expression!(quad, var, aff.variables)
    JuMP.add_to_expression!(quad, var, aff.decisions)
    return quad
end
function JuMP.add_to_expression!(quad::DQE,
                                 aff::Union{_VAE, _DAE, DAE},
                                 var::Union{VariableRef, DecisionRef})
    return JuMP.add_to_expression!(quad, var, aff)
end
function JuMP.add_to_expression!(quad::DQE,
                                 lhs::_VAE,
                                 rhs::_VAE)
    JuMP.add_to_expression!(quad.variables, lhs, rhs)
    return quad
end
function JuMP.add_to_expression!(quad::DQE,
                                 lhs::_DAE,
                                 rhs::_DAE)
    JuMP.add_to_expression!(quad.decisions, lhs, rhs)
    return quad
end
function JuMP.add_to_expression!(quad::DQE,
                                 lhs::Union{_VAE,_DAE,},
                                 rhs::Union{_VAE,_DAE,})
    lhs_length = length(linear_terms(lhs))
    rhs_length = length(linear_terms(rhs))

    # Quadratic terms
    for (lhscoef, lhsvar) in linear_terms(lhs)
        for (rhscoef, rhsvar) in linear_terms(rhs)
            add_to_expression!(quad, lhscoef*rhscoef, lhsvar, rhsvar)
        end
    end

    # Try to preallocate space for aff
    cur = length(linear_terms(quad, typeof(rhs)))
    if !iszero(lhs.constant)
        sizehint!(quad, cur + lhs_length + rhs_length, typeof(rhs))
    end
    if !iszero(rhs.constant)
        sizehint!(quad, cur + lhs_length, typeof(lhs))
    end

    # [LHS constant] * [RHS linear terms]
    if !iszero(lhs.constant)
        c = lhs.constant
        for (rhscoef, rhsvar) in linear_terms(rhs)
            if rhs isa _VAE
                add_to_expression!(quad.variables.aff, c*rhscoef, rhsvar)
            elseif rhs isa _DAE
                add_to_expression!(quad.decisions.aff, c*rhscoef, rhsvar)
            end
        end
    end

    # [RHS constant] * [LHS linear terms]
    if !iszero(rhs.constant)
        c = rhs.constant
        for (lhscoef, lhsvar) in linear_terms(lhs)
            if lhs isa _VAE
                add_to_expression!(quad.variables.aff, c*lhscoef, lhsvar)
            elseif lhs isa _DAE
                add_to_expression!(quad.decisions.aff, c*lhscoef, lhsvar)
            end
        end
    end

    quad.variables.aff.constant += lhs.constant * rhs.constant

    return quad
end
function JuMP.add_to_expression!(quad::DQE,
                                 lhs::Union{_VAE, _DAE, },
                                 rhs::DAE)
    JuMP.add_to_expression!(quad, lhs, rhs.variables)
    JuMP.add_to_expression!(quad, lhs, rhs.decisions)
    return quad
end
function JuMP.add_to_expression!(quad::DQE,
                                 lhs::DAE,
                                 rhs::Union{_VAE, _DAE})
    JuMP.add_to_expression!(quad, rhs, lhs)
    return quad
end
function JuMP.add_to_expression!(quad::DQE,
                                 lhs::DAE,
                                 rhs::DAE)
    # Variables
    JuMP.add_to_expression!(quad, lhs.variables, rhs.variables)
    JuMP.add_to_expression!(quad, lhs.variables, rhs.decisions)
    JuMP.add_to_expression!(quad, lhs.variables, rhs.knowns)
    # Decisions
    JuMP.add_to_expression!(quad, lhs.decisions, rhs.variables)
    JuMP.add_to_expression!(quad, lhs.decisions, rhs.decisions)
    JuMP.add_to_expression!(quad, lhs.decisions, rhs.knowns)
    return quad
end

# With three factors.
function JuMP.add_to_expression!(quad::DQE, new_coef::_Constant,
                                 new_var1::VariableRef,
                                 new_var2::VariableRef)
    JuMP.add_to_expression!(quad.variables, new_coef, new_var1, new_var2)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_coef::_Constant,
                                 new_var1::VariableRef,
                                 new_var2::DecisionRef)
    key = DecisionCrossTerm(new_var2, new_var1)
    JuMP._add_or_set!(quad.cross_terms, key, new_coef)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_coef::_Constant,
                                 new_var1::DecisionRef,
                                 new_var2::VariableRef)
    key = DecisionCrossTerm(new_var1, new_var2)
    JuMP._add_or_set!(quad.cross_terms, key, new_coef)
    return quad
end
function JuMP.add_to_expression!(quad::DQE, new_coef::_Constant,
                                 new_var1::DecisionRef,
                                 new_var2::DecisionRef)
    JuMP.add_to_expression!(quad.decisions, new_coef, new_var1, new_var2)
    return quad
end
