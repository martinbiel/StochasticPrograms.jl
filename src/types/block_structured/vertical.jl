struct VerticalBlockStructure{N, M, T <: AbstractFloat, SP <: NTuple{M, AbstractScenarioProblems}} <: AbstractBlockStructure{N,T}
    decision_variables::NTuple{N, DecisionVariables{T}}
    first_stage::JuMP.Model
    scenarioproblems::SP

    function VerticalBlockStructure(decision_variables::DecisionVariables{T}, scenarioproblems::AbstractScenarioProblems) where {T <: AbstractFloat}
        SP = typeof(scenarioproblems)
        return new{2,1,T,SP}(decision_variables, Model(), scenarioproblems)
    end

    function VerticalBlockStructure(decision_variables::NTuple{N,DecisionVariables{T}}, scenarioproblems::NTuple{M,AbstractScenarioProblems}) where {N, M, T <: AbstractFloat}
        M == N - 1 || error("Inconsistent number of stages $N and number of scenario types $M")
        SP = typeof(scenarioproblems)
        return new{N,M,T,SP}(decision_variables, Model(), scenarioproblems)
    end
end

function StochasticStructure(::Type{T}, ::Type{S}, instantiation::Union{BlockVertical, DistributedBlockVertical})
    decision_variables = (DecisionVariables(T), DecisionVariables(T))
    scenarioproblems = (ScenarioProblems(decision_variables[1], S, instantiation),)
    return VerticalBlockStructure(decision_variables, scenarioproblems)
end

function StochasticStructure(::Type{T}, scenarios::Scenarios, instantiation::Union{BlockVertical, DistributedBlockVertical})
    decision_variables = (DecisionVariables(T), DecisionVariables(T))
    scenarioproblems = (ScenarioProblems(decision_variables[1], scenarios, instantiation),)
    return VerticalBlockStructure(decision_variables, scenarioproblems)
end

function StochasticStructure(::Type{T}, scenario_types::NTuple{M, DataType}, instantiation::Union{BlockVertical, DistributedBlockVertical})
    N = M + 1
    decision_variables = ntuple(Val(N)) do i
        DecisionVariables(T)
    end
    scenarioproblems = ntuple(Val(M)) do i
        ScenarioProblems(decision_variables[i], scenario_types[i], instantiation)
    end
    return VerticalBlockStructure(decision_variables, scenarioproblems)
end

function StochasticStructure(::Type{T}, scenarios::NTuple{M, Vector{<:AbstractScenario}}, instantiation::Union{BlockVertical, DistributedBlockVertical})
    N = M + 1
    decision_variables = ntuple(Val(N)) do i
        DecisionVariables(T)
    end
    scenarioproblems = ntuple(Val(M)) do i
        ScenarioProblems(decision_variables[i], scenario_types[i], instantiation)
    end
    return VerticalBlockStructure(decision_variables, scenarioproblems)
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
function first_stage(stochasticprogram::StochasticProgram, structure::VerticalBlockStructure; optimizer = nothing)
    if optimizer == nothing
        return structure.first_stage
    end
    stage_one = copy(structure.first_stage)
    set_optimizer(stage_one, optimizer)
    return stage_one
end
# ========================== #
