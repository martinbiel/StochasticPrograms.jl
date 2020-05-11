struct VerticalBlockStructure{N, M, SP <: NTuple{M, AbstractScenarioProblems}} <: AbstractBlockStructure{N}
    decisions::NTuple{N, Decisions}
    first_stage::JuMP.Model
    scenarioproblems::SP

    function VerticalBlockStructure(scenarioproblems::NTuple{M,AbstractScenarioProblems}) where M
        N = M + 1
        decisions = ntuple(Val(N)) do i
            Decisions()
        end
        SP = typeof(scenarioproblems)
        return new{N,M,SP}(decisions, Model(), scenarioproblems)
    end
end

function StochasticStructure(scenario_types::ScenarioTypes{M}, instantiation::Union{BlockVertical, DistributedBlockVertical}) where M
    scenarioproblems = ntuple(Val(M)) do i
        ScenarioProblems(scenario_types[i], instantiation)
    end
    return VerticalBlockStructure(scenarioproblems)
end

function StochasticStructure(scenarios::NTuple{M, Vector{<:AbstractScenario}}, instantiation::Union{BlockVertical, DistributedBlockVertical}) where M
    scenarioproblems = ntuple(Val(M)) do i
        ScenarioProblems(scenarios[i], instantiation)
    end
    return VerticalBlockStructure(scenarioproblems)
end

# Base overloads #
# ========================== #
function Base.print(io::IO, structure::VerticalBlockStructure{N}) where N
    print(io, "Stage 1\n")
    print(io, "============== \n")
    print(io, structure.first_stage)
    for s = 2:N
        print(io, "\nStage $s\n")
        print(io, "============== \n")
        for (id, subproblem) in enumerate(subproblems(structure, s))
            @printf(io, "Subproblem %d (p = %.2f):\n", id, probability(scenario(structure, id, s)))
            print(io, subproblem)
            print(io, "\n")
        end
    end
end
function Base.print(io::IO, structure::VerticalBlockStructure{2})
    print(io, "First-stage \n")
    print(io, "============== \n")
    print(io, structure.first_stage)
    print(io, "\nSecond-stage \n")
    print(io, "============== \n")
    for (id, subproblem) in enumerate(subproblems(structure))
        @printf(io, "Subproblem %d (p = %.2f):\n", id, probability(scenario(structure, id)))
        print(io, subproblem)
        print(io, "\n")
    end
end
# ========================== #

# Getters #
# ========================== #
function structure_name(structure::VerticalBlockStructure)
    return "Block vertical"
end
function all_decision_variables(structure::VerticalBlockStructure{N}, s::Integer) where N
    1 <= s < N || error("Stage $s not in range 1 to $(N - 1).")
    if s == 1
        return all_decision_variables(structure.first_stage)
    end
    # TODO: what do at this point? Decisions at later stages are scenario-dependent
    error("all_decision_variables not yet implemented for later stages")
end
deferred_first_stage(structure::VerticalBlockStructure, ::Val{1}) = num_variables(first_stage(structure)) == 0
# ========================== #
