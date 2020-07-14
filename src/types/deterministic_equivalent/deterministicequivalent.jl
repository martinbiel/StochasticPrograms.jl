"""
    DeterministicEquivalent

Deterministic equivalent memory structure. Stochastic program is stored as one large optimization problem. Supported by any standard `AbstractOptimizer`.

"""
struct DeterministicEquivalent{N, M, S <: NTuple{M, Scenarios}} <: AbstractStochasticStructure{N}
    decisions::Decisions
    decision_variables::NTuple{M, Vector{DecisionRef}}
    scenarios::S
    sub_objectives::NTuple{M, Vector{MOI.AbstractScalarFunction}}
    model::JuMP.Model

    function DeterministicEquivalent(scenarios::NTuple{M, Scenarios}) where M
        N = M + 1
        decisions = Decisions()
        decision_variables = ntuple(Val(M)) do i
            Vector{DecisionRef}()
        end
        sub_objectives = ntuple(Val(M)) do i
            Vector{MOI.AbstractScalarFunction}()
        end
        S = typeof(scenarios)
        return new{N,M,S}(decisions, decision_variables, scenarios, sub_objectives, Model())
    end
end

function StochasticStructure(scenario_types::ScenarioTypes{M}, ::Deterministic) where M
    scenarios = ntuple(Val(M)) do i
        Vector{scenario_types[i]}()
    end
    return DeterministicEquivalent(scenarios)
end

function StochasticStructure(scenarios::NTuple{M, Vector{<:AbstractScenario}}, ::Deterministic) where M
    return DeterministicEquivalent(scenarios)
end

# Base overloads #
# ========================== #
function Base.print(io::IO, structure::DeterministicEquivalent)
    print(io, "Deterministic equivalent problem\n")
    print(io, structure.model)
end
# ========================== #

# MOI #
# ========================== #
function MOI.get(structure::DeterministicEquivalent, attr::MOI.AbstractModelAttribute)
    return MOI.get(backend(structure.model), attr)
end
function MOI.get(structure::DeterministicEquivalent, attr::MOI.AbstractVariableAttribute, index::MOI.VariableIndex)
    return MOI.get(backend(structure.model), attr, index)
end
function MOI.get(structure::DeterministicEquivalent, attr::Type{MOI.VariableIndex}, name::String)
    return MOI.get(backend(structure.model), attr, name)
end
function MOI.get(structure::DeterministicEquivalent, attr::MOI.AbstractConstraintAttribute, cindex::MOI.ConstraintIndex)
    return MOI.get(backend(structure.model), attr, cindex)
end

function MOI.set(structure::DeterministicEquivalent, attr::MOI.Silent, flag)
    MOI.set(backend(structure.model), attr, flag)
    return nothing
end
function MOI.set(structure::DeterministicEquivalent, attr::MOI.AbstractModelAttribute, value)
    MOI.set(backend(structure.model), attr, value)
    return nothing
end
function MOI.set(structure::DeterministicEquivalent, attr::MOI.AbstractVariableAttribute,
                 index::MOI.VariableIndex, value)
    MOI.set(backend(structure.model), attr, index, value)
    return nothing
end
function MOI.set(structure::DeterministicEquivalent, attr::MOI.AbstractConstraintAttribute,
                 cindex::MOI.ConstraintIndex, value)
    MOI.set(backend(structure.model), attr, cindex, value)
    return nothing
end

function MOI.is_valid(structure::DeterministicEquivalent, index::MOI.VariableIndex)
    return MOI.is_valid(backend(structure.model), index)
end

function MOI.add_constraint(structure::DeterministicEquivalent, f::MOI.AbstractFunction, s::MOI.AbstractSet)
    return MOI.add_constraint(backend(structure.model), f, s)
end

function MOI.delete(structure::DeterministicEquivalent, index::MOI.Index)
    # TODO: more to do if index is decision
    MOI.delete(backend(structure.model), index)
    return nothing
end

# Getters #
# ========================== #
function structure_name(structure::DeterministicEquivalent)
    return "Deterministic equivalent"
end
function decision(structure::DeterministicEquivalent, index::MOI.VariableIndex)
    return decision(structure.decisions, index)
end
function decisions(structure::DeterministicEquivalent)
    return structure.decisions
end
function all_decisions(structure::DeterministicEquivalent)
    return structure.decisions.undecided
end
function num_decisions(structure::DeterministicEquivalent{N}, s::Integer = 2) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    s == N && error("The final stage does not have decisions.")
    return length(structure.decision_variables[s])
end
function scenario(structure::DeterministicEquivalent{N}, i::Integer, s::Integer = 2) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    s == 1 && error("The first stage does not have scenarios.")
    return structure.scenarios[s-1][i]
end
function scenarios(structure::DeterministicEquivalent{N}, s::Integer = 2) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    s == 1 && error("The first stage does not have scenarios.")
    return structure.scenarios[s-1]
end
function subproblem(structure::DeterministicEquivalent, i::Integer, s::Integer = 2)
    return subproblem(scenarioproblems(structure, s), i)
end
function subproblems(structure::DeterministicEquivalent, s::Integer = 2)
    return subproblems(scenarioproblems(structure, s))
end
function num_subproblems(structure::DeterministicEquivalent, s::Integer = 2)
    return 0
end
function deferred(structure::DeterministicEquivalent)
    return num_variables(structure.model) == 0
end
# ========================== #

# Setters
# ========================== #
function update_decisions!(structure::DeterministicEquivalent, change::DecisionModification)
    update_decisions!(structure.model, change)
end

function add_scenario!(structure::DeterministicEquivalent, scenario::AbstractScenario, stage::Integer = 2)
    push!(scenarios(structure, stage), scenario)
    return nothing
end
function add_worker_scenario!(structure::DeterministicEquivalent, scenario::AbstractScenario, w::Integer, stage::Integer = 2)
    add_scenario!(structure, scenario, stage)
    return nothing
end
function add_scenario!(scenariogenerator::Function, structure::DeterministicEquivalent, stage::Integer = 2)
    add_scenario!(structure, scenariogenerator(), stage)
    return nothing
end
function add_worker_scenario!(scenariogenerator::Function, structure::DeterministicEquivalent, w::Integer, stage::Integer = 2)
    add_scenario!(scenariogenerator, structure, stage)
    return nothing
end
function add_scenarios!(structure::DeterministicEquivalent, _scenarios::Vector{<:AbstractScenario}, stage::Integer = 2)
    append!(scenarios(structure, stage), _scenarios)
    return nothing
end
function add_worker_scenarios!(structure::DeterministicEquivalent, scenarios::Vector{<:AbstractScenario}, w::Integer, stage::Integer = 2)
    add_scenarios!(structure, scenarios, stasge)
    return nothing
end
function add_scenarios!(scenariogenerator::Function, structure::DeterministicEquivalent, n::Integer, stage::Integer = 2)
    for i = 1:n
        add_scenario!(structure, stage) do
            return scenariogenerator()
        end
    end
    return nothing
end
function add_worker_scenarios!(scenariogenerator::Function, structure::DeterministicEquivalent, n::Integer, w::Integer, stage::Integer = 2)
    add_scenarios!(scenariogenerator, structure, n, stage)
    return nothing
end
function sample!(structure::DeterministicEquivalent, sampler::AbstractSampler, n::Integer, stage::Integer = 2)
    sample!(scenarios(structure, stage), sampler, n)
    return nothing
end
# ========================== #
