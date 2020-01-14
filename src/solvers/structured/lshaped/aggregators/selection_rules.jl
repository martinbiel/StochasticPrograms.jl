abstract type SelectionRule end

function reset!(::SelectionRule)
    return nothing
end

mutable struct SelectUniform <: SelectionRule
    n::Integer

    function SelectUniform(n::Integer)
        return new(max(1,n))
    end
end

function select(rule::SelectUniform, aggregates::Vector{<:AggregatedOptimalityCut}, ::HyperPlane{OptimalityCut})
    if nsubproblems(aggregates[1]) == rule.n - 1
        return 1, true
    end
    return 1, false
end

function str(::SelectUniform)
    return "balanced selection"
end

mutable struct SelectDecaying <: SelectionRule
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
    if nsubproblems(aggregates[1]) == rule.n - 1
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

struct SelectRandom <: SelectionRule
    max::Float64
end

SelectRandom(; max = Inf) = SelectRandom(max)

function select(rule::SelectRandom, aggregates::Vector{<:AggregatedOptimalityCut}, ::HyperPlane{OptimalityCut})
    idx = rand(eachindex(aggregates))
    while nsubproblems(aggregates[idx]) > rule.max
        idx = rand(eachindex(aggregates))
    end
    return idx, (nsubproblems(aggregates[idx]) == rule.max-1)
end

function str(rule::SelectRandom)
    if rule.max < Inf
        return "random selection of at most $(rule.max)"
    end
    return "random selection"
end

struct SelectClosest <: SelectionRule
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

mutable struct SelectClosestToReference{T <: AbstractFloat} <: SelectionRule
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
            if iszero(agg) || dist <= rule.τ/(nsubproblems(rule.reference) - nsubproblems(agg) + 1)
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
