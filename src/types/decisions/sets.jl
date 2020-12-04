# Helper structs to dispatch known decision variable construction
struct NoSpecifiedConstraint <: MOI.AbstractSet end
Base.copy(set::NoSpecifiedConstraint) = set

struct DecisionSet{S <: MOI.AbstractSet} <: MOI.AbstractScalarSet
    constraint::S

    function DecisionSet(; constraint::MOI.AbstractSet = NoSpecifiedConstraint())
        S = typeof(constraint)
        return new{S}(constraint)
    end
end
struct KnownSet <: MOI.AbstractScalarSet end

struct SingleDecisionSet{T, S} <: MOI.AbstractScalarSet
    decision::Decision{T}
    constraint::S
end
Base.copy(set::SingleDecisionSet) = reuse(set, set.decision)

struct SingleKnownSet{T} <: MOI.AbstractScalarSet
    known::Decision{T}
end
Base.copy(set::SingleKnownSet) = reuse(set, set.known)

set_constraint(set::SingleDecisionSet) = set.constraint
set_constraint(::SingleKnownSet) = NoSpecifiedConstraint()

struct FreeDecision <: MOI.AbstractScalarSet end
Base.copy(set::FreeDecision) = set

struct MultipleDecisionSet{T, S} <: MOI.AbstractVectorSet
    decisions::Vector{Decision{T}}
    constraint::S
end
MOI.dimension(set::MultipleDecisionSet) = length(set.decisions)
Base.copy(set::MultipleDecisionSet) = reuse(set, set.decisions)

struct MultipleKnownSet{T} <: MOI.AbstractVectorSet
    knowns::Vector{Decision{T}}
end
MOI.dimension(set::MultipleKnownSet) = length(set.knowns)
Base.copy(set::MultipleKnownSet) = reuse(set, set.knowns)

MOIU.variable_function_type(::Type{<:SingleDecisionSet}) = SingleDecision
MOIU.variable_function_type(::Type{<:MultipleDecisionSet}) = VectorOfDecisions
MOIU.variable_function_type(::Type{<:SingleKnownSet}) = SingleKnown
MOIU.variable_function_type(::Type{<:MultipleKnownSet}) = VectorOfKnowns

function JuMP.in_set_string(print_mode, set::SingleDecisionSet)
    if set.constraint == NoSpecifiedConstraint()
        return string(JuMP._math_symbol(print_mode, :in), " Decisions")
    else
        return string(JuMP._math_symbol(print_mode, :in), " Decisions($(JuMP.in_set_string(print_mode, set.constraint)))")
    end
end

function JuMP.in_set_string(print_mode, set::SingleKnownSet)
    return string(JuMP._math_symbol(print_mode, :in), " Known(value = $(set.known.value))")
end

function JuMP.in_set_string(print_mode, set::MultipleDecisionSet)
    if set.constraint == NoSpecifiedConstraint()
        return string(JuMP._math_symbol(print_mode, :in), " Decisions")
    else
        return string(JuMP._math_symbol(print_mode, :in), " Decisions($(JuMP.in_set_string(print_mode, set.constraint)))")
    end
end

function JuMP.in_set_string(print_mode, set::MultipleKnownSet)
    return string(JuMP._math_symbol(print_mode, :in), " Known(values = $([k.value for k in set.knowns]))")
end

function reuse(set::SingleDecisionSet, decision::Decision)
    return SingleDecisionSet(decision, copy(set.constraint))
end

function reuse(set::SingleKnownSet, decision::Decision)
    return SingleKnownSet(decision)
end

function reuse(set::MultipleDecisionSet, decisions::Vector{<:Decision})
    return MultipleDecisionSet(decisions, copy(set.constraint))
end

function reuse(set::MultipleKnownSet, decisions::Vector{<:Decision})
    return MultipleKnownSet(decisions)
end

function VariableRef(model::Model, index::MOI.VariableIndex, ::Union{SingleDecisionSet, MultipleDecisionSet})
    return DecisionRef(model, index)
end

function VariableRef(model::Model, index::MOI.VariableIndex, ::Union{SingleKnownSet, MultipleKnownSet})
    return KnownRef(model, index)
end

function set(variable::JuMP.ScalarVariable, ::Type{DecisionRef}, constraint::MOI.AbstractSet)
    return SingleDecisionSet(Decision(variable.info, Float64), constraint)
end

function set(variable::JuMP.ScalarVariable, ::Type{KnownRef}, ::NoSpecifiedConstraint)
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
