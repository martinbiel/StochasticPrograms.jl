abstract type ClusterRule end

struct StaticCluster <: ClusterRule
    clusters::Vector{Float64}

    function StaticCluster(clusters::Vector{Float64})
        sum(clusters) ≈ 1.0 || error("Static cluster")
        return new(clusters)
    end
end

function StaticCluster(frequencies::Vector{Int})
    return StaticCluster(frequencies ./ sum(frequencies))
end

function cluster(rule::StaticCluster, cuts::Vector{<:HyperPlane{OptimalityCut,T}}) where T <: AbstractFloat
    clusters::Vector{AggregatedOptimalityCut} = fill(zero(AggregatedOptimalityCut{T}), rule.clusters)
    i = 1
    for (j,n) in enumerate(round.(Int, rule.clusters * length(cuts)))
        for _ = 1:n
            clusters[j] += cuts[i]
            i += 1
            if i == length(cuts) + 1
                return clusters
            end
        end
    end
    return clusters
end

function str(::StaticCluster)
    return "static clustering"
end

struct ClusterByReference <: ClusterRule
    τ::Float64
    distance::Function
end

function ClusterByReference(τ::AbstractFloat; distance::Function = absolute_distance)
    return ClusterByReference(τ, distance)
end

function cluster(rule::ClusterByReference, cuts::Vector{<:HyperPlane{OptimalityCut,T}}) where T <: AbstractFloat
    clusters::Vector{AggregatedOptimalityCut} = fill(zero(AggregatedOptimalityCut{T}), length(cuts)+1)
    reference = zero(AggregatedOptimalityCut{T})
    for cut in cuts
        reference += cut
    end
    j = 2
    for cut in cuts
        if rule.distance(cut, reference) <= rule.τ
            # Cluster if distance to reference within tolerance
            clusters[1] += cut
        else
            # Multicut otherwise
            clusters[j] += cut
            j += 1
        end
    end
    return filter(c -> !iszero(c), clusters)
end

function str(::ClusterByReference)
    return "distance to reference based clustering"
end

struct Kmedoids <: ClusterRule
    nclusters::Int
    distance::Function
end

function Kmedoids(nclusters::Int; distance::Function = absolute_distance)
    return Kmedoids(nclusters, distance)
end

function cluster(rule::Kmedoids, cuts::Vector{<:HyperPlane{OptimalityCut,T}}) where T <: AbstractFloat
    clusters::Vector{AggregatedOptimalityCut} = fill(zero(AggregatedOptimalityCut{T}), rule.nclusters)
    if length(cuts) < rule.nclusters
        for (i,cut) in enumerate(cuts)
            clusters[i] += cut
        end
    else
        D = [rule.distance(c₁, c₂) for c₁ in cuts, c₂ in cuts]
        try
            kmeds = kmedoids(D, rule.nclusters)
            for (i, j) in enumerate(assignments(kmeds))
                clusters[j] += cuts[i]
            end
        catch
            # Fallback to even clustering
            (ncuts,extra) = divrem(length(cuts), length(clusters))
            extra > 0 && (ncuts += 1)
            i = 1
            for j in eachindex(clusters)
                for _ in 1:ncuts
                    clusters[j] += cuts[i]
                    i += 1
                    i == length(cuts)+1 && return filter(c -> !iszero(c), clusters)
                end
            end
        end
    end
    return filter(c -> !iszero(c), clusters)
end

function str(::Kmedoids)
    return "K-medoids clustering"
end

struct Hierarchical <: ClusterRule
    nclusters::Int
    distance::Function
    linkage::Symbol
end

function Hierarchical(nclusters::Int; distance::Function = absolute_distance, linkage::Symbol = :single)
    return Hierarchical(nclusters, distance, linkage)
end

function cluster(rule::Hierarchical, cuts::Vector{<:HyperPlane{OptimalityCut,T}}) where T <: AbstractFloat
    clusters::Vector{AggregatedOptimalityCut} = fill(zero(AggregatedOptimalityCut{T}), rule.nclusters)
    D = [rule.distance(c₁, c₂) for c₁ in cuts, c₂ in cuts]
    tree = hclust(D, linkage = rule.linkage)
    for (i, j) in enumerate(Clustering.cutree(tree; k = rule.nclusters))
        clusters[j] += cuts[i]
    end
    return filter(c -> !iszero(c), clusters)
end

function str(::Hierarchical)
    return "hierarchical clustering"
end
