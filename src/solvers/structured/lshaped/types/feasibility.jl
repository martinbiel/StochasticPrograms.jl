abstract type AbstractFeasibility end
abstract type AbstractFeasibilityHandler end

struct IgnoreFeasibility <: AbstractFeasibility end

handle_feasibility(::IgnoreFeasibility) = false
num_cuts(::IgnoreFeasibility) = 0

struct HandleFeasibility{T <: AbstractFloat} <: AbstractFeasibility
    cuts::Vector{SparseFeasibilityCut{T}}

    function HandleFeasibility(::Type{T}) where T <: AbstractFloat
        return new{T}(Vector{SparseFeasibilityCut{T}}())
    end
end

handle_feasibility(::HandleFeasibility) = true
num_cuts(feasibility::HandleFeasibility) = length(feasibility.cuts)
