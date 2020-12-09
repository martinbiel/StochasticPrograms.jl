"""
    GranulatedAggregation

Functor object for using partial aggregation in an L-shaped algorithm. Create by supplying a [`GranulatedAggregate`](@ref) object through `aggregate` in `LShaped.Optimizer` or by setting the [`Aggregator`](@ref) attribute.

...
# Parameters
- `size::Int`: Number of cuts in each aggregate
...
"""
struct GranulatedAggregation{T <: AbstractFloat, Agg <: AbstractAggregation} <: AbstractAggregation
    size::Int
    num_subproblems::Int
    start_id::Int
    collection::CutCollection{T}
    inner::Agg

    function GranulatedAggregation(size::Integer, start_id::Integer, num_subproblems::Integer, aggregator::AbstractAggregation, ::Type{T}) where T <: AbstractFloat
        Agg = typeof(aggregator)
        return new{T,Agg}(min(size, num_subproblems), num_subproblems, start_id, CutCollection(T, start_id), aggregator)
    end
end

function aggregate_cut!(lshaped::AbstractLShaped, aggregation::GranulatedAggregation, cut::HyperPlane)
    added = passthrough!(lshaped, aggregation, cut)
    add_to_collection!(aggregation.collection, cut, lshaped.x)
    if considered(aggregation.collection) == aggregation.size
        if collection_size(aggregation.collection) == aggregation.size
            granulated_cut = aggregate(aggregation.collection)
            added |= aggregate_cut!(lshaped, aggregation.inner, granulated_cut)
        end
        renew!(aggregation.collection, aggregation.collection.id % num_thetas(lshaped) + 1)
    end
    return added
end

function passthrough!(lshaped::AbstractLShaped, aggregation::GranulatedAggregation, cut::HyperPlane{H}) where H <: HyperPlaneType
    return add_cut!(lshaped, HyperPlane(cut.δQ, cut.q, aggregation.collection.id, H))
end

function passthrough!(lshaped::AbstractLShaped, aggregation::GranulatedAggregation, cut::HyperPlane{OptimalityCut})
    return false
end

function aggregate_cut!(cutqueue::CutQueue, aggregation::GranulatedAggregation, metadata::MetaData, t::Integer, cut::HyperPlane, x::AbstractArray)
    passthrough!(cutqueue, aggregation, cut, t, x)
    add_to_collection!(aggregation.collection, cut, x)
    if considered(aggregation.collection) == aggregation.size
        if collection_size(aggregation.collection) == aggregation.size
            granulated_cut = aggregate(aggregation.collection)
            aggregate_cut!(cutqueue, aggregation.inner, metadata, t, granulated_cut, x)
        end
        new_id = aggregation.start_id + (aggregation.collection.id - aggregation.start_id + 1) % ceil(Int, aggregation.num_subproblems/aggregation.size)
        renew!(aggregation.collection, new_id)
    end
    return nothing
end

function passthrough!(cutqueue::CutQueue, aggregation::GranulatedAggregation, cut::HyperPlane{H}, t::Integer, x::AbstractVector) where H <: HyperPlaneType
    put!(cutqueue, (t, HyperPlane(cut.δQ, cut.q, aggregation.collection.id, H)))
    return nothing
end

function passthrough!(::CutQueue, ::GranulatedAggregation, ::HyperPlane{OptimalityCut}, ::Integer, ::AbstractVector)
    return nothing
end

function num_thetas(num_subproblems::Integer, aggregation::GranulatedAggregation)
    return ceil(Int, num_subproblems / aggregation.size)
end

function num_thetas(num_subproblems::Integer, aggregation::GranulatedAggregation, sp::StochasticPrograms.ScenarioProblems)
    jobsize = ceil(Int, num_subproblems / nworkers())
    n = ceil(Int, jobsize/aggregation.size)
    remainder = num_subproblems - (nworkers() - 1) * jobsize
    aggregationem = ceil(Int, remainder/aggregation.size)
    return n * (nworkers() - 1) + aggregationem
end

function num_thetas(::Integer, aggregation::GranulatedAggregation, sp::DistributedScenarioProblems)
    return sum([ceil(Int, nscen/aggregation.size) for nscen in sp.scenario_distribution])
end

function flush!(lshaped::AbstractLShaped, aggregation::GranulatedAggregation)
    added = false
    if collection_size(aggregation.collection) > 0 && collection_size(aggregation.collection) == considered(aggregation.collection)
        granulated_cut = aggregate(aggregation.collection)
        added |= aggregate_cut!(lshaped, aggregation.inner, granulated_cut)
    end
    renew!(aggregation.collection, aggregation.start_id)
    added |= flush!(lshaped, aggregation.inner)
    return added
end

function flush!(cutqueue::CutQueue, aggregation::GranulatedAggregation, metadata::MetaData, t::Integer, x::AbstractArray)
    if collection_size(aggregation.collection) > 0 && collection_size(aggregation.collection) == considered(aggregation.collection)
        granulated_cut = aggregate(aggregation.collection)
        aggregate_cut!(cutqueue, aggregation.inner, metadata, t, granulated_cut, x)
    end
    renew!(aggregation.collection, aggregation.start_id)
    flush!(cutqueue, aggregation.inner, metadata, t, x)
    return nothing
end

# API
# ------------------------------------------------------------
"""
    GranulatedAggregate

Factory object for [`GranulatedAggregation`](@ref). Pass to `aggregate` in `LShaped.Optimizer` or by setting the [`Aggregator`](@ref) attribute.  See ?GranulatedAggregation for parameter descriptions.

"""
mutable struct GranulatedAggregate <: AbstractAggregator
    size::Int
    start_id::Int
    inner::AbstractAggregator

    function GranulatedAggregate(size::Integer, aggregator::AbstractAggregator)
        return new(size, 1, aggregator)
    end

    function GranulatedAggregate(size::Integer, start_id::Int, aggregator::AbstractAggregator)
        return new(size, start_id, aggregator)
    end
end

function (aggregator::GranulatedAggregate)(num_subproblems::Integer, ::Type{T}) where T <: AbstractFloat
    aggregator.size == 1 && return NoAggregation()
    aggregator.size == num_subproblems && return FullAggregation(1, num_subproblems, T)
    inner = aggregator.inner(num_subproblems, T)
    return GranulatedAggregation(aggregator.size, aggregator.start_id, num_subproblems, inner, T)
end

function remote_aggregator(aggregation::GranulatedAggregation, sp::ScenarioProblems, w::Integer)
    (nscen, extra) = divrem(num_subproblems(sp), nworkers())
    prev = map(2:(w - 1)) do p
        jobsize = nscen + (extra + 2 - p > 0)
        ceil(Int, jobsize / aggregation.size)
    end
    start_id = isempty(prev) ? 1 : sum(prev) + 1
    return GranulatedAggregate(aggregation.size, start_id, remote_aggregator(aggregation.inner, sp, w))
end

function remote_aggregator(aggregation::GranulatedAggregation, sp::DistributedScenarioProblems, w::Integer)
    prev = map(2:(w - 1)) do p
        ceil(Int, sp.scenario_distribution[p-1] / aggregation.size)
    end
    start_id = isempty(prev) ? 1 : sum(prev) + 1
    nscen = sp.scenario_distribution[w-1]
    return GranulatedAggregate(aggregation.size, start_id, remote_aggregator(aggregation.inner, sp, w))
end

function str(aggregator::GranulatedAggregate)
    return "Granulated cut aggregation of size $(aggregator.size) with inner aggregator: $(str(aggregator.inner))"
end
