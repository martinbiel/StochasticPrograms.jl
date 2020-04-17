struct DeterministicEquivalent{N, M, T <: AbstractFloat, S <: NTuple{M, Scenarios}} <: AbstractStochasticStructure{N, T}
    decision_variables::NTuple{N, DecisionVariables{T}}
    scenarios::S
    model::JuMP.Model

    function DeterministicEquivalent(decision_variables::DecisionVariables{T}, ::Type{S}) where {T <: AbstractFloat, S <: AbstractScenario}
        scenarios = (Vector{S}(),)
        return new{2,1,T,typeof(scenarios)}(decision_variables, scenarios, Model())
    end

    function DeterministicEquivalent(decision_variables::DecisionVariables{T}, ::Type{S}) where {T <: AbstractFloat, S <: AbstractScenario}
        scenarios = (Vector{S}(),)
        return new{2,1,T,typeof(scenarios)}(decision_variables, scenarios, Model())
    end
end

function StochasticStructure(::Type{T}, ::Type{S}, ::Deterministic)
    decision_variables = (DecisionVariables(T), DecisionVariables(T))
    scenarios = (Vector{S}(),)
    return DeterministicEquivalent(decision_variables, scenarios)
end

function StochasticStructure(::Type{T}, scenarios::Scenarios, ::Deterministic)
    decision_variables = (DecisionVariables(T), DecisionVariables(T))
    return DeterministicEquivalent(decision_variables, (scenarios,))
end

function StochasticStructure(::Type{T}, scenario_types::NTuple{M, DataType}, ::Deterministic)
    N = M + 1
    decision_variables = ntuple(Val(N)) do i
        DecisionVariables(T)
    end
    scenarios = ntuple(Val(M)) do i
        Vector{scenario_types[i]}()
    end
    return DeterministicEquivalent(decision_variables, scenarios)
end

function StochasticStructure(::Type{T}, scenarios::NTuple{M, Vector{<:AbstractScenario}}, ::Deterministic)
    N = M + 1
    decision_variables = ntuple(Val(N)) do i
        DecisionVariables(T)
    end
    return DeterministicEquivalent(decision_variables, scenarios)
end

# Base overloads #
# ========================== #
function Base.print(io::IO, dep::DeterministicEquivalent)
    print(io, "Deterministic equivalent problem\n")
    print(io, dep.model)
end
# ========================== #

# Getters #
# ========================== #
function scenario(dep::DeterministicEquivalent{N}, i::Integer, s::Integer = 2) where N
    1 <= s <= N || error("Stage $s not in range 1 to $(N - 1).")
    s == 1 && error("The first stage does not have scenarios.")
    return dep.scenarios[s][i]
end
function scenarios(dep::DeterministicEquivalent{N}, s::Integer = 2) where N
    1 <= s <= N || error("Stage $s not in range 1 to $(N - 1).")
    s == 1 && error("The first stage does not have scenarios.")
    return dep.scenarios[s]
end
function subproblem(dep::DeterministicEquivalent, i::Integer, s::Integer = 2)
    return subproblem(scenarioproblems(dep, s), i)
end
function subproblems(dep::DeterministicEquivalent, s::Integer = 2)
    return subproblems(scenarioproblems(dep, s))
end
function nsubproblems(dep::DeterministicEquivalent, s::Integer = 2)
    return 0
end
function deferred(dep::DeterministicEquivalent)
    return num_variables(dep.model) = 0
end
# ========================== #

# Setters
# ========================== #
function add_scenario!(dep::DeterministicEquivalent, scenario::AbstractScenario, stage::Integer = 2)
    push!(scenarios(dep, stage), scenario)
    return nothing
end
function add_worker_scenario!(dep::DeterministicEquivalent, scenario::AbstractScenario, w::Integer, stage::Integer = 2)
    add_scenario!(dep, scenario, stage)
    return nothing
end
function add_scenario!(scenariogenerator::Function, dep::DeterministicEquivalent, stage::Integer = 2)
    add_scenario!(dep, scenariogenerator(), stage)
    return nothing
end
function add_worker_scenario!(scenariogenerator::Function, dep::DeterministicEquivalent, w::Integer, stage::Integer = 2)
    add_scenario!(scenariogenerator, dep, stage)
    return nothing
end
function add_scenarios!(dep::DeterministicEquivalent, scenarios::Vector{<:AbstractScenario}, stage::Integer = 2)
    append!(scenarios(dep, stage), scenarios)
    return nothing
end
function add_worker_scenarios!(dep::DeterministicEquivalent, scenarios::Vector{<:AbstractScenario}, w::Integer, stage::Integer = 2)
    add_scenarios!(dep, scenarios, stasge)
    return nothing
end
function add_scenarios!(scenariogenerator::Function, dep::DeterministicEquivalent, n::Integer, stage::Integer = 2)
    for i = 1:n
        add_scenario!(dep, stage) do
            return scenariogenerator()
        end
    end
    return nothing
end
function add_worker_scenarios!(scenariogenerator::Function, dep::DeterministicEquivalent, n::Integer, w::Integer, stage::Integer = 2)
    add_scenarios!(scenariogenerator, dep, n, stage)
    return nothing
end
function sample!(dep::DeterministicEquivalent, sampler::AbstractSampler, n::Integer, stage::Integer = 2)
    sample!(scenarios(dep, stage), sampler, n)
    return nothing
end
# ========================== #
