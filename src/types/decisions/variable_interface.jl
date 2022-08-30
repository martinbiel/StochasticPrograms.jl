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

"""
    DecisionRef <: AbstractVariableRef

Holds a reference to the model, the stage the decision is taken in, and the corresponding MOI.VariableIndex.
"""
struct DecisionRef <: JuMP.AbstractVariableRef
    model::JuMP.Model
    index::MOI.VariableIndex
end
is_decision_type(::Type{DecisionRef}) = true

# Getters (model) #
# ========================== #
function get_decisions(model::JuMP.Model)::Decisions
    !haskey(model.ext, :decisions) && return IgnoreDecisions()
    return model.ext[:decisions]
end

function all_decisions(model::JuMP.Model, stage::Integer = 1)
    decisions = get_decisions(model)::Decisions
    return all_decisions(decisions, stage)
end

function all_known_decisions(model::JuMP.Model, stage::Integer = 2)
    decisions = get_decisions(model)::Decisions
    return all_known_decisions(decisions, stage)
end
"""
    all_decision_variables(model::JuMP.Model)

Returns a stage-wise list of all decisions currently in the `model`. The decisions are
ordered by creation time.
"""
function all_decision_variables(model::JuMP.Model)
    haskey(model.ext, :decisions) || error("No decisions in model.")
    N = stage(model)
    return ntuple(Val{N}()) do stage
        return all_decision_variables(model, stage)
    end
end
"""
    all_decision_variables(model::JuMP.Model, stage::Integer)

Returns a list of all decisions currently in the `model` at stage `stage`. The decisions are
ordered by creation time.
"""
function all_decision_variables(model::JuMP.Model, stage::Integer)
    haskey(model.ext, :decisions) || error("No decisions in model.")
    decisions = get_decisions(model)::Decisions
    return map(all_decisions(decisions, stage)) do index
        DecisionRef(model, index)
    end
end
"""
    all_known_decision_variables(model::JuMP.Model)

Returns a stage-wise list of all known decisions currently in the `model`. The decisions are
ordered by creation time.
"""
function all_known_decision_variables(model::JuMP.Model)
    haskey(model.ext, :decisions) || error("No decisions in model.")
    N = stage(model)
    return ntuple(Val{N}()) do s
        return all_known_decision_variables(model, s)
    end
end
"""
    all_known_decision_variables(model::JuMP.Model, stage::Integer)

Returns a stage-wise list of all known decisions currently in the `model` at stage `stage`. The decisions are
ordered by creation time.
"""
function all_known_decision_variables(model::JuMP.Model, stage::Integer)
    haskey(model.ext, :decisions) || error("No decisions in model.")
    decisions = get_decisions(model)::Decisions
    return map(all_known_decisions(decisions, stage)) do index
        DecisionRef(model, index)
    end
end
"""
    all_auxiliary_variables(model::JuMP.Model)

Returns a list of all auxiliary variables currently in the decision `model` through `@variable`. The variables are ordered by creation time.
"""
function all_auxiliary_variables(model::JuMP.Model)
    haskey(model.ext, :decisions) || error("No decisions in model. Use `all_variables` as usual.")
    N = stage(model)
    all_known = mapreduce(vcat, all_known_decision_variables(model)) do krefs
        index.(krefs)
    end
    all_decisions = map(all_decision_variables(model, N)) do drefs
        index.(drefs)
    end
    return filter(all_variables(model)) do var
        vi = index(var)
        return !(vi in all_known || vi in all_decisions)
    end
end
"""
    num_decisions(model::JuMP.Model, stage::Integer = 1)

Return the number of decisions in `model` at stage `stage`. Defaults to the first stage.
"""
function num_decisions(model::JuMP.Model, stage::Integer = 1)
    decisions = get_decisions(model)::Decisions
    return num_decisions(decisions, stage)
end
"""
    num_known_decisions(model::JuMP.Model, stage::Integer = 2)

Return the number of known decisions in `model` at stage `stage`. Defaults to the second stage.
"""
function num_known_decisions(model::JuMP.Model, stage::Integer = 2)
    stage > 1 || error("No decisions can be known in the first stage.")
    decisions = get_decisions(model)::Decisions
    return num_known_decisions(decisions, stage - 1)
end

function get_stage_objective(model::JuMP.Model, stage::Integer, ::Val{N}) where N
    stage > 1 && error("The objective at stage $stage is scenario dependent, consider `get_stage_objective(model, stage, scenario_index)`.")
    decisions = get_decisions(model)::Decisions{N}
    if decisions.is_node
        return (objective_sense(model), objective_function(model))
    end
    (sense, obj) = get_stage_objective(decisions, stage, 1)
    return (sense, jump_function(model, obj))
end
function get_stage_objective(model::JuMP.Model, stage::Integer, scenario_index::Integer, ::Val{N}) where N
    stage == 1 && error("The first-stage objective is not scenario dependent, consider `get_stage_objective(model, stage)`.")
    decisions = get_decisions(model)::Decisions{N}
    if decisions.is_node
        return (objective_sense(model), objective_function(model))
    end
    (sense, obj) = get_stage_objective(decisions, stage, scenario_index)
    return (sense, jump_function(model, obj))
end

# Getters (refs) #
# ========================== #
function stage(model::JuMP.Model)
    haskey(model.ext, :decisions) || error("No decisions in model.")
    return num_stages(get_decisions(model))
end
function stage(dref::DecisionRef)
    haskey(dref.model.ext, :decisions) || error("No decisions in model.")
    return stage(get_decisions(owner_model(dref)), index(dref))
end

function get_decisions(dref::DecisionRef)::Decisions
    return get_decisions(owner_model(dref))
end
"""
    decision(dref::DecisionRef)

Return the internal `Decision` associated with `dref`.
"""
function decision(dref::DecisionRef)
    decisions = get_decisions(dref)::Decisions
    return decision(decisions, index(dref))
end
"""
    state(dref::DecisionRef)

Return the `DecisionState` of `dref`.
"""
function state(dref::DecisionRef)
    return decision(dref).state
end

# Setters #
# ========================== #
function take_decisions!(model::JuMP.Model, drefs::Vector{DecisionRef}, vals::AbstractVector)
    # Check that all given decisions are in model
    map(dref -> check_belongs_to_model(dref, model), drefs)
    # Check decision length
    length(drefs) == length(vals) || error("Given decision of length $(length(vals)) not compatible with number of decision variables $(length(drefs)).")
    # Update decisions
    for (dref, val) in zip(drefs, vals)
        d = decision(dref)
        # Update state
        d.state = Taken
        # Update value
        d.value = val
        # Update
        update_decision_state!(dref, Taken)
    end
    return nothing
end

function untake_decisions!(model::JuMP.Model, drefs::Vector{DecisionRef})
    # Check that all given decisions are in model
    map(dref -> check_belongs_to_model(dref, model), drefs)
    # Update decisions
    need_update = false
    for dref in drefs
        d = decision(dref)
        if state(d) == Taken
            need_update |= true
            # Update state
            d.state = NotTaken
            update_decision_state!(dref, NotTaken)
        end
    end
    return nothing
end

function set_stage_objective!(model::JuMP.Model,
                              stage::Integer,
                              sense::MOI.OptimizationSense,
                              objective::MOI.AbstractScalarFunction)
    stage > 1 && error("The objective at stage $stage is scenario dependent, consider `set_stage_objective!(model, stage, scenario_index, sense, objective)`.")
    decisions = get_decisions(model)::Decisions
    set_stage_objective!(decisions, stage, 1, sense, objective)
    return nothing
end
function set_stage_objective!(model::JuMP.Model,
                              stage::Integer,
                              scenario_index::Integer,
                              sense::MOI.OptimizationSense,
                              objective::MOI.AbstractScalarFunction)
    stage == 1 && error("The first-stage objective is not scenario dependent, consider `set_stage_objective!(model, stage, sense, objective)`.")
    decisions = get_decisions(model)::Decisions
    set_stage_objective!(decisions, stage, scenario_index, sense, objective)
    return nothing
end

function add_stage_objective!(model::JuMP.Model,
                              stage::Integer,
                              sense::MOI.OptimizationSense,
                              objective::MOI.AbstractScalarFunction)
    decisions = get_decisions(model)::Decisions
    add_stage_objective!(decisions, stage, sense, objective)
    return nothing
end

# JuMP variable interface #
# ========================== #
function MOI.get(model::JuMP.Model, attr::MOI.AbstractVariableAttribute,
                 dref::DecisionRef)
    check_belongs_to_model(dref, model)
    if MOI.is_set_by_optimize(attr)
        return JuMP._moi_get_result(backend(model), attr, index(dref))
    else
        return MOI.get(backend(model), attr, index(dref))
    end
end

function MOI.set(model::Model, attr::MOI.AbstractVariableAttribute,
                 dref::DecisionRef, value)
    check_belongs_to_model(dref, model)
    MOI.set(backend(model), attr, index(dref), value)
    return nothing
end

function JuMP.name(dref::DecisionRef)
    return MOI.get(owner_model(dref), MOI.VariableName(), dref)::String
end

function JuMP.set_name(dref::DecisionRef, name::String)
    return MOI.set(owner_model(dref), MOI.VariableName(), dref, name)
end

function decision_by_name(model::Model, name::String)
    index = MOI.get(backend(model), MOI.VariableIndex, name)
    if index isa Nothing
        return nothing
    else
        return DecisionRef(model, index)
    end
end

JuMP.index(dref::DecisionRef) = dref.index

function JuMP.value(dref::DecisionRef; result::Int = 1)::Float64
    if state(dref) == NotTaken
        return MOI.get(owner_model(dref), MOI.VariablePrimal(result), dref)
    end
    # If decision has been taken or is known
    # the value can be fetched directly
    return decision(dref).value
end

function JuMP.is_fixed(dref::DecisionRef)
    if state(dref) == NotTaken
        return false
    end
    return true
end

function JuMP.unfix(dref::DecisionRef)
    if state(dref) == NotTaken
        # Nothing to do, just return
        return nothing
    end
    d = decision(dref)
    # Update state
    d.state = NotTaken
    # Update objective and constraints
    update_decision_state!(dref, NotTaken)
    return nothing
end

"""
    fix(dref::DecisionRef, val::Number)

Fix the decision associated with `dref` to `val`.

See also [`unfix`](@ref).
"""
function JuMP.fix(dref::DecisionRef, val::Number)
    d = decision(dref)
    if state(dref) == NotTaken
        # Update state
        d.state = Taken
        # Update value
        d.value = val
    else
        # Just update value
        d.value = val
    end
    # Modify decision state
    update_decision_state!(dref, d.state)
    return nothing
end

function JuMP.delete(model::JuMP.Model, dref::DecisionRef)
    if model !== owner_model(dref)
        error("The decision you are trying to delete does not " *
              "belong to the model.")
    end
    # First delete any SingleDecision constraints
    for S in [MOI.GreaterThan{Float64}, MOI.LessThan{Float64}, MOI.EqualTo{Float64}, MOI.ZeroOne, MOI.Integer]
        ci = CI{SingleDecision,S}(index(dref).value)
        inner = mapped_constraint(get_decisions(dref), ci)
        if MOI.is_valid(backend(model), inner)
            MOI.delete(backend(model), inner)
        end
    end
    # Remove SingleDecisionSet constraint
    ci = CI{MOI.VariableIndex,SingleDecisionSet{Float64}}(index(dref).value)
    MOI.delete(backend(model), ci)
    # Delete the variable corresponding to the decision
    MOI.delete(backend(model), index(dref))
    # Remove the decision
    remove_decision!(get_decisions(dref), index(dref))
    return nothing
end

function JuMP.delete(model::JuMP.Model, drefs::Vector{DecisionRef})
    isempty(drefs) && return nothing
    if any(model !== owner_model(dref) for dref in drefs)
        error("A decision you are trying to delete does not " *
              "belong to the model.")
    end
    # First delete any SingleDecision constraints
    for dref in drefs
        for S in [MOI.GreaterThan{Float64}, MOI.LessThan{Float64}, MOI.EqualTo{Float64}, MOI.ZeroOne, MOI.Integer]
            ci = CI{SingleDecision,S}(index(dref).value)
            inner = mapped_constraint(get_decisions(dref), ci)
            if MOI.is_valid(backend(model), inner)
                MOI.delete(backend(model), inner)
            end
        end
    end
    # Delete the variables corresponding to the decision
    MOI.delete(backend(model), index.(drefs))
    # Remove any MultipleDecisionSet constraint
    for ci in MOI.get(backend(model), MOI.ListOfConstraintIndices{MOI.VectorOfVariables, MultipleDecisionSet{Float64}}())
        f = MOI.get(backend(model), MOI.ConstraintFunction(), ci)::MOI.VectorOfVariables
        if all(f.variables .== index.(drefs))
            # This is the constraint
            MOI.delete(backend(model), ci)
            break
        end
    end
    # Remove any SingleDecisionSet constraints
    for dref in drefs
        ci = CI{MOI.VariableIndex,SingleDecisionSet{Float64}}(index(dref).value)
        if MOI.is_valid(backend(model), ci)
            MOI.delete(backend(model), ci)
        end
    end
    # Remove the decisions
    map(dref -> remove_decision!(get_decisions(dref), index(dref)), drefs)
    return nothing
end

JuMP.owner_model(dref::DecisionRef) = dref.model

struct DecisionNotOwned <: Exception
    dref::DecisionRef
end

function JuMP.check_belongs_to_model(dref::DecisionRef, model::AbstractModel)
    if owner_model(dref) !== model
        throw(DecisionNotOwned(dref))
    end
end

function JuMP.is_valid(model::Model, dref::DecisionRef)
    return model === owner_model(dref) && MOI.is_valid(backend(model), index(dref))
end

function JuMP.has_lower_bound(dref::DecisionRef)
    haskey(owner_model(dref).ext, :decisions) || error("No decisions in model.")
    if state(dref) == Known
        return false
    end
    ci = MOI.ConstraintIndex{SingleDecision, MOI.GreaterThan{Float64}}(index(dref).value)
    inner = mapped_constraint(get_decisions(dref), ci)
    if inner.value == 0
        return false
    end
    return MOI.is_valid(backend(owner_model(dref)), inner)
end
function JuMP.LowerBoundRef(dref::DecisionRef)
    haskey(owner_model(dref).ext, :decisions) || error("No decisions in model.")
    moi_lb =  MOI.ConstraintIndex{SingleDecision, MOI.GreaterThan{Float64}}
    ci = moi_lb(index(dref).value)
    inner = mapped_constraint(get_decisions(dref), ci)
    inner.value == 0 && error("Constraint $ci not properly mapped.")
    return ConstraintRef{JuMP.Model, moi_lb, ScalarShape}(owner_model(dref),
                                                          inner,
                                                          ScalarShape())
end
function JuMP.set_lower_bound(dref::DecisionRef, lower::Number)
    haskey(owner_model(dref).ext, :decisions) || error("No decisions in model.")
    new_set = MOI.GreaterThan(convert(Float64, lower))
    ci = MOI.ConstraintIndex{SingleDecision, MOI.GreaterThan{Float64}}(index(dref).value)
    if has_lower_bound(dref)
        inner = mapped_constraint(get_decisions(dref), ci)
        inner.value == 0 && error("Constraint $ci not properly mapped.")
        MOI.set(backend(owner_model(dref)), MOI.ConstraintSet(), inner, new_set)
    else
        inner = MOI.add_constraint(backend(owner_model(dref)), SingleDecision(index(dref)), new_set)
        map_constraint!(get_decisions(dref), ci, inner)
    end
    return nothing
end
function JuMP.delete_lower_bound(dref::DecisionRef)
    JuMP.delete(owner_model(dref), LowerBoundRef(dref))
    ci = MOI.ConstraintIndex{SingleDecision, MOI.GreaterThan{Float64}}(index(dref).value)
    remove_mapped_constraint!(get_decisions(dref), ci)
    return nothing
end
function JuMP.lower_bound(dref::DecisionRef)
    if !has_lower_bound(dref)
        error("Decision $(dref) does not have a lower bound.")
    end
    cset = MOI.get(owner_model(dref), MOI.ConstraintSet(),
                   LowerBoundRef(dref))::MOI.GreaterThan{Float64}
    return cset.lower
end

function JuMP.has_upper_bound(dref::DecisionRef)
    if state(dref) == Known
        return false
    end
    ci = MOI.ConstraintIndex{SingleDecision, MOI.LessThan{Float64}}(index(dref).value)
    inner = mapped_constraint(get_decisions(dref), ci)
    if inner.value == 0
        return false
    end
    return MOI.is_valid(backend(owner_model(dref)), inner)
end
function JuMP.UpperBoundRef(dref::DecisionRef)
    haskey(owner_model(dref).ext, :decisions) || error("No decisions in model.")
    moi_ub =  MOI.ConstraintIndex{SingleDecision, MOI.LessThan{Float64}}
    ci = moi_ub(index(dref).value)
    inner = mapped_constraint(get_decisions(dref), ci)
    inner.value == 0 && error("Constraint $ci not properly mapped.")
    return ConstraintRef{JuMP.Model, moi_ub, ScalarShape}(owner_model(dref),
                                                          inner,
                                                          ScalarShape())
end
function JuMP.set_upper_bound(dref::DecisionRef, lower::Number)
    haskey(owner_model(dref).ext, :decisions) || error("No decisions in model.")
    new_set = MOI.LessThan(convert(Float64, lower))
    ci = MOI.ConstraintIndex{SingleDecision, MOI.LessThan{Float64}}(index(dref).value)
    if has_upper_bound(dref)
        inner = mapped_constraint(get_decisions(dref), ci)
        inner.value == 0 && error("Constraint $ci not properly mapped.")
        MOI.set(backend(owner_model(dref)), MOI.ConstraintSet(), inner, new_set)
    else
        inner = MOI.add_constraint(backend(owner_model(dref)), SingleDecision(index(dref)), new_set)
        map_constraint!(get_decisions(dref), ci, inner)
    end
    return nothing
end
function JuMP.delete_upper_bound(dref::DecisionRef)
    JuMP.delete(owner_model(dref), UpperBoundRef(dref))
    ci = MOI.ConstraintIndex{SingleDecision, MOI.LessThan{Float64}}(index(dref).value)
    remove_mapped_constraint!(get_decisions(dref), ci)
    return nothing
end
function JuMP.upper_bound(dref::DecisionRef)
    if !has_upper_bound(dref)
        error("Decision $(dref) does not have a upper bound.")
    end
    cset = MOI.get(owner_model(dref), MOI.ConstraintSet(),
                   UpperBoundRef(dref))::MOI.LessThan{Float64}
    return cset.upper
end

function JuMP.is_integer(dref::DecisionRef)
    haskey(owner_model(dref).ext, :decisions) || error("No decisions in model.")
    if state(dref) == Known
        return false
    end
    ci = MOI.ConstraintIndex{SingleDecision, MOI.Integer}(index(dref).value)
    inner = mapped_constraint(get_decisions(dref), ci)
    if inner.value == 0
        return false
    end
    return MOI.is_valid(backend(owner_model(dref)), inner)
end
function JuMP.set_integer(dref::DecisionRef)
    if is_integer(dref)
        return nothing
    elseif is_binary(dref)
        error("Cannot set the decision $(dref) to integer as it is already binary.")
    else
        ci = MOI.ConstraintIndex{SingleDecision, MOI.Integer}(index(dref).value)
        inner = MOI.add_constraint(backend(owner_model(dref)), SingleDecision(index(dref)), MOI.Integer())
        map_constraint!(get_decisions(dref), ci, inner)
    end
    return nothing
end
function JuMP.unset_integer(dref::DecisionRef)
    JuMP.delete(owner_model(dref), IntegerRef(dref))
    ci = MOI.ConstraintIndex{SingleDecision, MOI.Integer}(index(dref).value)
    remove_mapped_constraint!(get_decisions(dref), ci)
    return nothing
end
function JuMP.IntegerRef(dref::DecisionRef)
    haskey(owner_model(dref).ext, :decisions) || error("No decisions in model.")
    moi_int =  MOI.ConstraintIndex{SingleDecision, MOI.Integer}
    ci = moi_int(index(dref).value)
    inner = mapped_constraint(get_decisions(dref), ci)
    inner.value == 0 && error("Constraint $ci not properly mapped.")
    return ConstraintRef{JuMP.Model, moi_int, ScalarShape}(owner_model(dref),
                                                           inner,
                                                           ScalarShape())
end

function JuMP.is_binary(dref::DecisionRef)
    haskey(owner_model(dref).ext, :decisions) || error("No decisions in model.")
    if state(dref) == Known
        return false
    end
    ci = MOI.ConstraintIndex{SingleDecision, MOI.ZeroOne}(index(dref).value)
    inner = mapped_constraint(get_decisions(dref), ci)
    if inner.value == 0
        return false
    end
    return MOI.is_valid(backend(owner_model(dref)), inner)
end
function JuMP.set_binary(dref::DecisionRef)
    if is_binary(dref)
        return nothing
    elseif is_integer(dref)
        error("Cannot set the decision $(dref) to binary as it is already integer.")
    else
        ci = MOI.ConstraintIndex{SingleDecision, MOI.ZeroOne}(index(dref).value)
        inner = MOI.add_constraint(backend(owner_model(dref)), SingleDecision(index(dref)), MOI.ZeroOne())
        map_constraint!(get_decisions(dref), ci, inner)
    end
    return nothing
end
function JuMP.unset_binary(dref::DecisionRef)
    JuMP.delete(owner_model(dref), BinaryRef(dref))
    ci = MOI.ConstraintIndex{SingleDecision, MOI.ZeroOne}(index(dref).value)
    remove_mapped_constraint!(get_decisions(dref), ci)
    return nothing
end
function JuMP.BinaryRef(dref::DecisionRef)
    haskey(owner_model(dref).ext, :decisions) || error("No decisions in model.")
    moi_bin =  MOI.ConstraintIndex{SingleDecision, MOI.ZeroOne}
    ci = moi_bin(index(dref).value)
    inner = mapped_constraint(get_decisions(dref), ci)
    inner.value == 0 && error("Constraint $ci not properly mapped.")
    return ConstraintRef{JuMP.Model, moi_bin, ScalarShape}(owner_model(dref),
                                                           inner,
                                                           ScalarShape())
end

function JuMP.start_value(dref::DecisionRef)
    return MOI.get(owner_model(dref), MOI.VariablePrimalStart(), dref)
end
function JuMP.set_start_value(dref::DecisionRef, value::Number)
    MOI.set(owner_model(dref), MOI.VariablePrimalStart(), dref, Float64(value))
    return nothing
end

function Base.hash(dref::DecisionRef, h::UInt)
    return hash(objectid(owner_model(dref)), hash(dref.index, h))
end

JuMP.isequal_canonical(d::DecisionRef, other::DecisionRef) = isequal(d, other)
function Base.isequal(dref::DecisionRef, other::DecisionRef)
    return owner_model(dref) === owner_model(other) && dref.index == other.index
end

Base.iszero(::DecisionRef) = false
Base.copy(dref::DecisionRef) = DecisionRef(dref.model, dref.index)
Base.broadcastable(dref::DecisionRef) = Ref(dref)

function JuMP._info_from_variable(dref::DecisionRef)
    has_lb = has_lower_bound(dref)
    lb = has_lb ? lower_bound(dref) : -Inf
    has_ub = has_upper_bound(dref)
    ub = has_ub ? upper_bound(dref) : Inf
    has_fix = is_fixed(dref)
    fixed_value = has_fix ? value(dref) : NaN
    start_or_nothing = start_value(dref)
    has_start = !(start_or_nothing isa Nothing)
    start = has_start ? start_or_nothing : NaN
    has_start = start !== Nothing
    binary = is_binary(dref)
    integer = is_integer(dref)
    return VariableInfo(has_lb, lb, has_ub, ub, has_fix, fixed_value,
                        has_start, start, binary, integer)
end

function relax_decision_integrality(model::JuMP.Model)
    N = num_stages(model.ext[:decisions])
    all_known = mapreduce(vcat, 1:N-1) do s
        index.(all_known_decision_variables(model, s))
    end
    all_decisions = index.(all_decision_variables(model, N))
    # Collect variable info
    info_pre_relaxation = Vector{Tuple{AbstractVariableRef, VariableInfo}}()
    for var in all_variables(model)
        vi = index(var)
        if vi in all_known
            # Known decision, skip
            continue
        end
        if vi in all_decisions
            # Decision variable
            dref = DecisionRef(model, vi)
            push!(info_pre_relaxation, (dref, JuMP._info_from_variable(dref)))
        else
            # Auxiliary variable
            push!(info_pre_relaxation, (var, JuMP._info_from_variable(var)))
        end
    end
    for (v, info) in info_pre_relaxation
        if info.integer
            unset_integer(v)
        elseif info.binary
            unset_binary(v)
            if !info.has_fix
                set_lower_bound(v, max(0.0, info.lower_bound))
                set_upper_bound(v, min(1.0, info.upper_bound))
            elseif info.fixed_value < 0 || info.fixed_value > 1
                error("The model has no valid relaxation: binary variable " *
                      "fixed out of bounds.")
            end
        end
    end
    function unrelax()
        for (v, info) in info_pre_relaxation
            if info.integer
                set_integer(v)
            elseif info.binary
                set_binary(v)
                if !info.has_fix
                    if info.has_lb
                        set_lower_bound(v, info.lower_bound)
                    else
                        delete_lower_bound(v)
                    end
                    if info.has_ub
                        set_upper_bound(v, info.upper_bound)
                    else
                        delete_upper_bound(v)
                    end
                end
            end
        end
        return
    end
    return unrelax
end
# JuMP copy interface #
# ========================== #
function JuMP.copy_extension_data(decisions::NTuple{N,Decisions}, dest::Model, src::Model) where N
    new_maps = ntuple(Val{N}()) do _
        DecisionMap()
    end
    new_decisions = Decisions(new_maps)
    for s in 1:N
        for dref in all_decision_variables(src, s)
            set_stage!(new_decisions, index(dref), stage(dref))
            set_decision!(new_decisions, index(dref), decision(dref))
        end
        for kref in all_known_decision_variables(src, s)
            set_stage!(new_decisions, index(kref), stage(kref))
            set_decision!(new_decisions, index(kref), decision(kref))
        end
    end
    return new_decisions
end

function Base.getindex(reference_map::JuMP.ReferenceMap, dref::DecisionRef)
    return DecisionRef(reference_map.model,
                       reference_map.index_map[index(dref)])
end
