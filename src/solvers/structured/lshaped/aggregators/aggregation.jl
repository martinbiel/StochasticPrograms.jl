# MIT License
#
# Copyright (c) 2018 Martin Biel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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
include("granulated_aggregation.jl")
include("hybrid_aggregation.jl")
