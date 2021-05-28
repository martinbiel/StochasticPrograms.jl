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
    StageDecomposition

Instantiates with the `StageDecompositionStructure` on a single core.

See also: [`StageDecompositionStructure`](@ref)
"""
struct StageDecomposition <: StochasticInstantiation end
"""
    Vertical

Instantiates with the `StageDecompositionStructure` on a single core.

See also: [`StageDecompositionStructure`](@ref)
"""
struct Vertical <: StochasticInstantiation end
"""
    ScenarioDecomposition

Instantiates with the `ScenarioDecompositionStructure` on a single core.

See also: [`ScenarioDecompositionStructure`](@ref)
"""
struct ScenarioDecomposition <: StochasticInstantiation end
"""
    Horizontal

Instantiates with the `ScenarioDecompositionStructure` on a single core.

See also: [`ScenarioDecompositionStructure`](@ref)
"""
struct Horizontal <: StochasticInstantiation end
"""
    DistributedStageDecomposition

Instantiates with the `StageDecompositionStructure` on multiple cores.

See also: [`StageDecompositionStructure`](@ref)
"""
struct DistributedStageDecomposition <: StochasticInstantiation end
"""
    DistributedVertical

Instantiates with the `StageDecompositionStructure` on multiple cores.

See also: [`StageDecompositionStructure`](@ref)
"""
struct DistributedVertical <: StochasticInstantiation end
"""
    DistributedScenarioDecomposition

Instantiates with the `ScenarioDecompositionStructure` on multiple cores.

See also: [`ScenarioDecompositionStructure`](@ref)
"""
struct DistributedScenarioDecomposition <: StochasticInstantiation end
"""
    DistributedHorizontal

Instantiates with the `ScenarioDecompositionStructure` on multiple cores.

See also: [`ScenarioDecompositionStructure`](@ref)
"""
struct DistributedHorizontal <: StochasticInstantiation end
"""
    StochasticStructure(scenario_types::ScenarioTypes{M}, instantiation::StochasticInstantiation) where M

Constructs a stochastic structure over the `M` provided scenario types according to the specified `instantiation`. Should be overrided for every defined stochastic structure.

    StochasticStructure(scenarios::NTuple{M, Vector{<:AbstractScenario}}, instantiation::StochasticInstantiation) where M

Constructs a stochastic structure over the `M` provided scenario sets according to the specified `instantiation`. Should be overrided for every defined stochastic structure.
"""
function StochasticStructure end
"""
    default_structure(instantiation::StochasticInstantiation, optimizer)

Returns a `StochasticInstantiation` based on the provided `instantiation` and `optimizer`. If an explicit `instantiation` is provided it is always prioritized. Otherwise, if `instantiation` is `UnspecifiedInstantiation`, returns whatever structure requested by the optimizer. Defaults to `Deterministic` if no optimizer is provided.
"""
function default_structure(instantiation::StochasticInstantiation, optimizer)
    if (instantiation isa DistributedStageDecomposition || instantiation isa DistributedVertical) && nworkers() == 1
        @warn "The distributed stage-decomposition structure is not available in a single-core setup. Switching to the `StageDecomposition` structure by default."
        return StageDecomposition()
    elseif (instantiation isa DistributedScenarioDecomposition || instantiation isa DistributedHorizontal) && nworkers() == 1
        @warn "The distributed scenario-decomposition structure is not available in a single-core setup. Switching to the `ScenarioDecomposition` structure by default."
        return ScenarioDecomposition()
    else
        return instantiation
    end
end
function default_structure(::UnspecifiedInstantiation, optimizer)
    if optimizer isa MOI.AbstractOptimizer
        if optimizer isa AbstractStructuredOptimizer
            # default to stage-decomposition structure
            if nworkers() > 1
                # Distribute in memory if Julia processes are available
                return DistributedStageDecomposition()
            else
                return StageDecomposition()
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
function num_decisions(structure::AbstractStochasticStructure{N}, stage::Integer = 1) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    return num_decisions(structure.decisions, stage)
end
function scenario_type(structure::AbstractStochasticStructure, s::Integer = 2)
    return _scenario_type(scenarios(structure, s))
end
function _scenario_type(::Vector{S}) where S <: AbstractScenario
    return S
end
function num_scenarios(structure::AbstractStochasticStructure, stage::Integer = 2)
    return length(scenarios(structure, stage))
end
function probability(structure::AbstractStochasticStructure, stage::Integer, scenario_index::Integer)
    return probability(scenario(structure, stage, scenario_index))
end
function stage_probability(structure::AbstractStochasticStructure, stage::Integer = 2)
    return probability(scenarios(structure, stage))
end
function expected(structure::AbstractStochasticStructure, stage::Integer = 2)
    return expected(scenarios(structure, stage))
end
function distributed(structure::AbstractStochasticStructure, stage::Integer)
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
