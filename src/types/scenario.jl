abstract type AbstractScenarioData end

probability(scenario::AbstractScenarioData)::Float64 = scenario.π
probability(scenarios::Vector{<:AbstractScenarioData}) = sum(probability.(scenarios))

function set_probability!(scenario::AbstractScenarioData, π::AbstractFloat)
    scenario.π.π = π
end

function expected(::Vector{SD}) where SD <: AbstractScenarioData
    error("Expected value operation not implemented for scenariodata type: ", SD)
end
