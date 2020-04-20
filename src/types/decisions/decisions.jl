const CleverDicts = MOI.Utilities.CleverDicts
const CleverDict = CleverDicts.CleverDict

# Decision #
# ========================== #
@enum DecisionState NotTaken Taken

mutable struct Decision{T}
    state::DecisionState
    value::T
end
state(decision::Decision) = decision.state
decision_value(decision::Decision) = state(decision) == NotTaken ? NaN : decision.value

function Decision{T}(info::JuMP.VariableInfo) where T
    if info.has_fix
        return Decision(Taken, T(info.fixed_value))
    end
    return Decision(NotTaken, T(NaN))
end

# KnownDecision #
# ========================== #
mutable struct KnownDecision{T}
    name::String
    value::T
end
name(known::KnownDecision) = known.name
known_value(known::KnownDecision) = known.value

function KnownDecision{T}(info::JuMP.VariableInfo) where T
    value = if info.has_fix
        # Value fixed at construction
        T(info.fixed_value)
    else
        # Value is known, but not yet set. Pick a feasible value for now
        value = if info.has_lb
            T(info.lower_bound)
        elseif info.has_ub
            T(info.upper_bound)
        else
            zero(T)
        end
    end
    return KnownDecision("", value)
end

# Decisions #
# ========================== #
struct IgnoreDecisions end

struct Decisions
    decisions::Dict{MOI.VariableIndex, Decision{Float64}}
    known_decisions::CleverDict{MOI.VariableIndex, KnownDecision{Float64}}
    name_index::Dict{String, MOI.VariableIndex}

    function Decisions()
        return new(Dict{MOI.VariableIndex, Decision{Float64}}(),
                   CleverDict{MOI.VariableIndex, KnownDecision{Float64}}(),
                   Dict{String, MOI.VariableIndex}())
    end
end

# Decisions
has_decision(decisions::Decisions, index::MOI.VariableIndex) = haskey(decisions.decisions, index)

decision(decisions::Decisions, index::MOI.VariableIndex) = decisions.decisions[index]
decision_value(decisions::Decisions, index::MOI.VariableIndex) = decision_value(decision(decisions, index))

function set_decision!(decisions::Decisions, index::MOI.VariableIndex, decision::Decision)
    decisions.decisions[index] = decision
end

function all_decisions(decisions::Decisions)
    return values(decisions.decisions)
end

function num_decisions(decisions::Decisions)
    return length(decisions.decisions)
end

# Known decision
has_known_decision(decisions::Decisions, index::MOI.VariableIndex) = haskey(decisions.known_decisions, index)

known_decision(decisions::Decisions, index::MOI.VariableIndex) = decisions.known_decisions[index]
known_value(decisions::Decisions, index::MOI.VariableIndex) = known_value(known_decision(decisions, index))

function add_known!(decisions::Decisions, known_decision::KnownDecision, name::String)
    index = if haskey(decisions.name_index, name)
        # If known decision variable has already been added, return it
        index = decisions.name_index[name]
    else
        # Rely on CleverDicts to get new variable index
        index = CleverDicts.add_item(decisions.known_decisions, known_decision)
    end
    # Add to name index if name not empty
    if !isempty(name)
        decisions.name_index[name] = index
    end
    # Finally, return the index
    return index
end

function all_known_decisions(decisions::Decisions)
    return values(decisions.known_decisions)
end

function num_known_decisions(decisions::Decisions)
    return length(decisions.known_decisions)
end

function untake_decisions!(decisions::Decisions)
    # Check decision length
    num_decisions(decisions) == length(x) || error("Given decision of length $(length(x)) not compatible with number of defined decision variables $(num_decisions(decisions)).")
    need_update = false
    # Update states and values
    for (k,d) in decisions.decisions
        if d.state != NotTaken
            d.state = NotTaken
            need_update |= true
        end
    end
    return need_update
end

function take_decisions!(decisions::Decisions, x::AbstractVector)
    # Check decision length
    num_decisions(decisions) == length(x) || error("Given decision of length $(length(x)) not compatible with number of defined decision variables $(num_decisions(decisions)).")
    # Assume x has been given in sorted order
    indices = sort!(collect(keys(decisions.decisions)), by = idx -> idx.value)
    # Update states and values
    for (i, val) in enumerate(x)
        d = decision(decisions, indices[i])
        d.state = Taken
        d.value = val
    end
    return nothing
end

function update_known_decisions!(decisions::Decisions, x::AbstractVector)
    # Check decision length
    num_known_decisions(decisions) == length(x) || error("Given decision of length $(length(x)) not compatible with number of defined known decision variables $(num_known_decisions(decisions)).")
    # Assume x has been given in sorted order
    indices = sort!(collect(keys(decisions.known_decisions)), by = idx -> idx.value)
    # Update values
    for (i, val) in enumerate(x)
        d = known_decision(decisions, indices[i])
        d.value = val
    end
    return nothing
end

# Sets #
# ========================== #
struct DecisionSet <: MOI.AbstractScalarSet end

struct SingleDecisionSet{T} <: MOI.AbstractScalarSet
    decision::Decision{T}
end

struct MultipleDecisionsSet{T} <: MOI.AbstractVectorSet
    decisions::Vector{Decision{T}}
end
MOI.dimension(set::MultipleDecisionsSet) = length(set.decisions)

function JuMP.in_set_string(print_mode, ::SingleDecisionSet)
    return string(JuMP._math_symbol(print_mode, :in), " Decisions")
end

function JuMP.in_set_string(print_mode, ::MultipleDecisionsSet)
    return string(JuMP._math_symbol(print_mode, :in), " Decisions")
end

# Modifications #
# ========================== #
struct DecisionCoefficientChange{T} <: MOI.AbstractFunctionModification
    decision::MOI.VariableIndex
    new_coefficient::T
end

struct KnownCoefficientChange{T} <: MOI.AbstractFunctionModification
    known::MOI.VariableIndex
    new_coefficient::T
    known_value::T
end

struct DecisionStateChange{T} <: MOI.AbstractFunctionModification
    decision::MOI.VariableIndex
    new_state::DecisionState
    value_difference::T
end

struct DecisionsStateChange <: MOI.AbstractFunctionModification end

struct KnownValueChange{T} <: MOI.AbstractFunctionModification
    known::MOI.VariableIndex
    value_difference::T
end

struct KnownValuesChange{T} <: MOI.AbstractFunctionModification
    known_decisions::CleverDict{MOI.VariableIndex, KnownDecision{T}}
end

const DecisionModification = Union{DecisionCoefficientChange, KnownCoefficientChange,
                                   DecisionStateChange, DecisionsStateChange,
                                   KnownValueChange, KnownValuesChange}

include("variable_interface.jl")
include("expressions/expressions.jl")
include("functions/functions.jl")
include("bridges/bridges.jl")
include("macros.jl")
include("updates.jl")
include("moi_overrides.jl")
