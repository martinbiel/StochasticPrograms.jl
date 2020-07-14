abstract type AbstractAggregation end
abstract type AbstractAggregator end
"""
    RawAggregationParameter

An optimizer attribute used for raw parameters of the aggregator. Defers to `RawParameter`.
"""
struct RawAggregationParameter <: AggregationParameter
    name::Any
end

function MOI.get(aggregator::AbstractAggregator, param::RawAggregationParameter)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(aggregator)))
        error("Unrecognized parameter name: $(name) for aggregator $(typeof(aggregator)).")
    end
    return getfield(aggregator, name)
end

function MOI.set(aggregator::AbstractAggregator, param::RawAggregationParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(aggregator)))
        error("Unrecognized parameter name: $(name) for aggregator $(typeof(aggregator)).")
    end
    setfield!(aggregator, name, value)
    return nothing
end

# ------------------------------------------------------------
include("cut_collection.jl")
include("distance_measures.jl")
include("selection_rules.jl")
include("cluster_rules.jl")
include("lock_rules.jl")
include("no_aggregation.jl")
include("partial_aggregation.jl")
include("dynamic_aggregation.jl")
include("cluster_aggregation.jl")
include("hybrid_aggregation.jl")
