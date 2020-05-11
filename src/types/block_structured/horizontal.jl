struct HorizontalBlockStructure{N, M, SP <: NTuple{M, AbstractScenarioProblems}} <: AbstractBlockStructure{N}
    decisions::NTuple{M, Decisions}
    scenarioproblems::SP

    function HorizontalBlockStructure(scenarioproblems::NTuple{M,AbstractScenarioProblems}) where M
        N = M + 1
        decisions = ntuple(Val(M)) do i
            Decisions()
        end
        SP = typeof(scenarioproblems)
        return new{N,M,SP}(decisions, scenarioproblems)
    end
end

function StochasticStructure(scenario_types::ScenarioTypes{M}, instantiation::Union{BlockHorizontal, DistributedBlockHorizontal}) where M
    scenarioproblems = ntuple(Val(M)) do i
        ScenarioProblems(scenario_types[i], instantiation)
    end
    return HorizontalBlockStructure(scenarioproblems)
end

function StochasticStructure(scenarios::NTuple{M, Vector{<:AbstractScenario}}, instantiation::Union{BlockHorizontal, DistributedBlockHorizontal}) where M
    scenarioproblems = ntuple(Val(M)) do i
        ScenarioProblems(scenarios[i], instantiation)
    end
    return HorizontalBlockStructure(scenarioproblems)
end

# Base overloads #
# ========================== #
function Base.print(io::IO, structure::HorizontalBlockStructure{2})
    print(io, "\nScenarioproblems \n")
    print(io, "============== \n")
    for (id, subproblem) in enumerate(subproblems(structure))
        @printf(io, "Subproblem %d (p = %.2f):\n", id, probability(scenario(structure, id)))
        print(io, subproblem)
        print(io, "\n")
    end
end

# Getters #
# ========================== #
function structure_name(structure::HorizontalBlockStructure)
    return "Block horizontal"
end
function all_decision_variables(structure::HorizontalBlockStructure{N}, s::Integer) where N
    1 <= s < N || error("Stage $s not in range 1 to $(N - 1).")
    # TODO: what do at this point? Decisions at later stages are scenario-dependent
    error("all_decision_variables not yet implemented for later stages")
end

# Setters #
# ========================== #
function untake_decisions!(structure::HorizontalBlockStructure{2,1,NTuple{1,SP}}) where SP <: ScenarioProblems
    if untake_decisions!(structure.decisions[1])
        update_decisions!(scenarioproblems(structure), DecisionsStateChange())
    end
    return nothing
end
function untake_decisions!(structure::HorizontalBlockStructure{2,1,NTuple{1,SP}}) where SP <: DistributedScenarioProblems
    sp = scenarioproblems(structure)
    @sync begin
        for (i,w) in enumerate(workers())
            @async remotecall_fetch(
                w, sp[w-1], sp.decisions[w-1]) do (sp, d)
                    if untake_decisions!(fetch(d))
                        update_decisions!(fetch(sp), DecisionsStateChange())
                    end
                end
        end
    end
    return nothing
end
