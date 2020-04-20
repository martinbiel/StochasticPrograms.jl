# Functions convertible to a AffineDecisionFunction
const ScalarAffineDecisionLike{T} = Union{MOIU.ScalarAffineLike{T}, SingleDecision, AffineDecisionFunction{T}}
const ScalarDecisionLike{T} = Union{SingleDecision, AffineDecisionFunction{T}}

# Functions convertible to a VectorAffineDecisionFunction
const VectorAffineDecisionLike{T} = Union{MOIU.VectorAffineLike{T}, VectorOfDecisions, VectorAffineDecisionFunction{T}}
const VectorDecisionLike{T} = Union{VectorOfDecisions, VectorAffineDecisionFunction{T}}

const DecisionLike{T} = Union{ScalarDecisionLike{T}, VectorDecisionLike{T}}

# +/- #
# ========================== #
function MOIU.promote_operation(::typeof(-), ::Type{T},
                                ::Type{<:Union{SingleDecision, AffineDecisionFunction{T}}}) where T
    return AffineDecisionFunction{T}
end

# Separate addition/subtraction into two cases to avoid type piracy
function MOIU.promote_operation(::Union{typeof(+), typeof(-)}, ::Type{T},
                                ::Type{<:ScalarDecisionLike{T}},
                                ::Type{<:ScalarAffineDecisionLike{T}}) where T
    return AffineDecisionFunction{T}
end
function MOIU.promote_operation(::Union{typeof(+), typeof(-)}, ::Type{T},
                                ::Type{<:MOIU.ScalarAffineLike{T}},
                                ::Type{<:ScalarDecisionLike{T}}) where T
    return AffineDecisionFunction{T}
end

# Unary -
function MOIU.operate!(op::typeof(-), ::Type{T},
                       f::AffineDecisionFunction{T}) where T
    return MA.mutable_operate!(-, f)
end

# AffineDecisionFunction +/-! ...
function MOIU.operate!(op::Union{typeof(+), typeof(-)}, ::Type{T},
                       f::AffineDecisionFunction{T},
                       g::ScalarAffineDecisionLike{T}) where T
    return MA.mutable_operate!(op, f, g)
end
function MOIU.operate!(op::Union{typeof(+), typeof(-)}, ::Type{T},
                       f::SingleDecision,
                       g::ScalarAffineDecisionLike{T}) where T
    return MOIU.operate(op, T, f, g)
end

# Scalar number +/- ...
function MOIU.operate(op::typeof(+), ::Type{T}, α::T, f::ScalarDecisionLike{T}) where T
    return operate(op, T, f, α)
end
function MOIU.operate(op::typeof(-), ::Type{T}, α::T, f::ScalarDecisionLike{T}) where T
    return operate!(+, T, operate(-, T, f), α)
end

# SingleDecision +/- ...
function MOIU.operate(::typeof(-), ::Type{T}, f::SingleDecision) where T
    return AffineDecisionFunction{T}(convert(MOI.ScalarAffineFunction{T}, zero(T)),
                                     MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(-one(T), f.decision)], zero(T)),
                                     convert(MOI.ScalarAffineFunction{T}, zero(T)))
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::SingleDecision, α::T) where T
    return AffineDecisionFunction{T}(convert(MOI.ScalarAffineFunction{T}, op(α)),
                                     MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(one(T), f.decision)], zero(T)),
                                     convert(MOI.ScalarAffineFunction{T}, zero(T)))
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::SingleDecision,
                      g::SingleDecision) where T
    return AffineDecisionFunction{T}(convert(MOI.ScalarAffineFunction{T}, zero(T)),
                                     MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(-one(T), f.decision),
                                                               MOI.ScalarAffineTerm(op(one(T)), g.decision)], zero(T)),
                                     convert(MOI.ScalarAffineFunction{T}, zero(T)))
end
function MOIU.operate(op::typeof(+), ::Type{T},
                      f::SingleDecision,
                      g::ScalarAffineDecisionLike{T}) where T
    return operate(op, T, convert(AffineDecisionFunction{T}, g), f)
end
function MOIU.operate(op::typeof(-), ::Type{T},
                      f::SingleDecision,
                      g::ScalarAffineDecisionLike{T}) where T
    return operate!(+, T, operate(-, T, convert(AffineDecisionFunction{T}, g)), f)
end

# Scalar Affine +/- ...
function MOIU.operate(op::Union{typeof(-)}, ::Type{T},
                      f::AffineDecisionFunction{T}) where T
    variable_part = operate(op, T, f.variable_part)
    decision_part = operate(op, T, f.decision_part)
    known_part = operate(op, T, f.known_part)
    return AffineDecisionFunction(variable_part, decision_part, known_part)
end

function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::AffineDecisionFunction{T},
                      g::ScalarAffineDecisionLike{T}) where T
    return MOIU.operate!(op, T, copy(f), g)
end

function MOIU.operate(op::typeof(-), ::Type{T},
                      f::ScalarAffineDecisionLike{T},
                      g::ScalarDecisionLike{T}) where T
    return MOIU.operate!(+, T, operate(-, T, convert(AffineDecisionFunction{T}, g)), f)
end

function Base.:+(arg::ScalarDecisionLike{T}, args::ScalarDecisionLike{T}...) where T
    return MOIU.operate(+, T, arg, args...)
end
function Base.:+(α::T, arg::AffineDecisionFunction{T}, args::ScalarDecisionLike{T}...) where T
    return MOIU.operate(+, T, α, arg, args...)
end
function Base.:+(α::Number, f::SingleDecision)
    return MOIU.operate(+, typeof(α), α, f)
end
function Base.:+(f::AffineDecisionFunction{T}, α::T) where T
    return MOIU.operate(+, T, f, α)
end
function Base.:+(f::SingleDecision, α::Number)
    return MOIU.operate(+, typeof(α), f, α)
end
function Base.:-(arg::ScalarDecisionLike{T}, args::ScalarDecisionLike{T}...) where T
    return MOIU.operate(-, T, arg, args...)
end
function Base.:-(f::AffineDecisionFunction{T}, α::T) where T
    return MOIU.operate(-, T, f, α)
end
function Base.:-(f::SingleDecision, α::Number)
    return MOIU.operate(-, typeof(α), f, α)
end
function Base.:-(α::T, f::AffineDecisionFunction{T}) where T
    return MOIU.operate(-, T, α, f)
end
function Base.:-(α::Number, f::SingleDecision)
    return MOIU.operate(-, typeof(α), α, f)
end

# VectorDecisionFunctions +/-
# ========================== #
function MOIU.promote_operation(::typeof(-), ::Type{T},
                                ::Type{<:VectorDecisionLike{T}}) where T
    return VectorAffineDecisionFunction{T}
end

# Separate addition/subtraction into two cases to avoid type piracy
function MOIU.promote_operation(::Union{typeof(+), typeof(-)}, ::Type{T},
                                ::Type{<:VectorDecisionLike{T}},
                                ::Type{<:VectorAffineDecisionLike{T}}) where T
    return VectorAffineDecisionFunction{T}
end
function MOIU.promote_operation(::Union{typeof(+), typeof(-)}, ::Type{T},
                                ::Type{<:MOIU.VectorAffineLike{T}},
                                ::Type{VectorDecisionLike}) where T
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
    MOIU.operate_output_index!(op, T, output_index, f.variable_part)
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
    g::MOI.SingleVariable) where T
    MIOU.operate_output_index!(op, T, output_index, f.variable_part, g)
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
    MIOU.operate_output_index!(op, T, output_index, f.variable_part, g)
    return f
end
function MOIU.operate_output_index!(
    op::Union{typeof(+), typeof(-)}, ::Type{T},
    output_index::Integer,
    f::VectorAffineDecisionFunction{T},
    g::AffineDecisionFunction{T}) where T
    MIOU.operate_output_index!(op, T, output_index, f.variable_part, g.variable_part)
    MIOU.operate_output_index!(op, T, output_index, f.decision_part, g.decision_part)
    MIOU.operate_output_index!(op, T, output_index, f.known_part, g.known_part)
    return f
end

function MOIU.operate(op::typeof(-), ::Type{T}, f::VectorOfDecisions) where T
    d = MOI.output_dimension(f)
    return VectorAffineDecisionFunction{T}(
        MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], zeros(T, d)),
        MOI.VectorAffineFunction(MOI.VectorAffineTerm.(
            collect(1:d),
            MOI.ScalarAffineTerm.(-one(T), f.decisions)),
                                 fill(zero(T),d)),
        MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], zeros(T, d)))
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
        MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], zeros(T, d)),
        MOI.VectorAffineFunction(MOI.VectorAffineTerm.(
            collect(1:d),
            MOI.ScalarAffineTerm.(one(T), f.decisions)),
                                 op.(α)),
        MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], zeros(T, d)))
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
                                 zeros(T, d)),
        MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], zeros(T, d)))
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
            zeros(T, d)),
        MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], zeros(T, d)))
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
            zeros(T, d)),
        MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], zeros(T, d)))
end
function MOIU.operate(op::typeof(+), ::Type{T},
                      f::VectorOfDecisions,
                      g::VectorAffineDecisionFunction{T}) where T
    MOIU.operate!(op, T, g, f)
end
function MOIU.operate(op::typeof(-), ::Type{T},
                      f::VectorOfDecisions,
                      g::VectorAffineDecisionFunction{T}) where T
    MOIU.operate!(op, T, MOIU.operate(-, T, g), f)
end

# Vector Affine +/- ...
function MOIU.operate(op::Union{typeof(-)}, ::Type{T},
                      f::VectorAffineDecisionFunction{T}) where T
    return VectorAffineDecisionFunction(
        MOIU.operate(op, T, f.variable_part),
        MOIU.operate(op, T, f.decision_part),
        MOIU.operate(op, T, f.known_part))
end
function MOIU.operate(op::Union{typeof(+), typeof(-)}, ::Type{T},
                      f::VectorAffineDecisionFunction{T},
                      g::VectorAffineDecisionLike{T}) where T
    return operate!(op, T, copy(f), g)
end

function Base.:+(α::Vector{T}, f::VectorDecisionLike{T}, g::VectorDecisionLike{T}...) where T
    return MOIU.operate(+, T, α, f, g...)
end
function Base.:+(f::VectorDecisionLike{T}, α::Vector{T}) where T
    return MOIU.operate(+, T, f, α)
end
function Base.:-(args::VectorDecisionLike{T}...) where T
    return MOIU.operate(-, T, args...)
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
                                ::Type{ScalarDecisionLike{T}}) where T
    return AffineDecisionFunction{T}
end
function MOIU.promote_operation(::typeof(*), ::Type{T},
                                ::Type{ScalarDecisionLike{T}},
                                ::Type{T}) where T
    return AffineDecisionFunction{T}
end

function MOIU.operate!(::typeof(*), ::Type{T}, f::SingleDecision, α::T) where T
    return MOIU.operate(*, T, α, f)
end
function MOIU.operate(::typeof(*), ::Type{T}, α::T, f::SingleDecision) where T
    return AffineDecisionFunction{T}(convert(MOIU.ScalarAffineLike{T}, zero(T)),
                                     MOI.ScalarAffineFunction{T}([MOI.ScalarAffineTerm(α, f.decision)], zero(T)),
                                     convert(MOI.ScalarAffineFunction{T}, zero(T)))
end
function MOIU.operate(::typeof(*), ::Type{T}, α::T, f::VectorOfDecisions) where T
    d = MOI.output_dimension(f)
    return VectorAffineDecisionFunction{T}(
        MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], zeros(T, d)),
        MOI.VectorAffineFunction(
            [MOI.VectorAffineTerm(i, MOI.ScalarAffineTerm(α, f.decisions[i]))
             for i in eachindex(f.decisions)], zeros(T, MOI.output_dimension(f))),
        MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], zeros(T, d)))
end

function MOIU.operate!(::typeof(*), ::Type{T},
                       f::AffineDecisionFunction{T}, α::T) where T<:Number
    MOIU.operate!(*, T, f.variable_part, α)
    MOIU.operate!(*, T, f.decision_part, α)
    MOIU.operate!(*, T, f.known_part, α)
    return f
end
function MOIU.operate!(::typeof(*), ::Type{T},
                       f::VectorAffineDecisionFunction{T}, α::T) where T
    MOIU.operate!(*, T, f.variable_part, α)
    MOIU.operate!(*, T, f.decision_part, α)
    MOIU.operate!(*, T, f.known_part, α)
    return f
end
function MOIU.operate(::typeof(*), ::Type{T}, α::T, f::Union{AffineDecisionFunction{T}, VectorAffineDecisionFunction{T}}) where T
    return MOIU.operate!(*, T, copy(f), α)
end

function Base.:*(f::ScalarDecisionLike{T}, g::ScalarDecisionLike{T}, args::ScalarDecisionLike{T}...) where T
    return MOIU.operate(*, T, f, g, args...)
end
function Base.:*(f::T, g::Union{AffineDecisionFunction{T}, VectorAffineDecisionFunction{T}}) where T
    return MOIU.operate(*, T, f, g)
end
function Base.:*(f::Number, g::Union{SingleDecision, VectorOfDecisions})
    return MOIU.operate(*, typeof(f), f, g)
end
function Base.:*(f::Union{AffineDecisionFunction{T}, VectorAffineDecisionFunction{T}}, g::T) where T
    return MOIU.operate(*, T, g, f)
end
function Base.:*(f::Union{SingleDecision, VectorOfDecisions}, g::Number)
    return MOIU.operate(*, typeof(g), f, g)
end
function Base.:*(f::Union{AffineDecisionFunction{T}, VectorAffineDecisionFunction{T}}, g::Bool) where T
    if g
        return MA.copy_if_mutable(f)
    else
        return zero(typeof(f))
    end
end

# / #
# ========================== #
function MOIU.promote_operation(::typeof(/), ::Type{T},
                                ::Type{ScalarDecisionLike{T}},
                                ::Type{T}) where T
    AffineDecisionFunction{T}
end

function MOIU.operate!(::typeof(/), ::Type{T}, f::SingleDecision,
                       α::T) where T
    return MOIU.operate(/, T, f, α)
end
function MOIU.operate(::typeof(/), ::Type{T}, f::SingleDecision, α::T) where T
    return AffineDecisionFunction{T}(convert(MOIU.ScalarAffineLike{T}, zero(T)),
                                     MOI.ScalarAffineFunction{T}([MOI.ScalarAffineTerm(inv(α), f.decision)], zero(T)),
                                     convert(MOI.ScalarAffineFunction{T}, zero(T)))
end

function MOIU.operate!(::typeof(/), ::Type{T},
                       f::Union{AffineDecisionFunction{T}, VectorAffineDecisionFunction{T}},
                       α::T) where T
    MOIU.operate!(/, T, f.variable_part, α)
    MOIU.operate!(/, T, f.decision_part, α)
    MOIU.operate!(/, T, f.known_part, α)
    return f
end

function MOIU.operate(::typeof(/), ::Type{T}, f::AffineDecisionFunction{T}, α::T) where T
    return MOIU.operate!(/, T, copy(f), α)
end

function MOIU.operate(::typeof(/), ::Type{T}, f::Union{AffineDecisionFunction{T}, VectorAffineDecisionFunction{T}}, α::T) where T
    return MOIU.operate!(/, T, copy(f), α)
end

function MOIU.operate(::typeof(/), ::Type{T},
                      f::Union{SingleDecision, VectorOfDecisions},
                      α::T) where T
    return MOIU.operate(*, T, inv(α), f)
end

function Base.:/(f::Union{AffineDecisionFunction{T}, VectorAffineDecisionFunction{T}}, g::T) where T
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
                                ::Type{<:Union{ScalarDecisionLike{T}, VectorOfDecisions, VectorAffineDecisionFunction{T}}}...) where T
    return VectorAffineDecisionFunction{T}
end

function MOIU.operate(::typeof(vcat), ::Type{T},
                      funcs::VectorAffineDecisionFunction{T}...) where T
    # Variable part
    nvariable_terms = sum(f -> number_of_affine_terms(T, f.variable_part), funcs)
    variable_out_dim = sum(f -> output_dim(T, f.variable_part), funcs)
    variable_terms = Vector{MOI.VectorAffineTerm{T}}(undef, nvariable_terms)
    variable_constant = zeros(T, variable_out_dim)
    MOIU.fill_vector(variable_terms, T, 0, 0,
                     MOIU.fill_terms, MOIU.number_of_affine_terms, [f.variable_part for f in funcs]...)
    MOIU.fill_vector(variable_constant, T, 0, 0,
                     MOIU.fill_constant, MOIU.output_dim, [f.variable_part for f in funcs]...)
    # Decision part
    ndecision_terms = sum(f -> number_of_affine_terms(T, f.decision_part), funcs)
    decision_out_dim = sum(f -> output_dim(T, f.decision_part), funcs)
    decision_terms = Vector{MOI.VectorAffineTerm{T}}(undef, ndecision_terms)
    decision_constant = zeros(T, decision_out_dim)
    MOIU.fill_vector(decision_terms, T, 0, 0,
                     MOIU.fill_terms, MOIU.number_of_affine_terms, [f.decision_part for f in funcs]...)
    MOIU.fill_vector(decision_constant, T, 0, 0,
                     MOIU.fill_constant, MOIU.output_dim, [f.decision_part for f in funcs]...)
    # Known part
    nknown_terms = sum(f -> number_of_affine_terms(T, f.known_part), funcs)
    known_out_dim = sum(f -> output_dim(T, f.known_part), funcs)
    known_terms = Vector{MOI.VectorAffineTerm{T}}(undef, nknown_terms)
    known_constant = zeros(T, known_out_dim)
    MOIU.fill_vector(known_terms, T, 0, 0,
                     MOIU.fill_terms, MOIU.number_of_affine_terms, [f.known_part for f in funcs]...)
    MOIU.fill_vector(known_constant, T, 0, 0,
                     MOIU.fill_constant, MOIU.output_dim, [f.known_part for f in funcs]...)
    return VectorAffineDecisionFunction{T}(MOIU.VAF(variable_terms, variable_constant),
                                           MOIU.VAF(decision_terms, decision_constant),
                                           MOIU.VAF(known_terms, known_constant))
end

# First argument must be decision like to avoid type piracy
function MOIU.operate(::typeof(vcat), ::Type{T},
                      func::DecisionLike{T},
                      funcs::Union{DecisionLike{T}, MOIU.ScalarAffineLike{T}, MOIU.VVF, MOIU.VAF{T}}...) where T
    return MOIU.operate(vcat, T, func, [convert(VectorAffineDecisionFunction{T}, f) for f in funcs]...)
end

Base.promote_rule(::Type{F}, ::Type{T}) where {T, F<:Union{AffineDecisionFunction{T}, VectorAffineDecisionFunction{T}}} = F
