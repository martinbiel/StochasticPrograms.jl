"""
    PartialAggregation

Functor object for using partial aggregation in an L-shaped algorithm. Create by supplying a [`PartialAggregate`](@ref) object through `aggregate ` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

...
# Parameters
- `size::Int`: Number of cuts in each aggregate
...
"""
struct PartialAggregation{T <: AbstractFloat} <: AbstractAggregation
    size::Int
    num_subproblems::Int
    start_id::Int
    collection::CutCollection{T}

    function PartialAggregation(size::Integer, start_id::Integer, num_subproblems::Integer, ::Type{T}) where T <: AbstractFloat
        return new{T}(min(size, num_subproblems), num_subproblems, start_id, CutCollection(T, start_id))
    end
end
"""
    FullAggregation

Functor object for using complete aggregation in an L-shaped algorithm. Create by supplying an [`Aggregate`](@ref) object through `aggregate ` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

"""
FullAggregation(start_id::Integer, num_subproblems::Integer, ::Type{T}) where T <: AbstractFloat = PartialAggregation(num_subproblems, start_id, num_subproblems, T)

function aggregate_cut!(lshaped::AbstractLShaped, aggregation::PartialAggregation, cut::HyperPlane)
    added = passthrough!(lshaped, aggregation, cut)
    add_to_collection!(aggregation.collection, cut, lshaped.x)
    if considered(aggregation.collection) == aggregation.size
        if collection_size(aggregation.collection) == aggregation.size
            aggregated_cut = aggregate(aggregation.collection)
            added |= add_cut!(lshaped, aggregated_cut)
        end
        renew!(aggregation.collection, aggregation.collection.id % num_thetas(lshaped) + 1)
    end
    return added
end

function passthrough!(lshaped::AbstractLShaped, aggregation::PartialAggregation, cut::HyperPlane{H}) where H <: HyperPlaneType
    return add_cut!(lshaped, HyperPlane(cut.δQ, cut.q, aggregation.collection.id, H))
end

function passthrough!(lshaped::AbstractLShaped, aggregation::PartialAggregation, cut::HyperPlane{OptimalityCut})
    return false
end

function aggregate_cut!(cutqueue::CutQueue, aggregation::PartialAggregation, ::MetaData, t::Integer, cut::HyperPlane, x::AbstractArray)
    passthrough!(cutqueue, aggregation, cut, t, x)
    add_to_collection!(aggregation.collection, cut, x)
    if considered(aggregation.collection) == aggregation.size
        if collection_size(aggregation.collection) == aggregation.size
            aggregated_cut = aggregate(aggregation.collection)
            put!(cutqueue, (t, aggregated_cut))
        end
        new_id = aggregation.start_id + (aggregation.collection.id - aggregation.start_id + 1) % ceil(Int, aggregation.num_subproblems/aggregation.size)
        renew!(aggregation.collection, new_id)
    end
    return nothing
end

function passthrough!(cutqueue::CutQueue, aggregation::PartialAggregation, cut::HyperPlane{H}, t::Integer, x::AbstractVector) where H <: HyperPlaneType
    put!(cutqueue, (t, HyperPlane(cut.δQ, cut.q, aggregation.collection.id, H)))
    return nothing
end

function passthrough!(::CutQueue, ::PartialAggregation, ::HyperPlane{OptimalityCut}, ::Integer, ::AbstractVector)
    return nothing
end

function num_thetas(num_subproblems::Integer, aggregation::PartialAggregation)
    return ceil(Int, num_subproblems / aggregation.size)
end

function num_thetas(num_subproblems::Integer, aggregation::PartialAggregation, sp::StochasticPrograms.ScenarioProblems)
    jobsize = ceil(Int, num_subproblems / nworkers())
    n = ceil(Int, jobsize/aggregation.size)
    remainder = num_subproblems - (nworkers() - 1) * jobsize
    aggregationem = ceil(Int, remainder/aggregation.size)
    return n * (nworkers() - 1) + aggregationem
end

function nthetas(::Integer, aggregation::PartialAggregation, sp::DistributedScenarioProblems)
    return sum([ceil(Int, nscen/aggregation.size) for nscen in sp.scenario_distribution])
end

function flush!(lshaped::AbstractLShaped, aggregation::PartialAggregation)
    added = false
    if collection_size(aggregation.collection) > 0 && collection_size(aggregation.collection) == considered(aggregation.collection)
        aggregated_cut = aggregate(aggregation.collection)
        added |= add_cut!(lshaped, aggregated_cut)
    end
    renew!(aggregation.collection, aggregation.start_id)
    return added
end

function flush!(cutqueue::CutQueue, aggregation::PartialAggregation, ::MetaData, t::Integer, x::AbstractArray)
    if collection_size(aggregation.collection) > 0 && collection_size(aggregation.collection) == considered(aggregation.collection)
        aggregated_cut = aggregate(aggregation.collection)
        put!(cutqueue, (t, aggregated_cut))
    end
    renew!(aggregation.collection, aggregation.start_id)
    return nothing
end

# API
# ------------------------------------------------------------
"""
    PartialAggregate

Factory object for [`PartialAggregation`](@ref). Pass to `aggregate` in the `LShapedSolver` factory function.  See ?PartialAggregation for parameter descriptions.

"""
struct PartialAggregate <: AbstractAggregator
    size::Int
    start_id::Int

    function PartialAggregate(size::Integer)
        return new(size, 1)
    end

    function PartialAggregate(size::Integer, start_id::Int)
        return new(size, start_id)
    end
end

function (aggregator::PartialAggregate)(num_subproblems::Integer, ::Type{T}) where T <: AbstractFloat
    aggregator.size == 1 && return NoAggregation()
    aggregator.size == num_subproblems && return FullAggregation(1, num_subproblems, T)
    return PartialAggregation(aggregator.size, aggregator.start_id, num_subproblems, T)
end

function remote_aggregator(aggregation::PartialAggregation, sp::ScenarioProblems, w::Integer)
    (nscen, extra) = divrem(num_subproblems(sp), nworkers())
    prev = map(2:(w - 1)) do p
        jobsize = nscen + (extra + 2 - p > 0)
        ceil(Int, jobsize / aggregation.size)
    end
    start_id = isempty(prev) ? 1 : sum(prev) + 1
    return PartialAggregate(aggregation.size, start_id)
end

function remote_aggregator(aggregation::PartialAggregation, sp::DistributedScenarioProblems, w::Integer)
    prev = map(2:(w - 1)) do p
        ceil(Int, sp.scenario_distribution[p-1] / aggregation.size)
    end
    start_id = isempty(prev) ? 1 : sum(prev) + 1
    nscen = sp.scenario_distribution[w-1]
    return PartialAggregate(aggregation.size, start_id)
end

function str(aggregator::PartialAggregate)
    return "partial cut aggregation of size $(aggregator.size)"
end

"""
    Aggregate

Factory object for [`FullAggregation`](@ref). Pass to `aggregate` in the `LShapedSolver` factory function.

"""
struct Aggregate <: AbstractAggregator end

function (::Aggregate)(num_subproblems::Integer, ::Type{T}) where T
    return FullAggregation(1, num_subproblems, T)
end

function str(::Aggregate)
    return "full cut aggregation"
end
