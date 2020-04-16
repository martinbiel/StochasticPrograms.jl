struct HorizontalBlockStructure{N, M, T <: AbstractFloat, S <: AbstractScenario, SP <: NTuple{M, AbstractScenarioProblems}} <: AbstractBlockStructure{N,T,S}
    decision_variables::NTuple{N, DecisionVariables{T}}
    scenarioproblems::SP

    function HorizontalBlockStructure(decision_variables::DecisionVariables{T}, scenarioproblems::AbstractScenarioProblems) where {T <: AbstractFloat}
        SP = typeof(scenarioproblems)
        return new{2,1,T,SP}(decision_variables, Model(), scenarioproblems)
    end

    function HorizontalBlockStructure(decision_variables::NTuple{N,DecisionVariables{T}}, scenarioproblems::NTuple{M,AbstractScenarioProblems}) where {N, M, T <: AbstractFloat}
        M == N - 1 || error("Inconsistent number of stages $N and number of scenario types $M")
        SP = typeof(scenarioproblems)
        return new{N,M,T,SP}(decision_variables, Model(), scenarioproblems)
    end
end

function StochasticStructure(::Type{T}, ::Type{S}, instantiation::Union{BlockHorizontal, DistributedBlockHorizontal})
    decision_variables = (DecisionVariables(T), DecisionVariables(T))
    scenarioproblems = (ScenarioProblems(decision_variables[1], S, instantiation),)
    return HorizontalBlockStructure(decision_variables, scenarioproblems)
end

function StochasticStructure(::Type{T}, scenarios::Scenarios, instantiation::Union{BlockHorizontal, DistributedBlockHorizontal})
    decision_variables = (DecisionVariables(T), DecisionVariables(T))
    scenarioproblems = (ScenarioProblems(decision_variables[1], scenarios, instantiation),)
    return HorizontalBlockStructure(decision_variables, scenarioproblems)
end

function StochasticStructure(::Type{T}, scenario_types::NTuple{M, DataType}, instantiation::Union{BlockHorizontal, DistributedBlockHorizontal})
    N = M + 1
    decision_variables = ntuple(Val(N)) do i
        DecisionVariables(T)
    end
    scenarioproblems = ntuple(Val(M)) do i
        ScenarioProblems(decision_variables[i], scenario_types[i], instantiation)
    end
    return HorizontalBlockStructure(decision_variables, scenarioproblems)
end

function StochasticStructure(::Type{T}, scenarios::NTuple{M, Vector{<:AbstractScenario}}, instantiation::Union{BlockHorizontal, DistributedBlockHorizontal})
    N = M + 1
    decision_variables = ntuple(Val(N)) do i
        DecisionVariables(T)
    end
    scenarioproblems = ntuple(Val(M)) do i
        ScenarioProblems(decision_variables[i], scenario_types[i], instantiation)
    end
    return HorizontalBlockStructure(decision_variables, scenarioproblems)
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
# ========================== #
