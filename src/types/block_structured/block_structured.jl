abstract type AbstractScenarioProblems{S <: AbstractScenario} end

abstract type AbstractBlockStructure{N} <: AbstractStochasticStructure{N} end

# JuMP #
# ========================== #
function JuMP.objective_function_type(structure::AbstractBlockStructure{N}, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    return get_from_scenarioproblem(scenarioproblems(structure, stage), scenario_index) do sp, i
        s = fetch(sp).problems[i]
        return jump_function_type(s, MOI.get(backend(s), MOI.ObjectiveFunctionType()))
    end
end

function JuMP.objective_function(structure::AbstractBlockStructure{N},
                                 stage::Integer,
                                 scenario_index::Integer,
                                 FunType::Type{<:AbstractJuMPScalar}) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    obj = get_from_scenarioproblem(scenarioproblems(structure, stage), scenario_index, FunType) do sp, i, FunType
        MOIFunType = moi_function_type(FunType)
        subprob = fetch(sp).problems[i]
        obj = MOI.get(subprob, MOI.ObjectiveFunction{MOIFunType}())::MOIFunType
        return obj
    end
    objective = jump_function(structure, stage, scenario_index, obj)::FunType
    return objective
end

function JuMP._moi_optimizer_index(structure::AbstractBlockStructure, ci::CI, scenario_index::Integer)
    return JuMP._moi_optimizer_index(scenarioproblems(structure), ci, scenario_index)
end

function DecisionRef(structure::AbstractBlockStructure, index::VI, stage::Integer, scenario_index::Integer)
    return DecisionRef(structure.proxy[stage], index)
end
function DecisionRef(structure::AbstractBlockStructure, index::VI, at_stage::Integer, stage::Integer, scenario_index::Integer)
    at_stage > 1 || error("There are no scenarios in the first at_stage.")
    n = num_scenarios(structure, at_stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    return DecisionRef(structure.proxy[at_stage], index)
end

# Getters #
# ========================== #
function scenarioproblems(structure::AbstractBlockStructure{N}, stage::Integer) where N
    1 < stage <= N || error("Stage $stage not in range 2 to $N.")
    stage == 1 && error("Stage 1 does not have scenario problems.")
    N == 2 && (stage == 2 || error("Stage $stage not available in two-stage model."))
    return structure.scenarioproblems[stage-1]
end
function scenarioproblems(structure::AbstractBlockStructure{2})
    return scenarioproblems(structure, 2)
end
function scenario_types(structure::AbstractBlockStructure{N}) where N
    return ntuple(Val{N-1}()) do s
        scenario_type(scenarioproblems(structure), s + 1)
    end
end
function proxy(structure::AbstractBlockStructure{N}, stage::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    return structure.proxy[stage]
end
function scenario(structure::AbstractBlockStructure, stage::Integer, scenario_index::Integer)
    scenario(scenarioproblems(structure, stage), scenario_index)
end
function scenario(structure::AbstractBlockStructure{2}, scenario_index::Integer)
    scenario(scenarioproblems(structure, 2), scenario_index)
end
function scenarios(structure::AbstractBlockStructure, stage::Integer)
    scenarios(scenarioproblems(structure, stage))
end
function scenarios(structure::AbstractBlockStructure{2})
    scenarios(scenarioproblems(structure, 2))
end
function expected(structure::AbstractBlockStructure, stage::Integer)
    return expected(scenarioproblems(structure, stage))
end
function expected(structure::AbstractBlockStructure{2})
    return expected(scenarioproblems(structure, 2))
end
function scenario_type(structure::AbstractBlockStructure, stage::Integer)
    return scenario_type(scenarioproblems(structure, stage))
end
function scenario_type(structure::AbstractBlockStructure{2})
    return scenario_type(scenarioproblems(structure, 2))
end
function probability(structure::AbstractBlockStructure, stage::Integer, scenario_index::Integer)
    return probability(scenarioproblems(structure, stage), scenario_index)
end
function probability(structure::AbstractBlockStructure{2}, scenario_index::Integer)
    return probability(scenarioproblems(structure, 2), scenario_index)
end
function stage_probability(structure::AbstractBlockStructure, stage::Integer)
    return probability(scenarioproblems(structure, stage))
end
function stage_probability(structure::AbstractBlockStructure{2})
    return probability(scenarioproblems(structure, 2))
end
function subproblem(structure::AbstractBlockStructure, stage::Integer, scenario_index::Integer)
    return subproblem(scenarioproblems(structure, stage), scenario_index)
end
function subproblem(structure::AbstractBlockStructure{2}, scenario_index::Integer)
    return subproblem(scenarioproblems(structure, 2), scenario_index)
end
function subproblems(structure::AbstractBlockStructure, stage::Integer)
    return subproblems(scenarioproblems(structure, stage))
end
function subproblems(structure::AbstractBlockStructure{2})
    return subproblems(scenarioproblems(structure, 2))
end
function num_subproblems(structure::AbstractBlockStructure, stage::Integer)
    return num_subproblems(scenarioproblems(structure, stage))
end
function num_subproblems(structure::AbstractBlockStructure{2})
    return num_subproblems(scenarioproblems(structure, 2))
end
function num_scenarios(structure::AbstractBlockStructure, stage::Integer)
    return num_scenarios(scenarioproblems(structure, stage))
end
function num_scenarios(structure::AbstractBlockStructure{2})
    return num_scenarios(scenarioproblems(structure, 2))
end
deferred(structure::AbstractBlockStructure{N}) where N = deferred(structure, Val(N))
deferred(structure::AbstractBlockStructure, ::Val{1}) = deferred_first_stage(structure)
function deferred(structure::AbstractBlockStructure, ::Val{N}) where N
    return deferred_stage(structure, N) || deferred(structure, Val(N-1))
end
deferred_first_stage(structure::AbstractBlockStructure) = false
function deferred_stage(structure::AbstractBlockStructure{N}, stage::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage == 1 && return deferred_first_stage(structure)
    num_subproblems(structure, stage) < num_scenarios(structure, stage)
end
function distributed(structure::AbstractBlockStructure{N}, stage::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage == 1 && return false
    return distributed(scenarioproblems(structure, stage))
end

# ========================== #

# Setters
# ========================== #
function update_known_decisions!(structure::AbstractBlockStructure, change::DecisionModification, stage::Integer, scenario_index::Integer)
    update_known_decisions!(scenarioproblems(structure, stage), change, scenario_index)
    return nothing
end
function add_scenario!(structure::AbstractBlockStructure, stage::Integer, scenario::AbstractScenario)
    add_scenario!(scenarioproblems(structure, stage), scenario)
    return nothing
end
function add_worker_scenario!(structure::AbstractBlockStructure, stage::Integer, scenario::AbstractScenario, w::Integer)
    add_scenario!(scenario(structure, stage), scenario, w)
    return nothing
end
function add_scenario!(scenariogenerator::Function, structure::AbstractBlockStructure, stage::Integer)
    add_scenario!(scenariogenerator, scenarioproblems(structure, stage))
    return nothing
end
function add_worker_scenario!(scenariogenerator::Function, structure::AbstractBlockStructure, stage::Integer, w::Integer)
    add_scenario!(scenariogenerator, scenarioproblems(structure, stage), w)
    return nothing
end
function add_scenarios!(structure::AbstractBlockStructure, stage::Integer, scenarios::Vector{<:AbstractScenario})
    add_scenarios!(scenarioproblems(structure, stage), scenarios)
    return nothing
end
function add_worker_scenarios!(structure::AbstractBlockStructure, stage::Integer, scenarios::Vector{<:AbstractScenario}, w::Integer)
    add_scenarios!(scenarioproblems(structure, stage), scenarios, w)
    return nothing
end
function add_scenarios!(scenariogenerator::Function, structure::AbstractBlockStructure, stage::Integer, n::Integer)
    add_scenarios!(scenariogenerator, scenarioproblems(structure, stage), n)
    return nothing
end
function add_worker_scenarios!(scenariogenerator::Function, structure::AbstractBlockStructure, stage::Integer, n::Integer, w::Integer)
    add_scenarios!(scenariogenerator, scenarioproblems(structure, stage), n, w)
    return nothing
end
function sample!(structure::AbstractBlockStructure, stage::Integer, sampler::AbstractSampler, n::Integer)
    sample!(scenarioproblems(structure, stage), sampler, n)
    return nothing
end
# ========================== #

# Includes
# ========================== #
include("scenarioproblems.jl")
include("vertical.jl")
include("horizontal.jl")
