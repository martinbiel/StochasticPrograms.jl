# No aggregation
# ------------------------------------------------------------
struct NoAggregation <: AbstractAggregation end

function aggregate_cut!(lshaped::AbstractLShapedSolver, ::NoAggregation, cut::HyperPlane)
    return add_cut!(lshaped, cut)
end

function aggregate_cut!(cutqueue::CutQueue, ::NoAggregation, ::MetaData, t::Integer, cut::HyperPlane, x::AbstractArray)
    put!(cutqueue, (t, cut(x), cut))
    return nothing
end

function nthetas(nscenarios::Integer, ::NoAggregation)
    return nscenarios
end

function nthetas(nscenarios::Integer, ::NoAggregation, ::AbstractScenarioProblems)
    return nscenarios
end

function flush!(::AbstractLShapedSolver, ::NoAggregation)
    return false
end

function flush!(::CutQueue, ::NoAggregation, ::MetaData, ::Integer, ::AbstractArray)
    return false
end

# API
# ------------------------------------------------------------
struct DontAggregate <: AbstractAggregator end

function (::DontAggregate)(::Integer, ::Type{<:AbstractFloat})
    return NoAggregation()
end

function remote_aggregator(::NoAggregation, ::AbstractScenarioProblems, ::Integer)
    return DontAggregate()
end

function str(::DontAggregate)
    return "disaggregate cuts"
end
