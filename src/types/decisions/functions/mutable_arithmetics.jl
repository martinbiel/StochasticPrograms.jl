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

# AffineDecisionFunction #
# ========================== #
MA.mutability(::Type{<:TypedDecisionLike}) = MA.IsMutable()

function MA.mutable_copy(f::AffineDecisionFunction)
    return AffineDecisionFunction(MA.mutable_copy(f.variable_part),
                                  MA.mutable_copy(f.decision_part))
end
function MA.mutable_copy(f::QuadraticDecisionFunction)
    return QuadraticDecisionFunction(
        MA.mutable_copy(f.variable_part),
        MA.mutable_copy(f.decision_part),
        MA.mutable_copy(f.cross_terms))
end

function MA.isequal_canonical(f::F, g::F) where F<:Union{AffineDecisionFunction, VectorAffineDecisionFunction}
    return MA.isequal_canonical(f.variable_part, g.variable_part) &&
        MA.isequal_canonical(f.decision_part, g.decision_part)
end

function MA.isequal_canonical(f::F, g::F) where F <: QuadraticDecisionFunction
    return MA.isequal_canonical(f.variable_part, g.variable_part) &&
        MA.isequal_canonical(f.decision_part, g.decision_part) &&
        MA.isequal_canonical(f.cross_terms, g.cross_terms)
end

function MA.iszero!!(f::TypedScalarDecisionLike)
    return iszero!!(MOI.constant(f)) && MOIU._is_constant(MOIU.canonicalize!(f))
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

function MA.operate!(op::Union{typeof(zero), typeof(one)}, f::AffineDecisionFunction)
    MA.operate!(op, f.variable_part)
    MA.operate!(zero, f.decision_part)
    return f
end
function MA.operate!(op::Union{typeof(zero), typeof(one)}, f::QuadraticDecisionFunction{T}) where T
    MA.operate!(op, f.variable_part)
    MA.operate!(zero, f.decision_part)
    MA.operate!(zero, f.cross_terms)
    return f
end

function MA.operate!(::typeof(-), f::AffineDecisionFunction)
    MA.operate!(op, f.variable_part)
    MA.operate!(op, f.decision_part)
    return f
end
function MA.operate!(::typeof(-), f::QuadraticDecisionFunction{T}) where T
    MA.operate!(op, f.variable_part)
    MA.operate!(op, f.decision_part)
    MA.operate!(op, f.cross_terms)
    return f
end

function MA.operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction{T},
                             g::T) where T
    MA.operate!(op, f.variable_part, g)
    return f
end
function MA.operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction{T},
                             g::MOI.VariableIndex) where T
    _operate_terms!(op, f.variable_part, AffineDecisionFunction{T}(g).variable_part)
    return f
end
function MA.operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction{T},
                             g::SingleDecision) where T
    _operate_terms!(op, f.decision_part, AffineDecisionFunction{T}(g).decision_part)
    return f
end
function MA.operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction{T},
                             g::MOI.ScalarAffineFunction{T}) where T
    _operate_terms!(op, f.variable_part, g)
    f.variable_part.constant = op(f.variable_part.constant, g.constant)
    return f
end
function MA.operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction{T},
                             g::AffineDecisionFunction{T}) where T
    # Variable part
    _operate_terms!(op, f.variable_part, g.variable_part)
    f.variable_part.constant = op(f.variable_part.constant, g.variable_part.constant)
    # Decision part
    _operate_terms!(op, f.decision_part, g.decision_part)
    f.decision_part.constant = op(f.decision_part.constant, g.decision_part.constant)
    return f
end

function MA.operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T},
                             g::T) where T
    MA.operate!(op, f.variable_part, g)
    return f
end
function MA.operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T},
                             g::MOI.VariableIndex) where T
    _operate_terms!(op, f.variable_part, convert(MOI.ScalarAffineFunction{T}, g))
    return f
end
function MA.operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T},
                             g::SingleDecision) where T
    _operate_terms!(op, f.decision_part, convert(AffineDecisionFunction{T}, g).decision_part)
    return f
end
function MA.operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T},
                             g::MOI.ScalarAffineFunction{T}) where T
    _operate_terms!(op, f.variable_part, g)
    f.variable_part.constant = op(f.variable_part.constant, g.constant)
    return f
end
function MA.operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T},
                             g::MOI.ScalarQuadraticFunction{T}) where T
    _operate_terms!(op, f.variable_part, g)
    f.variable_part.constant = op(f.variable_part.constant, g.constant)
    return f
end
function MA.operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T},
                             g::AffineDecisionFunction{T}) where T
    # Variable_Part
    _operate_terms!(op, f.variable_part, g.variable_part)
    f.variable_part.constant = op(f.variable_part.constant, g.variable_part.constant)
    # Decision part
    _operate_terms!(op, f.decision_part, g.decision_part)
    f.decision_part.constant = op(f.decision_part.constant, f.decision_part.constant)
    return f
end
function MA.operate!(op::Union{typeof(+), typeof(-)},
                             f::QuadraticDecisionFunction{T},
                             g::QuadraticDecisionFunction{T}) where T
    # Variable part
    _operate_terms!(op, f.variable_part, g.variable_part)
    f.variable_part.constant = op(f.variable_part.constant, g.variable_part.constant)
    # Decision part
    _operate_terms!(op, f.decision_part, g.decision_part)
    f.decision_part.constant = op(f.decision_part.constant, g.decision_part.constant)
    # Cross terms
    _operate_terms!(op, f.cross_terms, g.cross_terms)
    return f
end

MOIU.similar_type(::Type{<:AffineDecisionFunction}, ::Type{T}) where T = AffineDecisionFunction{T}
MOIU.similar_type(::Type{<:QuadraticDecisionFunction}, ::Type{T}) where T = QuadraticDecisionFunction{T}
MOIU.similar_type(::Type{<:VectorAffineDecisionFunction}, ::Type{T}) where T = VectorAffineDecisionFunction{T}

MA.promote_operation(::typeof(real), T::Type{<:Union{SingleDecision, VectorOfDecisions}}) = T
function MA.promote_operation(::typeof(imag), ::Type{T}, ::Type{F}) where {T, F <: SingleDecision}
    return AffineDecisionFunction{T}
end
function MA.promote_operation(::typeof(imag), ::Type{T}, ::Type{F}) where {T, F <: VectorOfDecisions}
    return VectorAffineDecisionFunction{T}
end
function MA.promote_operation(::typeof(conj), ::Type{T}, ::Type{F}) where {T, F <: Union{SingleDecision, VectorOfDecisions}}
    return T
end
function MA.promote_operation(op::Union{typeof(real), typeof(imag), typeof(conj)}, F::Type{<:TypedDecisionLike{T}}) where T
    return MOIU.similar_type(F, MA.promote_operation(op, T))
end

function MOIU.operate(::typeof(imag), ::Type{T}, ::SingleDecision) where T
    return zero(AffineDecisionFunction{T})
end
function MOIU.operate(::typeof(imag), ::Type{T}, f::VectorOfDecisions) where T
    zero_with_output_dimension(VectorAffineDecisionFunction{T}, MOIU.output_dimension(f))
end
function MOIU.operate(::typeof(imag), ::Type, f::TypedDecisionLike)
    imag(f)
end

Base.real(f::Union{SingleDecision, VectorOfDecisions}) = f
Base.real(f::TypedDecisionLike) = operate_coefficients(real, f)
Base.imag(f::TypedDecisionLike) = operate_coefficients(imag, f)
Base.conj(f::Union{SingleDecision, VectorOfDecisions}) = f
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
