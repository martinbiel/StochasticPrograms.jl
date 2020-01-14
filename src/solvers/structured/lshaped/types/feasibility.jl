abstract type AbstractFeasibility end

struct IgnoreFeasibility <: AbstractFeasibility end

handle_feasibility(::IgnoreFeasibility) = false
initial_theta_coefficient(::IgnoreFeasibility) = 1.0
ncuts(::IgnoreFeasibility) = 0

struct HandleFeasibility{T <: AbstractFloat} <: AbstractFeasibility
    cuts::Vector{SparseFeasibilityCut{T}}

    function HandleFeasibility(::Type{T}) where T <: AbstractFloat
        return new{T}(Vector{SparseFeasibilityCut{T}}())
    end
end

handle_feasibility(::HandleFeasibility) = true
initial_theta_coefficient(::HandleFeasibility) = 0.0
ncuts(feasibility::HandleFeasibility) = length(feasibility.cuts)
