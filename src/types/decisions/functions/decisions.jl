struct SingleDecision <: MOI.AbstractScalarFunction
    decision::MOI.VariableIndex
end

mutable struct SingleKnown <: MOI.AbstractScalarFunction
    known::MOI.VariableIndex
end

struct VectorOfDecisions <: MOI.AbstractVectorFunction
    decisions::Vector{MOI.VariableIndex}
end
MOI.output_dimension(f::VectorOfDecisions) = length(f.decisions)

struct VectorOfKnowns <: MOI.AbstractVectorFunction
    knowns::Vector{MOI.VariableIndex}
end
MOI.output_dimension(f::VectorOfKnowns) = length(f.knowns)

# Base overrides #
# ========================== #
Base.copy(f::SingleDecision) = f
Base.copy(f::SingleKnown) = f
Base.copy(f::VectorOfDecisions) = VectorOfDecisions(copy(f.decisions))
Base.copy(f::VectorOfKnowns) = VectorOfKnowns(copy(f.knowns))

Base.iszero(::SingleDecision) = false
Base.isone(::SingleDecision) = false
Base.iszero(::SingleKnown) = false
Base.isone(::SingleKnown) = false

# JuMP overrides #
# ========================== #
function DecisionRef(model::Model, f::SingleDecision)
    return DecisionRef(model, f.decision)
end

function KnownRef(model::Model, f::SingleKnown)
    return KnownRef(model, f.known)
end

SingleDecision(dref::DecisionRef) = SingleDecision(index(dref))
function JuMP.moi_function(dref::DecisionRef)
    return SingleDecision(dref)
end
function JuMP.moi_function_type(::Type{DecisionRef})
    return SingleDecision
end
JuMP.jump_function_type(::Model, ::Type{SingleDecision}) = DecisionRef
function JuMP.jump_function(model::Model, decision::SingleDecision)
    return DecisionRef(model, decision)
end

SingleKnown(kref::KnownRef) = SingleKnown(index(kref))
function JuMP.moi_function(kref::KnownRef)
    return SingleKnown(kref)
end
function JuMP.moi_function_type(::Type{KnownRef})
    return SingleKnown
end
JuMP.jump_function_type(::Model, ::Type{SingleKnown}) = KnownRef
function JuMP.jump_function(model::Model, known::SingleKnown)
    return KnownRef(model, known)
end

VectorOfDecisions(dvars::Vector{DecisionRef}) = VectorOfDecisions(index.(dvars))
function JuMP.moi_function(decisions::Vector{<:DecisionRef})
    return VectorOfDecisions(index.(decisions))
end
function JuMP.moi_function_type(::Type{<:Vector{<:DecisionRef}})
    return VectorOfDecisions
end
JuMP.jump_function_type(::Model, ::Type{VectorOfDecisions}) = Vector{DecisionRef}
function JuMP.jump_function(model::Model, decisions::VectorOfDecisions)
    return map(decisions.decisions) do decision
        DecisionRef(model, decision)
    end
end

VectorOfKnowns(kvars::Vector{KnownRef}) = VectorOfKnowns(index.(kvars))
function JuMP.moi_function(knowns::Vector{<:KnownRef})
    return VectorOfKnowns(index.(knowns))
end
function JuMP.moi_function_type(::Type{<:Vector{<:KnownRef}})
    return VectorOfKnowns
end
JuMP.jump_function_type(::Model, ::Type{VectorOfKnowns}) = Vector{KnownRef}
function JuMP.jump_function(model::Model, knowns::VectorOfKnowns)
    return map(knowns.knowns) do known
        KnownRef(model, known)
    end
end

# MOI Function interface #
# ========================== #
MOI.constant(f::SingleDecision, T::DataType) = zero(T)
MOI.constant(f::SingleKnown, T::DataType) = zero(T)

MOIU.eval_variables(varval::Function, f::SingleDecision) = varval(f.decision)
MOIU.eval_variables(::Function, f::SingleKnown) = varval(f.known)

function MOIU.map_indices(index_map::Function, f::SingleDecision)
    return SingleDecision(index_map(f.decision))
end
function MOIU.map_indices(index_map::Function, f::SingleKnown)
    return SingleKnown(index_map(f.known))
end
function MOIU.map_indices(index_map::Function, f::VectorOfDecisions)
    return VectorOfDecisions(index_map.(f.decisions))
end
function MOIU.map_indices(index_map::Function, f::VectorOfKnowns)
    return VectorOfKnowns(index_map.(f.knowns))
end

function Base.getindex(it::MOIU.ScalarFunctionIterator{VectorOfDecisions},
                       i::Integer)
    return SingleDecision(it.f.decisions[i])
end
function Base.getindex(it::MOIU.ScalarFunctionIterator{VectorOfDecisions},
                       I::AbstractVector)
    return VectorOfDecisions(it.f.decisions[I])
end

function Base.getindex(it::MOIU.ScalarFunctionIterator{VectorOfKnowns},
                       i::Integer)
    return SingleKnown(it.f.knowns[i])
end
function Base.getindex(it::MOIU.ScalarFunctionIterator{VectorOfKnowns},
                       I::AbstractVector)
    return VectorOfKnowns(it.f.knowns[I])
end

MOIU.scalar_type(::Type{VectorOfDecisions}) = SingleDecision
MOIU.scalar_type(::Type{VectorOfKnowns}) = SingleKnown

MOIU.canonicalize!(f::Union{SingleDecision, SingleKnown, VectorOfDecisions, VectorOfKnowns}) = f

function MOIU.filter_variables(keep::Function, f::SingleDecision)
    if !keep(f.decision)
        error("Cannot remove decision from a `SingleDecision` function of the",
              " same decision.")
    end
    return f
end

function MOIU.filter_variables(keep::Function, f::SingleKnown)
    if !keep(f.known)
        error("Cannot remove known from a `SingleKnown` function of the",
              " same known decision.")
    end
    return f
end

function MOIU.filter_variables(keep::Function, f::VectorOfDecisions)
    return VectorOfDecisions(MOIU._filter_variables(keep, f.decisions))
end

function MOIU.filter_variables(keep::Function, f::VectorOfKnowns)
    return VectorOfKnowns(MOIU._filter_variables(keep, f.knowns))
end

function MOIU.vectorize(funcs::AbstractVector{SingleDecision})
    decisions = MOI.VariableIndex[f.decision for f in funcs]
    return VectorOfDecisions(vars)
end

function MOIU.vectorize(funcs::AbstractVector{SingleKnown})
    knowns = MOI.VariableIndex[f.known for f in funcs]
    return VectorOfKnowns(knowns)
end

function MOIU.scalarize(f::VectorOfDecisions, ignore_constants::Bool = false)
    SingleDecision.(f.decisions)
end

function MOIU.scalarize(f::VectorOfKnowns, ignore_constants::Bool = false)
    SingleKnown.(f.knowns)
end
