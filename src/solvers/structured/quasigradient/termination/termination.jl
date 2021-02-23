abstract type AbstractTerminationCriterion end
abstract type AbstractTermination end

terminate(quasigradient::AbstractQuasiGradient, k::Integer, f::Float64, x::AbstractVector, ∇f::AbstractVector) = terminate(quasigradient.criterion, k, f, x, ∇f)

"""
    RawTerminationParameter

An optimizer attribute used for raw parameters of the termination criterion. Defers to `RawParameter`.
"""
struct RawTerminationParameter <: TerminationParameter
    name::Any
end

function MOI.get(termination::AbstractTermination, param::RawTerminationParameter)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(termination.parameters)))
        error("Unrecognized parameter name: $(name) for termination $(typeof(termination)).")
    end
    return getfield(termination.parameters, name)
end

function MOI.set(termination::AbstractTermination, param::RawTerminationParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(termination.parameters)))
        error("Unrecognized parameter name: $(name) for termination $(typeof(termination)).")
    end
    setfield!(termination.parameters, name, value)
    return nothing
end

include("iteration.jl")
include("objective.jl")
include("gradient.jl")
