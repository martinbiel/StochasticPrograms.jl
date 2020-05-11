const GQE{C,V} = JuMP.GenericQuadExpr{C,V}
const VariableQuadExpr{C} = JuMP.GenericQuadExpr{C,VariableRef}
const DecisionQuadExpr{C} = JuMP.GenericQuadExpr{C,DecisionRef}
const KnownQuadExpr{C} = JuMP.GenericQuadExpr{C,KnownRef}
const VQE = VariableQuadExpr{Float64}
const DQE = DecisionQuadExpr{Float64}
const KQE = KnownQuadExpr{Float64}

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

struct KnownCrossTerm{V}
    known::KnownRef
    variable::V
end
Base.first(t::KnownCrossTerm) = t.known
Base.last(t::KnownCrossTerm) = t.variable
KnownVariableCrossTerm = KnownCrossTerm{VariableRef}
KnownDecisionCrossTerm = KnownCrossTerm{DecisionRef}

Base.hash(t::KnownCrossTerm, h::UInt) = hash(hash(t.known) + hash(t.variable), h)
function Base.isequal(t1::KnownCrossTerm, t2::KnownCrossTerm)
    return (t1.known == t2.known && t1.variable == t2.variable)
end

mutable struct CombinedQuadExpr{C} <: JuMP.AbstractJuMPScalar
    variables::VariableQuadExpr{C}
    decisions::DecisionQuadExpr{C}
    knowns::KnownQuadExpr{C}
    cross_terms::OrderedDict{DecisionCrossTerm, C}
    known_variable_terms::OrderedDict{KnownVariableCrossTerm, C}
    known_decision_terms::OrderedDict{KnownDecisionCrossTerm, C}
end
const CQE = CombinedQuadExpr{Float64}

CQE() = zero(CQE{Float64})

mutable struct BilinearDecisionExpr{C} <: JuMP.AbstractJuMPScalar
    variables::VariableAffExpr{C}
    decisions::DecisionAffExpr{C}
    knowns::KnownQuadExpr{C}
    known_variable_terms::OrderedDict{KnownVariableCrossTerm, C}
    known_decision_terms::OrderedDict{KnownDecisionCrossTerm, C}
end
const BDE = BilinearDecisionExpr{Float64}

# Base overrides #
# ========================== #
function Base.iszero(quad::CombinedQuadExpr)
    return iszero(quad.variables) &&
        iszero(quad.decisions) &&
        iszero(quad.knowns)
end
function Base.zero(::Type{CombinedQuadExpr{C}}) where C
    return CombinedQuadExpr{C}(
        zero(VariableQuadExpr{C}),
        zero(DecisionQuadExpr{C}),
        zero(KnownQuadExpr{C}),
        OrderedDict{DecisionCrossTerm, C}(),
        OrderedDict{KnownVariableCrossTerm, C}(),
        OrderedDict{KnownDecisionCrossTerm, C}())
end
function Base.one(::Type{CombinedQuadExpr{C}}) where C
    return CombinedQuadExpr{C}(
        one(VariableQuadExpr{C}),
        zero(DecisionQuadExpr{C}),
        zero(KnownQuadexpr{C}),
        OrderedDict{DecisionCrossTerm, C}(),
        OrderedDict{KnownVariableCrossTerm, C}(),
        OrderedDict{KnownDecisionCrossTerm, C}())
end
Base.zero(quad::CombinedQuadExpr) = zero(typeof(quad))
Base.one(quad::CombinedQuadExpr) =  one(typeof(quad))
function Base.copy(quad::CombinedQuadExpr{C}) where C
    return CombinedQuadExpr{C}(
        copy(quad.variables),
        copy(quad.decisions),
        copy(quad.knowns),
        copy(quad.cross_terms),
        copy(quad.known_variable_terms),
        copy(quad.known_decision_terms))
end
Base.broadcastable(quad::CombinedQuadExpr) = Ref(quad)

function Base.convert(::Type{CombinedQuadExpr{C}}, c::Number) where C
    return convert(CombinedQuadExpr{C}, convert(CombinedAffExpr{C}, c))
end
function Base.convert(::Type{CombinedQuadExpr{C}}, expr::DecisionAffExpr) where C
    return convert(CombinedQuadExpr{C}, convert(CombinedAffExpr{C}, expr))
end
function Base.convert(::Type{CombinedQuadExpr{C}}, expr::KnownAffExpr) where C
    return convert(CombinedQuadExpr{C}, convert(CombinedAffExpr{C}, expr))
end
function Base.convert(::Type{CombinedQuadExpr{C}}, aff::CombinedAffExpr) where C
    return CombinedQuadExpr{C}(
        VariableQuadExpr(aff.variables),
        DecisionQuadExpr(aff.decisions),
        KnownQuadExpr(aff.knowns),
        OrderedDict{DecisionCrossTerm, C}(),
        OrderedDict{KnownVariableCrossTerm, C}(),
        OrderedDict{KnownDecisionCrossTerm, C}())
end

function Base.isequal(quad::CombinedQuadExpr{C}, other::CombinedQuadExpr{C}) where C
    return isequal(quad.variables, other.variables) &&
        isequal(quad.decisions, other.decisions) &&
        isequal(quad.knowns, other.knowns) &&
        isequal(quad.cross_terms, other.cross_terms) &&
        isequal(quad.known_variable_terms, other.known_variable_terms) &&
        isequal(quad.known_decision_terms, other.known_decision_terms)
end

Base.hash(quad::CombinedQuadExpr, h::UInt) =
    hash(hash(quad.variables, h),
         hash(quad.decisions, h),
         hash(quad.knowns, h),
         hash(quad.cross_terms, h),
         hash(quad.known_variable_terms, h),
         hash(quad.known_decision_terms, h))

function sizehint!(quad::CombinedQuadExpr, n::Int, ::Type{VAE})
    sizehint!(quad.variables.affine.terms, n)
end
function sizehint!(quad::CombinedQuadExpr, n::Int, ::Type{DAE})
    sizehint!(quad.decisions.affine.terms, n)
end
function sizehint!(quad::CombinedQuadExpr, n::Int, ::Type{KAE})
    sizehint!(quad.knowns.affine.terms, n)
end

# JuMP overrides #
# ========================== #
function JuMP.drop_zeros!(quad::CombinedQuadExpr)
    JuMP.drop_zeros!(quad.variables)
    JuMP.drop_zeros!(quad.decisions)
    JuMP.drop_zeros!(quad.knowns)
    dropzeros!(terms) = begin
        for (key, coef) in terms
            if iszero(coef)
                delete!(terms, key)
            end
        end
    end
    dropzeros!(quad.cross_terms)
    dropzeros!(quad.known_variable_terms)
    dropzeros!(quad.known_decision_terms)
    return nothing
end

function JuMP._affine_coefficient(f::CombinedQuadExpr, variable::VariableRef)
    return JuMP._affine_coefficient(f.variables, variable)
end
function JuMP._affine_coefficient(f::CombinedQuadExpr, decision::DecisionRef)
    return JuMP._affine_coefficient(f.decisions, decision)
end
function JuMP._affine_coefficient(f::CombinedQuadExpr, known::KnownRef)
    return JuMP._affine_coefficient(f.knowns, known)
end

function JuMP.map_coefficients_inplace!(f::Function, quad::CombinedQuadExpr)
    JuMP.map_coefficients_inplace!(f, quad.variables)
    JuMP.map_coefficients_inplace!(f, quad.decisions)
    JuMP.map_coefficients_inplace!(f, quad.knowns)
    _map_cross_terms(quad.cross_terms)
    _map_cross_terms(quad.known_variable_terms)
    _map_cross_terms(quad.known_decision_terms)
    return quad
end

function _map_cross_terms(f::Function, terms)
    for (key, value) in terms
        quad.terms[key] = f(value)
    end
end

function JuMP.map_coefficients(f::Function, quad::CombinedQuadExpr)
    return JuMP.map_coefficients_inplace!(f, copy(quad))
end

function JuMP.value(quad::CombinedQuadExpr, value_func::Function)
    varvalue = JuMP.value(quad.variables, value_func)
    dvarvalue = JuMP.value(quad.decisions, value_func)
    kvarvalue = JuMP.value(quad.knowns, value_func)
    T = promote_type(typeof(varvalue), typeof(dvarvalue), typeof(kvarvalue))
    ret = convert(T, varvalue) + convert(T, dvarvalue) + convert(T, kvarvalue)
    val(terms, T) = begin
        ret = zero(T)
        for (vars, coef) in quad.cross_terms
            ret += coef * value_func(vars.a) * value_func(vars.b)
        end
        ret
    end
    ret += val(quad.cross_terms, T)
    ret += val(quad.known_variable_terms, T)
    ret += val(quad.known_decision_terms, T)
    return ret
end

function JuMP.constant(quad::CombinedQuadExpr)
    return quad.variables.constant
end

function JuMP.linear_terms(quad::CombinedQuadExpr, ::Type{VAE})
    JuMP.linear_terms(quad.variables)
end
function JuMP.linear_terms(quad::CombinedQuadExpr, ::Type{DAE})
    JuMP.linear_terms(quad.decisions)
end
function JuMP.linear_terms(quad::CombinedQuadExpr, ::Type{KAE})
    JuMP.linear_terms(quad.knowns)
end

function SparseArrays.dropzeros(quad::CombinedQuadExpr{C}) where C
    variables = SparseArrays.dropzeros(quad.variables)
    decisions = SparseArrays.dropzeros(quad.decisions)
    knowns = SparseArrays.dropzeros(quad.knowns)
    dropzeros!(terms) = begin
        for (key, value) in terms
            if iszero(value)
                delete!(terms, key)
            end
        end
    end
    cross_terms = copy(quad.cross_terms)
    dropzeros!(cross_terms)
    known_variable_terms = copy(quad.known_variable_terms)
    dropzeros!(known_variable_terms)
    known_decision_terms = copy(quad.known_decision_terms)
    dropzeros!(known_decision_terms)
    return CombinedQuadExpr(variables, decisions, knowns, cross_terms, known_variable_terms, known_decision_terms)
end

function JuMP._assert_isfinite(quad::Union{DecisionQuadExpr, KnownQuadExpr})
    JuMP._assert_isfinite(quad.aff)
    for (coef, var1, var2) in quad_terms(quad)
        isfinite(coef) || error("Invalid coefficient $coef on quadratic term $var1*$var2.")
    end
    return nothing
end

function JuMP._assert_isfinite(quad::CombinedQuadExpr)
    JuMP._assert_isfinite(quad.variables)
    JuMP._assert_isfinite(quad.decisions)
    JuMP._assert_isfinite(quad.knowns)
    _assert_isfinite(terms) = begin
        for (vars, coef) in terms
            isfinite(coef) || error("Invalid coefficient $coef on quadratic cross term $first(vars)*$last(vars).")
        end
    end
    _assert_isfinite(quad.cross_terms)
    _assert_isfinite(quad.known_variable_terms)
    _assert_isfinite(quad.known_decision_terms)
    return nothing
end

function JuMP.check_belongs_to_model(quad::CombinedQuadExpr, model::AbstractModel)
    JuMP.check_belongs_to_model(quad.variables, model)
    JuMP.check_belongs_to_model(quad.decisions, model)
    JuMP.check_belongs_to_model(quad.knowns, model)
    check_belongs_to_model(terms) = begin
        for variable_pair in keys(terms)
            JuMP.check_belongs_to_model(first(variable_pair), model)
            JuMP.check_belongs_to_model(last(variable_pair), model)
        end
    end
    check_belongs_to_model(quad.cross_terms)
    check_belongs_to_model(quad.known_variable_terms)
    check_belongs_to_model(quad.known_decision_terms)
    return nothing
end

function JuMP.function_string(mode, quad::CombinedQuadExpr, show_constant=true)
    # Decisions
    ret = ""
    decision_terms = JuMP.function_string(mode, quad.decisions)
    if decision_terms != "0"
        ret = decision_terms
    end
    known_decision_terms = _cross_terms_function_string(mode, quad.known_decision_terms)
    ret = _add_terms(ret, known_decision_terms)
    cross_terms = _cross_terms_function_string(mode, quad.cross_terms)
    ret = _add_terms(ret, cross_terms)
    # Knowns
    known_terms = JuMP.function_string(mode, quad.knowns)
    ret = _add_terms(ret, known_terms)
    known_variable_terms = _cross_terms_function_string(mode, quad.known_variable_terms)
    ret = _add_terms(ret, known_variable_terms)
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
function JuMP.add_to_expression!(quad::CQE, other::Number)
    JuMP.add_to_expression!(quad.variables, other)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_var::VariableRef)
    JuMP.add_to_expression!(quad.variables, new_var)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_dvar::DecisionRef)
    JuMP.add_to_expression!(quad.decisions, new_dvar)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_kvar::KnownRef)
    JuMP.add_to_expression!(quad.knowns, new_kvar)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_vae::VAE)
    JuMP.add_to_expression!(quad.variables, new_vae)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_dae::DAE)
    JuMP.add_to_expression!(quad.decisions, new_dae)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_kae::KAE)
    JuMP.add_to_expression!(quad.knowns, new_kae)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_vqe::VQE)
    JuMP.add_to_expression!(quad.variables, new_vqe)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_dqe::DQE)
    JuMP.add_to_expression!(quad.decisions, new_dqe)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_kqe::KQE)
    JuMP.add_to_expression!(quad.knowns, new_kqe)
    return quad
end

function JuMP.add_to_expression!(lhs_quad::CQE, rhs_aff::CAE)
    JuMP.add_to_expression!(lhs_quad.variables, rhs_aff.variables)
    JuMP.add_to_expression!(lhs_quad.decisions, rhs_aff.decisions)
    JuMP.add_to_expression!(lhs_quad.knowns, rhs_aff.knowns)
    return lhs_quad
end

function JuMP.add_to_expression!(lhs_quad::CQE, rhs_quad::CQE)
    JuMP.add_to_expression!(lhs_quad.variables, rhs_quad.variables)
    JuMP.add_to_expression!(lhs_quad.decisions, rhs_quad.decisions)
    JuMP.add_to_expression!(lhs_quad.knowns, rhs_quad.knowns)
    add_cross_terms!(terms, other) = begin
        for (key, term_coef) in other
            JuMP._add_or_set!(terms, key, term_coef)
        end
    end
    add_cross_terms!(lhs_quad.cross_terms, rhs_quad.cross_terms)
    add_cross_terms!(lhs_quad.known_variable_terms, rhs_quad.known_variable_terms)
    add_cross_terms!(lhs_quad.known_decision_terms, rhs_quad.known_decision_terms)
    return lhs_quad
end

# With two factors.
function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant, new_var::VariableRef)
    JuMP.add_to_expression!(quad.variables, new_coef, new_var)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_var::VariableRef, new_coef::_Constant)
    JuMP.add_to_expression!(quad.variables, new_coef, new_var)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant, new_dvar::DecisionRef)
    JuMP.add_to_expression!(quad.decisions, new_coef, new_dvar)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_dvar::DecisionRef, new_coef::_Constant)
    JuMP.add_to_expression!(quad.decisions, new_coef, new_dvar)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant, new_kvar::KnownRef)
    JuMP.add_to_expression!(quad.knowns, new_coef, new_kvar)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_kvar::KnownRef, new_coef::_Constant)
    JuMP.add_to_expression!(quad.knowns, new_coef, new_kvar)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant, new_vae::VAE)
    JuMP.add_to_expression!(quad.variables, new_coef, new_vae)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_vae::VAE, new_coef::_Constant)
    JuMP.add_to_expression!(quad.variables, new_coef, new_vae)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant, new_dae::DAE)
    JuMP.add_to_expression!(quad.decisions, new_coef, new_dae)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_dae::DAE, new_coef::_Constant)
    JuMP.add_to_expression!(quad.decisions, new_coef, new_dae)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant, new_kae::KAE)
    JuMP.add_to_expression!(quad.knowns, new_coef, new_kae)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_kae::KAE, new_coef::_Constant)
    JuMP.add_to_expression!(quad.knowns, new_coef, new_kae)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant, new_vqe::VQE)
    JuMP.add_to_expression!(quad.variables, new_coef, new_vqe)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_vqe::VQE, new_coef::_Constant)
    JuMP.add_to_expression!(quad.variables, new_coef, new_vqe)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant, new_dqe::DQE)
    JuMP.add_to_expression!(quad.decisions, new_coef, new_dqe)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_dqe::DQE, new_coef::_Constant)
    JuMP.add_to_expression!(quad.decisions, new_coef, new_dqe)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant, new_kqe::KQE)
    JuMP.add_to_expression!(quad.knowns, new_coef, new_kqe)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, new_kqe::KQE, new_coef::_Constant)
    JuMP.add_to_expression!(quad.knowns, new_coef, new_kqe)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, coef::_Constant, other::CQE)
    JuMP.add_to_expression!(quad.variables, coef, other.variables)
    JuMP.add_to_expression!(quad.decisions, coef, other.decisions)
    JuMP.add_to_expression!(quad.knowns, coef, other.knowns)
    add_cross_terms!(terms, other) = begin
        for (key, term_coef) in other
            JuMP._add_or_set!(terms, key, coef * term_coef)
        end
    end
    add_cross_terms!(quad.cross_terms, other.cross_terms)
    add_cross_terms!(quad.known_variable_terms, other.known_variable_terms)
    add_cross_terms!(quad.known_decision_terms, other.known_decision_terms)
    return quad
end

function JuMP.add_to_expression!(quad::CQE, other::CQE, coef::_Constant)
    JuMP.add_to_expression!(quad, coef, other)
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 var_1::VariableRef,
                                 var_2::Union{DecisionRef, KnownRef})
    return JuMP.add_to_expression!(quad, 1.0, var_1, var_2)
end

function JuMP.add_to_expression!(quad::CQE,
                                 var_1::VariableRef,
                                 var_2::KnownRef)
    return JuMP.add_to_expression!(quad, 1.0, var_1, var_2)
end

function JuMP.add_to_expression!(quad::CQE,
                                 var_1::DecisionRef,
                                 var_2::Union{VariableRef,DecisionRef,KnownRef})
    return JuMP.add_to_expression!(quad, 1.0, var_1, var_2)
end

function JuMP.add_to_expression!(quad::CQE,
                                 var_1::KnownRef,
                                 var_2::Union{VariableRef,DecisionRef,KnownRef})
    return JuMP.add_to_expression!(quad, 1.0, var_1, var_2)
end

function JuMP.add_to_expression!(quad::CQE,
                                 var::VariableRef,
                                 aff::VAE)
    JuMP.add_to_expression!(quad.variables, var, aff)
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 dvar::DecisionRef,
                                 aff::VAE)
    for (coef, term_var) in linear_terms(aff)
        key = DecisionCrossTerm(dvar, term_var)
        JuMP._add_or_set!(quad.cross_terms, key, coef)
    end
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 kvar::KnownRef,
                                 aff::VAE)
    for (coef, term_var) in linear_terms(aff)
        key = KnownVariableCrossTerm(kvar, term_var)
        JuMP._add_or_set!(quad.known_variable_terms, key, coef)
    end
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 var::VariableRef,
                                 aff::DAE)
    for (coef, term_dvar) in linear_terms(aff)
        key = DecisionCrossTerm(term_dvar, var)
        JuMP._add_or_set!(quad.cross_terms, key, coef)
    end
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 dvar::DecisionRef,
                                 aff::DAE)
    JuMP.add_to_expression!(quad.decisions, dvar, aff)
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 kvar::KnownRef,
                                 aff::DAE)
    for (coef, term_dvar) in linear_terms(aff)
        key = KnownDecisionCrossTerm(kvar, term_dvar)
        JuMP._add_or_set!(quad.known_decision_terms, key, coef)
    end
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 var::VariableRef,
                                 aff::KAE)
    for (coef, term_kvar) in linear_terms(aff)
        key = KnownVariableCrossTerm(term_kvar, var)
        JuMP._add_or_set!(quad.known_variable_terms, key, coef)
    end
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 dvar::DecisionRef,
                                 aff::KAE)
    for (coef, term_kvar) in linear_terms(aff)
        key = KnownDecisionCrossTerm(term_kvar, dvar)
        JuMP._add_or_set!(quad.known_decision_terms, key, coef)
    end
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 kvar::KnownRef,
                                 aff::KAE)
    JuMP.add_to_expression!(quad.knowns, kvar, aff)
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 var::Union{VariableRef, DecisionRef, KnownRef},
                                 aff::CAE)
    JuMP.add_to_expression!(quad, var, aff.variables)
    JuMP.add_to_expression!(quad, var, aff.decisions)
    JuMP.add_to_expression!(quad, var, aff.knowns)
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 aff::Union{VAE, DAE, KAE, CAE},
                                 var::Union{VariableRef, DecisionRef, KnownRef})
    return JuMP.add_to_expression!(quad, var, aff)
end

function JuMP.add_to_expression!(quad::CQE,
                                 lhs::VAE,
                                 rhs::VAE)
    JuMP.add_to_expression!(quad.variables, lhs, rhs)
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 lhs::DAE,
                                 rhs::DAE)
    JuMP.add_to_expression!(quad.decisions, lhs, rhs)
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 lhs::KAE,
                                 rhs::KAE)
    JuMP.add_to_expression!(quad.knowns, lhs, rhs)
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 lhs::Union{VAE,DAE,KAE},
                                 rhs::Union{VAE,DAE,KAE})
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
            add_to_expression!(quad.aff, c*rhscoef, rhsvar)
        end
    end

    # [RHS constant] * [LHS linear terms]
    if !iszero(rhs.constant)
        c = rhs.constant
        for (lhscoef, lhsvar) in linear_terms(lhs)
            add_to_expression!(quad.aff, c*lhscoef, lhsvar)
        end
    end

    quad.variables.aff.constant += lhs.constant * rhs.constant

    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 lhs::Union{VAE, DAE, KAE},
                                 rhs::CAE)
    JuMP.add_to_expression!(quad, lhs, rhs.variables)
    JuMP.add_to_expression!(quad, lhs, rhs.decisions)
    JuMP.add_to_expression!(quad, lhs, rhs.knowns)
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 lhs::CAE,
                                 rhs::Union{VAE, DAE, KAE})
    JuMP.add_to_expression!(quad, rhs, lhs)
    return quad
end

function JuMP.add_to_expression!(quad::CQE,
                                 lhs::CAE,
                                 rhs::CAE)
    # Variables
    JuMP.add_to_expression!(quad, lhs.variables, rhs.variables)
    JuMP.add_to_expression!(quad, lhs.variables, rhs.decisions)
    JuMP.add_to_expression!(quad, lhs.variables, rhs.knowns)
    # Decisions
    JuMP.add_to_expression!(quad, lhs.decisions, rhs.variables)
    JuMP.add_to_expression!(quad, lhs.decisions, rhs.decisions)
    JuMP.add_to_expression!(quad, lhs.decisions, rhs.knowns)
    # Knowns
    JuMP.add_to_expression!(quad, lhs.knowns, rhs.variables)
    JuMP.add_to_expression!(quad, lhs.knowns, rhs.decisions)
    JuMP.add_to_expression!(quad, lhs.knowns, rhs.knowns)
    return quad
end

# With three factors.
function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant,
                                 new_var1::VariableRef,
                                 new_var2::VariableRef)
    JuMP.add_to_expression!(quad.variables, new_coef, new_var1, new_var2)
    return quad
end
function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant,
                                 new_var1::VariableRef,
                                 new_var2::DecisionRef)
    key = DecisionCrossTerm(new_var2, new_var1)
    JuMP._add_or_set!(quad.cross_terms, key, new_coef)
    return quad
end
function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant,
                                 new_var1::VariableRef,
                                 new_var2::KnownRef)
    key = KnownVariableCrossTerm(new_var2, new_var1)
    JuMP._add_or_set!(quad.known_variable_terms, key, new_coef)
    return quad
end
function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant,
                                 new_var1::DecisionRef,
                                 new_var2::VariableRef)
    key = DecisionCrossTerm(new_var1, new_var2)
    JuMP._add_or_set!(quad.cross_terms, key, new_coef)
    return quad
end
function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant,
                                 new_var1::DecisionRef,
                                 new_var2::DecisionRef)
    JuMP.add_to_expression!(quad.decisions, new_coef, new_var1, new_var2)
    return quad
end
function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant,
                                 new_var1::DecisionRef,
                                 new_var2::KnownRef)
    key = KnownDecisionCrossTerm(new_var2, new_var1)
    JuMP._add_or_set!(quad.known_decision_terms, key, new_coef)
    return quad
end
function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant,
                                 new_var1::KnownRef,
                                 new_var2::VariableRef)
    key = KnownVariableCrossTerm(new_var1, new_var2)
    JuMP._add_or_set!(quad.known_variable_terms, key, new_coef)
    return quad
end
function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant,
                                 new_var1::KnownRef,
                                 new_var2::DecisionRef)
    key = KnownDecisionCrossTerm(new_var1, new_var2)
    JuMP._add_or_set!(quad.known_decision_terms, key, new_coef)
    return quad
end
function JuMP.add_to_expression!(quad::CQE, new_coef::_Constant,
                                 new_var1::KnownRef,
                                 new_var2::KnownRef)
    JuMP.add_to_expression!(quad.knowns, new_coef, new_var1, new_var2)
    return quad
end
