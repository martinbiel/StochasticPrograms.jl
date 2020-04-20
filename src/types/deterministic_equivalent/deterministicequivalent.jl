struct DeterministicEquivalent{N, M, S <: NTuple{M, Scenarios}} <: AbstractStochasticStructure{N}
    decisions::Decisions
    decision_variables::NTuple{M, Vector{DecisionRef}}
    scenarios::S
    model::JuMP.Model

    function DeterministicEquivalent(scenarios::NTuple{M, Scenarios}) where M
        N = M + 1
        decisions = Decisions()
        decision_variables = ntuple(Val(M)) do i
            Vector{DecisionRef}()
        end
        S = typeof(scenarios)
        return new{N,M,S}(decisions, decision_variables, scenarios, Model())
    end
end

function StochasticStructure(scenario_types::NTuple{M, DataType}, ::Deterministic) where M
    scenarios = ntuple(Val(M)) do i
        Vector{scenario_types[i]}()
    end
    return DeterministicEquivalent(scenarios)
end

function StochasticStructure(scenarios::NTuple{M, Vector{<:AbstractScenario}}, ::Deterministic) where M
    return DeterministicEquivalent(scenarios)
end

function supports_structure(::MOI.AbstractOptimizer, ::DeterministicEquivalent)
    return true
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
function structure_name(structure::DeterministicEquivalent)
    return "Deterministic equivalent"
end
function decisions(dep::DeterministicEquivalent{N}, s::Integer) where N
    1 <= s < N || error("Stage $s not in range 1 to $(N - 1).")
    return [decision(dref) for dref in dep.decision_variables[s]]
end
function decision_variables(dep::DeterministicEquivalent{N}, s::Integer) where N
    1 <= s < N || error("Stage $s not in range 1 to $(N - 1).")
    return dep.decision_variables[s]
end
function all_decisions(dep::DeterministicEquivalent)
    return all_decisions(dep.model)
end
function all_decision_variables(dep::DeterministicEquivalent, s::Integer)
    return dep.decision_variables[s]
end
function num_decisions(dep::DeterministicEquivalent{N}, s::Integer) where N
    1 <= s < N || error("Stage $s not in range 1 to $(N - 1).")
    return length(dep.decision_variables[s])
end
function all_known_decisions(dep::DeterministicEquivalent)
    # There are never any known decisions in the deterministically equivalent problem
    return KnownDecisions[]
end
function all_known_decision_variables(dep::DeterministicEquivalent)
    # There are never any known decisions in the deterministically equivalent problem
    return KnownRef[]
end
function num_known_decisions(dep::DeterministicEquivalent{N}, s::Integer) where N
    # There are never any known decisions in the deterministically equivalent problem
    return 0
end
function scenario(dep::DeterministicEquivalent{N}, i::Integer, s::Integer = 2) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    s == 1 && error("The first stage does not have scenarios.")
    return dep.scenarios[s-1][i]
end
function scenarios(dep::DeterministicEquivalent{N}, s::Integer = 2) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    s == 1 && error("The first stage does not have scenarios.")
    return dep.scenarios[s-1]
end
function subproblem(dep::DeterministicEquivalent, i::Integer, s::Integer = 2)
    return subproblem(scenarioproblems(dep, s), i)
end
function subproblems(dep::DeterministicEquivalent, s::Integer = 2)
    return subproblems(scenarioproblems(dep, s))
end
function num_subproblems(dep::DeterministicEquivalent, s::Integer = 2)
    return 0
end
function deferred(dep::DeterministicEquivalent)
    return num_variables(dep.model) == 0
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
