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
