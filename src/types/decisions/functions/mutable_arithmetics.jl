# AffineDecisionFunction #
# ========================== #
MA.mutability(::Type{<:TypedDecisionLike}) = MA.IsMutable()

function MA.mutable_copy(f::AffineDecisionFunction)
    return AffineDecisionFunction(MA.mutable_copy(f.variable_part),
                                  MA.mutable_copy(f.decision_part),
                                  MA.mutable_copy(f.known_part))
end
function MA.mutable_copy(f::LinearPart)
    return LinearPart(
        MA.mutable_copy(f.variable_part),
        MA.mutable_copy(f.decision_part))
end
function MA.mutable_copy(f::QuadraticPart)
    return QuadraticPart(
        MA.mutable_copy(f.variable_part),
        MA.mutable_copy(f.decision_part),
        MA.mutable_copy(f.cross_terms))
end
function MA.mutable_copy(f::QuadraticDecisionFunction)
    return QuadraticDecisionFunction(
        MA.mutable_copy(f.linear_quadratic_terms),
        MA.mutable_copy(f.known_part),
        MA.mutable_copy(f.known_variable_terms),
        MA.mutable_copy(f.known_decision_terms))
end

function MA.isequal_canonical(f::F, g::F) where F<:Union{AffineDecisionFunction, VectorAffineDecisionFunction}
    return MA.isequal_canonical(f.variable_part, g.variable_part) &&
        MA.isequal_canonical(f.decision_part, g.decision_part) &&
        MA.isequal_canonical(f.known_part, g.known_part)
end

function MA.isequal_canonical(f::F, g::F) where F <: LinearPart
    return MA.isequal_canonical(f.variable_part, g.variable_part) &&
        MA.isequal_canonical(f.decision_part, g.decision_part)
end
function MA.isequal_canonical(f::F, g::F) where F <: QuadraticPart
    return MA.isequal_canonical(f.variable_part, g.variable_part) &&
        MA.isequal_canonical(f.decision_part, g.decision_part) &&
        MA.isequal_canonical(f.cross_terms, g.cross_terms)
end
function MA.isequal_canonical(f::F, g::F) where F <: QuadraticDecisionFunction
    return MA.isequal_canonical(f.linear_quadratic_terms, g.linear_quadratic_terms) &&
        MA.isequal_canonical(f.known_part, g.known_part) &&
        MA.isequal_canonical(f.known_variable_terms, g.known_variable_terms) &&
        MA.isequal_canonical(f.known_decision_terms, g.known_decision_terms)
end

function MA.iszero!(f::TypedScalarDecisionLike)
    return iszero!(MOI.constant(f)) && MOIU._is_constant(MOIU.canonicalize!(f))
end

function MA.scaling(f::TypedScalarDecisionLike)
    return MA.scaling(f.variable_part)
end

MA.promote_operation(::Union{typeof(zero), typeof(one)}, F::Type{<:TypedScalarDecisionLike}) = F

const PROMOTE_IMPLEMENTED_OP = Union{typeof(+), typeof(-), typeof(*), typeof(/)}
function MA.promote_operation(op::PROMOTE_IMPLEMENTED_OP,
                              F::Type{<:ScalarDecisionLike{T}},
                              G::Type{<:ScalarDecisionLike{T}}) where T
    MOIU.promote_operation(op, T, F, G)
end
function MA.promote_operation(op::PROMOTE_IMPLEMENTED_OP, F::Type{T},
                              G::Type{<:TypedDecisionLike{T}}) where T
    MOIU.promote_operation(op, T, F, G)
end
function MA.promote_operation(op::PROMOTE_IMPLEMENTED_OP, F::Type{<:TypedDecisionLike{T}},
                              G::Type{T}) where T
    MOIU.promote_operation(op, T, F, G)
end
function MA.promote_operation(op::PROMOTE_IMPLEMENTED_OP, F::Type{<:Number},
                              G::Type{<:Union{SingleDecision, VectorOfDecisions}})
    MOIU.promote_operation(op, F, F, G)
end
function MA.promote_operation(op::PROMOTE_IMPLEMENTED_OP,
                              F::Type{<:Union{SingleDecision, VectorOfDecisions}},
                              G::Type{<:Number})
    MOIU.promote_operation(op, G, F, G)
end

function MA.mutable_operate!(op::Union{typeof(zero), typeof(one)}, f::AffineDecisionFunction)
    MA.mutable_operate!(op, f.variable_part)
    MA.mutable_operate!(zero, f.decision_part)
    MA.mutable_operate!(zero, f.known_part)
    return f
end
function MA.mutable_operate!(op::Union{typeof(zero), typeof(one)}, f::QuadraticDecisionFunction{T,LinearPart{T}}) where T
    lq = f.linear_quadratic_terms
    MA.mutable_operate!(op, lq.variable_part)
    MA.mutable_operate!(zero, lq.decision_part)
    MA.mutable_operate!(zero, f.known_part)
    MA.mutable_operate!(zero, f.known_variable_terms)
    MA.mutable_operate!(zero, f.known_decision_terms)
    return f
end
function MA.mutable_operate!(op::Union{typeof(zero), typeof(one)}, f::QuadraticDecisionFunction{T,QuadraticPart{T}}) where T
    lq = f.linear_quadratic_terms
    MA.mutable_operate!(op, lq.variable_part)
    MA.mutable_operate!(zero, lq.decision_part)
    MA.mutable_operate!(zero, lq.cross_terms)
    MA.mutable_operate!(zero, f.known_part)
    MA.mutable_operate!(zero, f.known_variable_terms)
    MA.mutable_operate!(zero, f.known_decision_terms)
    return f
end

function MA.mutable_operate!(::typeof(-), f::AffineDecisionFunction)
    MA.mutable_operate!(op, f.variable_part)
    MA.mutable_operate!(op, f.decision_part)
    MA.mutable_operate!(op, f.known_part)
    return f
end
function MA.mutable_operate!(::typeof(-), f::QuadraticDecisionFunction{T,LinearPart{T}}) where T
    lq = f.linear_quadratic_terms
    MA.mutable_operate!(op, lq.variable_part)
    MA.mutable_operate!(op, lq.decision_part)
    MA.mutable_operate!(op, f.known_part)
    MA.mutable_operate!(op, f.known_variable_terms)
    MA.mutable_operate!(op, f.known_decision_terms)
    return f
end
function MA.mutable_operate!(::typeof(-), f::QuadraticDecisionFunction{T,QuadraticPart{T}}) where T
    lq = f.linear_quadratic_terms
    MA.mutable_operate!(op, lq.variable_part)
    MA.mutable_operate!(op, lq.decision_part)
    MA.mutable_operate!(op, lq.cross_terms)
    MA.mutable_operate!(op, f.known_part)
    MA.mutable_operate!(op, f.known_variable_terms)
    MA.mutable_operate!(op, f.known_decision_terms)
    return f
end

function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction{T},
                             g::T) where T
    MA.mutable_operate!(op, f.variable_part, g)
    return f
end
function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction{T},
                             g::MOI.SingleVariable) where T
    _operate_terms!(op, f.variable_part, AffineDecisionFunction{T}(g).variable_part)
    return f
end
function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction{T},
                             g::SingleDecision) where T
    _operate_terms!(op, f.decision_part, AffineDecisionFunction{T}(g).decision_part)
    return f
end
function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction{T},
                             g::SingleKnown) where T
    _operate_terms!(op, f.known_part, AffineDecisionFunction{T}(g).known_part)
    return f
end
function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction{T},
                             g::MOI.ScalarAffineFunction{T}) where T
    _operate_terms!(op, f.variable_part, g)
    f.variable_part.constant = op(f.variable_part.constant, g.constant)
    return f
end
function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction{T},
                             g::AffineDecisionFunction{T}) where T
    # Variable part
    _operate_terms!(op, f.variable_part, g.variable_part)
    f.variable_part.constant = op(f.variable_part.constant, g.variable_part.constant)
    # Decision part
    _operate_terms!(op, f.decision_part, g.decision_part)
    f.decision_part.constant = op(f.decision_part.constant, g.decision_part.constant)
    # Known part
    _operate_terms!(op, f.known_part, g.known_part)
    f.known_part.constant = op(f.known_part.constant, g.known_part.constant)
    return f
end

function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T},
                             g::T) where T
    MA.mutable_operate!(op, f.linear_quadratic_terms.variable_part, g)
    return f
end
function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T},
                             g::MOI.SingleVariable) where T
    _operate_terms!(op, f.linear_quadratic_terms.variable_part, convert(MOI.ScalarAffineFunction{T}, g))
    return f
end
function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T},
                             g::SingleDecision) where T
    _operate_terms!(op, f.linear_quadratic_terms.decision_part, convert(AffineDecisionFunction{T}, g))
    return f
end
function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T},
                             g::SingleKnown) where T
    _operate_terms!(op, f.known_part, convert(AffineDecisionFunction{T}, g))
    return f
end
function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T},
                             g::MOI.ScalarAffineFunction{T}) where T
    lq = f.linear_quadratic_terms
    _operate_terms!(op, lq.variable_part, g)
    lq.variable_part.constant = op(lq.variable_part.constant, g.constant)
    return f
end
function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T},
                             g::MOI.ScalarQuadraticFunction{T}) where T
    _operate_terms!(op, f.variable_part, g)
    f.variable_part.constant = op(f.variable_part.constant, g.constant)
    return f
end
function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T},
                             g::AffineDecisionFunction{T}) where T
    lq = f.linear_quadratic_terms
    # Variable_Part
    _operate_terms!(op, lq.variable_part, g.variable_part)
    lq.variable_part.constant = op(lq.variable_part.constant, g.variable_part.constant)
    # Decision part
    _operate_terms!(op, lq.decision_part, g.decision_part)
    lq.decision_part.constant = op(lq.decision_part.constant, lq.decision_part.constant)
    # Known part
    _operate_terms!(op, f.known_part, g.known_part)
    f.known_part.constant = op(f.known_part.constant, g.known_part.constant)
    return f
end
function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T,LQ},
                             g::QuadraticDecisionFunction{T,LinearPart{T}}) where {T, LQ <: LinearQuadraticPart{T}}
    f_lq = f.linear_quadratic_terms
    g_lq = g.linear_quadratic_terms
    # Variable part
    _operate_terms!(op, f_lq.variable_part, g_lq.variable_part)
    f_lq.variable_part.constant = op(f_lq.variable_part.constant, g_lq.variable_part.constant)
    # Decision part
    _operate_terms!(op, f_lq.decision_part, g_lq.decision_part)
    # Known part
    _operate_terms!(op, f.known_part, g.known_part)
    f.known_part.constant = op(f.known_part.constant, g.known_part.constant)
    _operate_terms!(op, f.known_variable_terms, g.known_variable_terms)
    _operate_terms!(op, f.known_decision_terms, g.known_decision_terms)
    f.known_decision_terms.constant = op(f.known_decision_terms.constant, g.known_decision_terms.constant)
    return f
end
function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T,QuadraticPart{T}},
                             g::QuadraticDecisionFunction{T,QuadraticPart{T}}) where T
    f_lq = f.linear_quadratic_terms
    g_lq = g.linear_quadratic_terms
    # Variable part
    _operate_terms!(op, f_lq.variable_part, g_lq.variable_part)
    f_lq.variable_part.constant = op(f_lq.variable_part.constant, g_lq.variable_part.constant)
    # Decision part
    _operate_terms!(op, f_lq.decision_part, g_lq.decision_part)
    f_lq.decision_part.constant = op(f_lq.decision_part.constant, g_lq.decision_part.constant)
    # Cross terms
    _operate_terms!(op, f_lq.cross_terms, g_lq.cross_terms)
    # Known part
    _operate_terms!(op, f.known_part, g.known_part)
    f.known_part.constant = op(f.known_part.constant, g.known_part.constant)
    _operate_terms!(op, f.known_variable_terms, g.known_variable_terms)
    _operate_terms!(op, f.known_decision_terms, g.known_decision_terms)
    f.known_decision_terms.constant = op(f.known_decision_terms.constant, g.known_decision_terms.constant)
    return f
end

MOIU.similar_type(::Type{<:AffineDecisionFunction}, ::Type{T}) where T = AffineDecisionFunction{T}
MOIU.similar_type(::Type{<:QuadraticDecisionFunction}, ::Type{T}) where T = QuadraticDecisionFunction{T}
MOIU.similar_type(::Type{<:VectorAffineDecisionFunction}, ::Type{T}) where T = VectorAffineDecisionFunction{T}

MA.promote_operation(::typeof(real), T::Type{<:Union{SingleDecision, SingleKnown, VectorOfDecisions, VectorOfKnowns}}) = T
function MA.promote_operation(::typeof(imag), ::Type{T}, ::Type{F}) where {T, F <: Union{SingleDecision, SingleKnown}}
    return AffineDecisionFunction{T}
end
function MA.promote_operation(::typeof(imag), ::Type{T}, ::Type{F}) where {T, F <: Union{VectorOfDecisions, VectorOfKnowns}}
    return VectorAffineDecisionFunction{T}
end
function MA.promote_operation(::typeof(conj), ::Type{T}, ::Type{F}) where {T, F <: Union{SingleDecision, SingleKnown, VectorOfDecisions, VectorOfKnowns}}
    return T
end
function MA.promote_operation(op::Union{typeof(real), typeof(imag), typeof(conj)}, F::Type{<:TypedDecisionLike{T}}) where T
    return MOIU.similar_type(F, MA.promote_operation(op, T))
end

function MOIU.operate(::typeof(imag), ::Type{T}, ::Union{SingleDecision, SingleKnown}) where T
    return zero(AffineDecisionFunction{T})
end
function MOIU.operate(::typeof(imag), ::Type{T}, f::Union{VectorOfDecisions, VectorOfKnowns}) where T
    zero_with_output_dimension(VectorAffineDecisionFunction{T}, MOIU.output_dimension(f))
end
function MOIU.operate(::typeof(imag), ::Type, f::TypedDecisionLike)
    imag(f)
end

Base.real(f::Union{SingleDecision, SingleKnown, VectorOfDecisions, VectorOfKnowns}) = f
Base.real(f::TypedDecisionLike) = operate_coefficients(real, f)
Base.imag(f::TypedDecisionLike) = operate_coefficients(imag, f)
Base.conj(f::Union{SingleDecision, SingleKnown, VectorOfDecisions, VectorOfKnowns}) = f
Base.conj(f::TypedDecisionLike) = operate_coefficients(conj, f)

function _operate_terms!(::typeof(+),
                         f::MOI.ScalarAffineFunction,
                         g::MOI.ScalarAffineFunction)
    for term in g.terms
        add_term!(f.terms, term)
    end
    return nothing
end

function _operate_terms!(::typeof(-),
                         f::MOI.ScalarAffineFunction,
                         g::MOI.ScalarAffineFunction)
    for term in g.terms
        remove_term!(f.terms, term)
    end
    return nothing
end

function _operate_terms!(::typeof(+),
                         f::MOI.ScalarQuadraticFunction,
                         g::MOI.ScalarAffineFunction)
    for term in g.terms
        add_term!(f.affine_terms, term)
    end
    return nothing
end

function _operate_terms!(::typeof(-),
                         f::MOI.ScalarQuadraticFunction,
                         g::MOI.ScalarAffineFunction)
    for term in g.terms
        remove_term!(f.affine_terms, term)
    end
    return nothing
end

function _operate_terms!(::typeof(+),
                         f::MOI.ScalarQuadraticFunction,
                         g::MOI.ScalarQuadraticFunction)
    for term in g.affine_terms
        add_term!(f.affine_terms, term)
    end
    for term in g.quadratic_terms
        add_term!(f.quadratic_terms, term)
    end
    return nothing
end

function _operate_terms!(::typeof(-),
                         f::MOI.ScalarQuadraticFunction,
                         g::MOI.ScalarQuadraticFunction)
    for term in g.affine_terms
        remove_term!(f.affine_terms, term)
    end
    for term in g.quadratic_terms
        remove_term!(f.quadratic_terms, term)
    end
    return nothing
end
