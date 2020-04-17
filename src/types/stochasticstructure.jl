abstract type AbstractStochasticStructure{N, T <: AbstractFloat} end

# Auxilliary type for selecting structure of stochastic program
abstract type StochasticInstantiation end
struct UnspecifiedInstantiation <: StochasticInstantiation end
struct Deterministic <: StochasticInstantiation end
struct BlockVertical <: StochasticInstantiation end
struct BlockHorizontal <: StochasticInstantiation end
struct DistributedBlockVertical <: StochasticInstantiation end
struct DistributedBlockHorizontal <: StochasticInstantiation end

# Constructor of stochastic structure. Should dispatch on instantiation type
function StochasticStructure end

# Always prefer user-provided instantiation type
function default_structure(instantiation::StochasticInstantiation, ::Any)
    return instantiation
end

# Otherwise, switch on provided optimizer
function default_structure(::UnspecifiedInstantiation, optimizer)
    if optimizer isa MOI.AbstractOptimizer
        # Default to DEP structure if standard MOI optimizer is given
        return Deterministic()
    else
        # In other cases, default to block-vertical structure
        if nworkers() > 1
            # Distribute in memory if Julia processes are available
            return DistributedBlockVertical()
        else
            return BlockVertical()
        end
    end
end

# Getters #
# ========================== #
function decision_variables(structure::AbstractStochasticStructure{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $(N - 1).")
    return structure.decision_variables[s]
end
function scenariotype(structure::AbstractStochasticStructure, s::Integer = 2)
    return _scenariotype(scenarios(structure, s))
end
function _scenariotype(::Vector{S}) where S <: AbstractScenario
    return S
end
function probability(structure::AbstractStochasticStructure, i::Integer, s::Integer = 2)
    return probability(scenario(structure, i, s))
end
function stage_probability(structure::StochasticProgram, s::Integer = 2)
    return probability(scenarios(structure, s))
end
function expected(structure::AbstractScenario, s::Integer = 2)
    return expected(scenarios(dep, s))
end
function nscenarios(structure::AbstractScenario, s::Integer = 2)
    return length(scenarios(structure, s))
end
# ========================== #
