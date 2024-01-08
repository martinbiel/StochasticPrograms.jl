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

# Type shorthands #
# ========================== #
const _Variable = VariableRef
const _Decision = DecisionRef
const _Scalar = Union{_Variable, _Decision, _Constant}
const _DecisionAffOrQuadExpr{C} = Union{DecisionAffExpr{C}, DecisionQuadExpr{C}}

# Basic operations #
# ========================== #
MA.mutability(::Type{<:_DecisionAffOrQuadExpr}) = MA.IsMutable()
function MA.mutable_copy(expr::_DecisionAffOrQuadExpr)
    return map_coefficients(MA.copy_if_mutable, expr)
end

# Promote operation #
# ========================== #
# _Constant--_Decision
function MA.promote_operation(::Union{typeof(+), typeof(-), typeof(*)},
                               ::Type{<:_Constant}, S::Type{<:_Decision})
    return DAE
end
function MA.promote_operation(::Union{typeof(+), typeof(-), typeof(*)},
                               S::Type{<:_Decision}, ::Type{<:_Constant})
    return DAE
end
# _Variable--Decision
function MA.promote_operation(::Union{typeof(+), typeof(-)},
                               ::Type{<:_Variable}, S::Type{<:_Decision})
    return DAE
end
function MA.promote_operation(::Union{typeof(+), typeof(-)},
                               S::Type{<:_Decision}, ::Type{<:_Variable})
    return DAE
end
# _Constant--_DecisionAffOrQuadExpr
function MA.promote_operation(::Union{typeof(+), typeof(-), typeof(*)},
                               ::Type{<:_Constant}, S::Type{<:_DecisionAffOrQuadExpr})
    return S
end
function MA.promote_operation(::Union{typeof(+), typeof(-), typeof(*)},
                               S::Type{<:_DecisionAffOrQuadExpr}, ::Type{<:_Constant})
    return S
end
# _Variable/_Decision--_DecisionAffOrQuadExpr
function MA.promote_operation(
    ::Union{typeof(+), typeof(-)}, ::Type{<:Union{_Variable, _Decision}},
    S::Type{<:_DecisionAffOrQuadExpr})
    return S
end
function MA.promote_operation(
    ::Union{typeof(+), typeof(-)}, S::Type{<:_DecisionAffOrQuadExpr},
    ::Type{<:Union{_Variable, _Decision}})
    return S
end
# (_Variable/_Decision)AffExpr--(_Variable/_Decision)AffExpr
function MA.promote_operation(
    op::Union{typeof(+), typeof(-)}, ::Type{GenericAffExpr{C1, _Variable}},
    ::Type{GenericAffExpr{C2, _Decision}}) where {C1, C2}
    C = MA.promote_operation(op, C1, C2)
    return DecisionAffExpr{C}
end
function MA.promote_operation(
    op::Union{typeof(+), typeof(-)}, ::Type{GenericAffExpr{C1, _Decision}},
    ::Type{GenericAffExpr{C2, _Variable}}) where {C1, C2}
    C = MA.promote_operation(op, C1, C2)
    return DecisionAffExpr{C}
end
# (_Variable/_Decision)AffExpr--_DecisionAffOrQuadExpr
function MA.promote_operation(
    ::Union{typeof(+), typeof(-)}, ::Type{GenericAffExpr{C,V}},
    S::Type{_DecisionAffOrQuadExpr{C}}) where {C, V <: Union{_Variable, _Decision}}
    return S
end
function MA.promote_operation(
    ::Union{typeof(+), typeof(-)}, S::Type{_DecisionAffOrQuadExpr{C}},
    ::Type{GenericAffExpr{C,V}}) where {C, V <: Union{_Variable, _Decision}}
    return S
end
# _DecisionAffOrQuadExpr--_DecisionAffOrQuadExpr
function MA.promote_operation(::Union{typeof(+), typeof(-)}, ::Type{A},
                               ::Type{A}) where {A <: _DecisionAffOrQuadExpr}
    return A
end
function MA.promote_operation(::Union{typeof(+), typeof(-)},
                               ::Type{<:DecisionAffExpr},
                               S::Type{<:DecisionQuadExpr})
    return S
end
function MA.promote_operation(::Union{typeof(+), typeof(-)},
                               S::Type{<:DecisionQuadExpr},
                               ::Type{<:DecisionAffExpr})
    return S
end
# _Variable--DecisionRef
function MA.promote_operation(::typeof(*), ::Type{<:_Variable}, ::Type{<:_Decision})
    return DQE
end
function MA.promote_operation(::typeof(*), ::Type{<:_Decision}, ::Type{<:_Variable})
    return DQE
end
# _Decision--_Decision
function MA.promote_operation(::typeof(*), ::Type{<:_Decision}, ::Type{<:_Decision})
    return DQE
end
# _Variable/_Decision--(_Variable/_Decision)AffExpr
function MA.promote_operation(::typeof(*), ::Type{<:_Variable}, ::Type{GenericAffExpr{C, _Decision}}) where {C}
    return DecisionQuadExpr{C}
end
function MA.promote_operation(::typeof(*), ::Type{GenericAffExpr{C, D}}, ::Type{<:_Variable}) where {C, D <: _Decision}
    return DecisionQuadExpr{C}
end
function MA.promote_operation(::typeof(*), ::Type{<:_Decision}, ::Type{GenericAffExpr{C, V}}) where {C, V <: _Variable}
    return DecisionQuadExpr{C}
end
function MA.promote_operation(::typeof(*), ::Type{GenericAffExpr{C, V}}, ::Type{<:_Decision}) where {C, V <: _Variable}
    return DecisionQuadExpr{C}
end
function MA.promote_operation(::typeof(*), ::Type{D}, ::Type{GenericAffExpr{C, D}}) where {C, D <: _Decision}
    return DecisionQuadExpr{C}
end
function MA.promote_operation(::typeof(*), ::Type{GenericAffExpr{C, D}}, ::Type{D}) where {C, D <: _Decision}
    return DecisionQuadExpr{C}
end
# _Variable/_Decision--DecisionAffExpr
function MA.promote_operation(::typeof(*), ::Type{V}, ::Type{DecisionAffExpr{C}}) where {C, V <: Union{_Variable, _Decision}}
    return DecisionQuadExpr{C}
end
function MA.promote_operation(::typeof(*), ::Type{DecisionAffExpr{C}}, ::Type{V}) where {C, V <: Union{_Variable, _Decision}}
    return DecisionQuadExpr{C}
end

function MA.scaling(aff::DecisionAffExpr{C}) where C
    if !isempty(aff.variables.terms) || !isempty(aff.decisions.terms)
        throw(InexactError("Cannot convert `$aff` to `$C`."))
    end
    return MA.scaling(aff.variables.constant)
end
function MA.scaling(quad::DecisionQuadExpr{C}) where C
    if !isempty(quad.variables.terms) || !isempty(quad.decisions.terms) || !isempty(quad.decisions.quad.terms) || !isempty(quad.cross_terms)
        throw(InexactError("Cannot convert `$quad` to `$C`."))
    end
    return MA.scaling(quad.variables.aff)
end

# Mutable operate #
# ========================== #
# zero/one #
function MA.operate!(op::Union{typeof(zero), typeof(one)}, aff::DecisionAffExpr)
    MA.operate!(op, aff.variables)
    MA.operate!(op, aff.decisions)
    return aff
end
function MA.operate!(op::Union{typeof(zero), typeof(one)}, quad::DecisionQuadExpr)
    MA.operate!(op, quad.variables)
    MA.operate!(op, quad.decisions)
    empty!(quad.cross_terms)
    return quad
end
# * #
function MA.operate!(::typeof(*), expr::_DecisionAffOrQuadExpr, α::_Constant)
    if iszero(α)
        return MA.operate!(zero, expr)
    else
        return map_coefficients_inplace!(x -> MA.mul!(x, α), expr)
    end
end
# +/- #
function MA.operate!(::typeof(+), expr::_DecisionAffOrQuadExpr, x)
    return JuMP.add_to_expression!(expr, x)
end
function MA.operate!(::typeof(-), expr::_DecisionAffOrQuadExpr, x)
    return JuMP.add_to_expression!(expr, -1.0, x)
end
# add/sub_mul #
function MA.operate!(::typeof(MA.add_mul), expr::_DecisionAffOrQuadExpr, x::_Scalar)
    return JuMP.add_to_expression!(expr, x)
end
function MA.operate!(::typeof(MA.add_mul), expr::_DecisionAffOrQuadExpr, x::_Scalar, y::_Scalar)
    return JuMP.add_to_expression!(expr, x, y)
end
function MA.operate!(::typeof(MA.sub_mul), expr::_DecisionAffOrQuadExpr, x::_Scalar)
    return JuMP.add_to_expression!(expr, -1.0, x)
end
function MA.operate!(::typeof(MA.sub_mul), expr::_DecisionAffOrQuadExpr, x::_Scalar, y::_Scalar)
    return JuMP.add_to_expression!(expr, -x, y)
end
function MA.operate!(::typeof(MA.sub_mul), expr::_DecisionAffOrQuadExpr, x::Union{_Variable, _Decision}, y::_Constant)
    return JuMP.add_to_expression!(expr, x, -y)
end
function MA.operate!(op::MA.AddSubMul, expr::_DecisionAffOrQuadExpr, x, y)
    return MA.operate!(op, expr, x * y)
end
@generated function _add_sub_mul_reorder!(op::MA.AddSubMul, expr::_DecisionAffOrQuadExpr, args::Vararg{Any, N}) where N
    n = length(args)
    @assert n ≥ 3
    varidx = findall(t -> (t <: Union{_Variable, _Decision}), collect(args))
    allscalar = all(t -> (t <: _Constant), args[setdiff(1:n, varidx)])
    idx = (allscalar && length(varidx) == 1) ? varidx[1] : n
    coef = Expr(:call, :*, [:(args[$i]) for i in setdiff(1:n, idx)]...)
    return :(MA.operate!(op, expr, $coef, args[$idx]))
end
function MA.operate!(op::MA.AddSubMul, expr::_DecisionAffOrQuadExpr, x, y, z, other_args::Vararg{Any, N}) where N
    return _add_sub_mul_reorder!(op, expr, x, y, z, other_args...)
end
function JuMP.add_to_expression!(expr::_DecisionAffOrQuadExpr, α::_Constant, β::_Constant)
    return JuMP.add_to_expression!(expr, *(α, β))
end
