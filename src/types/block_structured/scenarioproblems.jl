struct ScenarioProblems{S <: AbstractScenario} <: AbstractScenarioProblems{S}
    scenarios::Vector{S}
    problems::Vector{JuMP.Model}

    function ScenarioProblems(scenarios::Vector{S}) where S <: AbstractScenario
        # ScenarioProblems are initialized without any subproblems.
        # These are added during generation.
        return new{S}(scenarios, Vector{JuMP.Model}())
    end
end
ScenarioProblemChannel{S} = RemoteChannel{Channel{ScenarioProblems{S}}}
DecisionChannel = RemoteChannel{Channel{DecisionMap}}
struct DistributedScenarioProblems{S <: AbstractScenario} <: AbstractScenarioProblems{S}
    scenario_distribution::Vector{Int}
    scenarioproblems::Vector{ScenarioProblemChannel{S}}
    decisions::Vector{DecisionChannel}

    function DistributedScenarioProblems(scenario_distribution::Vector{Int},
                                         scenarioproblems::Vector{ScenarioProblemChannel{S}},
                                         decisions::Vector{DecisionChannel}) where S <: AbstractScenario
        return new{S}(scenario_distribution, scenarioproblems, decisions)
    end
end

function DistributedScenarioProblems(_scenarios::Vector{S}) where S <: AbstractScenario
    scenarioproblems = Vector{ScenarioProblemChannel{S}}(undef, nworkers())
    decisions = Vector{DecisionChannel}(undef, nworkers())
    (nscen, extra) = divrem(length(_scenarios), nworkers())
    start = 1
    stop = nscen + (extra > 0)
    scenario_distribution = zeros(Int, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            n = nscen + (extra > 0)
            scenarioproblems[i] = RemoteChannel(() -> Channel{ScenarioProblems{S}}(1), w)
            decisions[i] = RemoteChannel(() -> Channel{DecisionMap}(1), w)
            scenario_range = start:stop
            @async remotecall_fetch(
                w,
                scenarioproblems[i],
                _scenarios[scenario_range]) do sp, scenarios
                    put!(sp, ScenarioProblems(scenarios))
                end
            @async remotecall_fetch(
                w,
                decisions[i]) do channel
                    put!(channel, DecisionMap())
                end
            scenario_distribution[i] = n
            start = stop + 1
            stop += n
            stop = min(stop, length(_scenarios))
            extra -= 1
        end
    end
    return DistributedScenarioProblems(scenario_distribution, scenarioproblems, decisions)
end

ScenarioProblems(::Type{S}, instantiation) where S <: AbstractScenario = ScenarioProblems(Vector{S}(), instantiation)

function ScenarioProblems(scenarios::Vector{S}, ::Union{Vertical, Horizontal}) where S <: AbstractScenario
    ScenarioProblems(scenarios)
end

function ScenarioProblems(scenarios::Vector{S}, ::Union{DistributedVertical, DistributedHorizontal}) where S <: AbstractScenario
    DistributedScenarioProblems(scenarios)
end

# Distributed helper functions #
# ========================== #
function get_from_scenarioproblem(getter::Function, scenarioproblems::ScenarioProblems, scenario_index::Integer, args...)
    return getter(scenarioproblems, scenario_index, args...)
end
function get_from_scenarioproblem(getter::Function, scenarioproblems::DistributedScenarioProblems, scenario_index::Integer, args...)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    j = 0
    for w in workers()
        n = scenarioproblems.scenario_distribution[w-1]
        if scenario_index <= n + j
            return remotecall_fetch(getter, w, scenarioproblems[w-1], scenario_index - j, args...)
        end
        j += n
    end
    throw(BoundsError(scenarioproblems, scenario_index))
end
function get_from_scenarioproblems(getter::Function, scenarioproblems::ScenarioProblems, op::Function, partial_values, args...)
    return reduce(op, getter(scenarioproblems, args...))
end
function get_from_scenarioproblems(getter::Function, scenarioproblems::DistributedScenarioProblems, op::Function, partial_values, args...)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_values[i] = remotecall_fetch(getter, w, scenarioproblems[w-1], args...)
        end
    end
    return reduce(op, partial_values)
end
function set_in_scenarioproblem!(setter::Function, scenarioproblems::ScenarioProblems, scenario_index::Integer, args...)
    setter(scenarioproblems, scenario_index, args...)
    return nothing
end
function set_in_scenarioproblem!(setter::Function, scenarioproblems::DistributedScenarioProblems, scenario_index::Integer, args...)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    j = 0
    for w in workers()
        n = scenarioproblems.scenario_distribution[w-1]
        if scenario_index <= n + j
            return remotecall_fetch(setter, w, scenarioproblems[w-1], scenario_index - j, args...)
        end
        j += n
    end
    throw(BoundsError(scenarioproblems, scenario_index))
end
function set_in_scenarioproblems!(setter::Function, scenarioproblems::ScenarioProblems, args...)
    setter(scenarioproblems, args...)
    return nothing
end
function set_in_scenarioproblems!(setter::Function, scenarioproblems::DistributedScenarioProblems, args...)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    @sync begin
        for (i,w) in enumerate(workers())
            @async remotecall_fetch(setter, w, scenarioproblems[w-1], args...)
        end
    end
    return nothing
end

# Base overloads #
# ========================== #
Base.getindex(sp::DistributedScenarioProblems, i::Integer) = sp.scenarioproblems[i]
# ========================== #

# MOI #
# ========================== #
function MOI.get(scenarioproblems::ScenarioProblems, attr::ScenarioDependentModelAttribute)
    MOI.get(backend(subproblem(scenarioproblems, attr.scenario_index)), attr.attr)
end
function MOI.get(scenarioproblems::DistributedScenarioProblems, attr::ScenarioDependentModelAttribute)
    return get_from_scenarioproblem(scenarioproblems, attr.scenario_index, attr.attr) do sp, i, attr
        MOI.get(backend(fetch(sp).problems[i]), attr)
    end
end
function MOI.get(scenarioproblems::ScenarioProblems, attr::ScenarioDependentVariableAttribute, index::MOI.VariableIndex)
    MOI.get(backend(subproblem(scenarioproblems, attr.scenario_index)), attr.attr, index)
end
function MOI.get(scenarioproblems::DistributedScenarioProblems, attr::ScenarioDependentVariableAttribute, index::MOI.VariableIndex)
    return get_from_scenarioproblem(scenarioproblems, attr.scenario_index, attr.attr, index) do sp, i, attr, index
        MOI.get(backend(fetch(sp).problems[i]), attr, index)
    end
end
function MOI.get(scenarioproblems::ScenarioProblems, attr::ScenarioDependentConstraintAttribute, ci::CI)
    MOI.get(backend(subproblem(scenarioproblems, attr.scenario_index)), attr.attr, ci)
end
function MOI.get(scenarioproblems::ScenarioProblems, attr::ScenarioDependentConstraintAttribute, ci::CI{F,S}) where {F <: SingleDecision, S}
    subprob = subproblem(scenarioproblems, attr.scenario_index)
    con_ref = ConstraintRef(subprob, ci)
    MOI.get(subprob, attr.attr, con_ref)
end
function MOI.get(scenarioproblems::DistributedScenarioProblems, attr::ScenarioDependentConstraintAttribute, ci::CI)
    return get_from_scenarioproblem(scenarioproblems, attr.scenario_index, attr.attr, ci) do sp, i, attr, ci
        return MOI.get(backend(fetch(sp).problems[i]), attr, ci)
    end
end
function MOI.get(scenarioproblems::DistributedScenarioProblems, attr::ScenarioDependentConstraintAttribute, ci::CI{F,S}) where {F <: SingleDecision, S}
    return get_from_scenarioproblem(scenarioproblems, attr.scenario_index, attr.attr, ci) do sp, i, attr, ci
        subprob = fetch(sp).problems[i]
        con_ref = ConstraintRef(subprob, ci)
        return MOI.get(subprob, attr, con_ref)
    end
end
function MOI.set(scenarioproblems::ScenarioProblems, attr::MOI.AbstractModelAttribute, value)
    for problem in subproblems(scenarioproblems)
        MOI.set(backend(problem), attr, value)
    end
    return nothing
end
function MOI.set(scenarioproblems::DistributedScenarioProblems, attr::MOI.AbstractModelAttribute, value)
    set_in_scenarioproblems!(scenarioproblems, attr, value) do sp, attr, value
        MOI.set(fetch(sp), attr, value)
        return nothing
    end
    return nothing
end
function MOI.set(scenarioproblems::ScenarioProblems, attr::ScenarioDependentModelAttribute, value)
    MOI.set(backend(subproblem(scenarioproblems, attr.scenario_index)), attr.attr, value)
    return nothing
end
function MOI.set(scenarioproblems::DistributedScenarioProblems, attr::ScenarioDependentModelAttribute, value)
    set_in_scenarioproblem!(scenarioproblems, attr.scenario_index, attr.attr, value) do sp, i, attr, value
        MOI.set(backend(fetch(sp).problems[i]), attr, value)
        return nothing
    end
    return nothing
end
function MOI.set(scenarioproblems::ScenarioProblems, attr::MOI.AbstractOptimizerAttribute, value)
    for problem in subproblems(scenarioproblems)
        MOI.set(backend(problem), attr, value)
    end
    return nothing
end
function MOI.set(scenarioproblems::DistributedScenarioProblems, attr::MOI.AbstractOptimizerAttribute, value)
    set_in_scenarioproblems!(scenarioproblems, attr, value) do sp, attr, value
        MOI.set(fetch(sp), attr, value)
        return nothing
    end
    return nothing
end
function MOI.set(scenarioproblems::ScenarioProblems, attr::MOI.AbstractVariableAttribute,
                 index::MOI.VariableIndex, value)
    for problem in subproblems(scenarioproblems)
        MOI.set(backend(problem), attr, index, value)
    end
    return nothing
end
function MOI.set(scenarioproblems::DistributedScenarioProblems, attr::MOI.AbstractVariableAttribute,
                 index::MOI.VariableIndex, value)
    set_in_scenarioproblems!(scenarioproblems, attr, index, value) do sp, attr, index, value
        MOI.set(fetch(sp), attr, index, value)
        return nothing
    end
    return nothing
end
function MOI.set(scenarioproblems::ScenarioProblems, attr::ScenarioDependentVariableAttribute,
                 index::MOI.VariableIndex, value)
    MOI.set(backend(subproblem(scenarioproblems, attr.scenario_index)), attr.attr, index, value)
    return nothing
end
function MOI.set(scenarioproblems::DistributedScenarioProblems, attr::ScenarioDependentVariableAttribute,
                 index::MOI.VariableIndex, value)
    set_in_scenarioproblem!(scenarioproblems, attr.scenario_index, attr.attr, index, value) do sp, i, attr, index, value
        MOI.set(backend(fetch(sp).problems[i]), attr, index, value)
        return nothing
    end
    return nothing
end
function MOI.set(scenarioproblems::ScenarioProblems, attr::MOI.AbstractConstraintAttribute, ci::CI, value)
    for problem in subproblems(scenarioproblems)
        MOI.set(backend(subproblem(scenarioproblems, attr.scenario_index)), attr.attr, ci, value)
    end
    return nothing
end
function MOI.set(scenarioproblems::ScenarioProblems, attr::MOI.AbstractConstraintAttribute, ci::CI{F,S}, value) where {F <: SingleDecision, S}
    for problem in subproblems(scenarioproblems)
        subprob = subproblem(scenarioproblems, attr.scenario_index)
        con_ref = ConstraintRef(subprob, ci)
        MOI.set(subprob, attr.attr, con_ref, value)
    end
    return nothing
end
function MOI.set(scenarioproblems::DistributedScenarioProblems, attr::MOI.AbstractConstraintAttribute,
                 ci::CI, value)
    set_in_scenarioproblems!(scenarioproblems, attr, ci, value) do sp, attr, ci, value
        MOI.set(fetch(sp), attr.attr, ci, value)
        return nothing
    end
    return nothing
end
function MOI.set(scenarioproblems::DistributedScenarioProblems, attr::MOI.AbstractConstraintAttribute,
                 ci::CI{F,S}, value) where {F <: SingleDecision, S}
    set_in_scenarioproblems!(scenarioproblems, attr, ci, value) do sp, attr, ci, value
        subprob = fetch(sp).problems[i]
        con_ref = ConstraintRef(subprob, ci)
        MOI.set(subprob, attr.attr, con_ref, value)
        return nothing
    end
    return nothing
end
function MOI.set(scenarioproblems::ScenarioProblems, attr::ScenarioDependentConstraintAttribute,
                 ci::MOI.ConstraintIndex, value)
    subprob = subproblem(scenarioproblems, attr.scenario_index)
    con_ref = ConstraintRef(subprob, ci)
    MOI.set(subprob, attr.attr, con_ref, value)
    return nothing
end
function MOI.set(scenarioproblems::DistributedScenarioProblems, attr::ScenarioDependentConstraintAttribute,
                 ci::MOI.ConstraintIndex, value)
    set_in_scenarioproblem!(scenarioproblems, attr.scenario_index, attr.attr, ci, value) do sp, i, attr, ci, value
        subprob = fetch(sp).problems[i]
        con_ref = ConstraintRef(subprob, ci)
        MOI.set(subprob, attr, con_ref, value)
        return nothing
    end
    return nothing
end

function MOI.is_valid(scenarioproblems::ScenarioProblems, index::MOI.VariableIndex, scenario_index::Integer)
    return MOI.is_valid(backend(subproblem(scenarioproblems, scenario_index)), index)
end
function MOI.is_valid(scenarioproblems::DistributedScenarioProblems, index::MOI.VariableIndex, scenario_index::Integer)
    return get_from_scenarioproblem(scenarioproblems, scenario_index, index) do sp, i, index
        MOI.is_valid(backend(fetch(sp).problems[i]), index)
    end
end

function MOI.is_valid(scenarioproblems::ScenarioProblems, ci::MOI.ConstraintIndex, scenario_index::Integer)
    return MOI.is_valid(backend(subproblem(scenarioproblems, scenario_index)), ci)
end
function MOI.is_valid(scenarioproblems::DistributedScenarioProblems, ci::MOI.ConstraintIndex, scenario_index::Integer)
    return get_from_scenarioproblem(scenarioproblems, scenario_index, ci) do sp, i, ci
        MOI.is_valid(backend(fetch(sp).problems[i]), ci)
    end
end

function MOI.add_constraint(scenarioproblems::ScenarioProblems, f::SingleDecision, s::MOI.AbstractSet, scenario_index::Integer)
    return MOI.add_constraint(backend(subproblem(scenarioproblems, scenario_index)), f, s)
end
function MOI.add_constraint(scenarioproblems::DistributedScenarioProblems, f::SingleDecision, s::MOI.AbstractSet, scenario_index::Integer)
    return set_in_scenarioproblem!(scenarioproblems, scenario_index, f, s) do sp, i, f, s
        return MOI.add_constraint(backend(fetch(sp).problems[i]), f, s)
    end
end

function MOI.delete(scenarioproblems::ScenarioProblems, indices::Vector{MOI.VariableIndex})
    for subprob in subproblems(scenarioproblems)
        drefs = DecisionRef.(subprob, indices)
        delete(subprob, drefs)
    end
    return nothing
end
function MOI.delete(scenarioproblems::DistributedScenarioProblems, indices::Vector{MOI.VariableIndex})
    set_in_scenarioproblems!(scenarioproblems, indices) do sp, indices
        for subprob in fetch(sp).problems
            dref = DecisionRef.(subprob, indices)
            delete(subprob, dref)
        end
        return nothing
    end
    return nothing
end
function MOI.delete(scenarioproblems::ScenarioProblems, indices::Vector{MOI.VariableIndex}, scenario_index::Integer)
    subprob = subproblem(scenarioproblems, scenario_index)
    JuMP.delete(subprob, DecisionRef.(subprob, indices))
    return nothing
end
function MOI.delete(scenarioproblems::DistributedScenarioProblems, indices::Vector{MOI.VariableIndex}, scenario_index::Integer)
    set_in_scenarioproblem!(scenarioproblems, scenario_index, indices) do sp, i, indices
        subprob = fetch(sp).problems[i]
        JuMP.delete(subprob, DecisionRef.(subprob, indices))
        return nothing
    end
    return nothing
end
function MOI.delete(scenarioproblems::ScenarioProblems, ci::MOI.ConstraintIndex, scenario_index::Integer)
    MOI.delete(backend(subproblem(scenarioproblems, scenario_index)), ci)
    return nothing
end
function MOI.delete(scenarioproblems::DistributedScenarioProblems, ci::MOI.ConstraintIndex, scenario_index::Integer)
    set_in_scenarioproblem!(scenarioproblems, scenario_index, ci) do sp, i, ci
        MOI.delete(backend(fetch(sp).problems[i]), ci)
        return nothing
    end
    return nothing
end
function MOI.delete(scenarioproblems::ScenarioProblems, cis::Vector{<:MOI.ConstraintIndex}, scenario_index::Integer)
    MOI.delete(backend(subproblem(scenarioproblems, scenario_index)), cis)
    return nothing
end
function MOI.delete(scenarioproblems::DistributedScenarioProblems, cis::Vector{<:MOI.ConstraintIndex}, scenario_index::Integer)
    set_in_scenarioproblem!(scenarioproblems, scenario_index, cis) do sp, i, cis
        MOI.delete(backend(fetch(sp).problems[i]), cis)
        return nothing
    end
    return nothing
end

# JuMP #
# ========================== #
function scenario_decision_dispatch(decision_function::Function,
                                    scenarioproblems::ScenarioProblems,
                                    index::MOI.VariableIndex,
                                    scenario_index::Integer,
                                    args...) where N
    dref = DecisionRef(subproblem(scenarioproblems, scenario_index), index)
    return decision_function(dref, args...)
end
function scenario_decision_dispatch(decision_function::Function,
                                    scenarioproblems::DistributedScenarioProblems,
                                    index::MOI.VariableIndex,
                                    scenario_index::Integer,
                                    args...) where N
    return get_from_scenarioproblem(scenarioproblems, scenario_index, decision_function, index, args...) do sp, i, decision_function, index, args...
        subprob = fetch(sp).problems[i]
        dref = DecisionRef(subprob, index)
        return decision_function(dref, args...)
    end
end
function scenario_decision_dispatch!(decision_function!::Function,
                                     scenarioproblems::ScenarioProblems,
                                     index::MOI.VariableIndex,
                                     scenario_index::Integer,
                                     args...) where N
    dref = DecisionRef(subproblem(scenarioproblems, scenario_index), index)
    decision_function!(dref, args...)
    return nothing
end
function scenario_decision_dispatch!(decision_function!::Function,
                                     scenarioproblems::DistributedScenarioProblems,
                                     index::MOI.VariableIndex,
                                     scenario_index::Integer,
                                     args...) where N
    set_in_scenarioproblem!(scenarioproblems, scenario_index, decision_function!, index, args...) do sp, i, decision_function!, index, args...
        subprob = fetch(sp).problems[i]
        dref = DecisionRef(subprob, index)
        decision_function!(dref, args...)
        return nothing
    end
    return nothing
end
function JuMP.fix(scenarioproblems::ScenarioProblems, index::MOI.VariableIndex, scenario_index::Integer, val::Number)
    subprob = scenarioproblems.problems[scenario_index]
    dref = DecisionRef(subprob, index)
    fix(dref, val)
    return nothing
end
function JuMP.fix(scenarioproblems::DistributedScenarioProblems, index::MOI.VariableIndex, scenario_index::Integer, val::Number)
    set_in_scenarioproblem!(scenarioproblems, scenario_index, index, val) do sp, i, index, val
        subprob = fetch(sp).problems[i]
        dref = DecisionRef(subprob, index)
        fix(dref, val)
        return nothing
    end
    return nothing
end
function JuMP.unfix(scenarioproblems::ScenarioProblems, index::MOI.VariableIndex, scenario_index::Integer)
    subprob = scenarioproblems.problems[scenario_index]
    dref = DecisionRef(subprob, index)
    unfix(dref)
    return nothing
end
function JuMP.unfix(scenarioproblems::DistributedScenarioProblems, index::MOI.VariableIndex, scenario_index::Integer)
    set_in_scenarioproblem!(scenarioproblems, scenario_index, index) do sp, i, index
        subprob = fetch(sp).problems[i]
        dref = DecisionRef(subprob, index)
        unfix(dref)
        return nothing
    end
    return nothing
end

function JuMP._moi_optimizer_index(scenarioproblems::ScenarioProblems, index::MOI.VariableIndex, scenario_index::Integer)
    return decision_index(backend(subproblem(scenarioproblems, scenario_index)), index)
end

function JuMP._moi_optimizer_index(scenarioproblems::ScenarioProblems, ci::CI, scenario_index::Integer)
    return decision_index(backend(subproblem(scenarioproblems, scenario_index)), ci)
end
function JuMP._moi_optimizer_index(scenarioproblems::ScenarioProblems, ci::CI{F,S}, scenario_index::Integer) where {F <: SingleDecision, S}
    subprob = subproblem(scenarioproblems, scenario_index)
    decisions = get_decisions(subprob)::Decisions
    inner = mapped_constraint(decisions, ci)
    inner.value == 0 && error("Constraint $ci not properly mapped.")
    return decision_index(backend(subprob), inner)
end

function JuMP.set_objective_coefficient(scenarioproblems::ScenarioProblems, index::VI, scenario_index::Integer, coeff::Real)
    subprob = subproblem(scenarioproblems, scenario_index)
    dref = DecisionRef(subprob, index)
    set_objective_coefficient(subprob, dref, coeff)
    return nothing
end
function JuMP.set_objective_coefficient(scenarioproblems::DistributedScenarioProblems, index::VI, scenario_index::Integer, coeff::Real)
    set_in_scenarioproblem!(scenarioproblems, scenario_index, index, coeff) do sp, i, index, coeff
        subprob = fetch(sp).problems[i]
        dref = DecisionRef(subprob, index)
        set_objective_coefficient(subprob, dref, coeff)
        return nothing
    end
    return nothing
end

function JuMP.set_normalized_coefficient(scenarioproblems::ScenarioProblems,
                                         ci::CI{F,S},
                                         index::VI,
                                         scenario_index::Integer,
                                         value) where {T, F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}, S}
    MOI.modify(backend(subproblem(scenarioproblems, scenario_index)), ci,
               DecisionCoefficientChange(index, convert(T, value)))
    return nothing
end
function JuMP.set_normalized_coefficient(scenarioproblems::DistributedScenarioProblems,
                                         ci::CI{F,S},
                                         index::VI,
                                         scenario_index::Integer,
                                         value) where {T, F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}, S}
    set_in_scenarioproblem!(scenarioproblems, scenario_index, ci, index, convert(T, value)) do sp, i, ci, index, value
        MOI.modify(backend(fetch(sp).problems[i]), ci,
                  DecisionCoefficientChange(index, value))
        return nothing
    end
    return nothing
end

function JuMP.normalized_coefficient(scenarioproblems::ScenarioProblems,
                                     ci::CI{F,S},
                                     index::VI,
                                     scenario_index::Integer) where {T, F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}, S}
    subprob = subproblem(scenarioproblems, scenario_index)
    f = MOI.get(backend(subprob), MOI.ConstraintFunction(), ci)::F
    dref = DecisionRef(subprob, index)
    return JuMP._affine_coefficient(jump_function(subprob, f), dref)
end
function JuMP.normalized_coefficient(scenarioproblems::DistributedScenarioProblems,
                                     ci::CI{F,S},
                                     index::VI,
                                     scenario_index::Integer) where {T, F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}, S}
    return get_from_scenarioproblem(scenarioproblems, scenario_index, ci, index) do sp, i, ci, index
        subprob = fetch(sp).problems[i]
        f = MOI.get(backend(subprob), MOI.ConstraintFunction(), ci)::F
        dref = DecisionRef(subprob, index)
        return JuMP._affine_coefficient(jump_function(subprob, f), dref)
    end
end

function JuMP.set_normalized_rhs(scenarioproblems::ScenarioProblems,
                                 ci::CI{F,S},
                                 scenario_index::Integer,
                                 value) where {T,
                                               F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}},
                                               S <: MOIU.ScalarLinearSet{T}}
    MOI.set(backend(subproblem(scenarioproblems, scenario_index)), MOI.ConstraintSet(), ci,
            S(convert(T, value)))
    return nothing
end
function JuMP.set_normalized_rhs(scenarioproblems::DistributedScenarioProblems,
                                 ci::CI{F,S},
                                 scenario_index::Integer,
                                 value) where {T,
                                               F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}},
                                               S <: MOIU.ScalarLinearSet{T}}
    set_in_scenarioproblem!(scenarioproblems, scenario_index, ci, S(convert(T, value))) do sp, i, ci, value
        MOI.set(backend(fetch(sp).problems[i]), MOI.ConstraintSet(), ci, value)
        return nothing
    end
    return nothing
end

# Getters #
# ========================== #
function decision(scenarioproblems::ScenarioProblems, index::MOI.VariableIndex, scenario_index::Integer) where N
    subprob = subproblem(scenarioproblems, scenario_index)
    return decision(DecisionRef(subprob, index))
end
function decision(scenarioproblems::DistributedScenarioProblems, index::MOI.VariableIndex, scenario_index::Integer) where N
    return get_from_scenarioproblem(scenarioproblems, scenario_index, index) do sp, i, index
        subprob = fetch(sp).problems[i]
        return decision(DecisionRef(subprob, index))
    end
end
function scenario(scenarioproblems::ScenarioProblems, scenario_index::Integer)
    return scenarioproblems.scenarios[scenario_index]
end
function scenario(scenarioproblems::DistributedScenarioProblems, scenario_index::Integer)
    return get_from_scenarioproblem(scenarioproblems, scenario_index) do sp, i
        return fetch(sp).scenarios[i]
    end
end
function scenarios(scenarioproblems::ScenarioProblems)
    return scenarioproblems.scenarios
end
function scenarios(scenarioproblems::DistributedScenarioProblems{S}) where S <: AbstractScenario
    partial_scenarios = Vector{Vector{S}}(undef, nworkers())
    return get_from_scenarioproblems(scenarioproblems, vcat, partial_scenarios) do sp
        return fetch(sp).scenarios
    end
end
function expected(scenarioproblems::ScenarioProblems)
    return expected(scenarioproblems.scenarios)
end
function expected(scenarioproblems::DistributedScenarioProblems{S}) where S <: AbstractScenario
    partial_expectations = Vector{ExpectedScenario{S}}(undef, nworkers())
    return get_from_scenarioproblems(scenarioproblems, expected, partial_expectations) do sp
        return expected(fetch(sp))
    end
end
function scenario_type(scenarioproblems::ScenarioProblems{S}) where S <: AbstractScenario
    return S
end
function scenario_type(scenarioproblems::DistributedScenarioProblems{S}) where S <: AbstractScenario
    return S
end
function subproblem(scenarioproblems::ScenarioProblems, scenario_index::Integer)
    return scenarioproblems.problems[scenario_index]
end
function subproblem(scenarioproblems::DistributedScenarioProblems, scenario_index::Integer)
    return get_from_scenarioproblem(scenarioproblems, scenario_index) do sp, i
        return fetch(sp).scenarios[i]
    end
end
function subproblems(scenarioproblems::ScenarioProblems)
    return scenarioproblems.problems
end
function subproblems(scenarioproblems::DistributedScenarioProblems)
    partial_subproblems = Vector{Vector{JuMP.Model}}(undef, nworkers())
    return get_from_scenarioproblems(scenarioproblems, vcat, partial_subproblems) do sp
        return fetch(sp).problems
    end
end
function num_subproblems(scenarioproblems::ScenarioProblems)
    return length(scenarioproblems.problems)
end
function num_subproblems(scenarioproblems::DistributedScenarioProblems)
    partial_lengths = Vector{Int}(undef, nworkers())
    return get_from_scenarioproblems(scenarioproblems, +, partial_lengths) do sp
        return num_subproblems(fetch(sp))
    end
end
function decision_variables(scenarioproblems::ScenarioProblems)
    return scenarioproblems.decision_variables
end
function probability(scenarioproblems::ScenarioProblems, scenario_index::Integer)
    return probability(scenario(scenarioproblems, scenario_index))
end
function probability(scenarioproblems::DistributedScenarioProblems, scenario_index::Integer)
    return get_from_scenarioproblem(scenarioproblems, scenario_index) do sp, i
        return probability(fetch(sp).scenarios[i])
    end
end
function probability(scenarioproblems::ScenarioProblems)
    return probability(scenarioproblems.scenarios)
end
function probability(scenarioproblems::DistributedScenarioProblems)
    partial_probabilities = Vector{Float64}(undef, nworkers())
    return get_from_scenarioproblems(scenarioproblems, +, partial_probabilities) do sp
        return probability(fetch(sp))
    end
end
function num_scenarios(scenarioproblems::ScenarioProblems)
    return length(scenarioproblems.scenarios)
end
function num_scenarios(scenarioproblems::DistributedScenarioProblems)
    return sum(scenarioproblems.scenario_distribution)
end
distributed(scenarioproblems::ScenarioProblems) = false
distributed(scenarioproblems::DistributedScenarioProblems) = true
# ========================== #

# Setters
# ========================== #
function update_decision_state!(scenarioproblems::ScenarioProblems, index::MOI.VariableIndex, state::DecisionState)
    map(subproblems(scenarioproblems)) do subprob
        dref = DecisionRef(subprob, index)
        update_decision_state!(dref, state)
    end
    return nothing
end
function update_decision_state!(scenarioproblems::DistributedScenarioProblems, index::MOI.VariableIndex, state::DecisionState)
    set_in_scenarioproblems!(scenarioproblems, index, state) do sp, index, state
        update_decision_state!(fetch(sp), index, state)
        return nothing
    end
    return nothing
end
function update_known_decisions!(scenarioproblems::ScenarioProblems, scenario_index::Integer)
    update_known_decisions!(subproblem(scenarioproblems, scenario_index))
    return nothing
end
function update_known_decisions!(scenarioproblems::DistributedScenarioProblems, scenario_index::Integer)
    set_in_scenarioproblems!(scenarioproblems, scenario_index) do sp, i
        update_known_decisions!(fetch(sp).problems[i])
        return nothing
    end
    return nothing
end

function set_optimizer!(scenarioproblems::ScenarioProblems, optimizer)
    map(subproblems(scenarioproblems)) do subprob
        set_optimizer(subprob, optimizer)
    end
    return nothing
end
function set_optimizer!(scenarioproblems::DistributedScenarioProblems, optimizer)
    set_in_scenarioproblems!(scenarioproblems, optimizer) do sp, opt
        set_optimizer!(fetch(sp), opt)
        return nothing
    end
    return nothing
end
function add_scenario!(scenarioproblems::ScenarioProblems{S}, scenario::S) where S <: AbstractScenario
    push!(scenarioproblems.scenarios, scenario)
    return nothing
end
function add_scenario!(scenarioproblems::DistributedScenarioProblems{S}, scenario::S) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    _, w = findmin(scenarioproblems.scenario_distribution)
    add_scenario!(scenarioproblems, scenario, w+1)
    return nothing
end
function add_scenario!(scenarioproblems::DistributedScenarioProblems{S}, scenario::S, w::Integer) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch(
        w,
        scenarioproblems[w-1],
        scenario) do sp, scenario
            add_scenario!(fetch(sp), scenario)
        end
    scenarioproblems.scenario_distribution[w-1] += 1
    return nothing
end
function add_scenario!(scenariogenerator::Function, scenarioproblems::ScenarioProblems)
    add_scenario!(scenarioproblems, scenariogenerator())
    return nothing
end
function add_scenario!(scenariogenerator::Function, scenarioproblems::DistributedScenarioProblems)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    _, w = findmin(scenarioproblems.scenario_distribution)
    add_scenario!(scenariogenerator, scenarioproblems, w + 1)
    return nothing
end
function add_scenario!(scenariogenerator::Function, scenarioproblems::DistributedScenarioProblems, w::Integer)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch(
        w,
        scenarioproblems[w-1],
        scenariogenerator) do sp, generator
            add_scenario!(fetch(sp), generator())
        end
    scenarioproblems.scenario_distribution[w] += 1
    return nothing
end
function add_scenarios!(scenarioproblems::ScenarioProblems{S}, scenarios::Vector{S}) where S <: AbstractScenario
    append!(scenarioproblems.scenarios, scenarios)
    return nothing
end
function add_scenarios!(scenariogenerator::Function, scenarioproblems::ScenarioProblems{S}, n::Integer) where S <: AbstractScenario
    for i = 1:n
        add_scenario!(scenarioproblems) do
            return scenariogenerator()
        end
    end
    return nothing
end
function add_scenarios!(scenarioproblems::DistributedScenarioProblems{S}, scenarios::Vector{S}) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    (nscen, extra) = divrem(length(scenarios), nworkers())
    start = 1
    stop = 0
    @sync begin
        for w in workers()
            n = nscen + (extra > 0)
            stop += n
            stop = min(stop, length(scenarios))
            scenario_range = start:stop
            @async remotecall_fetch(
                w,
                scenarioproblems[w-1],
                scenarios[scenario_range]) do sp, scenarios
                    add_scenarios!(fetch(sp), scenarios)
                end
            scenarioproblems.scenario_distribution[w-1] += n
            start = stop + 1
            extra -= 1
        end
    end
    return nothing
end
function add_scenarios!(scenarioproblems::DistributedScenarioProblems{S}, scenarios::Vector{S}, w::Integer) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch(
        w,
        scenarioproblems[w-1],
        scenarios) do sp, scenarios
            add_scenarios!(fetch(sp), scenarios)
        end
    scenarioproblems.scenario_distribution[w-1] += length(scenarios)
    return nothing
end
function add_scenarios!(scenariogenerator::Function, scenarioproblems::DistributedScenarioProblems, n::Integer)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    (nscen, extra) = divrem(n, nworkers())
    @sync begin
        for w in workers()
            m = nscen + (extra > 0)
            @async remotecall_fetch(
                w,
                scenarioproblems[w-1],
                scenariogenerator,
                m) do sp, gen, n
                    add_scenarios!(gen, fetch(sp), n)
                end
            scenarioproblems.scenario_distribution[w-1] += m
            extra -= 1
        end
    end
    return nothing
end
function add_scenarios!(scenariogenerator::Function, scenarioproblems::DistributedScenarioProblems, n::Integer, w::Integer)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch(
        w,
        scenarioproblems[w-1],
        scenariogenerator,
        n) do sp, gen
            add_scenarios!(gen, fetch(sp), n)
        end
    scenarioproblems.scenario_distribution[w-1] += n
    return nothing
end
function clear_scenarios!(scenarioproblems::ScenarioProblems)
    empty!(scenarioproblems.scenarios)
    return nothing
end
function clear_scenarios!(scenarioproblems::DistributedScenarioProblems)
    set_in_scenarioproblems!(scenarioproblems) do sp
        remove_scenarios!(fetch(sp))
        return nothing
    end
    scenarioproblems.scenario_distribution .= 0
    return nothing
end
function clear!(scenarioproblems::ScenarioProblems)
    map(scenarioproblems.problems) do subprob
        # Clear decisions
        if haskey(subprob.ext, :decisions)
            clear!(subprob.ext[:decisions])
        end
        # Clear model
        empty!(subprob)
    end
    empty!(scenarioproblems.problems)
    return nothing
end
function clear!(scenarioproblems::DistributedScenarioProblems)
    set_in_scenarioproblems!(scenarioproblems) do sp
        clear!(fetch(sp))
        return nothing
    end
    return nothing
end

function cache_solution!(cache::Dict{Symbol,SolutionCache},
                         scenarioproblems::ScenarioProblems,
                         optimizer::MOI.AbstractOptimizer,
                         stage::Integer,
                         variables::Vector{<:VI},
                         constraints::Vector{<:CI})
    for scenario_index in 1:num_scenarios(scenarioproblems)
        key = Symbol(:node_solution_, stage, :_, scenario_index)
        subprob = subproblem(scenarioproblems, scenario_index)
        cache[key] = SolutionCache(backend(subprob))
        cache_model_attributes!(cache[key], optimizer, stage, scenario_index)
        cache_variable_attributes!(cache[key], optimizer, variables, stage, scenario_index)
        cache_constraint_attributes!(cache[key], optimizer, constraints, stage, scenario_index)
    end
end
function cache_solution!(cache::Dict{Symbol,SolutionCache},
                         scenarioproblems::DistributedScenarioProblems,
                         optimizer::MOI.AbstractOptimizer,
                         stage::Integer,
                         variables::Vector{<:VI},
                         constraints::Vector{<:CI})
    for scenario_index in 1:num_scenarios(scenarioproblems)
        key = Symbol(:node_solution_, stage, :_, scenario_index)
        cache[key] = _prepare_subproblem_cache(scenarioproblems, scenario_index)
        cache_model_attributes!(cache[key], optimizer, stage, scenario_index)
        cache_variable_attributes!(cache[key], optimizer, variables, stage, scenario_index)
        cache_constraint_attributes!(cache[key], optimizer, constraints, stage, scenario_index)
    end
end
function _prepare_subproblem_cache(scenarioproblems::DistributedScenarioProblems, scenario_index::Integer)
    return get_from_scenarioproblem(scenarioproblems, scenario_index) do sp, i
        subprob = fetch(sp).problems[i]
        subcache = SolutionCache(backend(subprob))
        return subcache
    end
end
# ========================== #

# Sampling #
# ========================== #
function sample!(scenarioproblems::ScenarioProblems{S}, sampler::AbstractSampler{S}, n::Integer) where S <: AbstractScenario
    _sample!(scenarioproblems, sampler, n, num_scenarios(scenarioproblems), 1/n)
end
function sample!(scenarioproblems::ScenarioProblems{S}, sampler::AbstractSampler{Scenario}, n::Integer) where S <: AbstractScenario
    _sample!(scenarioproblems, sampler, n, num_scenarios(scenarioproblems), 1/n)
end
function sample!(scenarioproblems::DistributedScenarioProblems{S}, sampler::AbstractSampler{S}, n::Integer) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    m = nscenarios(scenarioproblems)
    (nscen, extra) = divrem(n, nworkers())
    @sync begin
        for w in workers()
            d = nscen + (extra > 0)
            @async remotecall_fetch(
                w,
                scenarioproblems[w-1],
                sampler,
                d,
                m,
                1/n) do sp, sampler, n, m, π
                    _sample!(fetch(sp), sampler, n, m, π)
                end
            scenarioproblems.scenario_distribution[w-1] += d
            extra -= 1
        end
    end
    return nothing
end
function sample!(scenarioproblems::DistributedScenarioProblems{S}, sampler::AbstractSampler{Scenario}, n::Integer) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    m = nscenarios(scenarioproblems)
    (nscen, extra) = divrem(n, nworkers())
    @sync begin
        for w in workers()
            d = nscen + (extra > 0)
            @async remotecall_fetch(
                w,
                scenarioproblems[w-1],
                sampler,
                d,
                m,
                1/n) do sp, sampler, n, m, π
                    _sample!(fetch(sp), sampler, n, m, π)
                end
            scenarioproblems.scenario_distribution[w-1] += d
            extra -= 1
        end
    end
    return nothing
end
function _sample!(scenarioproblems::ScenarioProblems, sampler::AbstractSampler, n::Integer, m::Integer, π::AbstractFloat)
    if m > 0
        # Rescale probabilities of existing scenarios
        for scenario in scenarioproblems.scenarios
            p = probability(scenario) * m / (m+n)
            set_probability!(scenario, p)
        end
        π *= n/(m+n)
    end
    for i = 1:n
        add_scenario!(scenarioproblems) do
            return sample(sampler, π)
        end
    end
    return nothing
end
# ========================== #
