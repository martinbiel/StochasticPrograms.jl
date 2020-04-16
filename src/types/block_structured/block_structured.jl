abstract type AbstractScenarioProblems{T <: AbstractFloat, S <: AbstractScenario} end

abstract type AbstractBlockStructure{N, T} <: AbstractStochasticStructure{N,T} end

# Getters #
# ========================== #
function scenarioproblems(structure::AbstractBlockStructure{N}, s::Integer = 2) where N
    s == 1 && error("Stage 1 does not have scenario problems.")
    N == 2 && (s == 2 || error("Stage $s not available in two-stage model."))
    1 < s <= N || error("Stage $s not in range 2 to $N.")
    return structure.scenarioproblems[s-1]
end
function scenario(structure::AbstractBlockStructure, i::Integer, s::Integer = 2)
    scenario(scenarioproblems(structure, s), i)
end
function expected(structure::AbstractBlockStructure, s::Integer = 2)
    return expected(scenarioproblems(structure, s)).scenario
end
function scenariotype(structure::AbstractBlockStructure, s::Integer = 2)
    return scenariotype(scenarioproblems(stochasticprogram, s))
end
function stage_probability(structure::AbstractBlockStructure, s::Integer = 2)
    return probability(scenarioproblems(structure, s))
end
function subproblem(structure::AbstractBlockStructure, i::Integer, s::Integer = 2)
    return subproblem(scenarioproblems(structure, s), i)
end
function subproblems(structure::AbstractBlockStructure, s::Integer = 2)
    return subproblems(scenarioproblems(structure, s))
end
function nsubproblems(structure::AbstractBlockStructure, s::Integer = 2)
    return nsubproblems(scenarioproblems(structure, s))
end
function nscenarios(structure::AbstractBlockStructure, s::Integer = 2)
    return nscenarios(scenarioproblems(structure, s))
end
# ========================== #

# Setters
# ========================== #

# Includes
# ========================== #
include("scenarioproblems.jl")
include("vertical.jl")
include("horizontal.jl")
