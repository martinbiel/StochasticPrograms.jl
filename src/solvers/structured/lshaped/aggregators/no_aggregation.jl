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

# No aggregation
# ------------------------------------------------------------
"""
    NoAggregation

Empty functor object for running an L-shaped algorithm without aggregation (multi-cut L-shaped).

"""
struct NoAggregation <: AbstractAggregation end

function aggregate_cut!(lshaped::AbstractLShaped, ::NoAggregation, cut::HyperPlane)
    return add_cut!(lshaped, cut)
end

function aggregate_cut!(cutqueue::CutQueue, ::NoAggregation, ::MetaDataChannel, t::Integer, cut::HyperPlane, x::AbstractArray)
    put!(cutqueue, (t, cut))
    return nothing
end

function num_thetas(num_subproblems::Integer, ::NoAggregation)
    return num_subproblems
end

function num_thetas(num_subproblems::Integer, ::NoAggregation, ::AbstractScenarioProblems)
    return num_subproblems
end

function flush!(::AbstractLShaped, ::NoAggregation)
    return false
end

function flush!(::CutQueue, ::NoAggregation, ::MetaDataChannel, ::Integer, ::AbstractArray)
    return false
end

# API
# ------------------------------------------------------------
"""
    DontAggregate

Factory object for [`NoAggregation`](@ref). Passed by default to `aggregate` in `LShaped.Optimizer`.

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
