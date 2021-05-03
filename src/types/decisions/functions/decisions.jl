struct SingleDecision <: MOI.AbstractScalarFunction
    decision::MOI.VariableIndex
end

struct VectorOfDecisions <: MOI.AbstractVectorFunction
    decisions::Vector{MOI.VariableIndex}
end
MOI.output_dimension(f::VectorOfDecisions) = length(f.decisions)

# Base overrides #
# ========================== #
Base.copy(f::SingleDecision) = f
Base.copy(f::VectorOfDecisions) = VectorOfDecisions(copy(f.decisions))

Base.iszero(::SingleDecision) = false
Base.isone(::SingleDecision) = false

function Base.:(==)(f::VectorOfDecisions, g::VectorOfDecisions)
    return f.decisions == g.decisions
end

function Base.isapprox(f::Union{SingleDecision,VectorOfDecisions},
                       g::Union{SingleDecision,VectorOfDecisions};
                       kwargs...)
    return f == g
end

function Base.convert(::Type{MOI.ScalarAffineFunction{T}},
                      f::SingleDecision) where T
    return MOI.ScalarAffineFunction{T}(MOI.SingleVariable(f.decision))
end

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

is_decision_type(::Type{SingleDecision}) = true

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

is_decision_type(::Type{VectorOfDecisions}) = true

# MOI Function interface #
# ========================== #
MOI.constant(f::SingleDecision, T::DataType) = zero(T)

function MOIU.eval_variables(varval::Function, f::SingleDecision)
    return varval(f.decision)
end
function MOIU.eval_variables(varval::Function, f::VectorOfDecisions)
    return varval.(f.decisions)
end

function MOIU.map_indices(index_map::Function, f::SingleDecision)
    return SingleDecision(index_map(f.decision))
end
function MOIU.map_indices(index_map::Function, f::VectorOfDecisions)
    return VectorOfDecisions(index_map.(f.decisions))
end

function Base.getindex(it::MOIU.ScalarFunctionIterator{VectorOfDecisions},
                       output_index::Integer)
    return SingleDecision(it.f.decisions[output_index])
end
function Base.getindex(it::MOIU.ScalarFunctionIterator{VectorOfDecisions},
                       output_indices::AbstractVector)
    return VectorOfDecisions(it.f.decisions[output_indices])
end

Base.eltype(it::MOIU.ScalarFunctionIterator{VectorOfDecisions}) = SingleDecision

MOIU.scalar_type(::Type{VectorOfDecisions}) = SingleDecision

MOIU.canonicalize!(f::Union{SingleDecision, VectorOfDecisions}) = f

function MOIU.filter_variables(keep::Function, f::SingleDecision)
    if !keep(f.decision)
        error("Cannot remove decision from a `SingleDecision` function of the",
              " same decision.")
    end
    return f
end

function MOIU.filter_variables(keep::Function, f::VectorOfDecisions)
    return VectorOfDecisions(MOIU._filter_variables(keep, f.decisions))
end

function MOIU.vectorize(funcs::AbstractVector{SingleDecision})
    decisions = MOI.VariableIndex[f.decision for f in funcs]
    return VectorOfDecisions(decisions)
end

function MOIU.scalarize(f::VectorOfDecisions, ignore_constants::Bool = false)
    SingleDecision.(f.decisions)
end
