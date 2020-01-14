@enum Active Initial Final

mutable struct ActiveAggregation
    active::Active

    function ActiveAggregation()
        return new(Initial)
    end
end

function shift(gap::AbstractFloat, τ::AbstractFloat)
    return gap <= τ
end

struct HybridAggregation{T <: AbstractFloat, Agg1 <: AbstractAggregation, Agg2 <: AbstractAggregation} <: AbstractAggregation
    initial::Agg1
    final::Agg2
    τ::T
    active::ActiveAggregation

    function HybridAggregation(initial::AbstractAggregation, final::AbstractAggregation, τ::AbstractFloat)
        Agg1 = typeof(initial)
        Agg2 = typeof(final)
        T = typeof(τ)
        return new{T,Agg1,Agg2}(initial, final, τ, ActiveAggregation())
    end
end

function active(aggregation::HybridAggregation)
    if aggregation.active.active == Initial
        return aggregation.initial
    end
    return aggregation.final
end

function activate_final!(aggregation::HybridAggregation)
    aggregation.active.active = Final
    return nothing
end

function aggregate_cut!(lshaped::AbstractLShapedSolver, aggregation::HybridAggregation, cut::HyperPlane)
    return aggregate_cut!(lshaped, active(aggregation), cut)
end

function aggregate_cut!(cutqueue::CutQueue, aggregation::HybridAggregation, metadata::MetaData, t::Integer, cut::HyperPlane, x::AbstractArray)
    return aggregate_cut!(cutqueue, active(aggregation), metadata, t, cut, x)
end

function nthetas(nscenarios::Integer, aggregation::HybridAggregation)
    return nthetas(nscenarios, active(aggregation))
end

function nthetas(nscenarios::Integer, aggregation::HybridAggregation, sp::DScenarioProblems)
    return nthetas(nscenarios, active(aggregation), sp)
end

function flush!(lshaped::AbstractLShapedSolver, aggregation::HybridAggregation)
    added = flush!(lshaped, active(aggregation))
    if shift(gap(lshaped), aggregation.τ)
        activate_final!(aggregation)
    end
    return added
end

function flush!(cutqueue::CutQueue, aggregation::HybridAggregation, metadata::MetaData, t::Integer, x::AbstractArray) where T <: AbstractFloat
    flush!(cutqueue, active(aggregation), metadata, t, x)
    if shift(fetch(metadata, t, :gap), aggregation.τ)
        activate_final!(aggregation)
    end
    return nothing
end

# API
# ------------------------------------------------------------
struct HybridAggregate{T <: AbstractFloat, Agg1 <: AbstractAggregator, Agg2 <: AbstractAggregator} <: AbstractAggregator
    initial::Agg1
    final::Agg2
    τ::T

    function HybridAggregate(initial::AbstractAggregator, final::AbstractAggregator, τ::AbstractFloat)
        Agg1 = typeof(initial)
        Agg2 = typeof(final)
        T = typeof(τ)
        return new{T,Agg1,Agg2}(initial, final, τ)
    end
end

function (aggregator::HybridAggregate)(nscenarios::Integer, T::Type{<:AbstractFloat})
    initial = aggregator.initial(nscenarios, T)
    final = aggregator.final(nscenarios, T)
    n₁ = nthetas(nscenarios, initial)
    n₂ = nthetas(nscenarios, final)
    n₁ == n₂|| error("Inconsistent number of theta variables in hybrid aggregation: $n₁ ≠ $n₂")
    return HybridAggregation(initial, final, convert(T, aggregator.τ))
end

function remote_aggregator(aggregation::HybridAggregation, sp::AbstractScenarioProblems, w::Integer)
    return HybridAggregate(remote_aggregator(aggregation.initial, sp, w),
                           remote_aggregator(aggregation.final, sp, w),
                           aggregation.τ)
end

function str(aggregator::HybridAggregate)
    return "hybrid aggregation consisting of $(str(aggregator.initial)) and $(str(aggregator.final))"
end
