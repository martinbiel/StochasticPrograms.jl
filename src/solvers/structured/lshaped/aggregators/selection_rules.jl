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
            return idx, true
        end
        return zero_idx, false
    end
    return idx, false
end

function str(::SelectClosest)
    return "distance based selection"
end

"""
    SelectClosestToReference(τ::AbstractFloat; distance::Function = absolute_distance)

Incoming cuts are placed into an aggregate based on the distance to a reference cut, according the supplied `distance` function. Behaves as [`SelectClosest`](@ref) if not withing the tolerance `τ` to the reference cut.

The following distance measures are available
- [`absolute_distance`](@ref)
- [`angular_distance`](@ref)
- [`spatioangular_distance`](@ref

"""
mutable struct SelectClosestToReference{T <: AbstractFloat} <: AbstractSelectionRule
    τ::T
    distance::Function
    reference::AggregatedOptimalityCut{T}
    buffer::AggregatedOptimalityCut{T}
end

function SelectClosestToReference(τ::AbstractFloat; distance::Function = absolute_distance)
    T = typeof(τ)
    return SelectClosestToReference{T}(τ, distance, zero(AggregatedOptimalityCut{T}), zero(AggregatedOptimalityCut{T}))
end

function select(rule::SelectClosestToReference, aggregates::Vector{<:AggregatedOptimalityCut}, cut::HyperPlane{OptimalityCut})
    # Fill buffer with total aggregate each iteration
    rule.buffer += cut
    if iszero(rule.reference)
        # Multicut before reference has been calculated
        return 1, true
    elseif rule.distance(cut, rule.reference) <= rule.τ
        # Distance to reference within tolerance
        return 1, false
    else
        for i = 2:length(aggregates)
            agg = aggregates[i]
            dist = rule.distance(cut, agg)
            if iszero(agg) || dist <= rule.τ / (num_subproblems(rule.reference) -
                                                num_subproblems(agg) + 1)
                if i == length(aggregates)
                    # Last position operates as multicut
                    return i, true
                end
                # Aggregate at i if within number adjusted tolerance
                return i, false
            end
        end
    end
end

function reset!(rule::SelectClosestToReference{T}) where T <: AbstractFloat
    # Swap in buffer and reset when all cuts have been seen
    rule.reference = zero(AggregatedOptimalityCut{T})
    rule.reference += rule.buffer
    rule.buffer = zero(AggregatedOptimalityCut{T})
    return nothing
end

function str(::SelectClosestToReference)
    return "distance to reference based selection"
end
