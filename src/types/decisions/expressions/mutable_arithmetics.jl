const _Variable = VariableRef
const _Decision = DecisionRef
const _Scalar = Union{_Variable, _Decision, _Constant}
const _DecisionAffOrQuadExpr{C} = Union{DecisionAffExpr{C}, DecisionQuadExpr{C}}

function MA.promote_operation(::Union{typeof(+), typeof(-), typeof(*)},
                               ::Type{<:_Constant}, S::Type{<:_Decision})
    return DAE
end
function MA.promote_operation(::Union{typeof(+), typeof(-), typeof(*)},
                               S::Type{<:_Decision}, ::Type{<:_Constant})
    return DAE
end
function MA.promote_operation(::Union{typeof(+), typeof(-), typeof(*)},
                               ::Type{<:_Constant}, S::Type{<:_DecisionAffOrQuadExpr})
    return S
end
function MA.promote_operation(::Union{typeof(+), typeof(-), typeof(*)},
                               S::Type{<:_DecisionAffOrQuadExpr}, ::Type{<:_Constant})
    return S
end
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
function MA.promote_operation(
    ::Union{typeof(+), typeof(-)}, ::Type{GenericQuadExpr{C,V}},
    S::Type{_DecisionAffOrQuadExpr{C}}) where {C, V <: Union{_Variable, _Decision}}
    return DecisionQuadExpr{C}
end
function MA.promote_operation(
    ::Union{typeof(+), typeof(-)}, S::Type{_DecisionAffOrQuadExpr{C}},
    ::Type{GenericQuadExpr{C,V}}) where {C, V <: Union{_Variable, _Decision}}
    return DecisionQuadExpr{C}
end
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

function MA.promote_operation(::typeof(*), ::Type{<:_Variable}, ::Type{<:_Decision})
    return DQE
end
function MA.promote_operation(::typeof(*), ::Type{<:_Decision}, ::Type{<:_Variable})
    return DQE
end
function MA.promote_operation(::typeof(*), ::Type{<:_Decision}, ::Type{<:_Decision})
    return DQE
end
function MA.promote_operation(::typeof(*), ::Type{<:_Variable}, ::Type{GenericAffExpr{T, D}}) where {T, D <: _Decision}
    return DecisionQuadExpr{T}
end
function MA.promote_operation(::typeof(*), ::Type{GenericAffExpr{T, D}}, ::Type{<:_Variable}) where {T, D <: _Decision}
    return DecisionQuadExpr{T}
end
function MA.promote_operation(::typeof(*), ::Type{<:_Decision}, ::Type{GenericAffExpr{T, V}}) where {T, V <: _Variable}
    return DecisionQuadExpr{T}
end
function MA.promote_operation(::typeof(*), ::Type{GenericAffExpr{T, V}}, ::Type{<:_Decision}) where {T, V <: _Variable}
    return DecisionQuadExpr{T}
end
function MA.promote_operation(::typeof(*), ::Type{D}, ::Type{GenericAffExpr{T, D}}) where {T, D <: _Decision}
    return DecisionQuadExpr{T}
end
function MA.promote_operation(::typeof(*), ::Type{GenericAffExpr{T, D}}, ::Type{D}) where {T, D <: _Decision}
    return DecisionQuadExpr{T}
end
function MA.promote_operation(::typeof(*), ::Type{V}, ::Type{DecisionAffExpr{T}}) where {T, V <: Union{_Variable, _Decision}}
    return DecisionQuadExpr{T}
end
function MA.promote_operation(::typeof(*), ::Type{DecisionAffExpr{T}}, ::Type{V}) where {T, V <: Union{_Variable, _Decision}}
    return DecisionQuadExpr{T}
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

MA.mutability(::Type{<:_DecisionAffOrQuadExpr}) = MA.IsMutable()
function MA.mutable_copy(expr::_DecisionAffOrQuadExpr)
    return map_coefficients(MA.copy_if_mutable, expr)
end

function MA.mutable_operate!(op::Union{typeof(zero), typeof(one)}, aff::DecisionAffExpr)
    MA.mutable_operate!(op, aff.variables)
    MA.mutable_operate!(zerl, aff.decisions)
    return aff
end
function MA.mutable_operate!(op::Union{typeof(zero), typeof(one)}, quad::DecisionQuadExpr)
    MA.mutable_operate!(op, quad.variables)
    MA.mutable_operate!(zero, quad.decisions)
    empty!(quad.cross_terms)
    return quad
end

function MA.mutable_operate!(::typeof(*), expr::_DecisionAffOrQuadExpr, α::_Constant)
    if iszero(α)
        return MA.mutable_operate!(zero, expr)
    else
        return map_coefficients_inplace!(x -> MA.mul!(x, α), expr)
    end
end

function MA.mutable_operate!(::typeof(+), expr::_DecisionAffOrQuadExpr, x)
    return JuMP.add_to_expression!(expr, x)
end
function MA.mutable_operate!(::typeof(-), expr::_DecisionAffOrQuadExpr, x)
    return JuMP.add_to_expression!(expr, -1, x)
end

function MA.mutable_operate!(::typeof(MA.add_mul), expr::_DecisionAffOrQuadExpr, x::_Scalar)
    return JuMP.add_to_expression!(expr, x)
end
function MA.mutable_operate!(::typeof(MA.add_mul), expr::_DecisionAffOrQuadExpr, x::_Scalar, y::_Scalar)
    return JuMP.add_to_expression!(expr, x, y)
end
function MA.mutable_operate!(::typeof(MA.sub_mul), expr::_DecisionAffOrQuadExpr, x::_Scalar)
    return JuMP.add_to_expression!(expr, -1.0, x)
end
function MA.mutable_operate!(::typeof(MA.sub_mul), expr::_DecisionAffOrQuadExpr, x::_Scalar, y::_Scalar)
    return JuMP.add_to_expression!(expr, -x, y)
end
function MA.mutable_operate!(::typeof(MA.sub_mul), expr::_DecisionAffOrQuadExpr, x::Union{_Variable, _Decision}, y::_Constant)
    return JuMP.add_to_expression!(expr, x, -y)
end
function MA.mutable_operate!(op::MA.AddSubMul, expr::_DecisionAffOrQuadExpr, x, y)
    return MA.mutable_operate!(op, expr, x * y)
end
@generated function _add_sub_mul_reorder!(op::MA.AddSubMul, expr::_DecisionAffOrQuadExpr, args::Vararg{Any, N}) where N
    n = length(args)
    @assert n ≥ 3
    varidx = findall(t -> (t <: Union{_Variable, _Decision}), collect(args))
    allscalar = all(t -> (t <: _Constant), args[setdiff(1:n, varidx)])
    idx = (allscalar && length(varidx) == 1) ? varidx[1] : n
    coef = Expr(:call, :*, [:(args[$i]) for i in setdiff(1:n, idx)]...)
    return :(MA.mutable_operate!(op, expr, $coef, args[$idx]))
end
function MA.mutable_operate!(op::MA.AddSubMul, expr::_DecisionAffOrQuadExpr, x, y, z, other_args::Vararg{Any, N}) where N
    return _add_sub_mul_reorder!(op, expr, x, y, z, other_args...)
end
function JuMP.add_to_expression!(expr::_DecisionAffOrQuadExpr, α::_Constant, β::_Constant)
    return JuMP.add_to_expression!(expr, *(α, β))
end
