# Types #
# ========================== #
abstract type AbstractStructuredSolver end

SPSolverType = Union{MathProgBase.AbstractMathProgSolver, AbstractStructuredSolver}
mutable struct SPSolver
    solver::SPSolverType
end

include("probability.jl")
include("scenario.jl")
include("sampler.jl")
include("stage.jl")
include("scenarioproblems.jl")
include("twostage.jl")
include("multistage.jl")
