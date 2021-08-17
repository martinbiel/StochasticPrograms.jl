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

# FixedPenalization penalty
# ------------------------------------------------------------
"""
    FixedPenalization

Functor object for using fixed penalty in a progressive-hedging algorithm. Create by supplying a [`Fixed`](@ref) object through `penalty` in the `ProgressiveHedgingSolver` factory function and then pass to a `StochasticPrograms.jl` model.

...
# Parameters
- `r::T = 1.00`: Fixed penalty
...
"""
mutable struct FixedPenalization{T <: AbstractFloat} <: AbstractPenalization
    r::T

    function FixedPenalization(r::AbstractFloat)
        T = typeof(r)
        return new{T}(r)
    end
end
function penalty(::AbstractProgressiveHedging, penalty::FixedPenalization)
    return penalty.r
end
function initialize_penalty!(::AbstractProgressiveHedging, ::FixedPenalization)
    nothing
end
function update_penalty!(::AbstractProgressiveHedging, ::FixedPenalization)
    nothing
end

# API
# ------------------------------------------------------------
"""
    Fixed

Factory object for [`FixedPenalization`](@ref). Pass to `penalty` in the `ProgressiveHedgingSolver` factory function. See ?FixedPenalization for parameter descriptions.

"""
struct Fixed{T <: AbstractFloat} <: AbstractPenalizer
    r::T

    function Fixed(; r::AbstractFloat = 1.0)
        T = typeof(r)
        return new{T}(r)
    end
end

function (fixed::Fixed)()
    return FixedPenalization(fixed.r)
end

function str(::Fixed)
    return "fixed penalty"
end
