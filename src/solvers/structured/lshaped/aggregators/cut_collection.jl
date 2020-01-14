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
