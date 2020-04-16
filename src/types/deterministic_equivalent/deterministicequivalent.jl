struct DeterministicEquivalent{N, M, T <: AbstractFloat, S <: NTuple{M, Scenarios}} <: AbstractStochasticStructure{N, T}
    decision_variables::NTuple{N, DecisionVariables{T}}
    scenarios::S
    model::JuMP.Model

    function DeterministicEquivalent(decision_variables::DecisionVariables{T}, ::Type{S}) where {T <: AbstractFloat, S <: AbstractScenario}
        scenarios = (Vector{S}(),)
        return new{2,1,T,typeof(scenarios)}(decision_variables, scenarios, Model())
    end
end

function decision_variables(dep::DeterministicEquivalent{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $(N - 1).")
    return dep.decision_variables[s]
end
function scenario(dep::DeterministicEquivalent{N}, i::Integer, s::Integer = 2) where N
    1 <= s <= N || error("Stage $s not in range 1 to $(N - 1).")
    s == 1 && error("The first stage does not have scenarios.")
    return dep.scenarios[s][i]
end
