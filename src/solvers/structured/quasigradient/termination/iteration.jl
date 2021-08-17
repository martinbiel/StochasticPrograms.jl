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

@with_kw mutable struct MaximumIterationParameters
    maximum::Int = 1000
end

"""
    MaximumIterations

Functor object for using maximum number of iterations as termination criterion in a quasigradient algorithm. Create by supplying a [`AfterMaximumIterations`](@ref) object through `terminate` to `QuasiGradient.Optimizer` or by setting the [`Termination`](@ref) attribute.

...
# Parameters
- `maximum::Integer = 1000`: Maximum number of iterations
...
"""
struct MaximumIterations <: AbstractTerminationCriterion
    parameters::MaximumIterationParameters

    function MaximumIterations(; kw...)
        return new(MaximumIterationParameters(; kw...))
    end
end

function Progress(termination::MaximumIterations, str::AbstractString)
    return Progress(termination.parameters.maximum, 0.0, str)
end

function progress_value(::MaximumIterations, k::Integer, f::AbstractFloat, ∇f_norm::AbstractFloat)
    return k
end

function terminate(termination::MaximumIterations, k::Integer, f::Float64, x::AbstractVector, ∇f::AbstractVector)
    return k >= termination.parameters.maximum
end

# API
# ------------------------------------------------------------
"""
    AfterMaximumIterations

Factory object for [`MaximumIterations`](@ref). Pass to `terminate` in `Quasigradient.Optimizer` or set the [`Termination`](@ref) attribute. See ?MaximumIterations for parameter descriptions.

"""
struct AfterMaximumIterations <: AbstractTermination
    parameters::MaximumIterationParameters
end
AfterMaximumIterations(maximum::Integer) = AfterMaximumIterations(MaximumIterationParameters(; maximum = maximum))
AfterMaximumIterations(; kw...) = AfterMaximumIterations(MaximumIterationParameters(; kw...))

function (criteria::AfterMaximumIterations)(::Type{T}) where T <: AbstractFloat
    return MaximumIterations(; type2dict(criteria.parameters)...)
end
