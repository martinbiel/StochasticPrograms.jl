struct DynamicAggregation{T <: AbstractFloat, S <: SelectionRule} <: AbstractAggregation
    aggregates::Vector{AggregatedOptimalityCut{T}}
    rule::S
    partitioning::Dict{Int,Int}
    lock::Function

    function DynamicAggregation(naggregates::Integer, rule::SelectionRule, lock::Function, ::Type{T}) where T <: AbstractFloat
        S = typeof(rule)
        aggregates = [zero(AggregatedOptimalityCut{T}) for _ = 1:naggregates]
        return new{T,S}(aggregates, rule, Dict{Int,Int}(), lock)
    end
end

function aggregate_cut!(lshaped::AbstractLShapedSolver, ::DynamicAggregation, cut::HyperPlane)
    return add_cut!(lshaped, cut)
end

function aggregate_cut!(lshaped::AbstractLShapedSolver, aggregation::DynamicAggregation{T}, cut::HyperPlane{OptimalityCut}) where T <: AbstractFloat
    if aggregation.lock(gap(lshaped),niterations(lshaped)) && haskey(aggregation.partitioning, cut.id)
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
    put!(cutqueue, (t, cut(x), cut))
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
        put!(cutqueue, (t, aggregate(x), aggregate))
        aggregation.aggregates[idx] = zero(AggregatedOptimalityCut{T})
    end
    return nothing
end

function nthetas(nscenarios::Integer, ::DynamicAggregation)
    return nscenarios
end

function nthetas(nscenarios::Integer, ::DynamicAggregation, ::AbstractScenarioProblems)
    return nscenarios
end

function flush!(lshaped::AbstractLShapedSolver, aggregation::DynamicAggregation{T}) where T <: AbstractFloat
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
            put!(cutqueue, (t, aggregate(x), aggregate))
            aggregation.aggregates[i] = zero(AggregatedOptimalityCut{T})
        end
    end
    reset!(aggregation.rule)
    return nothing
end

# API
# ------------------------------------------------------------
struct DynamicAggregate{S <: SelectionRule} <: AbstractAggregator
    naggregates::Int
    rule::S
    lock::Function

    function DynamicAggregate(naggregates::Integer, rule::SelectionRule; lock_after = (τ,n)->false)
        S = typeof(rule)
        return new{S}(naggregates, rule, lock_after)
    end
end

function (aggregator::DynamicAggregate)(nscenarios::Integer, T::Type{<:AbstractFloat})
    if aggregator.rule isa SelectRandom && aggregator.rule.max == 1
        return NoAggregation()
    end
    return DynamicAggregation(aggregator.naggregates, aggregator.rule, aggregator.lock, T)
end

function remote_aggregator(aggregation::DynamicAggregation, ::AbstractScenarioProblems, ::Integer)
    return DynamicAggregate(length(aggregation.aggregates), aggregation.rule; lock_after = aggregation.lock)
end

function str(aggregator::DynamicAggregate)
    return "dynamic aggregation ruled by $(str(aggregator.rule))"
end
