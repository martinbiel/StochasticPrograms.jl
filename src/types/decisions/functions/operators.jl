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

# Functions convertible to a AffineDecisionFunction
const ScalarAffineLike{T} = Union{MOIU.ScalarAffineLike{T}, SingleDecision, AffineDecisionFunction{T}}
const ScalarAffineDecisionLike{T} = Union{SingleDecision, AffineDecisionFunction{T}}

# Functions convertible to a QuadraticDecisionFunction
const ScalarQuadraticLike{T} = Union{MOIU.ScalarQuadraticLike{T}, SingleDecision, AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}
const ScalarQuadraticDecisionLike{T} = Union{SingleDecision, AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}

const TypedScalarDecisionLike{T} = Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}
const ScalarDecisionLike{T} = Union{SingleDecision, TypedScalarDecisionLike{T}}
const MixedTypedScalarLike{T} = Union{MOIU.TypedScalarLike{T}, TypedScalarDecisionLike{T}}
const MixedScalarLike{T} = Union{MOIU.ScalarLike{T}, ScalarDecisionLike{T}}

# Functions convertible to a VectorAffineDecisionFunction
const VectorAffineLike{T} = Union{MOIU.VectorAffineLike{T}, VectorOfDecisions, VectorAffineDecisionFunction{T}}
const VectorAffineDecisionLike{T} = Union{VectorOfDecisions, VectorAffineDecisionFunction{T}}

const TypedVectorDecisionLike{T} = Union{VectorAffineDecisionFunction{T}}
const VectorDecisionLike{T} = Union{VectorOfDecisions, VectorAffineDecisionFunction{T}}
const MixedVectorLike{T} = Union{MOIU.VectorLike{T}, VectorDecisionLike{T}}

const TypedDecisionLike{T} = Union{TypedScalarDecisionLike{T}, TypedVectorDecisionLike{T}}
const AffineLike{T} = Union{ScalarAffineLike{T}, VectorAffineLike{T}}
const AffineDecisionLike{T} = Union{ScalarAffineDecisionLike{T}, VectorAffineDecisionLike{T}}
const DecisionLike{T} = Union{ScalarDecisionLike{T}, VectorDecisionLike{T}}

MOIU._eltype(::AffineDecisionFunction{T}, tail) where {T} = T

# +/- #
# ========================== #
function MOIU.promote_operation(::typeof(-), ::Type{T},
                                ::Type{<:ScalarAffineDecisionLike{T}}) where T
    return AffineDecisionFunction{T}
end
function MOIU.promote_operation(::typeof(-), ::Type{T},
                                ::Type{<:ScalarQuadraticDecisionLike{T}}) where T
    return QuadraticDecisionFunction{T}
end
function MOIU.promote_operation(::typeof(-), ::Type{T},
                                ::Type{QuadraticDecisionFunction{T}}) where T
    return QuadraticDecisionFunction{T}
end

function MOIU.promote_operation(::Union{typeof(+), typeof(-)}, ::Type{T},
                                ::Type{<:ScalarAffineDecisionLike{T}},
                                ::Type{<:ScalarAffineLike{T}}) where T
    return AffineDecisionFunction{T}
end
function MOIU.promote_operation(::Union{typeof(+), typeof(-)}, ::Type{T},
                                ::Type{<:MOIU.ScalarAffineLike{T}},
                                ::Type{<:ScalarAffineDecisionLike{T}}) where T
    return AffineDecisionFunction{T}
end

function MOIU.promote_operation(::Union{typeof(+), typeof(-)}, ::Type{T},
                                ::Type{<:ScalarQuadraticDecisionLike{T}},
                                ::Type{<:ScalarQuadraticLike{T}}) where T
    return QuadraticDecisionFunction{T}
end
function MOIU.promote_operation(::Union{typeof(+), typeof(-)}, ::Type{T},
                                ::Type{<:MOIU.ScalarQuadraticLike{T}},
                                ::Type{<:ScalarQuadraticDecisionLike{T}}) where T
    return QuadraticDecisionFunction{T}
end

# Unary -
function MOIU.operate!(op::typeof(-), ::Type{T},
                       f::Union{AffineDecisionFunction{T},
                                QuadraticDecisionFunction{T}}) where T
    return MA.operate!(-, f)
end

# AffineDecisionFunction +/-! ...
function MOIU.operate!(op::Union{typeof(+), typeof(-)}, ::Type{T},
                       f::AffineDecisionFunction{T},
                       g::ScalarAffineLike{T}) where T
    return MA.operate!(op, f, g)
end
function MOIU.operate!(op::Union{typeof(+), typeof(-)}, ::Type{T},
                       f::SingleDecision,
                       g::ScalarQuadraticLike{T}) where T
    return MOIU.operate(op, T, f, g)
end
function MOIU.operate!(op::Union{typeof(+), typeof(-)}, ::Type{T},
                       f::AffineDecisionFunction{T},
                       g::MOI.ScalarQuadraticFunction{T}) where T
    return MOIU.operate(op, T, f, g)
end
function MOIU.operate!(op::Union{typeof(+), typeof(-)}, ::Type{T},
                       f::AffineDecisionFunction{T},
                       g::QuadraticDecisionFunction{T}) where T
    return MOIU.operate(op, T, f, g)
end
# QuadraticDecisionFunction +/-! ...
function MOIU.operate!(op::Union{typeof(+), typeof(-)}, ::Type{T},
                       f::QuadraticDecisionFunction{T},
                       g::ScalarQuadraticLike{T}) where T
    return MA.operate!(op, f, g)
end

# Scalar number +/- ...
function MOIU.operate(op::typeof(+), ::Type{T}, α::T, f::ScalarDecisionLike{T}) where T
    return MOIU.operate(op, T, f, α)
end
function MOIU.operate(op::typeof(-), ::Type{T}, α::T, f::ScalarDecisionLike{T}) where T
    return MOIU.operate!(+, T, MOIU.operate(-, T, f), α)
end

# SingleDecision +/- ...
function MOIU.operate(::typeof(-), ::Type{T}, f::SingleDecision) where T
    return AffineDecisionFunction{T}(convert(MOI.ScalarAffineFunction{T}, zero(T)),
                                     MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(-one(T), f.decision)], zero(T)))
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::SingleDecision, α::T) where T
    return AffineDecisionFunction{T}(convert(MOI.ScalarAffineFunction{T}, op(α)),
                                     MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(one(T), f.decision)], zero(T)))
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::SingleDecision,
                      g::MOI.VariableIndex) where T
    return AffineDecisionFunction{T}(MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(one(T), g.variable)], zero(T)),
                                     MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(one(T), f.decision)], zero(T)))
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::SingleDecision,
                      g::SingleDecision) where T
    return AffineDecisionFunction{T}(convert(MOI.ScalarAffineFunction{T}, zero(T)),
                                     MOI.ScalarAffineFunction(
                                         [MOI.ScalarAffineTerm(one(T), f.decision),
                                          MOI.ScalarAffineTerm(op(one(T)), g.decision)], zero(T)))
end
function MOIU.operate(op::typeof(+), ::Type{T},
                      f::SingleDecision,
                      g::MOI.ScalarAffineFunction{T}) where T
    return MOIU.operate(op, T, convert(AffineDecisionFunction{T}, g), f)
end
function MOIU.operate(op::typeof(-), ::Type{T},
                      f::SingleDecision,
                      g::MOI.ScalarAffineFunction{T}) where T
    return MOIU.operate!(+, T, MOIU.operate(-, T, convert(AffineDecisionFunction{T}, g)), f)
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::SingleDecision,
                      g::AffineDecisionFunction{T}) where T
    return MOIU.operate(op, T, convert(AffineDecisionFunction{T}, f), g)
end
function MOIU.operate(op::typeof(+), ::Type{T},
                      f::SingleDecision,
                      g::MOI.ScalarQuadraticFunction{T}) where T
    return MOIU.operate(op, T, convert(QuadraticDecisionFunction{T}, g), f)
end
function MOIU.operate(op::typeof(-), ::Type{T},
                      f::SingleDecision,
                      g::MOI.ScalarQuadraticFunction{T}) where T
    return MOIU.operate!(+, T, MOIU.operate(-, T, convert(QuadraticDecisionFunction{T}, g)), f)
end
function MOIU.operate(op::typeof(+), ::Type{T},
                      f::SingleDecision,
                      g::QuadraticDecisionFunction{T}) where T
    return MOIU.operate!(op, T, copy(g), f)
end
function MOIU.operate(op::typeof(-), ::Type{T},
                      f::SingleDecision,
                      g::QuadraticDecisionFunction{T}) where T
    return MOIU.operate!(+, T, operate(-, T, g), f)
end

# VariableIndex +- SingleDecision
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::MOI.VariableIndex,
                      g::SingleDecision) where T
    return MOIU.operate(op, T, g, f)
end

# Scalar Affine +/- ...
function MOIU.operate(op::Union{typeof(-)}, ::Type{T},
                      f::AffineDecisionFunction{T}) where T
    return AffineDecisionFunction(
        MOIU.operate(op, T, f.variable_part),
        MOIU.operate(op, T, f.decision_part))
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::AffineDecisionFunction{T},
                      g::ScalarAffineLike{T}) where T
    return MOIU.operate!(op, T, copy(f), g)
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::AffineDecisionFunction{T},
                      g::QuadraticDecisionFunction{T}) where T
    return QuadraticDecisionFunction(
            MOIU.operate(op, T, f.variable_part, g.variable_part),
            MOIU.operate(op, T, f.decision_part, g.decision_part),
            copy(g.cross_terms))
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::AffineDecisionFunction{T},
                      g::ScalarQuadraticLike{T}) where T
    return MOIU.operate(op, T, f, convert(QuadraticDecisionFunction{T}, g))
end

# Scalar Quadratic +/- ...
function MOIU.operate(op::Union{typeof(-)}, ::Type{T},
                      f::QuadraticDecisionFunction{T}) where T
    return QuadraticDecisionFunction(
            MOIU.operate(op, T, f.variable_part),
            MOIU.operate(op, T, f.decision_part),
            MOIU.operate(op, T, f.cross_terms))
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::QuadraticDecisionFunction{T},
                      g::ScalarQuadraticLike{T}) where T
    MOIU.operate!(op, T, copy(f), g)
end

# Base overloads
function Base.:+(arg::ScalarDecisionLike{T}, args::MixedScalarLike{T}...) where T
    return MOIU.operate(+, T, arg, args...)
end
function Base.:+(arg::MOIU.ScalarLike{T}, args::MixedScalarLike{T}...) where T
    return MOIU.operate(+, T, convert(AffineDecisionFunction{T}, arg), args...)
end
function Base.:+(α::T, arg::TypedScalarDecisionLike{T}, args::MixedScalarLike{T}...) where T
    return MOIU.operate(+, T, α, arg, args...)
end
function Base.:+(α::Number, f::SingleDecision)
    return MOIU.operate(+, typeof(α), α, f)
end
function Base.:+(f::TypedScalarDecisionLike{T}, α::T) where T
    return MOIU.operate(+, T, f, α)
end
function Base.:+(f::SingleDecision, α::Number)
    return MOIU.operate(+, typeof(α), f, α)
end
function Base.:-(arg::ScalarDecisionLike{T}, args::MixedScalarLike{T}...) where T
    return MOIU.operate(-, T, arg, args...)
end
function Base.:-(arg::MOIU.ScalarLike{T}, args::MixedScalarLike{T}...) where T
    return MOIU.operate(-, T, convert(AffineDecisionFunction{T}, arg), args...)
end
function Base.:-(f::TypedScalarDecisionLike{T}, α::T) where T
    return MOIU.operate(-, T, f, α)
end
function Base.:-(f::SingleDecision, α::Number)
    return MOIU.operate(-, typeof(α), f, α)
end
function Base.:-(α::T, f::TypedScalarDecisionLike{T}) where T
    return MOIU.operate(-, T, α, f)
end
function Base.:-(α::Number, f::SingleDecision)
    return MOIU.operate(-, typeof(α), α, f)
end

# VectorDecisionFunctions +/-
# ========================== #
function MOIU.promote_operation(::typeof(-), ::Type{T},
                                ::Type{<:VectorAffineDecisionLike{T}}) where T
    return VectorAffineDecisionFunction{T}
end

function MOIU.promote_operation(::Union{typeof(+), typeof(-)}, ::Type{T},
                                ::Type{<:VectorAffineDecisionLike{T}},
                                ::Type{<:VectorAffineLike{T}}) where T
    return VectorAffineDecisionFunction{T}
end
function MOIU.promote_operation(::Union{typeof(+), typeof(-)}, ::Type{T},
                                ::Type{<:MOIU.VectorAffineLike{T}},
                                ::Type{<:VectorAffineDecisionLike}) where T
    return VectorAffineDecisionFunction{T}
end

# Vector Decision +/- ...
function MOIU.operate!(op::Union{typeof(+), typeof(-)}, ::Type{T},
                       f::VectorOfDecisions,
                       g::VectorAffineDecisionLike{T}) where T
    return operate(op, T, f, g)
end
# VectorAffineDecision +/-! ...
function MOIU.operate_output_index!(
    op::Union{typeof(+), typeof(-)}, ::Type{T},
    output_index::Integer,
    f::VectorAffineDecisionFunction{T}, α::T) where T
    MOIU.operate_output_index!(op, T, output_index, f.variable_part, α)
    return f
end
function MOIU.operate!(op::Union{typeof(+), typeof(-)}, ::Type{T},
                       f::VectorAffineDecisionFunction{T},
                       g::Vector{T}) where T
    MOIU.operate!(op, T, f.variable_part, g)
    return f
end
function MOIU.operate_output_index!(
    op::Union{typeof(+), typeof(-)}, ::Type{T},
    output_index::Integer,
    f::VectorAffineDecisionFunction{T},
    g::MOI.VariableIndex) where T
    MOIU.operate_output_index!(op, T, output_index, f.variable_part, g)
    return f
end
function MOIU.operate_output_index!(
    op::Union{typeof(+), typeof(-)}, ::Type{T},
    output_index::Integer,
    f::VectorAffineDecisionFunction{T},
    g::SingleDecision) where T
    push!(f.decision_part.terms, MOI.VectorAffineTerm(
        output_index, MOI.ScalarAffineTerm(op(one(T)), g.decision)))
    return f
end
function MOIU.operate!(op::Union{typeof(+), typeof(-)}, ::Type{T},
                       f::VectorAffineDecisionFunction{T},
                       g::MOI.VectorOfVariables) where T
    MOIU.operate!(op, T, f.variable_part, g)
    return f
end
function MOIU.operate!(op::Union{typeof(+), typeof(-)}, ::Type{T},
                       f::VectorAffineDecisionFunction{T},
                       g::VectorOfDecisions) where T
    d = MOI.output_dimension(g)
    @assert MOI.output_dimension(f.decision_part) == d
    append!(f.decision_part.terms, MOI.VectorAffineTerm.(
        collect(1:d),
        MOI.ScalarAffineTerm.(op(one(T)), g.decisions)))
    return f
end
function MOIU.operate_output_index!(
    op::Union{typeof(+), typeof(-)}, ::Type{T},
    output_index::Integer,
    f::VectorAffineDecisionFunction{T},
    g::MOI.ScalarAffineFunction{T}) where T
    MOIU.operate_output_index!(op, T, output_index, f.variable_part, g)
    return f
end
function MOIU.operate_output_index!(
    op::Union{typeof(+), typeof(-)}, ::Type{T},
    output_index::Integer,
    f::VectorAffineDecisionFunction{T},
    g::AffineDecisionFunction{T}) where T
    MOIU.operate_output_index!(op, T, output_index, f.variable_part, g.variable_part)
    MOIU.operate_output_index!(op, T, output_index, f.decision_part, g.decision_part)
    return f
end
function MOIU.operate!(op::Union{typeof(+), typeof(-)}, ::Type{T},
                       f::VectorAffineDecisionFunction{T},
                       g::VectorAffineDecisionFunction{T}) where T
    MOIU.operate!(op, T, f.variable_part, g.variable_part)
    MOIU.operate!(op, T, f.decision_part, g.decision_part)
    return f
end

function MOIU.operate(op::typeof(-), ::Type{T}, f::VectorOfDecisions) where T
    d = MOI.output_dimension(f)
    return VectorAffineDecisionFunction{T}(
        MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], zeros(T, d)),
        MOI.VectorAffineFunction(MOI.VectorAffineTerm.(
            collect(1:d),
            MOI.ScalarAffineTerm.(-one(T), f.decisions)),
                                 fill(zero(T),d)))
end

# VectorDecision number +/- ...
function MOIU.operate(op::typeof(+), ::Type{T}, α::Vector{T}, f::Union{VectorOfDecisions, VectorAffineDecisionFunction{T}}) where T
    return MOIU.operate(op, T, f, α)
end
function MOIU.operate(op::typeof(-), ::Type{T}, α::Vector{T}, f::Union{VectorOfDecisions, VectorAffineDecisionFunction{T}}) where T
    return MOIU.operate!(+, T, operate(-, T, f), α)
end

# Vector Decisions +/- ...
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::VectorOfDecisions, α::Vector{T}) where T
    d = MOI.output_dimension(f)
    @assert length(α) == d
    return VectorAffineDecisionFunction{T}(
        MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], op.(α)),
        MOI.VectorAffineFunction(MOI.VectorAffineTerm.(
            collect(1:d),
            MOI.ScalarAffineTerm.(one(T), f.decisions)),
                                 zeros(T, d)))
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::VectorOfDecisions,
                      g::MOI.VectorOfVariables) where T
    d = MOI.output_dimension(f)
    @assert MOI.output_dimension(g) == d
    return VectorAffineDecisionFunction{T}(
        MOI.VectorAffineFunction(MOI.VectorAffineTerm.(
            collect(1:d),
            MOI.ScalarAffineTerm.(op(one(T)), g.variables)),
                                 zeros(T, d)),
        MOI.VectorAffineFunction(MOI.VectorAffineTerm.(
            collect(1:d),
            MOI.ScalarAffineTerm.(one(T), f.decisions)),
                                 zeros(T, d)))
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::VectorOfDecisions,
                      g::VectorOfDecisions) where T
    d = MOI.output_dimension(f)
    @assert MOI.output_dimension(g) == d
    return VectorAffineDecisionFunction{T}(
        MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], zeros(T, d)),
        MOI.VectorAffineFunction(
            vcat(
                MOI.VectorAffineTerm.(
                    collect(1:d),
                    MOI.ScalarAffineTerm.(one(T), f.decisions)),
                MOI.VectorAffineTerm.(
                    collect(1:d),
                    MOI.ScalarAffineTerm.(op(one(T)), g.decisions))),
            zeros(T, d)))
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::VectorOfDecisions,
                      g::MOI.VectorAffineFunction{T}) where T
    d = MOI.output_dimension(f)
    @assert MOI.output_dimension(g) == d
    return VectorAffineDecisionFunction{T}(
        MOIU.operate(op, T, g),
        MOI.VectorAffineFunction(
            MOI.VectorAffineTerm.(
                collect(1:d),
                MOI.ScalarAffineTerm.(one(T), f.decisions)),
            zeros(T, d)))
end

# Vector Variables +- Vector Decisions
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::MOI.VectorOfVariables,
                      g::VectorOfDecisions) where T
    return MOIU.operate(op, T, convert(VectorAffineDecisionFunction{T}, f), g)
end

# Vector Decisions +- VectorAffineFunction
function MOIU.operate(op::typeof(+), ::Type{T},
                      f::VectorOfDecisions,
                      g::VectorAffineDecisionFunction{T}) where T
    MOIU.operate!(op, T, convert(VectorAffineDecisionFunction{T}, f), g)
end
function MOIU.operate(op::typeof(-), ::Type{T},
                      f::VectorOfDecisions,
                      g::VectorAffineDecisionFunction{T}) where T
    MOIU.operate!(op, T, convert(VectorAffineDecisionFunction{T}, f), g)
end

# Vector Affine +/- ...
function MOIU.operate(op::Union{typeof(-)}, ::Type{T},
                      f::VectorAffineDecisionFunction{T}) where T
    return VectorAffineDecisionFunction(
        MOIU.operate(op, T, f.variable_part),
        MOIU.operate(op, T, f.decision_part))
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::VectorAffineDecisionFunction{T},
                      g::VectorAffineLike{T}) where T
    return MOIU.operate!(op, T, copy(f), g)
end

function Base.:+(arg::VectorDecisionLike{T}, args::MixedVectorLike{T}...) where T
    return MOIU.operate(+, T, arg, args...)
end
function Base.:+(arg::MOIU.VectorLike{T}, args::MixedVectorLike{T}...) where T
    return MOIU.operate(+, T, convert(VectorAffineDecisionFunction{T}, arg), args...)
end
function Base.:+(α::Vector{T}, f::VectorDecisionLike{T}, g::MixedVectorLike{T}...) where T
    return MOIU.operate(+, T, α, f, g...)
end
function Base.:+(f::VectorDecisionLike{T}, α::Vector{T}) where T
    return MOIU.operate(+, T, f, α)
end
function Base.:-(arg::VectorDecisionLike{T}, args::MixedVectorLike{T}...) where T
    return MOIU.operate(-, T, arg, args...)
end
function Base.:-(arg::MOIU.VectorLike{T}, args::MixedVectorLike{T}...) where T
    return MOIU.operate(-, T, convert(VectorAffineDecisionFunction{T}, arg), args...)
end
function Base.:-(f::VectorDecisionLike{T}, α::Vector{T}) where T
    return MOIU.operate(-, T, f, α)
end
function Base.:-(α::Vector{T}, f::VectorDecisionLike{T}) where T
    return MOIU.operate(-, T, α, f)
end

# * #
# ========================== #
function MOIU.promote_operation(::typeof(*), ::Type{T}, ::Type{T},
                                ::Type{<:ScalarAffineDecisionLike{T}}) where T
    return AffineDecisionFunction{T}
end
function MOIU.promote_operation(::typeof(*), ::Type{T},
                                ::Type{<:ScalarAffineDecisionLike{T}},
                                ::Type{T}) where T
    return AffineDecisionFunction{T}
end
function MOIU.promote_operation(::typeof(*), ::Type{T}, ::Type{T},
                                ::Type{QuadraticDecisionFunction{T}}) where T
    return QuadraticDecisionFunction{T}
end
function MOIU.promote_operation(::typeof(*), ::Type{T},
                                ::Type{QuadraticDecisionFunction{T}},
                                ::Type{T}) where T
    return QuadraticDecisionFunction{T}
end
function MOIU.promote_operation(::typeof(*), ::Type{T},
                                ::Type{<:ScalarAffineDecisionLike{T}},
                                ::Type{<:ScalarAffineLike{T}}) where T
    return QuadraticDecisionFunction{T}
end
function MOIU.promote_operation(::typeof(*), ::Type{T},
                                ::Type{<:MOIU.ScalarAffineLike{T}},
                                ::Type{<:ScalarAffineDecisionLike{T}}) where T
    return QuadraticDecisionFunction{T}
end

function MOIU.operate!(::typeof(*), ::Type{T}, f::SingleDecision, α::T) where T
    return MOIU.operate(*, T, α, f)
end
function MOIU.operate(::typeof(*), ::Type{T}, α::T, f::SingleDecision) where T
    return AffineDecisionFunction{T}(convert(MOIU.ScalarAffineLike{T}, zero(T)),
                                     MOI.ScalarAffineFunction{T}([MOI.ScalarAffineTerm(α, f.decision)], zero(T)))
end
function MOIU.operate(::typeof(*), ::Type{T}, α::T, f::VectorOfDecisions) where T
    d = MOI.output_dimension(f)
    return VectorAffineDecisionFunction{T}(
        MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], zeros(T, d)),
        MOI.VectorAffineFunction(
            [MOI.VectorAffineTerm(i, MOI.ScalarAffineTerm(α, f.decisions[i]))
             for i in eachindex(f.decisions)], zeros(T, MOI.output_dimension(f))))
end
function MOIU.operate(::typeof(*), ::Type{T}, f::Union{SingleDecision, VectorOfDecisions}, α::T) where T
    return MOIU.operate(*, T, α, f)
end

function MOIU.operate!(::typeof(*), ::Type{T},
                       f::AffineDecisionFunction{T}, α::T) where T<:Number
    MOIU.operate!(*, T, f.variable_part, α)
    MOIU.operate!(*, T, f.decision_part, α)
    return f
end
function MOIU.operate!(::typeof(*), ::Type{T},
                       f::QuadraticDecisionFunction{T}, α::T) where T<:Number
    MOIU.operate!(*, T, f.variable_part, α)
    MOIU.operate!(*, T, f.decision_part, α)
    MOIU.operate!(*, T, f.cross_terms, α)
    return f
end

function MOIU.operate!(::typeof(*), ::Type{T},
                       f::VectorAffineDecisionFunction{T}, α::T) where T
    MOIU.operate!(*, T, f.variable_part, α)
    MOIU.operate!(*, T, f.decision_part, α)
    return f
end

function MOIU.operate(::typeof(*), ::Type{T}, α::T, f::TypedDecisionLike{T}) where T
    return MOIU.operate!(*, T, copy(f), α)
end

function MOIU.operate(::typeof(*), ::Type{T}, f::SingleDecision,
                      g::MOI.VariableIndex) where T
    return QuadraticDecisionFunction(
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        MOI.ScalarQuadraticFunction{T}(
            [MOI.ScalarQuadraticTerm(one(T), f.decision, g.variable)],
            MOI.ScalarAffineTerm{T}[],
            zero(T)))
end
function MOIU.operate(::typeof(*), ::Type{T}, f::SingleDecision,
                      g::SingleDecision) where T
    return QuadraticDecisionFunction(
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        MOI.ScalarQuadraticFunction(
            [MOI.ScalarQuadraticTerm(f.decision == g.decision ? 2one(T) : one(T),
                                     f.decision, g.decision)],
            MOI.ScalarAffineTerm{T}[],
            zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end

function MOIU.operate(::typeof(*), ::Type{T}, f::MOI.VariableIndex, g::SingleDecision) where T
    return MOIU.operate(*, T, g, f)
end

function MOIU.operate(::typeof(*), ::Type{T}, f::AffineDecisionFunction{T},
                      g::AffineDecisionFunction{T}) where T
    # Variable part
    variable_part = MOIU.operate(*, T, f.variable_part, g.variable_part)
    # Decision part
    decision_part = MOIU.operate(*, T, f.decision_part, g.decision_part)
    if !iszero(f.variable_part.constant)
        for term in g.decision_part.terms
            new_term = MOIU.operate_term(*, f.variable_part.constant, term)
            add_term!(decision_part.affine_terms, new_term)
        end
    end
    if !iszero(g.variable_part.constant)
        for term in f.decision_part.terms
            new_term = MOIU.operate_term(*, g.variable_part.constant, term)
            add_term!(decision_part.affine_terms, new_term)
        end
    end
    # Cross terms
    cross_terms = convert(MOI.ScalarQuadraticFunction{T}, zero(T))
    for var_term in f.variable_part.terms
        for dvar_term in g.decision_part.terms
            new_term = MOIU.operate_term(*, dvar_term, var_term)
            add_term!(cross_terms.quadratic_terms, new_term)
        end
    end
    for var_term in g.variable_part.terms
        for dvar_term in f.decision_part.terms
            new_term = MOIU.operate_term(*, dvar_term, var_term)
            add_term!(cross_terms.quadratic_terms, new_term)
        end
    end
    return QuadraticDecisionFunction(
        variable_part,
        decision_part,
        cross_terms)
end
function MOIU.operate(::typeof(*), ::Type{T}, f::AffineDecisionFunction{T},
                      g::ScalarAffineLike{T}) where T
    return MOIU.operate(*, T, f, convert(AffineDecisionFunction{T}, g))
end
function MOIU.operate(::typeof(*), ::Type{T}, f::ScalarAffineLike{T},
                      g::AffineDecisionFunction{T}) where T
    return MOIU.operate(*, T, g, convert(AffineDecisionFunction{T}, f))
end
function MOIU.operate(::typeof(*), ::Type{T}, α::T,
                      g::AffineDecisionFunction{T}) where T
    return MOIU.operate!(*, T, copy(g), α)
end

MOIU.is_coefficient_type(::Type{<:Union{SingleDecision, VectorOfDecisions}}, ::Type) = true
MOIU.is_coefficient_type(::Type{<:TypedDecisionLike{T}}, ::Type{T}) where T = true
MOIU.is_coefficient_type(::Type{<:TypedDecisionLike}, ::Type) = false

function Base.:*(f::ScalarDecisionLike{T}, g::MixedScalarLike{T}, args::MixedScalarLike{T}...) where T
    return MOIU.operate(*, T, f, g, args...)
end
function Base.:*(f::MOIU.ScalarLike, g::MixedScalarLike, args::MixedScalarLike...)
    T = MOIU._eltype(f, (g, args...))
    @assert T !== nothing
    return MOIU.operate(*, T, convert(AffineDecisionFunction{T}, f), g, args...)
end
function Base.:*(α::T, g::TypedDecisionLike{T}) where T
    return MOIU.operate_coefficients(β -> α * β, g)
end
function Base.:*(α::Number, g::TypedDecisionLike)
    return MOIU.operate_coefficients(β -> α * β, g)
end
function Base.:*(α::T, g::TypedDecisionLike{T}) where T <: Number
    return MOIU.operate_coefficients(β -> α * β, g)
end
function Base.:*(f::Number, g::Union{SingleDecision, VectorOfDecisions})
    return MOIU.operate(*, typeof(f), f, g)
end
function Base.:*(f::TypedDecisionLike{T}, α::T) where T
    return MOIU.operate_coefficients(β -> α * β, f)
end
function Base.:*(f::TypedDecisionLike, α::Number)
    return MOIU.operate_coefficients(β -> α * β, f)
end
function Base.:*(f::TypedDecisionLike{T}, α::T) where T <: Number
    return MOIU.operate_coefficients(β -> α * β, f)
end
function Base.:*(f::Union{SingleDecision, VectorOfDecisions}, g::Number)
    return MOIU.operate(*, typeof(g), f, g)
end
function Base.:*(f::TypedDecisionLike{T}, g::Bool) where T
    if g
        return MA.copy_if_mutable(f)
    else
        return zero(typeof(f))
    end
end

function Base.:^(func::AffineDecisionFunction{T}, p::Integer) where T
    if iszero(p)
        return one(QuadraticDecisionFunction{T})
    elseif isone(p)
        return convert(QuadraticDecisionFunction{T}, func)
    elseif p == 2
        return func * func
    else
        throw(ArgumentError("Cannot take $(typeof(func)) to the power $p."))
    end
end
function Base.:^(func::QuadraticDecisionFunction{T}, p::Integer) where T
    if iszero(p)
        return one(QuadraticDecisionFunction{T})
    elseif isone(p)
        return MA.mutable_copy(func)
    else
        throw(ArgumentError("Cannot take $(typeof(func)) to the power $p."))
    end
end

function LinearAlgebra.dot(f::ScalarDecisionLike, g::ScalarDecisionLike)
    return f * g
end
function LinearAlgebra.dot(α::T, func::TypedDecisionLike{T}) where T
    return α * func
end
function LinearAlgebra.dot(func::TypedDecisionLike{T}, α::T) where T
    return func * α
end
function LinearAlgebra.dot(f::VectorAffineDecisionFunction{T}, g::VectorAffineDecisionFunction{T}) where T
    result = zero(QuadraticDecisionFunction{T})
    for (lhs,rhs) in zip(MOIU.scalarize(f), MOIU.scalarize(g))
        term = MOIU.operate(*, T, lhs, rhs)
        MOIU.operate!(+, T, result, term)
    end
    return result
end

LinearAlgebra.adjoint(f::ScalarDecisionLike) = f
LinearAlgebra.transpose(f::ScalarDecisionLike) = f
LinearAlgebra.symmetric_type(::Type{F}) where {F <: ScalarDecisionLike} = F
LinearAlgebra.symmetric(f::ScalarDecisionLike, ::Symbol) = f

# / #
# ========================== #
function MOIU.promote_operation(::typeof(/), ::Type{T},
                                ::Type{<:ScalarAffineDecisionLike{T}},
                                ::Type{T}) where T
    AffineDecisionFunction{T}
end
function MOIU.promote_operation(::typeof(/), ::Type{T},
                                ::Type{QuadraticDecisionFunction{T}},
                                ::Type{T}) where T
    QuadraticDecisionFunction{T}
end

function MOIU.operate!(::typeof(/), ::Type{T}, f::SingleDecision,
                       α::T) where T
    return MOIU.operate(/, T, f, α)
end
function MOIU.operate(::typeof(/), ::Type{T},
                      α::T,
                      f::Union{SingleDecision, VectorOfDecisions}) where T
    return MOIU.operate(*, T, inv(α), f)
end
function MOIU.operate(::typeof(/), ::Type{T},
                      f::Union{SingleDecision, VectorOfDecisions},
                      α::T) where T
    return MOIU.operate(*, T, inv(α), f)
end

function MOIU.operate!(::typeof(/), ::Type{T},
                       f::Union{AffineDecisionFunction{T}, VectorAffineDecisionFunction{T}},
                       α::T) where T
    MOIU.operate!(/, T, f.variable_part, α)
    MOIU.operate!(/, T, f.decision_part, α)
    return f
end

function MOIU.operate!(::typeof(/), ::Type{T},
                       f::QuadraticDecisionFunction{T},
                       α::T) where T
    MOIU.operate!(/, T, f.variable_part, α)
    MOIU.operate!(/, T, f.decision_part, α)
    MOIU.operate!(/, T, f.cross_terms, α)
    return f
end

function MOIU.operate(::typeof(/), ::Type{T}, f::TypedDecisionLike{T}, α::T) where T
    return MOIU.operate!(/, T, copy(f), α)
end

function Base.:/(f::TypedDecisionLike{T}, g::T) where T
    return MOIU.operate(/, T, f, g)
end
function Base.:/(f::Union{SingleDecision, VectorOfDecisions}, g::Number)
    return MOIU.operate(/, typeof(g), f, g)
end

# vcat #
# ========================== #
function MOIU.fill_variables(decisions::Vector{MOI.VariableIndex}, offset::Int,
                             output_offset::Int, f::SingleDecision)
    decisions[offset + 1] = f.decision
end

function MOIU.fill_variables(decisions::Vector{MOI.VariableIndex}, offset::Int,
                             output_offset::Int, f::VectorOfDecisions)
    decisions[offset .+ (1:length(f.decisions))] .= f.decisions
end

function MOIU.promote_operation(::typeof(vcat), ::Type{T},
                                ::Type{<:Union{SingleDecision,
                                               VectorOfDecisions}}...) where T
    return VectorOfDecisions
end
function MOIU.operate(::typeof(vcat), ::Type{T},
                      funcs::Union{SingleDecision,
                                   VectorOfDecisions}...) where T
    out_dim = sum(func -> MOIU.output_dim(T, func), funcs)
    decisions = Vector{MOI.VariableIndex}(undef, out_dim)
    MOIU.fill_vector(decisions, T, 0, 0, MOIU.fill_variables, MOIU.output_dim, funcs...)
    return VectorOfDecisions(decisions)
end

function MOIU.promote_operation(::typeof(vcat), ::Type{T},
                                ::Type{<:AffineDecisionLike{T}},
                                ::Type{<:AffineLike{T}}...) where T
    return VectorAffineDecisionFunction{T}
end

function MOIU.promote_operation(::typeof(vcat), ::Type{T},
                                ::Type{QuadraticDecisionFunction{T}}) where T
    return QuadraticDecisionFunction{T}
end

function MOIU.operate(::typeof(vcat), ::Type{T},
                      funcs::VectorAffineDecisionFunction{T}...) where T
    # Variable part
    nvariable_terms = sum(f -> MOIU.number_of_affine_terms(T, f.variable_part), funcs)
    variable_out_dim = sum(f -> MOIU.output_dim(T, f.variable_part), funcs)
    variable_terms = Vector{MOI.VectorAffineTerm{T}}(undef, nvariable_terms)
    variable_constants = zeros(T, variable_out_dim)
    MOIU.fill_vector(variable_terms, T, 0, 0,
                     MOIU.fill_terms, MOIU.number_of_affine_terms, [f.variable_part for f in funcs]...)
    MOIU.fill_vector(variable_constants, T, 0, 0,
                     MOIU.fill_constant, MOIU.output_dim, [f.variable_part for f in funcs]...)
    # Decision part
    ndecision_terms = sum(f -> MOIU.number_of_affine_terms(T, f.decision_part), funcs)
    decision_out_dim = sum(f -> MOIU.output_dim(T, f.decision_part), funcs)
    decision_terms = Vector{MOI.VectorAffineTerm{T}}(undef, ndecision_terms)
    decision_constants = zeros(T, decision_out_dim)
    MOIU.fill_vector(decision_terms, T, 0, 0,
                     MOIU.fill_terms, MOIU.number_of_affine_terms, [f.decision_part for f in funcs]...)
    MOIU.fill_vector(decision_constants, T, 0, 0,
                     MOIU.fill_constant, MOIU.output_dim, [f.decision_part for f in funcs]...)
    # Pad output
    out_dim = max(variable_out_dim, decision_out_dim)
    append!(variable_constants, zeros(T, out_dim - length(variable_constants)))
    append!(decision_constants, zeros(T, out_dim - length(decision_constants)))
    return VectorAffineDecisionFunction{T}(MOIU.VAF(variable_terms, variable_constants),
                                           MOIU.VAF(decision_terms, decision_constants))
end

# First or second argument must be decision like to avoid type piracy
function MOIU.operate(::typeof(vcat), ::Type{T},
                      f::AffineDecisionLike{T},
                      funcs::AffineLike{T}...) where T
    return MOIU.operate(vcat,
                        T,
                        convert(VectorAffineDecisionFunction{T}, f),
                        [convert(VectorAffineDecisionFunction{T}, f) for f in funcs]...)
end
function MOIU.operate(::typeof(vcat), ::Type{T},
                      f::Union{MOIU.ScalarAffineLike{T}, MOIU.VectorAffineLike{T}},
                      g::AffineDecisionLike{T},
                      funcs::AffineLike{T}...) where T
    return MOIU.operate(vcat,
                        T,
                        convert(VectorAffineDecisionFunction{T}, f),
                        convert(VectorAffineDecisionFunction{T}, g),
                        [convert(VectorAffineDecisionFunction{T}, f) for f in funcs]...)
end

Base.promote_rule(::Type{F}, ::Type{T}) where {T, F<:Union{AffineDecisionFunction{T}, VectorAffineDecisionFunction{T}}} = F
