struct HorizontalBlockStructure{N, M, SP <: NTuple{M, AbstractScenarioProblems}} <: AbstractBlockStructure{N}
    decisions::NTuple{M, Decisions}
    proxy::JuMP.Model
    scenarioproblems::SP

    function HorizontalBlockStructure(scenarioproblems::NTuple{M,AbstractScenarioProblems}) where M
        N = M + 1
        decisions = ntuple(Val(M)) do i
            Decisions()
        end
        SP = typeof(scenarioproblems)
        return new{N,M,SP}(decisions, Model(), scenarioproblems)
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
    print(io, "Block-horizontal scenario problems \n")
    print(io, "============== \n")
    for (id, subproblem) in enumerate(subproblems(structure))
        @printf(io, "Subproblem %d (p = %.2f):\n", id, probability(scenario(structure, id)))
        print(io, subproblem)
        print(io, "\n")
    end
end

# MOI #
# ========================== #
function MOI.get(structure::HorizontalBlockStructure, attr::MOI.AbstractModelAttribute)
    return MOI.get(backend(structure.proxy), attr)
end
function MOI.get(structure::HorizontalBlockStructure, attr::MOI.AbstractVariableAttribute, index::MOI.VariableIndex)
    return MOI.get(backend(structure.proxy), attr, index)
end
function MOI.get(structure::HorizontalBlockStructure, attr::MOI.AbstractConstraintAttribute, cindex::MOI.ConstraintIndex)
    return MOI.get(backend(structure.proxy), attr, cindex)
end

function MOI.set(structure::HorizontalBlockStructure, attr::MOI.AbstractModelAttribute, value)
    MOI.set(scenarioproblems(structure), attr, value)
    MOI.set(backend(structure.proxy), attr, value)
end
function MOI.set(structure::HorizontalBlockStructure, attr::MOI.AbstractVariableAttribute,
                 index::MOI.VariableIndex, value)
    MOI.set(scenarioproblems(structure), attr, index, value)
    MOI.set(backend(structure.proxy), attr, index, value)
    return nothing
end
function MOI.set(structure::HorizontalBlockStructure, attr::MOI.AbstractConstraintAttribute,
                 cindex::MOI.ConstraintIndex, value)
    MOI.set(scenarioproblems(structure), attr, index, value)
    MOI.set(backend(structure.proxy), attr, cindex, value)
    return nothing
end

function MOI.is_valid(structure::HorizontalBlockStructure, index::MOI.VariableIndex)
    return MOI.is_valid(backend(structure.proxy), index)
end

function MOI.add_constraint(structure::HorizontalBlockStructure, f::MOI.AbstractFunction, s::MOI.AbstractSet)
    MOI.add_constraint(scenarioproblems(structure), f, s)
    return MOI.add_constraint(backend(structure.proxy), f, s)
end

function MOI.delete(structure::HorizontalBlockStructure, index::MOI.Index)
    # TODO: more to do if index is decision
    MOI.delete(scenarioproblems(structure), index)
    MOI.delete(backend(structure.proxy), index)
    return nothing
end

# Getters #
# ========================== #
function structure_name(structure::HorizontalBlockStructure)
    return "Block horizontal"
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
                w, sp[w-1], sp.decisions[w-1]) do sp, d
                    if untake_decisions!(fetch(d))
                        update_decisions!(fetch(sp), DecisionsStateChange())
                    end
                end
        end
    end
    return nothing
end
