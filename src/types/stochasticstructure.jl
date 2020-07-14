"""
    AbstractStochasticStructure{N}

Abstract supertype for the underlying memory structure of a stochastic program. `N` is the number of stages.
"""
abstract type AbstractStochasticStructure{N} end
"""
    StochasticInstantiation

Abstract supertype for the underlying memory structure of a stochastic program. `N` is the number of stages.
"""
abstract type StochasticInstantiation end
"""
    UnspecifiedInstantiation

Default instantiation value, which defers the choice to `default_structure`.

See also: [`default_structure`](@ref)
"""
struct UnspecifiedInstantiation <: StochasticInstantiation end
"""
    Deterministic

Instantiates with the `DeterministicEquivalent` structure.

See also: [`DeterministicEquivalent`](@ref)
"""
struct Deterministic <: StochasticInstantiation end
"""
    Vertical

Instantiates with the `VerticalStructure` on a single core.

See also: [`VerticalStructure`](@ref)
"""
struct Vertical <: StochasticInstantiation end
"""
    Horizontal

Instantiates with the `HorizontalStructure` on a single core.

See also: [`HorizontalStructure`](@ref)
"""
struct Horizontal <: StochasticInstantiation end
"""
    DistributedVertical

Instantiates with the `VerticalStructure` on multiple cores.

See also: [`VerticalStructure`](@ref)
"""
struct DistributedVertical <: StochasticInstantiation end
"""
    DistributedHorizontal

Instantiates with the `HorizontalStructure` on multiple cores.

See also: [`HorizontalStructure`](@ref)
"""
struct DistributedHorizontal <: StochasticInstantiation end
"""
    StochasticStructure(scenario_types::ScenarioTypes{M}, instantiation::StochasticInstantiation) where M

Constructs a stochastic structure over the `M` provided scenario types according to the specified `instantiation`. Should be overrided for every defined stochastic structure.
"""
function StochasticStructure(scenario_types::ScenarioTypes{M}, instantiation::StochasticInstantiation) where M
    throw(MethodError(StochasticStructure, scenario_types, instantiation))
end
"""
    StochasticStructure(scenarios::NTuple{M, Vector{<:AbstractScenario}}, instantiation::StochasticInstantiation) where M

Constructs a stochastic structure over the `M` provided scenario sets according to the specified `instantiation`. Should be overrided for every defined stochastic structure.
"""
function StochasticStructure(scenarios::NTuple{M, Vector{<:AbstractScenario}}, instantiation::StochasticInstantiation) where M
    throw(MethodError(StochasticStructure, scenario_types, instantiation))
end
"""
    default_structure(instantiation::StochasticInstantiation, optimizer)

Returns a `StochasticInstantiation` based on the provided `instantiation` and `optimizer`. If an explicit `instantiation` is provided it is always prioritized. Otherwise, if `instantiation` is `UnspecifiedInstantiation`, returns whatever structure requested by the optimizer. Defaults to `Deterministic` if no optimizer is provided.
"""
function default_structure(instantiation::StochasticInstantiation, optimizer)
    return instantiation
end
function default_structure(::UnspecifiedInstantiation, optimizer)
    if optimizer isa MOI.AbstractOptimizer
        if optimizer isa AbstractStructuredOptimizer
            # default to vertical structure
            if nworkers() > 1
                # Distribute in memory if Julia processes are available
                return DistributedVertical()
            else
                return Vertical()
            end
        else
            # Default to DEP structure if standard MOI optimizer is given
            return Deterministic()
        end
    end
    # Default to deterministic if no recognized optimizer has been given.
    return Deterministic()
end

# Optimization #
# ========================== #
"""
    UnsupportedStructure{Opt <: StochasticProgramOptimizerType, S <: AbstractStochasticStructure}

Error indicating that an optimizer of type `Opt` does not support the stochastic structure `S`.
"""
struct UnsupportedStructure{Opt <: StochasticProgramOptimizerType, S <: AbstractStochasticStructure} <: Exception end

function Base.showerror(io::IO, err::UnsupportedStructure{Opt, S}) where {Opt <: StochasticProgramOptimizerType, S <: AbstractStochasticStructure}
    print(io, "The stochastic structure $S is not supported by the optimizer $Opt")
end

"""
    UnloadedStructure{Opt <: StochasticProgramOptimizerType}

Error thrown when an optimizer of type `Opt` has not yet loaded a stochastic structure and an operation which requires a structure to be loaded is called.
"""
struct UnloadedStructure{Opt <: StochasticProgramOptimizerType} <: Exception end

function Base.showerror(io::IO, err::UnloadedStructure{Opt}) where Opt <: StochasticProgramOptimizerType
    print(io, "The optimizer $Opt has no loaded structure. Consider `load_structure!`")
end

"""
    UnloadasbleStructure{Opt <: StochasticProgramOptimizerType, S <: AbstractStochasticStructure}

Error thrown when an optimizer of type `Opt` cannot load a structure of type `S`.
"""
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
