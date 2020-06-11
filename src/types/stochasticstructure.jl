abstract type AbstractStochasticStructure{N} end

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
        if optimizer isa AbstractStructuredOptimizer
            # default to block-vertical structure
            if nworkers() > 1
                # Distribute in memory if Julia processes are available
                return DistributedBlockVertical()
            else
                return BlockVertical()
            end
        else
            # Default to DEP structure if standard MOI optimizer is given
            return Deterministic()
        end
    end
end

# Optimization #
# ========================== #
struct UnsupportedStructure{Opt <: StochasticProgramOptimizerType, S <: AbstractStochasticStructure} <: Exception end

function Base.showerror(io::IO, err::UnsupportedStructure{Opt, S}) where {Opt <: StochasticProgramOptimizerType, S <: AbstractStochasticStructure}
    print(io, "The stochastic structure $S is not supported by the optimizer $Opt")
end

struct UnloadedStructure{Opt <: StochasticProgramOptimizerType} <: Exception end

function Base.showerror(io::IO, err::UnloadedStructure{Opt}) where Opt <: StochasticProgramOptimizerType
    print(io, "The optimizer $Opt has no loaded structure. Consider `load_structure!`")
end

struct UnloadableStructure{Opt <: StochasticProgramOptimizerType, S <: AbstractStochasticStructure} <: Exception
    message # Human-friendly explanation why the structure cannot be loaded by the optimizer
end

function Base.showerror(io::IO, err::UnloadableStructure{Opt, S}) where {Opt <: StochasticProgramOptimizerType, S <: AbstractStochasticStructure}
    print(io, "The optimizer $Opt cannot load structure $S")
    m = message(err)
    if Base.isempty(m)
        print(io, ".")
    else
        print(io, ": ", m)
    end
end
message(err::UnloadableStructure) = err.message

# Getters #
# ========================== #
function structure_name(structure::AbstractStochasticStructure)
    return "Unknown"
end
function scenario_type(structure::AbstractStochasticStructure, s::Integer = 2)
    return _scenario_type(scenarios(structure, s))
end
function _scenario_type(::Vector{S}) where S <: AbstractScenario
    return S
end
function num_scenarios(structure::AbstractStochasticStructure, s::Integer = 2)
    return length(scenarios(structure, s))
end
function probability(structure::AbstractStochasticStructure, i::Integer, s::Integer = 2)
    return probability(scenario(structure, i, s))
end
function stage_probability(structure::AbstractStochasticStructure, s::Integer = 2)
    return probability(scenarios(structure, s))
end
function expected(structure::AbstractStochasticStructure, s::Integer = 2)
    return expected(scenarios(structure, s))
end
function distributed(structure::AbstractStochasticStructure, s)
    return false
end
# ========================== #

# Printing #
# ========================== #
function _print(io::IO, ::AbstractStochasticStructure)
    # Just give summary as default
    show(io, stochasticprogram)
end
# ========================== #
