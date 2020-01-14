struct PartialAggregation{T <: AbstractFloat} <: AbstractAggregation
    size::Int
    nscenarios::Int
    start_id::Int
    collection::CutCollection{T}

    function PartialAggregation(size::Integer, start_id::Integer, nscenarios::Integer, ::Type{T}) where T <: AbstractFloat
        return new{T}(min(size, nscenarios), nscenarios, start_id, CutCollection(T, start_id))
    end
end
FullAggregation(start_id::Integer, nscenarios::Integer, ::Type{T}) where T <: AbstractFloat = PartialAggregation(nscenarios, start_id, nscenarios, T)

function aggregate_cut!(lshaped::AbstractLShapedSolver, aggregation::PartialAggregation, cut::HyperPlane)
    if passthrough!(lshaped, aggregation, cut)
        return true
    end
    added = false
    add_to_collection!(aggregation.collection, cut, lshaped.x)
    if considered(aggregation.collection) == aggregation.size
        if collection_size(aggregation.collection) == aggregation.size
            aggregated_cut = aggregate(aggregation.collection)
            added |= add_cut!(lshaped, aggregated_cut)
        end
        renew!(aggregation.collection, aggregation.collection.id % nthetas(lshaped) + 1)
    end
    return added
end

function passthrough!(lshaped::AbstractLShapedSolver, aggregation::PartialAggregation, cut::HyperPlane{H}) where H <: HyperPlaneType
    return add_cut!(lshaped, HyperPlane(cut.δQ, cut.q, aggregation.collection.id, H))
end

function passthrough!(lshaped::AbstractLShapedSolver, aggregation::PartialAggregation, cut::HyperPlane{OptimalityCut})
    return false
end

function aggregate_cut!(cutqueue::CutQueue, aggregation::PartialAggregation, ::MetaData, t::Integer, cut::HyperPlane, x::AbstractArray)
    passthrough!(cutqueue, aggregation, cut, t, x)
    add_to_collection!(aggregation.collection, cut, x)
    if considered(aggregation.collection) == aggregation.size
        if collection_size(aggregation.collection) == aggregation.size
            aggregated_cut = aggregate(aggregation.collection)
            put!(cutqueue, (t, aggregated_cut(x), aggregated_cut))
        end
        new_id = aggregation.start_id + (aggregation.collection.id - aggregation.start_id + 1) % ceil(Int, aggregation.nscenarios/aggregation.size)
        renew!(aggregation.collection, new_id)
    end
    return nothing
end

function passthrough!(cutqueue::CutQueue, aggregation::PartialAggregation, cut::HyperPlane{H}, t::Integer, x::AbstractVector) where H <: HyperPlaneType
    put!(cutqueue, (t, cut(x), HyperPlane(cut.δQ, cut.q, aggregation.collection.id, H)))
    return nothing
end

function passthrough!(::CutQueue, ::PartialAggregation, ::HyperPlane{OptimalityCut}, ::Integer, ::AbstractVector)
    return nothing
end

function nthetas(nscenarios::Integer, aggregation::PartialAggregation)
    return ceil(Int, nscenarios/aggregation.size)
end

function nthetas(nscenarios::Integer, aggregation::PartialAggregation, sp::StochasticPrograms.ScenarioProblems)
    jobsize = ceil(Int, nscenarios/nworkers())
    n = ceil(Int, jobsize/aggregation.size)
    remainder = nscenarios-(nworkers()-1)*jobsize
    aggregationem = ceil(Int, remainder/aggregation.size)
    return n*(nworkers()-1)+aggregationem
end

function nthetas(::Integer, aggregation::PartialAggregation, sp::DScenarioProblems)
    return sum([ceil(Int, nscen/aggregation.size) for nscen in sp.scenario_distribution])
end

function flush!(lshaped::AbstractLShapedSolver, aggregation::PartialAggregation)
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
        put!(cutqueue, (t, aggregated_cut(x), aggregated_cut))
    end
    renew!(aggregation.collection, aggregation.start_id)
    return nothing
end

# API
# ------------------------------------------------------------
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

function (aggregator::PartialAggregate)(nscenarios::Integer, ::Type{T}) where T <: AbstractFloat
    aggregator.size == 1 && return NoAggregation()
    aggregator.size == nscenarios && return FullAggregation(1, nscenarios, T)
    return PartialAggregation(aggregator.size, aggregator.start_id, nscenarios, T)
end

function remote_aggregator(aggregation::PartialAggregation, sp::ScenarioProblems, w::Integer)
    (nscen, extra) = divrem(StochasticPrograms.nscenarios(sp), nworkers())
    prev = [begin
            jobsize = nscen + (extra + 2 - p > 0)
            ceil(Int, jobsize/aggregation.size)
            end for p in 2:(w-1)]
    start_id = isempty(prev) ? 1 : sum(prev) + 1
    return PartialAggregate(aggregation.size, start_id)
end

function remote_aggregator(aggregation::PartialAggregation, sp::DScenarioProblems, w::Integer)
    prev = [ceil(Int,sp.scenario_distribution[p-1]/aggregation.size) for p in 2:(w-1)]
    start_id = isempty(prev) ? 1 : sum(prev) + 1
    nscen = sp.scenario_distribution[w-1]
    return PartialAggregate(aggregation.size, start_id)
end

function str(aggregator::PartialAggregate)
    return "partial cut aggregation of size $(aggregator.size)"
end

struct Aggregate <: AbstractAggregator end

function (::Aggregate)(nscenarios::Integer, ::Type{T}) where T
    return FullAggregation(1, nscenarios, T)
end

function str(::Aggregate)
    return "full cut aggregation"
end
