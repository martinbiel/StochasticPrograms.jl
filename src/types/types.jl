# Types #
# ========================== #
abstract type AbstractStructuredSolver end

mutable struct SPSolver
    solver::Union{MathProgBase.AbstractMathProgSolver,AbstractStructuredSolver}
end

abstract type AbstractScenarioData end
probability(sd::AbstractScenarioData) = sd.π
function expected(::Vector{SD}) where SD <: AbstractScenarioData
    error("Expected value operation not implemented for scenariodata type: ", SD)
end

abstract type AbstractSampler{SD <: AbstractScenarioData} end
struct NullSampler{SD <: AbstractScenarioData} <: AbstractSampler{SD} end

mutable struct Stage{D}
    stage::Int
    data::D

    function (::Type{Stage})(stage::Integer,data::D) where D
        return new{D}(stage,data)
    end
end

include("scenarios.jl")
include("twostage.jl")
include("multistage.jl")
