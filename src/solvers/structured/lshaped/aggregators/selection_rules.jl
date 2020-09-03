abstract type AbstractSelectionRule end

function reset!(::AbstractSelectionRule)
    return nothing
end

"""
    SelectUniform(n::Integer)

Incoming cuts are placed into aggregates uniformly, so that each aggregate has at most `n` cuts. Behaves as [`PartialAggregation`](@ref).

"""
mutable struct SelectUniform <: AbstractSelectionRule
    n::Integer

    function SelectUniform(n::Integer)
        return new(max(1,n))
    end
end

function select(rule::SelectUniform, aggregates::Vector{<:AggregatedOptimalityCut}, ::HyperPlane{OptimalityCut})
    if num_subproblems(aggregates[1]) == rule.n - 1
        return 1, true
    end
    return 1, false
end

function str(::SelectUniform)
    return "uniform selection"
end

"""
    SelectDecaying(T₀::Integer, T̲::Integer = 1, γ::T)

Behaves like [`SelectUniform`](@ref), but the uniform aggregate size decays by `γ` each iteration, starting from `T₀`. `T̲` is an optional lower bound on the aggregate size.

"""
mutable struct SelectDecaying <: AbstractSelectionRule
    n::Int
    T̲::Int
    γ::Float64
    idx::Int

    function SelectDecaying(T₀::Integer, γ::Float64)
        return new(max(1,T₀), 1, γ, 1)
    end

    function SelectDecaying(T₀::Integer, T̲::Integer, γ::Float64)
        return new(max(T₀), max(1,T̲), γ, 1)
    end
end

function select(rule::SelectDecaying, aggregates::Vector{<:AggregatedOptimalityCut}, ::HyperPlane{OptimalityCut})
    if num_subproblems(aggregates[1]) == rule.n - 1
        return 1, true
    end
    return 1, false
end

function reset!(rule::SelectDecaying)
    rule.n = max(rule.T̲, round(Int, rule.γ*rule.n))
    rule.idx = 1
    return nothing
end

function str(::SelectDecaying)
    return "decaying aggregation level selection"
end

"""
    SelectRandom(max = Inf)

Incoming cuts are placed into aggregates randomly. An optional maximum number of cuts `max` can be specified.

"""
struct SelectRandom <: AbstractSelectionRule
    max::Float64
end

SelectRandom(; max = Inf) = SelectRandom(max)

function select(rule::SelectRandom, aggregates::Vector{<:AggregatedOptimalityCut}, ::HyperPlane{OptimalityCut})
    idx = rand(eachindex(aggregates))
    while num_subproblems(aggregates[idx]) > rule.max
        idx = rand(eachindex(aggregates))
    end
    return idx, (num_subproblems(aggregates[idx]) == rule.max-1)
end

function str(rule::SelectRandom)
    if rule.max < Inf
        return "random selection of at most $(rule.max)"
    end
    return "random selection"
end

"""
    SelectClosest(τ::AbstractFloat; distance::Function = absolute_distance)

Incoming cuts are placed into the closest aggregate, according the supplied `distance` function. An empty aggregate is chosen if no aggregate is within the tolerance `τ`

The following distance measures are available
- [`absolute_distance`](@ref)
- [`angular_distance`](@ref)
- [`spatioangular_distance`](@ref

"""
struct SelectClosest <: AbstractSelectionRule
    τ::Float64
    distance::Function
end

function SelectClosest(τ::AbstractFloat; distance::Function = absolute_distance)
    return SelectClosest(τ, distance)
end

function select(rule::SelectClosest, aggregates::Vector{<:AggregatedOptimalityCut}, cut::HyperPlane{OptimalityCut})
    separations = map(c -> rule.distance(c, cut), aggregates)
    (dist, idx) = findmin(separations)
    if dist > rule.τ
        zero_idx = findfirst(iszero, aggregates)
         if zero_idx == nothing
            return idx, false
        end
        return zero_idx, false
    end
    return idx, false
end

function str(::SelectClosest)
    return "distance based selection"
end

"""
    SortByReference(τ::AbstractFloat; distance::Function = absolute_distance)

Incoming cuts are placed into an aggregate based on the distance to a reference cut, according the supplied `distance` function. Behaves as [`SelectClosest`](@ref) if not withing the tolerance `τ` to the reference cut.

The following distance measures are available
- [`absolute_distance`](@ref)
- [`angular_distance`](@ref)
- [`spatioangular_distance`](@ref

"""
mutable struct SortByReference <: AbstractSelectionRule
    distance::Function
    reference::AggregatedOptimalityCut{Float64}
    buffer::AggregatedOptimalityCut{Float64}
end

function SortByReference(; distance::Function = absolute_distance)
    return SortByReference(distance, zero(AggregatedOptimalityCut{Float64}), zero(AggregatedOptimalityCut{Float64}))
end

function select(rule::SortByReference, aggregates::Vector{<:AggregatedOptimalityCut}, cut::HyperPlane{OptimalityCut})
    # Fill buffer with total aggregate each iteration
    rule.buffer += cut
    if iszero(rule.reference)
        # Single-cut before reference has been calculated
        return 1, false
    else
        τs = LinRange(0., 1., length(aggregates))
        dist = rule.distance(cut, agg)
        i = something(findfirst(τ -> dist <= τ, τs), 1)
        return i, false
    end
end

function reset!(rule::SortByReference)
    # Swap in buffer and reset when all cuts have been seen
    rule.reference = zero(AggregatedOptimalityCut{Float64})
    rule.reference += rule.buffer
    rule.buffer = zero(AggregatedOptimalityCut{Float64})
    return nothing
end

function str(::SortByReference)
    return "sort by reference based selection"
end
