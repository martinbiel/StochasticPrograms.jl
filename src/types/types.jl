# Types #
# ========================== #
"""
    AbstractStructuredSolver

Abstract supertype for structured solver interface objects.
"""
abstract type AbstractStructuredSolver end
"""
    AbstractStructuredModel

Abstract supertype for structured solver objects.
"""
abstract type AbstractStructuredModel end
"""
    AbstractSampledSolver

Abstract supertype for sample-based solver interface objects.
"""
abstract type AbstractSampledSolver end
"""
    AbstractSampledModel

Abstract supertype for sample-based solver objects.
"""
abstract type AbstractSampledModel end

SPSolverType = Union{MPB.AbstractMathProgSolver, AbstractStructuredSolver, AbstractSampledSolver}
mutable struct SPSolver
    solver::SPSolverType
    internal_model

    function SPSolver(solver::SPSolverType)
        return new(solver, nothing)
    end
end

include("scenario.jl")
include("sampler.jl")
include("stage.jl")
include("model.jl")
include("scenarioproblems.jl")
include("stochasticprogram.jl")
include("stochasticsolution.jl")
