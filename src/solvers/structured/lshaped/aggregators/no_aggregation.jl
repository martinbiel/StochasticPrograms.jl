# No aggregation
# ------------------------------------------------------------
"""
    NoAggregation

Empty functor object for running an L-shaped algorithm without aggregation (multi-cut L-shaped).

"""
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
"""
    DontAggregate

Factory object for [`NoAggregation`](@ref). Passed by default to `aggregate` in the `LShapedSolver` factory function.

"""
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
