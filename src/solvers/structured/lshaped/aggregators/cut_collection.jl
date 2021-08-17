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

mutable struct CutCollection{T <: AbstractFloat}
    cuts::Vector{SparseOptimalityCut{T}}
    q::T
    considered::Int
    id::Int

    function CutCollection(::Type{T}, id::Integer = 1) where T <: AbstractFloat
        new{T}(Vector{SparseOptimalityCut{T}}(), zero(T), 0, id)
    end
end

collection_size(collection::CutCollection) = length(collection.cuts)
considered(collection::CutCollection) = collection.considered

function aggregate(collection::CutCollection)
    return aggregate(collection.cuts, collection.id)
end

function renew!(collection::CutCollection{T}, id::Integer) where T <: AbstractFloat
    empty!(collection.cuts)
    collection.q = zero(T)
    collection.considered = 0
    collection.id = id
    return nothing
end

function add_to_collection!(collection::CutCollection, cut::HyperPlane, x::AbstractVector)
    collection.considered += 1
    return nothing
end

function add_to_collection!(collection::CutCollection, cut::HyperPlane{OptimalityCut}, x::AbstractVector)
    push!(collection.cuts, cut)
    collection.q += cut(x)
    collection.considered += 1
    return nothing
end
