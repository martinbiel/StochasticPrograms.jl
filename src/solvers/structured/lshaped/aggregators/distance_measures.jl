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
    absolute_distance(c₁::AnyOptimalityCut, c₂::AnyOptimalityCut)

Absolute distance between two optimality cuts

"""
function absolute_distance(c₁::AnyOptimalityCut, c₂::AnyOptimalityCut)
    c̃₁ = vcat(c₁.δQ, c₁.q) ./ num_subproblems(c₁)
    c̃₂ = vcat(c₂.δQ, c₂.q) ./ num_subproblems(c₂)
    return norm(c̃₁-c̃₂) / max(norm(c̃₁), norm(c̃₂))
end
function absolute_distance(c₁::AnyOptimalityCut{T}, c₂::AggregatedOptimalityCut{T,ZeroVector{T}}) where T <: AbstractFloat
    return Inf
end
function absolute_distance(c₁::AggregatedOptimalityCut{T,ZeroVector{T}}, c₂::AnyOptimalityCut{T}) where T <: AbstractFloat
    return Inf
end

"""
    angular_distance(c₁::AnyOptimalityCut, c₂::AnyOptimalityCut)

Angular distance between two optimality cuts

"""
function angular_distance(c₁::AnyOptimalityCut, c₂::AnyOptimalityCut)
    return 1-abs(c₁.δQ ⋅ c₂.δQ) / (norm(c₁.δQ) * norm(c₂.δQ))
end
function angular_distance(c₁::AnyOptimalityCut{T}, c₂::AggregatedOptimalityCut{T,ZeroVector{T}}) where T <: AbstractFloat
    return Inf
end
function angular_distance(c₁::AggregatedOptimalityCut{T,ZeroVector{T}}, c₂::AnyOptimalityCut{T}) where T <: AbstractFloat
    return Inf
end

"""
    spatioangular_distance(c₁::AnyOptimalityCut, c₂::AnyOptimalityCut)

Spatioangular distance between two optimality cuts.

"""
function spatioangular_distance(c₁::AnyOptimalityCut, c₂::AnyOptimalityCut)
    return 1-abs(c₁.δQ ⋅ c₂.δQ) / (norm(c₁.δQ) * norm(c₂.δQ)) +
        (abs(c₁.q / num_subproblems(c₁) - c₂.q / num_subproblems(c₂)) /
        max(abs(c₁.q / num_subproblems(c₁)), abs(c₂.q / num_subproblems(c₂))))
end
function spatioangular_distance(c₁::AnyOptimalityCut{T}, c₂::AggregatedOptimalityCut{T,ZeroVector{T}}) where T <: AbstractFloat
    return Inf
end
function spatioangular_distance(c₁::AggregatedOptimalityCut{T,ZeroVector{T}}, c₂::AnyOptimalityCut{T}) where T <: AbstractFloat
    return Inf
end
