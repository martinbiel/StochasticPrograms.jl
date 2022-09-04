# MIT License
#
# Copyright (c) 2018 Martin Biel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Quadratic decision function #
# ========================== #
struct QuadraticDecisionFunction{T} <: MOI.AbstractScalarFunction
    variable_part::MOI.ScalarQuadraticFunction{T}
    decision_part::MOI.ScalarQuadraticFunction{T}
    cross_terms::MOI.ScalarQuadraticFunction{T}
end

# Base overrides #
# ========================== #
function Base.copy(f::F) where F <: QuadraticDecisionFunction
    return F(copy(f.variable_part),
             copy(f.decision_part),
             copy(f.cross_terms))
end
function Base.convert(::Type{QuadraticDecisionFunction{T}}, α::T) where T
    return QuadraticDecisionFunction{T}(
        convert(MOI.ScalarQuadraticFunction{T}, α),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end
function Base.convert(::Type{QuadraticDecisionFunction{T}},
                      f::MOI.VariableIndex) where T
    return QuadraticDecisionFunction{T}(
        convert(MOI.ScalarQuadraticFunction{T}, f),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end
function Base.convert(::Type{QuadraticDecisionFunction{T}},
                      f::SingleDecision) where T
    return QuadraticDecisionFunction{T}(
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        MOI.ScalarQuadraticFunction{T}(
            MOI.ScalarQuadraticTerm{T}[],
            [MOI.ScalarAffineTerm(one(T), f.decision)],
            zero(T),
        ),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end
function Base.convert(::Type{QuadraticDecisionFunction{T}},
                      f::MOI.ScalarAffineFunction{T}) where T
    return QuadraticDecisionFunction{T}(
        convert(MOI.ScalarQuadraticFunction{T}, f),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end
function Base.convert(::Type{QuadraticDecisionFunction{T}},
                      f::MOI.ScalarQuadraticFunction{T}) where T
    return QuadraticDecisionFunction{T}(
        f,
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end
function Base.convert(::Type{QuadraticDecisionFunction{T}},
                      f::AffineDecisionFunction{T}) where T
    return QuadraticDecisionFunction{T}(
        convert(MOI.ScalarQuadraticFunction{T}, f.variable_part),
        convert(MOI.ScalarQuadraticFunction{T}, f.decision_part),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end
function Base.convert(::Type{MOI.VariableIndex},
                      f::QuadraticDecisionFunction{T}) where T
    return convert(MOI.VariableIndex, convert(AffineDecisionFunction{T}, f))
end
function Base.convert(::Type{SingleDecision},
                      f::QuadraticDecisionFunction{T}) where T
    return convert(SingleDecision, convert(AffineDecisionFunction{T}, f))
end

function Base.convert(::Type{AffineDecisionFunction{T}},
                      f::QuadraticDecisionFunction{T}) where T
    if !Base.isempty(f.cross_terms.quadratic_terms)
        throw(InexactError(:convert, AffineDecisionFunction{T}, f))
    end
    return AffineDecisionFunction{T}(
        convert(MOI.ScalarAffineFunction{T}, f.variable_part),
        convert(MOI.ScalarAffineFunction{T}, f.decision_part))
end

function Base.zero(F::Type{QuadraticDecisionFunction{T}}) where T
    return convert(F, zero(T))
end

function Base.iszero(f::QuadraticDecisionFunction)
    return iszero(MOI.constant(f)) && MOIU._is_constant(MOIU.canonical(f))
end

function Base.isone(f::QuadraticDecisionFunction)
    return isone(MOI.constant(f)) && MOIU._is_constant(MOIU.canonical(f))
end

function Base.one(F::Type{QuadraticDecisionFunction{T}}) where T
    return convert(F, one(T))
end

function MOI._dicts(f::QuadraticDecisionFunction)
    return (MOI.sum_dict(MOI.term_pair.(f.variable_part.affine_terms)),
            MOI.sum_dict(MOI.term_pair.(f.variable_part.quadratic_terms)),
            MOI.sum_dict(MOI.term_pair.(f.decision_part.affine_terms)),
            MOI.sum_dict(MOI.term_pair.(f.decision_part.quadratic_terms)),
            MOI.sum_dict(MOI.term_pair.(f.cross_terms.quadratic_terms)))
end

function Base.isapprox(f::QuadraticDecisionFunction, g::QuadraticDecisionFunction; kwargs...)
    return isapprox(MOI.constant(f), MOI.constant(g); kwargs...) && all(
        MOI.dict_compare.(
            MOI._dicts(f),
            MOI._dicts(g),
            (α, β) -> isapprox(α, β; kwargs...),
        ),
    )
end

# JuMP overrides #
# ========================== #
function QuadraticDecisionFunction(quad::DQE)
    JuMP._assert_isfinite(quad)
    # Variable part
    variable_part = JuMP.moi_function(quad.variables)
    # Decision part
    decision_affine_terms =  Vector{MOI.ScalarAffineTerm{Float64}}()
    for (coef, dvar) in linear_terms(quad.decisions.aff)
        # Any fixed decision value is set in the decision bridge
        push!(decision_affine_terms, MOI.ScalarAffineTerm(coef, index(dvar)))
    end
    decision_quad_terms = Vector{MOI.ScalarQuadraticTerm{Float64}}()
    for t in quad_terms(quad.decisions)
        # Any fixed decision value is set in the decision bridge
        push!(decision_quad_terms, JuMP._moi_quadratic_term(t))
    end
    # Cross terms
    cross_terms = Vector{MOI.ScalarQuadraticTerm{Float64}}()
    for (cross_term, coeff) in quad.cross_terms
        # Any fixed decision value is set in the decision bridge
        push!(cross_terms,
              MOI.ScalarQuadraticTerm(coeff, index(cross_term.decision), index(cross_term.variable)))
    end
    # Return QuadraticDecisionFunction with QuadraticPart
    return QuadraticDecisionFunction(
        variable_part,
        MOI.ScalarQuadraticFunction(decision_quad_terms,
                                    decision_affine_terms,
                                    0.0),
        MOI.ScalarQuadraticFunction(cross_terms,
                                    MOI.ScalarAffineTerm{Float64}[],
                                    0.0))
end
JuMP.moi_function(quad::DQE) = QuadraticDecisionFunction(quad)
function JuMP.moi_function_type(::Type{DecisionQuadExpr{T}}) where T
    return QuadraticDecisionFunction{T}
end

is_decision_type(::Type{<:QuadraticDecisionFunction}) = true

QuadraticDecisionFunction(quad::_DQE) = QuadraticDecisionFunction(convert(DQE, quad))

function _DecisionQuadExpr(m::Model, f::MOI.ScalarQuadraticFunction)
    quad = _DQE(_DecisionAffExpr(m, MOI.ScalarAffineFunction(f.affine_terms, 0.0)))
    for t in f.quadratic_terms
        v1 = t.variable_1
        v2 = t.variable_2
        coef = t.coefficient
        if v1 == v2
            coef /= 2
        end
        JuMP.add_to_expression!(quad, coef, DecisionRef(m, v1), DecisionRef(m, v2))
    end
    # There should not be any constants in the decision terms
    return quad
end

function DQE(model::Model, f::QuadraticDecisionFunction{T}) where T
    # Decision part
    cross_terms = OrderedDict{DecisionCrossTerm, Float64}()
    for term in f.cross_terms.quadratic_terms
        cross_term = DecisionCrossTerm(
            DecisionRef(model, term.variable_1),
            VariableRef(model, term.variable_2))
        JuMP._add_or_set!(cross_terms, cross_term, term.coefficient)
    end
    return DQE(QuadExpr(model,
                        convert(MOI.ScalarQuadraticFunction{T}, f.variable_part)),
               _DecisionQuadExpr(model,
                                convert(MOI.ScalarQuadraticFunction{T}, f.decision_part)),
               cross_terms)
end

function JuMP.jump_function_type(::Model,
                                 ::Type{QuadraticDecisionFunction{T}}) where T
    return DecisionQuadExpr{T}
end
function JuMP.jump_function(model::Model, f::QuadraticDecisionFunction{T}) where T
    return DecisionQuadExpr{T}(model, f)
end

# MOI Function interface #
# ========================== #
MOI.constant(f::QuadraticDecisionFunction) =
    MOI.constant(f.variable_part)
MOI.constant(f::QuadraticDecisionFunction, T::Type) = MOI.constant(f)

function MOIU.eval_variables(varval::Function, f::QuadraticDecisionFunction)
    var_value = MOIU.eval_variables(varval, f.variable_part)
    dvar_value = MOIU.eval_variables(varval, f.decision_part)
    cross_value = MOIU.eval_variables(varval, f.cross_terms)
    return var_value + dvar_value + cross_value
end

function MOIU.map_indices(index_map::Function, f::QuadraticDecisionFunction{T}) where T
    return typeof(f)(MOIU.map_indices(index_map, f.variable_part),
                     MOIU.map_indices(index_map, f.decision_part),
                     MOIU.map_indices(index_map, f.cross_terms))
end

function MOIU.substitute_variables(variable_map::Function, f::QuadraticDecisionFunction{T}) where T
    g = QuadraticDecisionFunction(
        convert(MOI.ScalarQuadraticFunction{T}, MOI.constant(f.variable_part)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
    # Substitute variables
    for term in f.variable_part.affine_terms
        func::AffineDecisionFunction{T} = variable_map(term.variable)
        new_term = MOIU.operate(*, T, term.coefficient, func)::AffineDecisionFunction{T}
        MOIU.operate!(+, T, g, new_term)::QuadraticDecisionFunction{T}
    end
    for term in f.variable_part.quadratic_terms
        f1::AffineDecisionFunction{T} = variable_map(term.variable_1)
        f2::AffineDecisionFunction{T} = variable_map(term.variable_2)
        f12 = MOIU.operate(*, T, f1, f2)::QuadraticDecisionFunction{T}
        coeff = term.coefficient
        if term.variable_1 == term.variable_2
            coeff /= 2
        end
        new_term = MOIU.operate!(*, T, f12, coeff)::QuadraticDecisionFunction{T}
        MOIU.operate!(+, T, g, new_term)::QuadraticDecisionFunction{T}
    end
    # Substitute decisions
    for term in f.decision_part.affine_terms
        func::AffineDecisionFunction{T} = variable_map(term.variable)
        new_term = MOIU.operate(*, T, term.coefficient, func)::AffineDecisionFunction{T}
        MOIU.operate!(+, T, g, new_term)::QuadraticDecisionFunction{T}
    end
    for term in f.decision_part.quadratic_terms
        f1::AffineDecisionFunction{T} = variable_map(term.variable_1)
        f2::AffineDecisionFunction{T} = variable_map(term.variable_2)
        f12 = MOIU.operate(*, T, f1, f2)::QuadraticDecisionFunction{T}
        coeff = term.coefficient
        if term.variable_1 == term.variable_2
            coeff /= 2
        end
        new_term = MOIU.operate!(*, T, f12, coeff)::QuadraticDecisionFunction{T}
        MOIU.operate!(+, T, g, new_term)::QuadraticDecisionFunction{T}
    end
    # Substitute decisions in cross terms
    for term in f.cross_terms.quadratic_terms
        f1::AffineDecisionFunction{T} = variable_map(term.variable_1)
        f2::AffineDecisionFunction{T} = variable_map(term.variable_2)
        f12 = MOIU.operate(*, T, f1, f2)::QuadraticDecisionFunction{T}
        coeff = term.coefficient
        if term.variable_1 == term.variable_2
            coeff /= 2
        end
        new_term = MOIU.operate!(*, T, f12, coeff)::QuadraticDecisionFunction{T}
        MOIU.operate!(+, T, g, new_term)::QuadraticDecisionFunction{T}
    end
    return g
end

function MOIU.is_canonical(f::QuadraticDecisionFunction)
    return MOIU.is_canonical(f.variable_part) &&
        MOIU.is_canonical(f.decision_part) &&
        MOIU.is_canonical(f.cross_terms)
end

MOIU.canonical(f::QuadraticDecisionFunction) = MOIU.canonicalize!(copy(f))

function MOIU.canonicalize!(f::QuadraticDecisionFunction)
    MOIU.canonicalize!(f.variable_part)
    MOIU.canonicalize!(f.decision_part)
    MOIU.canonicalize!(f.cross_terms)
    return f
end

function MOIU._is_constant(f::QuadraticDecisionFunction)
    return MOIU._is_constant(f.variable_part) &&
        MOIU._is_constant(f.decision_part) &&
        MOIU._is_constant(f.cross_terms)
end

function MOIU.all_coefficients(p::Function, f::QuadraticDecisionFunction)
    return MOIU.all_coefficients(p, f.variable_part) &&
        MOIU.all_coefficients(p, f.decision_part) &&
        MOIU.all_coefficients(p, f.cross_terms)
end

function MOIU.isapprox_zero(f::QuadraticDecisionFunction, tol)
    return MOIU.isapprox_zero(f.variable_part, tol) &&
        MOIU.isapprox_zero(f.decision_part, tol) &&
        MOIU.isapprox_zero(f.cross_terms, tol)
end

function MOIU.filter_variables(keep::Function, f::QuadraticDecisionFunction)
    return typeof(f)(MOIU.filter_variables(keep, f.variable_part),
                     MOIU.filter_variables(keep, f.decision_part),
                     MOIU.filter_variables(keep, f.cross_terms))
end

function MOIU.operate_coefficients(f, func::QuadraticDecisionFunction)
    return typeof(func)(MOIU.operate_coefficients(f, func.variable_part),
                        MOIU.operate_coefficients(f, func.decision_part),
                        MOIU.operate_coefficients(f, func.cross_terms))
end

function add_term!(terms::Vector{MOI.ScalarQuadraticTerm{T}},
                   term::MOI.ScalarQuadraticTerm{T}) where T
    index_1 = term.variable_1
    index_2 = term.variable_2
    coefficient = term.coefficient
    i = something(findfirst(t -> t.variable_1 == index_1 &&
                            t.variable_2 == index_2,
                            terms), 0)
    if iszero(i)
        if !iszero(coefficient)
            # The variable was not already included in the terms
            push!(terms, MOI.ScalarQuadraticTerm(coefficient, index_1, index_2))
        end
    else
        # Variable already included, increment the coefficient
        new_coeff = terms[i].coefficient + coefficient
        if iszero(new_coeff)
            deleteat!(terms, i)
        else
            terms[i] = MOI.ScalarQuadraticTerm(new_coeff, index_1, index_2)
        end
    end
    return nothing
end

function remove_term!(terms::Vector{MOI.ScalarQuadraticTerm{T}},
                      term::MOI.ScalarQuadraticTerm{T}) where T
    index_1 = term.variable_1
    index_2 = term.variable_2
    coefficient = term.coefficient
    i = something(findfirst(t -> t.variable_1 == index_1 &&
                            t.variable_2 == index_2,
                            terms), 0)
    if iszero(i) && !iszero(coefficient)
        # The term was not already included in the terms
        push!(terms, MOI.ScalarQuadraticTerm(-coefficient, index_1, index_2))
    else
        # Term already included, increment the coefficient
        new_coeff = terms[i].coefficient - coefficient
        if iszero(new_coeff)
            deleteat!(terms, i)
        else
            terms[i] = MOI.ScalarQuadraticTerm(new_coeff, index_1, index_2)
        end
    end
    return nothing
end
