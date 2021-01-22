abstract type AbstractHyperPlane end

abstract type HyperPlaneType end
abstract type OptimalityCut <: HyperPlaneType end
abstract type FeasibilityCut <: HyperPlaneType end
abstract type LinearConstraint <: HyperPlaneType end
abstract type Infeasible <: HyperPlaneType end
abstract type Unbounded <: HyperPlaneType end

struct HyperPlane{H <: HyperPlaneType, T <: AbstractFloat, A <: AbstractVector} <: AbstractHyperPlane
    δQ::A
    q::T
    id::Int

    function HyperPlane(δQ::AbstractVector, q::AbstractFloat, id::Int, ::Type{H}) where H <: HyperPlaneType
        T = promote_type(eltype(δQ), Float32)
        δQ_ = convert(AbstractVector{T}, δQ)
        new{H, T, typeof(δQ_)}(δQ_, q, id)
    end
end
OptimalityCut(δQ::AbstractVector, q::AbstractFloat, id::Int) = HyperPlane(δQ, q, id, OptimalityCut)
FeasibilityCut(δQ::AbstractVector, q::AbstractFloat, id::Int) = HyperPlane(δQ, q, id, FeasibilityCut)
LinearConstraint(δQ::AbstractVector, q::AbstractFloat, id::Int) = HyperPlane(δQ, q, id, LinearConstraint)
Infeasible(Q::AbstractFloat, id::Int) = HyperPlane(sparsevec(Float64[]), Q, id, Infeasible)
Unbounded(Q::AbstractFloat, id::Int) = HyperPlane(sparsevec(Float64[]), Q, id, Unbounded)

struct AggregatedOptimalityCut{T <: AbstractFloat, A <: AbstractVector} <: AbstractHyperPlane
    δQ::A
    q::T
    ids::Vector{Int}

    function AggregatedOptimalityCut(δQ::AbstractVector, q::AbstractFloat, ids::Vector{Int})
        T = promote_type(eltype(δQ), Float32)
        δQ_ = convert(AbstractVector{T}, δQ)
        new{T, typeof(δQ_)}(δQ_, q, ids)
    end
end

SparseFeasibilityCut{T <: AbstractFloat} = HyperPlane{FeasibilityCut, T, SparseVector{T,Int64}}
SparseLinearConstraint{T <: AbstractFloat} = HyperPlane{LinearConstraint, T, SparseVector{T,Int64}}
AnyOptimalityCut{T, A} = Union{HyperPlane{OptimalityCut, T, A}, AggregatedOptimalityCut{T, A}}
SparseOptimalityCut{T <: AbstractFloat} = HyperPlane{OptimalityCut, T, SparseVector{T,Int64}}
SparseAggregatedOptimalityCut{T <: AbstractFloat} = AggregatedOptimalityCut{T, SparseVector{T,Int64}}
AnySparseOptimalityCut{T <: AbstractFloat} = Union{SparseOptimalityCut, SparseAggregatedOptimalityCut{T}}
SparseHyperPlane{T <: AbstractFloat} = Union{HyperPlane{<:HyperPlaneType, T, SparseVector{T,Int64}}, SparseAggregatedOptimalityCut{T}}
QCut{T} = Tuple{Int,SparseHyperPlane{T}}
CutQueue{T} = RemoteChannel{Channel{QCut{T}}}

function (hyperplane::HyperPlane{FeasibilityCut})(x::AbstractVector)
    return Inf
end
function (cut::HyperPlane{OptimalityCut})(x::AbstractVector)
    if length(cut.δQ) != length(x)
        throw(ArgumentError(@sprintf("Dimensions of the cut (%d)) and the given optimization vector (%d) does not match", length(cut.δQ), length(x))))
    end
    return cut.q-cut.δQ⋅x
end
function (cut::AggregatedOptimalityCut)(x::AbstractVector)
    if length(cut.δQ) != length(x)
        throw(ArgumentError(@sprintf("Dimensions of the cut (%d)) and the given optimization vector (%d) does not match", length(cut.δQ), length(x))))
    end
    return cut.q-cut.δQ⋅x
end
function (hyperplane::HyperPlane{Infeasible})(x::AbstractVector)
    return hyperplane.q
end
function (hyperplane::HyperPlane{Unbounded})(x::AbstractVector)
    return hyperplane.q
end

infeasible(hyperplane::AbstractHyperPlane) = false
infeasible(hyperplane::HyperPlane{Infeasible}) = true
bounded(hyperplane::AbstractHyperPlane) = true
bounded(hyperplane::HyperPlane{Unbounded}) = false
function optimal(cut::AnyOptimalityCut, x::AbstractVector, θ::AbstractFloat, τ::AbstractFloat)
    Q = cut(x)
    return θ > -Inf && abs(θ-Q) <= τ*(1+abs(Q))
end
function active(hyperplane::AbstractHyperPlane, x::AbstractVector, τ::AbstractFloat)
    return abs(gap(hyperplane,x)) <= τ
end
function satisfied(hyperplane::AbstractHyperPlane, x::AbstractVector, τ::AbstractFloat)
    return gap(hyperplane,x) >= -τ
end
function satisfied(cut::HyperPlane{OptimalityCut}, x::AbstractVector, θ::AbstractFloat, τ::AbstractFloat)
    Q = cut(x)
    return θ > -Inf && θ >= Q - τ
end
function gap(hyperplane::AbstractHyperPlane, x::AbstractVector)
    if length(hyperplane.δQ) != length(x)
        throw(ArgumentError(@sprintf("Dimensions of the cut (%d)) and the given optimization vector (%d) does not match", length(hyperplane.δQ), length(x))))
    end
    return hyperplane.δQ⋅x-hyperplane.q
end
function gap(cut::AnyOptimalityCut, x::AbstractVector, θ::AbstractFloat)
    if θ > -Inf
        return θ-cut(x)
    else
        return Inf
    end
end
function num_subproblems(::AbstractHyperPlane)
    return 1
end
function num_subproblems(cut::AggregatedOptimalityCut)
    return length(cut.ids)
end

moi_constraint(hyperplane::AbstractHyperPlane, master_variables::Vector{MOI.VariableIndex}) = moi_constraint(hyperplane, master_variables, 1.)
function moi_constraint(hyperplane::HyperPlane{H,T,SparseVector{T,Int}}, ::Vector{MOI.VariableIndex}, scaling::T) where {H <: HyperPlaneType, T <: AbstractFloat}
    terms = map(zip(hyperplane.δQ.nzval, hyperplane.δQ.nzind)) do (coeff, idx)
        MOI.ScalarAffineTerm(scaling * coeff, MOI.VariableIndex(idx))
    end
    f = MOI.ScalarAffineFunction{Float64}(terms, 0.0)
    set = MOI.GreaterThan{Float64}(scaling * hyperplane.q)
    return f, set
end
function moi_constraint(cut::HyperPlane{FeasibilityCut,T,SparseVector{T,Int}}, ::Vector{MOI.VariableIndex}, scaling::T) where T <: AbstractFloat
    terms = map(zip(cut.δQ.nzval, cut.δQ.nzind)) do (coeff, idx)
        MOI.ScalarAffineTerm(scaling * coeff, MOI.VariableIndex(idx))
    end
    f = AffineDecisionFunction(convert(MOI.ScalarAffineFunction{T}, zero(T)),
                               MOI.ScalarAffineFunction(terms, zero(T)))
    set = MOI.GreaterThan{Float64}(scaling * cut.q)
    return f, set
end
function moi_constraint(cut::HyperPlane{OptimalityCut,T,SparseVector{T,Int}}, master_variables::Vector{MOI.VariableIndex}, scaling::T) where T <: AbstractFloat
    terms = map(zip(cut.δQ.nzval, cut.δQ.nzind)) do (coeff, idx)
        MOI.ScalarAffineTerm(scaling * coeff, MOI.VariableIndex(idx))
    end
    # Add model term
    model_terms = [MOI.ScalarAffineTerm(scaling, master_variables[cut.id])]
    f = AffineDecisionFunction(MOI.ScalarAffineFunction(model_terms, zero(T)),
                               MOI.ScalarAffineFunction(terms, zero(T)))
    set = MOI.GreaterThan{Float64}(scaling * cut.q)
    return f, set
end
function moi_constraint(cut::SparseAggregatedOptimalityCut, master_variables::Vector{MOI.VariableIndex}, scaling::T) where T <: AbstractFloat
    terms = map(zip(cut.δQ.nzval, cut.δQ.nzind)) do (coeff, idx)
        MOI.ScalarAffineTerm(scaling * coeff, MOI.VariableIndex(idx))
    end
    # Add model terms
    model_terms = map(cut.ids) do idx
        MOI.ScalarAffineTerm(scaling, master_variables[idx])
    end
    f = AffineDecisionFunction(MOI.ScalarAffineFunction(model_terms, zero(T)),
                               MOI.ScalarAffineFunction(terms, zero(T)))
    set = MOI.GreaterThan{Float64}(scaling * cut.q)
    return f, set
end

function aggregate(cuts::Vector{HyperPlane{OptimalityCut,T,A}}, id::Integer) where {T <: AbstractFloat, A <: AbstractVector}
    return HyperPlane(sum([cut.δQ for cut in cuts]),
                      sum([cut.q for cut in cuts]),
                      id,
                      OptimalityCut)
end

function aggregate(cuts::Vector{<:AbstractHyperPlane})
    return sum(cuts)
end

struct ZeroVector{T <: AbstractFloat} <: AbstractVector{T} end
length(::ZeroVector) = 0
size(::ZeroVector) = 0
ZeroOptimalityCut{T <: AbstractFloat} = AggregatedOptimalityCut{T, ZeroVector{T}}

function Base.zero(::Type{AggregatedOptimalityCut{T}}) where T <: AbstractFloat
    return AggregatedOptimalityCut(ZeroVector{T}(), zero(T), Int[])
end
Base.iszero(::AggregatedOptimalityCut) = false
Base.iszero(::AggregatedOptimalityCut{T,ZeroVector{T}}) where T <: AbstractFloat = true

function +(c₁::AggregatedOptimalityCut{T,ZeroVector{T}}, c₂::AggregatedOptimalityCut{T,ZeroVector{T}}) where T <: AbstractFloat
    return c₁
end
function +(c₁::HyperPlane{OptimalityCut, T, A}, c₂::HyperPlane{OptimalityCut, T, A}) where {T <: AbstractFloat, A <: AbstractVector}
    return AggregatedOptimalityCut(c₁.δQ + c₂.δQ, c₁.q + c₂.q, vcat(c₁.id, c₂.id))
end
function +(c₁::AggregatedOptimalityCut{T, A}, c₂::AggregatedOptimalityCut{T, A}) where {T <: AbstractFloat, A <: AbstractVector}
    return AggregatedOptimalityCut(c₁.δQ + c₂.δQ, c₁.q + c₂.q, vcat(c₁.ids, c₂.ids))
end
function +(c₁::AggregatedOptimalityCut{T, A}, c₂::HyperPlane{OptimalityCut, T, A}) where {T <: AbstractFloat, A <: AbstractVector}
    return AggregatedOptimalityCut(c₁.δQ + c₂.δQ, c₁.q + c₂.q, vcat(c₁.ids, c₂.id))
end
function +(c₁::HyperPlane{OptimalityCut, T, A}, c₂::AggregatedOptimalityCut{T, A}) where {T <: AbstractFloat, A <: AbstractVector}
    return AggregatedOptimalityCut(c₁.δQ + c₂.δQ, c₁.q + c₂.q, vcat(c₁.id, c₂.ids))
end
function +(c₁::AggregatedOptimalityCut{T,ZeroVector{T}}, c₂::AggregatedOptimalityCut{T}) where T <: AbstractFloat
    return c₂
end
function +(c₁::AggregatedOptimalityCut{T}, c₂::AggregatedOptimalityCut{T,ZeroVector{T}}) where T <: AbstractFloat
    return c₁
end
function +(c₁::AggregatedOptimalityCut{T,ZeroVector{T}}, c₂::HyperPlane{OptimalityCut,T}) where T <: AbstractFloat
    return AggregatedOptimalityCut(c₂.δQ, c₂.q, [c₂.id])
end
function +(c₁::HyperPlane{OptimalityCut,T}, c₂::AggregatedOptimalityCut{T,ZeroVector{T}}) where T <: AbstractFloat
    return AggregatedOptimalityCut(c₁.δQ, c₁.q, [c₁.id])
end
