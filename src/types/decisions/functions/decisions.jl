struct SingleDecision <: MOI.AbstractScalarFunction
    decision::MOI.VariableIndex
end

struct VectorOfDecisions <: MOI.AbstractVectorFunction
    decisions::Vector{MOI.VariableIndex}
end
output_dimension(f::VectorOfDecisions) = length(f.decisions)

# Base overrides #
# ========================== #
Base.copy(f::SingleDecision) = f
Base.copy(f::VectorOfDecisions) = VectorOfDecisions(copy(f.decisions))

Base.iszero(::SingleDecision) = false
Base.isone(::SingleDecision) = false

# JuMP overrides #
# ========================== #
function DecisionRef(model::Model, f::SingleDecision)
    return DecisionRef(model, f.decision)
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

VectorOfDecisions(dvars::Vector{DecisionRef}) = VectorOfDecisions(index.(dvars))
function JuMP.moi_function(decisions::Vector{<:DecisionRef})
    return VectorOfDecisions(decisions)
end
function JuMP.moi_function_type(::Type{<:Vector{<:DecisionRef}})
    return VectorOfDecisions
end

# MOI Function interface #
# ========================== #
MOI.constant(f::SingleDecision, T::DataType) = zero(T)

MOIU.variable_function_type(::Type{<:SingleDecisionSet}) = SingleDecision
MOIU.variable_function_type(::Type{<:MultipleDecisionsSet}) = VectorOfDecisions

MOIU.eval_variables(varval::Function, f::SingleDecision) = varval(f.variable)

function MOIU.map_indices(index_map::Function, f::SingleDecision)
    return SingleDecision(index_map(f.decision))
end
function map_indices(index_map::Function, f::VectorOfDecisions)
    return VectorOfDecisions(index_map.(f.decisions))
end

function Base.getindex(it::MOIU.ScalarFunctionIterator{VectorOfDecisions},
                       i::Integer)
    return SingleDecision(it.f.decisions[i])
end
function Base.getindex(it::MOIU.ScalarFunctionIterator{VectorOfDecisions},
                       I::AbstractVector)
    return VectorOfDecisions(it.f.decisions[I])
end

MOIU.scalar_type(::Type{VectorOfDecisions}) = SingleDecision

function filter_variables(keep::Function, f::SingleDecision)
    if !keep(f.decision)
        error("Cannot remove decision from a `SingleDecision` function of the",
              " same decision.")
    end
    return f
end

function filter_variables(keep::Function, f::VectorOfDecisions)
    return VectorOfDecisions(MOIU._filter_variables(keep, f.decisions))
end

function MOIU.vectorize(funcs::AbstractVector{SingleDecision})
    decisions = MOI.VariableIndex[f.decision for f in funcs]
    return VectorOfDecisions(vars)
end

function MOIU.scalarize(f::VectorOfDecisions, ignore_constants::Bool = false)
    SingleDecision.(f.decisions)
end
