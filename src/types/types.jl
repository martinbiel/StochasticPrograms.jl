# Types #
# ========================== #
"""
    AbstractScenario

Abstract supertype for structured solver interface objects.
"""
abstract type AbstractStructuredSolver end
"""
    AbstractStructuredModel

Abstract supertype for structured solver objects.
"""
abstract type AbstractStructuredModel end

SPSolverType = Union{MPB.AbstractMathProgSolver, AbstractStructuredSolver}
mutable struct SPSolver
    solver::SPSolverType
    internal_model

    function (::Type{SPSolver})(solver::SPSolverType)
        return new(solver, nothing)
    end
end

include("scenario.jl")
include("sampler.jl")
include("stage.jl")
include("scenarioproblems.jl")
include("twostage.jl")
include("multistage.jl")
