# Types #
# ========================== #
abstract type AbstractStructuredSolver end

mutable struct SPSolver
    solver::Union{MathProgBase.AbstractMathProgSolver,AbstractStructuredSolver}
end

include("probability.jl")
include("scenario.jl")
include("sampler.jl")
include("stage.jl")
include("scenarioproblems.jl")
include("twostage.jl")
include("multistage.jl")
