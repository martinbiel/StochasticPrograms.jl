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
