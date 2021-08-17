# MIT License
#
# Copyright (c) 2018 Martin Biel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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

set_constraint(set::SingleDecisionSet) = set.constraint

struct MultipleDecisionSet{T} <: MOI.AbstractVectorSet
    stage::Int
    decisions::Vector{Decision{T}}
    constraint::MOI.AbstractSet
    is_recourse::Bool
end
MOI.dimension(set::MultipleDecisionSet) = length(set.decisions)
Base.copy(set::MultipleDecisionSet) = reuse(set, set.decisions)

MOIU.variable_function_type(::Type{<:SingleDecisionSet}) = SingleDecision
MOIU.variable_function_type(::Type{<:MultipleDecisionSet}) = VectorOfDecisions

is_decision_type(::Type{SingleDecisionSet}) = true
is_decision_type(::Type{MultipleDecisionSet}) = false

function JuMP.in_set_string(print_mode, set::SingleDecisionSet)
    decision_str(set) = set.is_recourse ? "RecourseDecisions" : "Decisions"
    if state(set.decision) == Taken
        return string(JuMP._math_symbol(print_mode, :in), " $(decision_str(set))(value = $(set.decision.value))")
    end
    if state(set.decision) == Known
        return string(JuMP._math_symbol(print_mode, :in), " Known(value = $(set.decision.value))")
    end
    if set.constraint isa NoSpecifiedConstraint
        return string(JuMP._math_symbol(print_mode, :in), " $(decision_str(set))")
    else
        return string(JuMP._math_symbol(print_mode, :in), " $(decision_str(set))($(JuMP.in_set_string(print_mode, set.constraint)))")
    end
end

function JuMP.in_set_string(print_mode, set::MultipleDecisionSet)
    decision_str(set) = set.is_recourse ? "RecourseDecisions" : "Decisions"
    if all(d -> state(d) == Taken, set.decisions)
        return string(JuMP._math_symbol(print_mode, :in), " $(decision_str(set))(values = $([d.value for d in set.decisions]))")
    end
    if all(d -> state(d) == Known, set.decisions)
        return string(JuMP._math_symbol(print_mode, :in), " Known(values = $([d.value for d in set.decisions]))")
    end
    if set.constraint isa NoSpecifiedConstraint
        return string(JuMP._math_symbol(print_mode, :in), " $(decision_str(set))")
    else
        return string(JuMP._math_symbol(print_mode, :in), " $(decision_str(set))($(JuMP.in_set_string(print_mode, set.constraint)))")
    end
end

function reuse(set::SingleDecisionSet, decision::Decision)
    return SingleDecisionSet(set.stage, decision, copy(set.constraint), set.is_recourse)
end

function reuse(set::MultipleDecisionSet, decisions::Vector{<:Decision})
    return MultipleDecisionSet(set.stage, decisions, copy(set.constraint), set.is_recourse)
end

function decision_set(variable::JuMP.ScalarVariable, set::DecisionSet)
    return SingleDecisionSet(set.stage, Decision(variable.info, Float64), set.constraint, set.is_recourse)
end

function decision_set(variables::Vector{<:JuMP.ScalarVariable}, set::DecisionSet)
    decisions = map(variables) do variable
        Decision(variable.info, Float64)
    end
    if set.constraint isa JuMP.AbstractVectorSet
        return MultipleDecisionSet(set.stage,
                                   decisions,
                                   JuMP.moi_set(set.constraint, length(variables)),
                                   set.is_recourse)
    else
        return MultipleDecisionSet(set.stage,
                                   decisions,
                                   set.constraint,
                                   set.is_recourse)
    end
end

function decision_set(variables::Matrix{<:JuMP.ScalarVariable}, set::DecisionSet)
    decisions = map(variables) do variable
        Decision(variable.info, Float64)
    end
    if set.constraint isa JuMP.AbstractVectorSet
        return MultipleDecisionSet(set.stage,
                                   decisions,
                                   JuMP.moi_set(set.constraint, length(variables)),
                                   set.is_recourse)
    else
        return MultipleDecisionSet(set.stage,
                                   decisions,
                                   set.constraint,
                                   set.is_recourse)
    end
end

function decision_set(variable::JuMP.ScalarVariable, set::KnownSet)
    return SingleDecisionSet(set.stage, KnownDecision(variable.info, Float64), NoSpecifiedConstraint(), false)
end

function decision_set(variables, set::KnownSet)
    decisions = map(variables) do variable
        KnownDecision(variable.info, Float64)
    end
    return MultipleDecisionSet(set.stage,
                               decisions,
                               NoSpecifiedConstraint(),
                               false)
end
