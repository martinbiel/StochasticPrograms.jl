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

function Decision(value, ::Type{T}) where T
    return Decision(Taken, T(value))
end

function Decision(info::JuMP.VariableInfo, ::Type{T}) where T
    if info.has_fix
        return Decision(Taken, T(info.fixed_value))
    end
    return Decision(NotTaken, T(NaN))
end

Base.copy(decision::Decision) = Decision(decision.state, decision.value)

function KnownDecision(info::JuMP.VariableInfo, ::Type{T}) where T
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
    return Decision(Taken, value)
end

# Decisions #
# ========================== #
struct IgnoreDecisions end

struct Decisions
    decisions::Dict{MOI.VariableIndex, Decision{Float64}}
    undecided::Vector{MOI.VariableIndex}
    knowns::Vector{MOI.VariableIndex}

    function Decisions()
        return new(Dict{MOI.VariableIndex, Decision{Float64}}(),
                   Vector{MOI.VariableIndex}(),
                   Vector{MOI.VariableIndex}())
    end
end

has_decision(decisions::Decisions, index::MOI.VariableIndex) = haskey(decisions.decisions, index)
decision(decisions::Decisions, index::MOI.VariableIndex) = decisions.decisions[index]
decision_value(decisions::Decisions, index::MOI.VariableIndex) = decision_value(decision(decisions, index))

function set_decision!(decisions::Decisions, index::MOI.VariableIndex, decision::Decision)
    if !haskey(decisions.decisions, index)
        push!(decisions.undecided, index)
    end
    decisions.decisions[index] = decision
    return nothing
end

function remove_decision!(decisions::Decisions, index::MOI.VariableIndex)
    if !haskey(decisions.decisions, index)
        return nothing
    end
    i = something(findfirst(i -> i == index, decisions.undecided), 0)
    if iszero(i)
        error("Decision at index $index exists in set of decisions, but has not been properly added through `set_decision!`.")
    end
    deleteat!(decisions.undecided, i)
    delete!(decisions.decisions, index)
    return nothing
end

function set_known_decision!(decisions::Decisions, index::MOI.VariableIndex, decision::Decision)
    if !haskey(decisions.decisions, index)
        push!(decisions.knowns, index)
    end
    decisions.decisions[index] = decision
    return nothing
end

function remove_known_decision!(decisions::Decisions, index::MOI.VariableIndex)
    if !haskey(decisions.decisions, index)
        return nothing
    end
    i = something(findfirst(i -> i == index, decisions.knowns), 0)
    if iszero(i)
        error("Known decision at index $index exists in set of decisions, but has not been properly added through `set_known_decision!`.")
    end
    deleteat!(decisions.knowns, i)
    delete!(decisions.decisions, index)
    return nothing
end

function all_decisions(decisions::Decisions)
    return map(decisions.undecided) do index
        decisions.decisions[index]
    end
end

function all_known_decisions(decisions::Decisions)
    return map(decisions.knowns) do index
        decisions.decisions[index]
    end
end

function num_decisions(decisions::Decisions)
    return length(decisions.undecided)
end

function num_known_decisions(decisions::Decisions)
    return length(decisions.knowns)
end

function untake_decisions!(decisions::Decisions)
    need_update = false
    # Update states and values
    for decision in all_decisions(decisions)
        if decision.state != NotTaken
            decision.state = NotTaken
            need_update |= true
        end
    end
    return need_update
end

function take_decisions!(decisions::Decisions, x::AbstractVector)
    # Check decision length
    num_decisions(decisions) == length(x) || error("Given decision of length $(length(x)) not compatible with number of defined decision variables $(num_decisions(decisions)).")
    # Update states and values (assume x given in sorted order)
    for (decision, val) in zip(all_decisions(decisions), x)
        decision.state = Taken
        decision.value = val
    end
    return nothing
end

function update_known_decisions!(decisions::Decisions, x::AbstractVector)
    # Check decision length
    num_known_decisions(decisions) == length(x) || error("Given decision of length $(length(x)) not compatible with number of defined known decision variables $(num_known_decisions(decisions)).")
    # Update values (assume x given in sorted order)
    for (decision, val) in zip(all_known_decisions(decisions), x)
        decision.value = val
    end
    return nothing
end

include("variable_interface.jl")
include("expressions/expressions.jl")
include("functions/functions.jl")
include("sets.jl")
include("modifications.jl")
include("bridges/bridges.jl")
include("macros.jl")
include("updates.jl")
include("moi_overrides.jl")
