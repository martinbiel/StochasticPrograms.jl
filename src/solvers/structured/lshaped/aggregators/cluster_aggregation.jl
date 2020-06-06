"""
    ClusterAggregation

Functor object for using cluster aggregation in an L-shaped algorithm. Create by supplying a [`ClusterAggregate`](@ref) object through `aggregate ` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

The following cluster rules are available
- [`StaticCluster`](@ref)
- [`ClusterByReference`](@ref)
- [`Kmedoids`](@ref
- [`Hierarchical`](@ref)

...
# Parameters
- `rule::ClusterRule`: Rule that determines how cuts should be sorted into clusters
- `lock_after::Function = (τ,n)->false`: Function that determines if the current aggregation scheme should be fixed, based on the current optimality gap `τ` and the number of iterations `n`
...
"""
struct ClusterAggregation{T <: AbstractFloat, C <: AbstractClusterRule} <: AbstractAggregation
    buffer::Vector{SparseOptimalityCut{T}}
    rule::C
    partitioning::Dict{Int,Int}
    lock::Function
    aggregates::Vector{AggregatedOptimalityCut{T}}

    function ClusterAggregation(rule::AbstractClusterRule, lock::Function, ::Type{T}) where T <: AbstractFloat
        C = typeof(rule)
        aggregates = [zero(AggregatedOptimalityCut{T}) for _ = 1:5]
        return new{T,C}(Vector{SparseOptimalityCut{T}}(), rule, Dict{Int,Int}(), lock, aggregates)
    end
end

function aggregate_cut!(lshaped::AbstractLShaped, ::ClusterAggregation, cut::HyperPlane)
    return add_cut!(lshaped, cut)
end

function aggregate_cut!(lshaped::AbstractLShaped, aggregation::ClusterAggregation{T}, cut::HyperPlane{OptimalityCut}) where T <: AbstractFloat
    if aggregation.lock(gap(lshaped), num_iterations(lshaped)) && haskey(aggregation.partitioning, cut.id)
        aggregation.aggregates[aggregation.partitioning[cut.id]] += cut
        return false
    end
    push!(aggregation.buffer, cut)
    return false
end

function aggregate_cut!(cutqueue::CutQueue, aggregation::ClusterAggregation, ::MetaData, t::Integer, cut::HyperPlane, x::AbstractArray)
    put!(cutqueue, (t, cut))
    return nothing
end

function aggregate_cut!(cutqueue::CutQueue, aggregation::ClusterAggregation{T}, metadata::MetaData, t::Integer, cut::HyperPlane{OptimalityCut}, x::AbstractArray) where T <: AbstractFloat
    gap = fetch(metadata, t, :gap)
    if aggregation.lock(gap, t) && haskey(aggregation.partitioning, cut.id)
        aggregation.aggregates[aggregation.partitioning[cut.id]] += cut
        return nothing
    end
    push!(aggregation.buffer, cut)
    return nothing
end

function num_thetas(num_subproblems::Integer, ::ClusterAggregation)
    return num_subproblems
end

function num_thetas(num_subproblems::Integer, ::ClusterAggregation, ::AbstractScenarioProblems)
    return num_subproblems
end

function flush!(lshaped::AbstractLShaped, aggregation::ClusterAggregation{T}) where T <: AbstractFloat
    added = false
    if aggregation.lock(gap(lshaped), num_iterations(lshaped)) && !isempty(aggregation.partitioning)
        for (idx,aggregate) in enumerate(aggregation.aggregates)
            if !iszero(aggregate)
                added |= add_cut!(lshaped, aggregate)
                aggregation.aggregates[idx] = zero(AggregatedOptimalityCut{T})
            end
        end
    else
        if isempty(aggregation.buffer)
            return false
        end
        aggregates = cluster(aggregation.rule, aggregation.buffer)
        for (idx, aggregate) in enumerate(aggregates)
            for id in aggregate.ids
                aggregation.partitioning[id] = idx
            end
            added |= add_cut!(lshaped, aggregate)
        end
        n = maximum(values(aggregation.partitioning))
        resize!(aggregation.aggregates, n)
        for i in 1:n
            aggregation.aggregates[i] = zero(AggregatedOptimalityCut{T})
        end
    end
    empty!(aggregation.buffer)
    return added
end

function flush!(cutqueue::CutQueue, aggregation::ClusterAggregation{T}, metadata::MetaData, t::Integer, x::AbstractArray) where T <: AbstractFloat
    gap = fetch(metadata, t, :gap)
    if aggregation.lock(gap, t) && !isempty(aggregation.partitioning)
        for (idx,aggregate) in enumerate(aggregation.aggregates)
            if !iszero(aggregate)
                put!(cutqueue, (t, aggregate))
                aggregation.aggregates[idx] = zero(AggregatedOptimalityCut{T})
            end
        end
    else
        if isempty(aggregation.buffer)
            return nothing
        end
        aggregates = cluster(aggregation.rule, aggregation.buffer)
        for (idx, aggregate) in enumerate(aggregates)
            for id in aggregate.ids
                aggregation.partitioning[id] = idx
            end
            put!(cutqueue, (t, aggregate))
        end
        n = maximum(values(aggregation.partitioning))
        resize!(aggregation.aggregates, n)
        for i in 1:n
            aggregation.aggregates[i] = zero(AggregatedOptimalityCut{T})
        end
    end
    empty!(aggregation.buffer)
    return nothing
end

# API
# ------------------------------------------------------------
"""
    ClusterAggregate(rule::AbstractClusterRule; lock_after::Function = (τ,n)->false)

Factory object for [`ClusterAggregation`](@ref). Pass to `aggregate ` in the `LShapedSolver` factory function. See ?ClusterAggregation for parameter descriptions.

"""
mutable struct ClusterAggregate <: AbstractAggregator
    rule::AbstractClusterRule
    lock::Function

    function ClusterAggregate(rule::AbstractClusterRule; lock_after = (τ,n) -> false)
        return new(rule, lock_after)
    end
end

struct ClusterRule <: AggregationParameter end

function MOI.get(aggregator::ClusterAggregate, ::ClusterRule)
    return aggregator.rule
end

function MOI.set(aggregator::ClusterAggregate, ::ClusterRule, rule::AbstractClusterRule)
    return aggregator.rule = rule
end

function (aggregator::ClusterAggregate)(num_subproblems::Integer, T::Type{<:AbstractFloat})
    return ClusterAggregation(aggregator.rule, aggregator.lock, T)
end

function remote_aggregator(aggregation::ClusterAggregation, ::AbstractScenarioProblems, ::Integer)
    return ClusterAggregate(aggregation.rule; lock_after = aggregation.lock)
end

function str(aggregator::ClusterAggregate)
    return "cluster aggregation ruled by $(str(aggregator.rule))"
end
