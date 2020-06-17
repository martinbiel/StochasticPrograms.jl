# Helper struct to dispatch known decision variable construction
struct DecisionSet <: MOI.AbstractScalarSet end
struct KnownSet <: MOI.AbstractScalarSet end

struct SingleDecisionSet{T} <: MOI.AbstractScalarSet
    decision::Decision{T}
end

struct SingleKnownSet{T} <: MOI.AbstractScalarSet
    known::Decision{T}
end

struct FreeDecision <: MOI.AbstractScalarSet end

struct MultipleDecisionSet{T} <: MOI.AbstractVectorSet
    decisions::Vector{Decision{T}}
end
MOI.dimension(set::MultipleDecisionSet) = length(set.decisions)

struct MultipleKnownSet{T} <: MOI.AbstractVectorSet
    knowns::Vector{Decision{T}}
end
MOI.dimension(set::MultipleKnownSet) = length(set.knowns)

MOIU.variable_function_type(::Type{<:SingleDecisionSet}) = SingleDecision
MOIU.variable_function_type(::Type{<:MultipleDecisionSet}) = VectorOfDecisions
MOIU.variable_function_type(::Type{<:SingleKnownSet}) = SingleKnown
MOIU.variable_function_type(::Type{<:MultipleKnownSet}) = VectorOfKnowns

function JuMP.in_set_string(print_mode, ::SingleDecisionSet)
    return string(JuMP._math_symbol(print_mode, :in), " Decisions")
end

function JuMP.in_set_string(print_mode, ::SingleKnownSet)
    return string(JuMP._math_symbol(print_mode, :in), " Known")
end

function JuMP.in_set_string(print_mode, ::MultipleDecisionSet)
    return string(JuMP._math_symbol(print_mode, :in), " Decisions")
end

function JuMP.in_set_string(print_mode, ::MultipleKnownSet)
    return string(JuMP._math_symbol(print_mode, :in), " Known")
end

function VariableRef(model::Model, index::MOI.VariableIndex, ::Union{SingleDecisionSet, MultipleDecisionSet})
    return DecisionRef(model, index)
end

function VariableRef(model::Model, index::MOI.VariableIndex, ::Union{SingleKnownSet, MultipleKnownSet})
    return KnownRef(model, index)
end

function set(variable::JuMP.ScalarVariable, ::Type{DecisionRef})
    return SingleDecisionSet(Decision(variable.info, Float64))
end

function set(variable::JuMP.ScalarVariable, ::Type{KnownRef})
    return SingleKnownSet(KnownDecision(variable.info, Float64))
end

function set_decision!(decisions::Decisions, index::MOI.VariableIndex, set::SingleDecisionSet)
    set_decision!(decisions, index, set.decision)
    return nothing
end

function set_decision!(decisions::Decisions, index::MOI.VariableIndex, set::SingleKnownSet)
    set_known_decision!(decisions, index, set.known)
    return nothing
end

function set_decision!(decisions::Decisions, index::MOI.VariableIndex, set_index::Int, set::MultipleDecisionSet)
    set_decision!(decisions, index, set.decisions[set_index])
    return nothing
end

function set_decision!(decisions::Decisions, index::MOI.VariableIndex, set_index::Int, set::MultipleKnownSet)
    set_known_decision!(decisions, index, set.knowns[set_index])
    return nothing
end
