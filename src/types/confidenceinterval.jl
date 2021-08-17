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

"""
    ConfidenceInterval

An estimated interval around an unknown quantity at a given confidence level
"""
struct ConfidenceInterval{T <: AbstractFloat}
    lower::T
    upper::T
    confidence::T

    function ConfidenceInterval(lower::AbstractFloat, upper::AbstractFloat, confidence::AbstractFloat)
        T = promote_type(typeof(lower), typeof(upper), typeof(confidence), Float32)
        lower <= upper || error("Inconsistent confidence interval: $lower ≰ $upper")
        return new{T}(lower, upper, confidence)
    end
end
lower(interval::ConfidenceInterval) = interval.lower
upper(interval::ConfidenceInterval) = interval.upper
confidence(interval::ConfidenceInterval) = interval.confidence
length(interval::ConfidenceInterval) = upper(interval) - lower(interval)
function in(x::T, interval::ConfidenceInterval) where T <: Real
    isinf(x) && return false
    return interval.lower <= x <= interval.upper
end
function issubset(a::ConfidenceInterval, b::ConfidenceInterval)
    return a.lower >= b.lower && a.upper <= b.upper
end
function show(io::IO, interval::ConfidenceInterval)
    intervalstr = @sprintf "Confidence interval (p = %.0f%%): [%.2f − %.2f]" 100*interval.confidence interval.lower interval.upper
    print(io, intervalstr)
    return io
end
