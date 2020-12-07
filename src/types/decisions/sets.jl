# Helper structs to dispatch known decision variable construction
struct NoSpecifiedConstraint <: MOI.AbstractSet end
Base.copy(set::NoSpecifiedConstraint) = set

struct DecisionSet <: MOI.AbstractScalarSet
    stage::Int
    constraint::Union{MOI.AbstractSet, JuMP.AbstractVectorSet}
    is_recourse::Bool

    function DecisionSet(stage::Integer; constraint::Union{MOI.AbstractSet, JuMP.AbstractVectorSet} = NoSpecifiedConstraint(), is_recourse::Bool = false)
        return new(stage, constraint, is_recourse)
    end
end
struct KnownSet <: MOI.AbstractScalarSet
    stage::Int
end

struct SingleDecisionSet{T} <: MOI.AbstractScalarSet
    stage::Int
    decision::Decision{T}
    constraint::MOI.AbstractSet
    is_recourse::Bool
end
Base.copy(set::SingleDecisionSet) = reuse(set, set.decision)

struct SingleKnownSet{T} <: MOI.AbstractScalarSet
    stage::Int
    known::Decision{T}
end
Base.copy(set::SingleKnownSet) = reuse(set, set.known)

set_constraint(set::SingleDecisionSet) = set.constraint
set_constraint(::SingleKnownSet) = NoSpecifiedConstraint()

struct FreeDecision <: MOI.AbstractScalarSet end
Base.copy(set::FreeDecision) = set

struct MultipleDecisionSet{T} <: MOI.AbstractVectorSet
    stage::Int
    decisions::Vector{Decision{T}}
    constraint::MOI.AbstractSet
    is_recourse::Bool
end
MOI.dimension(set::MultipleDecisionSet) = length(set.decisions)
Base.copy(set::MultipleDecisionSet) = reuse(set, set.decisions)

struct MultipleKnownSet{T} <: MOI.AbstractVectorSet
    stage::Int
    knowns::Vector{Decision{T}}
end
MOI.dimension(set::MultipleKnownSet) = length(set.knowns)
Base.copy(set::MultipleKnownSet) = reuse(set, set.knowns)

MOIU.variable_function_type(::Type{<:SingleDecisionSet}) = SingleDecision
MOIU.variable_function_type(::Type{<:MultipleDecisionSet}) = VectorOfDecisions
MOIU.variable_function_type(::Type{<:SingleKnownSet}) = SingleKnown
MOIU.variable_function_type(::Type{<:MultipleKnownSet}) = VectorOfKnowns

is_decision_type(::Type{SingleDecisionSet}) = true
is_decision_type(::Type{MultipleDecisionSet}) = false

function JuMP.in_set_string(print_mode, set::SingleDecisionSet)
    decision_str(set) = set.is_recourse ? "RecourseDecisions" : "Decisions"
    if state(set.decision) == Taken
        return string(JuMP._math_symbol(print_mode, :in), " $(decision_str(set))(value = $(set.decision.value))")
    end
    if set.constraint isa NoSpecifiedConstraint
        return string(JuMP._math_symbol(print_mode, :in), " $(decision_str(set))")
    else
        return string(JuMP._math_symbol(print_mode, :in), " $(decision_str(set))($(JuMP.in_set_string(print_mode, set.constraint)))")
    end
end

function JuMP.in_set_string(print_mode, set::SingleKnownSet)
    return string(JuMP._math_symbol(print_mode, :in), " Known(value = $(set.known.value))")
end

function JuMP.in_set_string(print_mode, set::MultipleDecisionSet)
    decision_str(set) = set.is_recourse ? "RecourseDecisions" : "Decisions"
    if all(d -> state(d) == Taken, set.decisions)
        return string(JuMP._math_symbol(print_mode, :in), " $(decision_str(set))(values = $([d.value for d in set.decisions]))")
    end
    if set.constraint isa NoSpecifiedConstraint
        return string(JuMP._math_symbol(print_mode, :in), " $(decision_str(set))")
    else
        return string(JuMP._math_symbol(print_mode, :in), " $(decision_str(set))($(JuMP.in_set_string(print_mode, set.constraint)))")
    end
end

function JuMP.in_set_string(print_mode, set::MultipleKnownSet)
    return string(JuMP._math_symbol(print_mode, :in), " Known(values = $([k.value for k in set.knowns]))")
end

function reuse(set::SingleDecisionSet, decision::Decision)
    return SingleDecisionSet(set.stage, decision, copy(set.constraint), set.is_recourse)
end

function reuse(set::SingleKnownSet, decision::Decision)
    return SingleKnownSet(set.stage, decision)
end

function reuse(set::MultipleDecisionSet, decisions::Vector{<:Decision})
    return MultipleDecisionSet(set.stage, decisions, copy(set.constraint), set.is_recourse)
end

function reuse(set::MultipleKnownSet, decisions::Vector{<:Decision})
    return MultipleKnownSet(set.stage, decisions)
end

function VariableRef(model::Model, index::MOI.VariableIndex, ::Union{SingleDecisionSet, MultipleDecisionSet})
    return DecisionRef(model, index)
end

function VariableRef(model::Model, index::MOI.VariableIndex, ::Union{SingleKnownSet, MultipleKnownSet})
    return KnownRef(model, index)
end

function set(variable::JuMP.ScalarVariable, ::Type{DecisionRef}, stage::Integer, constraint::MOI.AbstractSet, is_recourse::Bool)
    return SingleDecisionSet(stage, Decision(variable.info, Float64), constraint, is_recourse)
end

function set(variable::JuMP.ScalarVariable, ::Type{KnownRef}, stage::Integer, ::NoSpecifiedConstraint, is_recourse::Bool)
    return SingleKnownSet(stage, KnownDecision(variable.info, Float64))
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
