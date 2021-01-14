"""
    DynamicAggregation

Functor object for using dynamic aggregation in an L-shaped algorithm. Create by supplying a [`DynamicAggregate`](@ref) object through `aggregate` in `LShaped.Optimizer` or by setting the [`Aggregator`](@ref) attribute.

The following selection rules are available
- [`SelectUniform`](@ref)
- [`SelectDecaying`](@ref)
- [`SelectRandom`](@ref
- [`SelectClosest`](@ref)
- [`SortByReference`](@ref)

...
# Parameters
- `num_aggregates::Int`: Number of aggregates
- `rule::SelectionRule`: Rule that determines which aggregate an incoming cut should be placed in
- `lock_after::Function = (τ,n)->false`: Function that determines if the current aggregation scheme should be fixed, based on the current optimality gap `τ` and the number of iterations `n`
...
"""
struct DynamicAggregation{T <: AbstractFloat, S <: AbstractSelectionRule} <: AbstractAggregation
    aggregates::Vector{AggregatedOptimalityCut{T}}
    rule::S
    partitioning::Dict{Int,Int}
    lock::Function

    function DynamicAggregation(num_aggregates::Integer, rule::AbstractSelectionRule, lock::Function, ::Type{T}) where T <: AbstractFloat
        S = typeof(rule)
        aggregates = [zero(AggregatedOptimalityCut{T}) for _ = 1:num_aggregates]
        return new{T,S}(aggregates, rule, Dict{Int,Int}(), lock)
    end
end

function aggregate_cut!(lshaped::AbstractLShaped, ::DynamicAggregation, cut::HyperPlane)
    return add_cut!(lshaped, cut)
end

function aggregate_cut!(lshaped::AbstractLShaped, aggregation::DynamicAggregation{T}, cut::HyperPlane{OptimalityCut}) where T <: AbstractFloat
    if aggregation.lock(gap(lshaped), num_iterations(lshaped)) && haskey(aggregation.partitioning, cut.id)
        aggregation.aggregates[aggregation.partitioning[cut.id]] += cut
        return false
    end
    (idx, full) = select(aggregation.rule, aggregation.aggregates, cut)
    aggregation.aggregates[idx] += cut
    aggregation.partitioning[cut.id] = idx
    if full
        aggregate = aggregation.aggregates[idx]
        aggregation.aggregates[idx] = zero(AggregatedOptimalityCut{T})
        return add_cut!(lshaped, aggregate)
    end
    return false
end

function aggregate_cut!(cutqueue::CutQueue, aggregation::DynamicAggregation, ::MetaData, t::Integer, cut::HyperPlane, x::AbstractArray)
    put!(cutqueue, (t, cut))
    return nothing
end

function aggregate_cut!(cutqueue::CutQueue, aggregation::DynamicAggregation{T}, metadata::MetaData, t::Integer, cut::HyperPlane{OptimalityCut}, x::AbstractArray) where T <: AbstractFloat
    gap = fetch(metadata, t, :gap)
    if aggregation.lock(gap, t) && haskey(aggregation.partitioning, cut.id)
        aggregation.aggregates[aggregation.partitioning[cut.id]] += cut
        return nothing
    end
    (idx, full) = select(aggregation.rule, aggregation.aggregates, cut)
    aggregation.partitioning[cut.id] = idx
    aggregation.aggregates[idx] += cut
    if full
        aggregate = aggregation.aggregates[idx]
        put!(cutqueue, (t, aggregate))
        aggregation.aggregates[idx] = zero(AggregatedOptimalityCut{T})
    end
    return nothing
end

function num_thetas(nscenarios::Integer, ::DynamicAggregation)
    return nscenarios
end

function num_thetas(nscenarios::Integer, ::DynamicAggregation, ::AbstractScenarioProblems)
    return nscenarios
end

function flush!(lshaped::AbstractLShaped, aggregation::DynamicAggregation{T}) where T <: AbstractFloat
    added = false
    for (i,aggregate) in enumerate(aggregation.aggregates)
        if !iszero(aggregate)
            added |= add_cut!(lshaped, aggregate)
            aggregation.aggregates[i] = zero(AggregatedOptimalityCut{T})
        end
    end
    reset!(aggregation.rule)
    return added
end

function flush!(cutqueue::CutQueue, aggregation::DynamicAggregation{T}, ::MetaData, t::Integer, x::AbstractArray) where T <: AbstractFloat
    for (i,aggregate) in enumerate(aggregation.aggregates)
        if !iszero(aggregate)
            put!(cutqueue, (t, aggregate))
            aggregation.aggregates[i] = zero(AggregatedOptimalityCut{T})
        end
    end
    reset!(aggregation.rule)
    return nothing
end

# API
# ------------------------------------------------------------
"""
    DynamicAggregate(num_aggregates::Integer, rule::AbstractSelectionRule; lock_after::Function = (τ,n)->false)

Factory object for [`DynamicAggregation`](@ref). Pass to `aggregate` in `LShaped.Optimizer` or set the [`Aggregator`](@ref) attribute. See ?DynamicAggregation for parameter descriptions.

"""
mutable struct DynamicAggregate <: AbstractAggregator
    num_aggregates::Int
    rule::AbstractSelectionRule
    lock::Function

    function DynamicAggregate(num_aggregates::Integer, rule::AbstractSelectionRule; lock_after = (τ,n)->false)
        return new(num_aggregates, rule, lock_after)
    end
end

struct SelectionRule <: AggregationParameter end

function MOI.get(aggregator::DynamicAggregate, ::SelectionRule)
    return aggregator.rule
end

function MOI.set(aggregator::DynamicAggregate, ::SelectionRule, rule::AbstractSelectionRule)
    return aggregator.rule = rule
end

function (aggregator::DynamicAggregate)(nscenarios::Integer, T::Type{<:AbstractFloat})
    if aggregator.rule isa SelectRandom && aggregator.rule.max == 1
        return NoAggregation()
    end
    return DynamicAggregation(aggregator.num_aggregates, aggregator.rule, aggregator.lock, T)
end

function remote_aggregator(aggregation::DynamicAggregation, ::AbstractScenarioProblems, ::Integer)
    return DynamicAggregate(length(aggregation.aggregates), aggregation.rule; lock_after = aggregation.lock)
end

function str(aggregator::DynamicAggregate)
    return "dynamic aggregation ruled by $(str(aggregator.rule))"
end
