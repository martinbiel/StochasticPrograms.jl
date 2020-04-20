# AffineDecisionFunction #
# ========================== #
MA.mutability(::Type{<:Union{AffineDecisionFunction, VectorAffineDecisionFunction}}) = MA.IsMutable()

function MA.mutable_copy(f::AffineDecisionFunction)
    return AffineDecisionFunction(MA.mutable_copy(f.variable_part),
                                  MA.mutable_copy(f.decision_part),
                                  MA.mutable_copy(f.known_part))
end

function MA.isequal_canonical(f::F, g::F) where F<:Union{AffineDecisionFunction, MOI.ScalarAffineFunction}

    return MA.isequal_canonical(f.variable_part, g.variable_part) &&
        MA.isequal_canonical(f.decision_part, g.decision_part) &&
        MA.isequal_canonical(f.known_part, g.known_part)
end

function MA.iszero!(f::AffineDecisionFunction)
    return MA.iszero!(f.variable_part) &&
        MA.iszero!(f.decision_part) &&
        MA.iszero!(f.known_part)
end

function MA.scaling(f::AffineDecisionFunction)
    return MA.scaling(f.variable_part)
end

MA.promote_operation(::Union{typeof(zero), typeof(one)}, F::Type{<:AffineDecisionFunction}) = F

const PROMOTE_IMPLEMENTED_OP = Union{typeof(+), typeof(-), typeof(*), typeof(/)}
function MA.promote_operation(op::PROMOTE_IMPLEMENTED_OP,
                              F::Type{ScalarDecisionLike{T}},
                              G::Type{ScalarDecisionLike{T}}) where T
    promote_operation(op, T, F, G)
end
function MA.promote_operation(op::PROMOTE_IMPLEMENTED_OP, F::Type{T},
                              G::Type{<:Union{AffineDecisionFunction{T}, VectorAffineDecisionFunction{T}}}) where T
    promote_operation(op, T, F, G)
end
function MA.promote_operation(op::PROMOTE_IMPLEMENTED_OP, F::Type{<:Union{AffineDecisionFunction{T}, VectorAffineDecisionFunction{T}}},
                              G::Type{T}) where T
    promote_operation(op, T, F, G)
end
function MA.promote_operation(op::PROMOTE_IMPLEMENTED_OP, F::Type{<:Number},
                              G::Type{<:Union{SingleDecision, VectorOfDecisions}})
    promote_operation(op, F, F, G)
end
function MA.promote_operation(op::PROMOTE_IMPLEMENTED_OP,
                              F::Type{<:Union{SingleDecision, VectorOfDecisions}},
                              G::Type{<:Number})
    promote_operation(op, G, F, G)
end

function MA.mutable_operate!(op::Union{typeof(zero), typeof(one)}, f::AffineDecisionFunction)
    MA.mutable_operate!(op, f.variable_part)
    MA.mutable_operate!(op, f.decision_part)
    MA.mutable_operate!(op, f.known_part)
    return f
end

function MA.mutable_operate!(::typeof(-), f::AffineDecisionFunction)
    MA.mutable_operate!(op, f.variable_part)
    MA.mutable_operate!(op, f.decision_part)
    MA.mutable_operate!(op, f.known_part)
    return f
end

function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction,
                             g::T) where T
    MA.mutable_operate!(op, f.variable_part, g)
    return f
end

function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::MOI.ScalarAffineFunction{T},
                             g::SingleDecision) where T
    push!(f.decision_part.terms, MOI.ScalarAffineTerm(op(one(T)), g.decision))
    return f
end

function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction{T},
                             g::MOI.SingleVariable) where T
    MA.mutable_operate!(op, f.variable_part, g)
    return f
end

function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction{T},
                             g::MOI.ScalarAffineFunction{T}) where T
    MA.mutable_operate!(op, f.variable_part, g)
    return f
end

function MA.mutable_operate!(op::Union{typeof(+), typeof(-)},
                             f::AffineDecisionFunction{T},
                             g::AffineDecisionFunction{T}) where T
    MA.mutable_operate!(op, f.variable_part, g.variable_part)
    MA.mutable_operate!(op, f.decision_part, g.decision_part)
    MA.mutable_operate!(op, f.known_part, g.known_part)
    return f
end

function MA.mutable_operate_to!(
    output::AffineDecisionFunction{T}, op::Union{typeof(+), typeof(-)},
    f::AffineDecisionFunction{T}, g::AffineDecisionFunction{T}) where T

    MA.mutable_operate_to!(output.variable_part, op, f.variable_part, g.variable_part)
    MA.mutable_operate_to!(output.decision_part, op, f.decision_part, g.decision_part)
    MA.mutable_operate_to!(output.decision_part, op, f.known_part, g.known_part)
    return output
end

function MA.mutable_operate!(op::MA.AddSubMul, f::AffineDecisionFunction{T},
                             args::Vararg{Union{AffineDecisionFunction{T}, MOIU.ScalarAffineLike{T}}, N}) where {T, N}
    MA.mutable_operate!(op, f.variable_part, [g.variable_part for g in args]...)
    MA.mutable_operate!(op, f.decision_part, [g.decision_part for g in args]...)
    MA.mutable_operate!(op, f.known_part, [g.known_part for g in args]...)
    return f
end
