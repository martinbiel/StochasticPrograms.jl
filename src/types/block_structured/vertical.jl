struct VerticalStructure{N, M, SP <: NTuple{M, AbstractScenarioProblems}} <: AbstractBlockStructure{N}
    decisions::NTuple{N, Decisions}
    first_stage::JuMP.Model
    scenarioproblems::SP

    function VerticalStructure(scenarioproblems::NTuple{M,AbstractScenarioProblems}) where M
        N = M + 1
        decisions = ntuple(Val(N)) do i
            Decisions()
        end
        SP = typeof(scenarioproblems)
        return new{N,M,SP}(decisions, Model(), scenarioproblems)
    end
end

function StochasticStructure(scenario_types::ScenarioTypes{M}, instantiation::Union{Vertical, DistributedVertical}) where M
    scenarioproblems = ntuple(Val(M)) do i
        ScenarioProblems(scenario_types[i], instantiation)
    end
    return VerticalStructure(scenarioproblems)
end

function StochasticStructure(scenarios::NTuple{M, Vector{<:AbstractScenario}}, instantiation::Union{Vertical, DistributedVertical}) where M
    scenarioproblems = ntuple(Val(M)) do i
        ScenarioProblems(scenarios[i], instantiation)
    end
    return VerticalStructure(scenarioproblems)
end

# Base overloads #
# ========================== #
function Base.print(io::IO, structure::VerticalStructure{N}) where N
    print(io, "Stage 1\n")
    print(io, "============== \n")
    print(io, structure.first_stage)
    for s = 2:N
        print(io, "\nStage $s\n")
        print(io, "============== \n")
        for (id, subproblem) in enumerate(subproblems(structure, s))
            @printf(io, "Subproblem %d (p = %.2f):\n", id, probability(structure, id, s))
            print(io, subproblem)
            print(io, "\n")
        end
    end
end
function Base.print(io::IO, structure::VerticalStructure{2})
    print(io, "First-stage \n")
    print(io, "============== \n")
    print(io, structure.first_stage)
    print(io, "\nSecond-stage \n")
    print(io, "============== \n")
    for (id, subproblem) in enumerate(subproblems(structure))
        @printf(io, "Subproblem %d (p = %.2f):\n", id, probability(structure, id))
        print(io, subproblem)
        print(io, "\n")
    end
end
# ========================== #

# MOI #
# ========================== #
function MOI.get(structure::VerticalStructure, attr::MOI.AbstractModelAttribute)
    return MOI.get(backend(structure.first_stage), attr)
end
function MOI.get(structure::VerticalStructure, attr::MOI.AbstractVariableAttribute, index::MOI.VariableIndex)
    return MOI.get(backend(structure.first_stage), attr, index)
end
function MOI.get(structure::VerticalStructure, attr::MOI.AbstractConstraintAttribute, cindex::MOI.ConstraintIndex)
    return MOI.get(backend(structure.first_stage), attr, cindex)
end

function MOI.set(structure::VerticalStructure, attr::MOI.AbstractModelAttribute, value)
    MOI.set(backend(structure.first_stage), attr, value)
    return nothing
end
function MOI.set(structure::VerticalStructure, attr::MOI.Silent, flag)
    # Silence master
    MOI.set(backend(structure.first_stage), attr, flag)
    # Silence subproblems
    MOI.set(scenarioproblems(structure), attr, flag)
    return nothing
end
function MOI.set(structure::VerticalStructure, attr::MOI.AbstractVariableAttribute,
                 index::MOI.VariableIndex, value)
    MOI.set(backend(structure.first_stage), attr, index, value)
    return nothing
end
function MOI.set(structure::VerticalStructure, attr::MOI.AbstractConstraintAttribute,
                 cindex::MOI.ConstraintIndex, value)
    MOI.set(backend(structure.first_stage), attr, cindex, value)
    return nothing
end

function MOI.is_valid(structure::VerticalStructure, index::MOI.VariableIndex)
    return MOI.is_valid(backend(structure.first_stage), index)
end

function MOI.add_constraint(structure::VerticalStructure, f::MOI.AbstractFunction, s::MOI.AbstractSet)
    return MOI.add_constraint(backend(structure.first_stage), f, s)
end

function MOI.delete(structure::VerticalStructure, index::MOI.Index)
    # TODO: more to do if index is decision
    MOI.delete(backend(structure.first_stage), index)
    return nothing
end

# Getters #
# ========================== #
function structure_name(structure::VerticalStructure)
    return "Vertical"
end
deferred_first_stage(structure::VerticalStructure, ::Val{1}) = num_variables(first_stage(structure)) == 0
# ========================== #

# Setters
# ========================== #
function update_decisions!(structure::VerticalStructure, change::DecisionModification)
    update_decisions!(structure.first_stage, change)
end
