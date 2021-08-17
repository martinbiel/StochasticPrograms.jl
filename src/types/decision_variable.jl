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
    DecisionVariable <: AbstractVariableRef

Identifier for a decision in a stochastic program. Holds a reference to the stochastic program, the stage the decision is taken in, and its corresponding MOI.VariableIndex.
"""
struct DecisionVariable <: JuMP.AbstractVariableRef
    stochasticprogram::StochasticProgram
    stage::Int
    index::MOI.VariableIndex
end

# Getters #
# ========================== #
"""
    decision(dvar::DecisionVariable)

Return the internal `Decision` associated with the first-stage `dvar`.
"""
function decision(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `decision(dvar, scenario_index)`.")
    # Dispatch to structure
    return decision_dispatch(decision,
                             structure(owner_model(dvar)),
                             index(dvar),
                             stage(dvar))
end
"""
    decision(dvar::DecisionVariable, scenario_index::Integer)

Return the scenario-dependent internal `Decision` associated with `dvar` at `scenario_index`.
"""
function decision(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `decision(dvar)`.")
    # Dispatch to structure
    return scenario_decision_dispatch(decision,
                                      structure(owner_model(dvar)),
                                      index(dvar),
                                      stage(dvar),
                                      scenario_index)
end
"""
    stage(dvar::DecisionVariable)

Return the stage of `dvar`.
"""
function stage(dvar::DecisionVariable)
    return dvar.stage
end
"""
    state(dvar::DecisionVariable)

Return the `DecisionState` of the first-stage `dvar`.
"""
function state(dvar::DecisionVariable)
    return decision(dvar).state
end
"""
    state(dvar::DecisionVariable, scenario_index::Integer)

Return the scenario-dependent `DecisionState` of `dvar` at `scenario_index`.
"""
function state(dvar::DecisionVariable, scenario_index::Integer)
    return decision(dvar,scenario_index).state
end

# Setters #
# ========================== #
function take_decisions!(stochasticprogram::StochasticProgram, dvars::Vector{DecisionVariable}, vals::AbstractVector)
    if isempty(dvars)
        @warn "No decision variables specified. Nothing to do."
        return nothing
    end
    # Check that all given decisions are in model
    map(dvar -> check_belongs_to_model(dvar, stochasticprogram), dvars)
    # Check that all decisions belong to the same stage
    all(dvar -> stage(dvar) == stage(dvars[1]), dvars) || error("All decisions should be taken in the same stage.")
    # Check that decisions are first-stage
    stage(dvars[1]) == 1 || error("Decisions are scenario-dependent, consider `take_decisions!(sp, dvars, vals, scenario_index)`")
    # Check decision length
    length(dvars) == length(vals) || error("Given decision of length $(length(vals)) not compatible with number of decision variables $(length(dvars)).")
    # Update decisions
    for (dvar, val) in zip(dvars, vals)
        fix(dvar, val)
    end
    return nothing
end
function take_decisions!(stochasticprogram::StochasticProgram, dvars::Vector{DecisionVariable}, vals::AbstractVector, scenario_index::Integer)
    if isempty(dvars)
        @warn "No decision variables specified. Nothing to do."
        return nothing
    end
    # Check that all given decisions are in model
    map(dvar -> check_belongs_to_model(dvar, stochasticprogram), dvars)
    # Check that all decisions belong to the same stage
    all(dvar -> stage(dvar) == stage(dvars[1]), dvars) || error("All decisions should be taken in the same stage.")
    # Check that decisions are not first-stage
    stage(dvars[1]) > 1 || error("Decisions are not scenario-dependent, consider `take_decisions!(sp, dvars, vals)`")
    # Check decision length
    length(dvars) == length(vals) || error("Given decision of length $(length(vals)) not compatible with number of decision variables $(length(dvars)).")
    # Update decisions
    for (dvar, val) in zip(dvars, vals)
        fix(dvar, scenario_index, val)
    end
    return nothing
end

function untake_decisions!(stochasticprogram::StochasticProgram, dvars::Vector{DecisionVariable})
    if isempty(dvars)
        @warn "No decision variables specified. Nothing to do."
        return nothing
    end
    # Check that all given decisions are in model
    map(dvar -> check_belongs_to_model(dvar, model), dvars)
    # Check that all decisions belong to the same stage
    all(dvar -> stage(dvar) == stage(dvars[1]), dvars) || error("All decisions should be taken in the same stage.")
    # Check that decisions are first-stage
    stage(dvars[1]) == 1 || error("Decisions are scenario-dependent, consider `unttake_decisions!(sp, dvars, scenario_index)`")
    # Update decisions
    need_update = false
    for dvar in dvars
        unfix(dvar)
    end
    return nothing
end
function untake_decisions!(stochasticprogram::StochasticProgram, dvars::Vector{DecisionVariable}, scenario_index::Integer)
    if isempty(dvars)
        @warn "No decision variables specified. Nothing to do."
        return nothing
    end
    # Check that all given decisions are in model
    map(dvar -> check_belongs_to_model(dvar, model), dvars)
    # Check that all decisions belong to the same stage
    all(dvar -> stage(dvar) == stage(dvars[1]), dvars) || error("All decisions should be taken in the same stage.")
    # Check that decisions are first-stage
    stage(dvars[1]) > 1 || error("Decisions are not scenario-dependent, consider `take_decisions!(sp, dvars, vals)`")
    # Update decisions
    for dvar in dvars
        unfix(dvar, scenario_index)
    end
    return nothing
end

# MOI #
# ========================== #
function MOI.get(stochasticprogram::StochasticProgram, attr::MOI.AbstractVariableAttribute,
                 dvar::DecisionVariable)
    check_belongs_to_model(dvar, stochasticprogram)
    if MOI.is_set_by_optimize(attr)
        # Check if there is a cached solution
        cache = solutioncache(stochasticprogram)
        if haskey(cache, :solution)
            # Returned cached solution if possible
            try
                return MOI.get(cache[:solution], attr, index(dvar))
            catch
            end
        end
        if haskey(cache, :node_solution_1)
            # Value was possibly only cached in first-stage solution
            try
                return MOI.get(cache[:node_solution_1], attr, index(dvar))
            catch
            end
        end
        check_provided_optimizer(stochasticprogram.optimizer)
        if MOI.get(stochasticprogram, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        end
        return MOI.get(optimizer(stochasticprogram), attr, index(dvar))
    end
    return MOI.get(backend(proxy(stochasticprogram, stage(dvar))), attr, index(dvar))
end
function MOI.get(stochasticprogram::StochasticProgram, attr::ScenarioDependentVariableAttribute,
                 dvar::DecisionVariable)
    check_belongs_to_model(dvar, stochasticprogram)
    if MOI.is_set_by_optimize(attr)
        # Check if there is a cached solution
        cache = solutioncache(stochasticprogram)
        key = Symbol(:node_solution_, attr.stage, :_, attr.scenario_index)
        if haskey(cache, key)
            # Returned cached solution if possible
            try
                return MOI.get(cache[key], attr.attr, index(dvar))
            catch
            end
        end
        check_provided_optimizer(stochasticprogram.optimizer)
        if MOI.get(stochasticprogram, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        end
        try
            # Try to get scenario-dependent value directly
            return MOI.get(optimizer(stochasticprogram), attr, index(dvar))
        catch
            # Fallback to resolving scenario-dependence in structure if
            # not supported natively by optimizer
            return scenario_decision_dispatch(
                structure(stochasticprogram),
                index(dvar),
                stage(dvar),
                attr.scenario_index,
                attr.attr,
            ) do dref, attr
                return MOI.get(owner_model(dref), attr, dref)
            end
        end
    end
    # Get value from structure if not set by optimizer
    return decision_dispatch(
        structure(stochasticprogram),
        index(dvar),
        stage(dvar),
        attr.scenario_index,
        attr.attr,
    ) do dref, attr
        return MOI.get(owner_model(dref), attr, dref)
    end
end

function MOI.set(stochasticprogram::StochasticProgram, attr::MOI.AbstractVariableAttribute,
                 dvar::DecisionVariable, value)
    check_belongs_to_model(dvar, stochasticprogram)
    # Dispatch to structure
    return decision_dispatch!(
        structure(owner_model(dvar)),
        index(dvar),
        stage(dvar),
        attr,
        value,
    ) do dref, attr, value
        MOI.set(owner_model(dref), attr, dref, value)
    end
    return nothing
end
function MOI.set(stochasticprogram::StochasticProgram, attr::ScenarioDependentVariableAttribute,
                 dvar::DecisionVariable, value)
    check_belongs_to_model(dvar, stochasticprogram)
    # Dispatch to structure
    return scenario_decision_dispatch!(
        structure(owner_model(dvar)),
        index(dvar),
        stage(dvar),
        scenario_index,
        attr,
        value,
    ) do dref, attr, value
        MOI.set(owner_model(dref), attr, dref, value)
    end
end

# JuMP variable interface #
# ========================== #
"""
    name(dvar::DecisionVariable, scenario_index::Integer)::String

Get the name of the decision variable `dvar`.
"""
function JuMP.name(dvar::DecisionVariable)::String
    return MOI.get(backend(proxy(owner_model(dvar), stage(dvar))), MOI.VariableName(), index(dvar))::String
end
"""
    name(dvar::DecisionVariable, scenario_index::Integer)::String

Get the name of the scenario-dependent decision variable `dvar` in scenario `scenario_index`.
"""
function JuMP.name(dvar::DecisionVariable, scenario_index::Integer)::String
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `name(dvar)`.")
    # Dispatch to structure
    scenario_decision_dispatch(JuMP.name,
                               structure(owner_model(dvar)),
                               index(dvar),
                               stage(dvar),
                               scenario_index)::String
end
"""
    set_name(dvar::DecisionVariable, scenario_index::Integer, name::String)

Set the name of the decision variable `dvar` to `name`.
"""
function JuMP.set_name(dvar::DecisionVariable, name::String)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `set_name(dvar, scenario_index, name)`.")
    # Dispatch to structure
    decision_dispatch!(JuMP.set_name,
                       structure(owner_model(dvar)),
                       index(dvar),
                       stage(dvar),
                       name)
    return nothing
end
"""
    set_name(dvar::DecisionVariable, scenario_index::Integer, name::String)

Set the name of the scenario-dependent decision variable `dvar` in scenario `scenario_index` to `name`.
"""
function JuMP.set_name(dvar::DecisionVariable, scenario_index::Integer, name::String)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `set_name(dvar, name)`.")
    # Dispatch to structure
    scenario_decision_dispatch!(JuMP.set_name,
                                structure(owner_model(dvar)),
                                index(dvar),
                                stage(dvar),
                                scenario_index,
                                name)
    return nothing
end
"""
    decision_by_name(stochasticprogram::Stochasticprogram,
                     stage::Integer,
                     name::String)::Union{AbstractVariableRef, Nothing}

Returns the reference of the variable with name attribute `name` at `stage` of `stochasticprogram` or `Nothing` if
no variable has this name attribute. Throws an error if several variables have
`name` as their name attribute at stage `s`.
"""
function decision_by_name(stochasticprogram::StochasticProgram{N}, stage::Integer, name::String) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    index = MOI.get(backend(proxy(stochasticprogram, stage)), MOI.VariableIndex, name)
    if index isa Nothing
        return nothing
    else
        return DecisionVariable(stochasticprogram, stage, index)
    end
end
"""
    index(dvar::DecisionVariable)::MOI.VariableIndex

Return the index of the decision variable that corresponds to `dvar` in the MOI backend.
"""
function JuMP.index(dvar::DecisionVariable)
    return dvar.index
end
"""
    optimizer_index(dvar::DecisionVariable)::MOI.VariableIndex

Return the index of the variable that corresponds to `dvar` in the optimizer model.
"""
function JuMP.optimizer_index(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `optimizer_index(dvar, scenario_index)`.")
    return JuMP._moi_optimizer_index(structure(owner_model(dvar)), index(dvar))
end
"""
    optimizer_index(dvar::DecisionVariable, scenario_index)::MOI.VariableIndex

Return the index of the variable that corresponds to the scenario-dependent `dvar` in the optimizer model at `scenario_index`.
"""
function JuMP.optimizer_index(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `optimizer_index(dvar)`.")
    return JuMP._moi_optimizer_index(structure(owner_model(dvar)), index(dvar), scenario_index)
end
"""
    has_duals(stochasticprogram::StochasticProgram; result::Int = 1)

Return `true` if the solver has a primal solution in the first-stage of
`stochasticprogram` in result index `result` available to query,
otherwise return `false`.
"""
function JuMP.has_values(stochasticprogram::StochasticProgram; result::Int = 1)
    return primal_status(stochasticprogram; result = result) != MOI.NO_SOLUTION
end
"""
    has_values(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer; result::Int = 1)

Return `true` if the solver has a primal solution in the node at stage
`stage` and scenario `scenario_index` in result index `result`
available to query, otherwise return `false`.
"""
function JuMP.has_values(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer; result::Int = 1)
    return primal_status(stochasticprogram, stage, scenario_index; result = result) != MOI.NO_SOLUTION
end
"""
    has_values(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer; result::Int = 1)

Return `true` if the solver has a primal solution in scenario `scenario_index`
in result index `result` available to query, otherwise return `false`.
"""
function JuMP.has_values(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer; result::Int = 1)
    return has_values(stochasticprogram, 2, scenario_index; result = result)
end
"""
    value(dvar::DecisionVariable; result = 1)

Return the value of the first-stage decision variable `dvar`
associated with result index `result` of the most-recent
returned by the solver.
"""
function JuMP.value(dvar::DecisionVariable; result::Int = 1)::Float64
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `value(dvar, scenario_index)`.")
    d = decision(dvar)
    if d.state == Taken
        # If decision has been fixed the value can be fetched
        # directly
        return d.value
    end
    return MOI.get(owner_model(dvar), MOI.VariablePrimal(result), dvar)
end
"""
    value(dvar::DecisionVariable, scenario_index::Integer; result = 1)

Return the scenario-dependent value of the decision variable `dvar`
associated with result index `result` at `scenario_index` of the
most-recent returned by the solver.
"""
function JuMP.value(dvar::DecisionVariable, scenario_index::Integer; result::Int = 1)::Float64
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `value(dvar)`.")
    d = decision(dvar, scenario_index)
    if d.state == Taken
        # If decision has been fixed the value can be fetched
        # directly
        return d.value
    end
    attr = ScenarioDependentVariableAttribute(stage(dvar), scenario_index, MOI.VariablePrimal(result))
    return MOI.get(owner_model(dvar), attr, dvar)
end
"""
    value(dvar_expr::Union{GenericAffExpr{T,DecisionVariable}, GenericQuadExpr{T,DecisionVariable}}, stage_to_scenario::Dict{Int,Int}) where T

Evaluate `dvar_expr` where the value of a given `dvar` is found in the scenario returned by the provided `stage_to_scenario` map.
"""
function JuMP.value(dvar_expr::Union{GenericAffExpr{T,DecisionVariable}, GenericQuadExpr{T,DecisionVariable}}, stage_to_scenario::Dict{Int,Int}; result::Int = 1)::Float64 where T
    var_value = (dvar) -> begin
        if stage(dvar) == 1
            return value(dvar; result = result)
        end
        return value(dvar, stage_to_scenario[stage(dvar)]; result = result)
    end
    return value(dvar_expr, var_value)
end
"""
    reduced_cost(dvar::DecisionVariable)::Float64

Return the reduced cost associated with the decision variable `dvar`.
"""
function JuMP.reduced_cost(dvar::DecisionVariable)::Float64
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `reduced_cost(dvar, scenario_index)`.")
    sp = owner_model(dvar)
    if !has_duals(sp)
        error("Unable to query reduced cost of variable because stochastic program does" *
              " not have duals available in the first stage.")
    end
    sign = objective_sense(sp) == MOI.MIN_SENSE ? 1.0 : -1.0
    if is_fixed(dvar)
        return sign * dual(FixRef(dvar))
    end
    rc = 0.0
    if has_upper_bound(dvar)
        rc += dual(UpperBoundRef(dvar))
    end
    if has_lower_bound(dvar)
        rc += dual(LowerBoundRef(dvar))
    end
    return sign * rc
end
"""
    reduced_cost(dvar::DecisionVariable)::Float64

Return the reduced cost associated with the scenario-dependent decision variable `dvar` at `scenario_index`.
"""
function JuMP.reduced_cost(dvar::DecisionVariable, scenario_index::Integer)::Float64
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `reduced_cost(dvar)`.")
    sp = owner_model(dvar)
    if !has_duals(sp, scenario_index)
        error("Unable to query reduced cost of variable because stochastic program does" *
              " not have duals available in scenario `scenario_index`.")
    end
    sign = objective_sense(sp) == MOI.MIN_SENSE ? 1.0 : -1.0
    if is_fixed(dvar, scenario_index)
        return sign * dual(FixRef(dvar), scenario_index)
    end
    rc = 0.0
    if has_upper_bound(dvar, scenario_index)
        rc += dual(UpperBoundRef(dvar), scenario_index)
    end
    if has_lower_bound(dvar, scenario_index)
        rc += dual(LowerBoundRef(dvar), scenario_index)
    end
    return sign * rc
end
"""
    is_fixed(dvar::DecisionVariable)

Return `true` if `dvar` is a fixed first-stage decision variable.
"""
function JuMP.is_fixed(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `is_fixed(dvar, scenario_index)`.")
    if state(dvar) == Taken
        return true
    end
    return false
end
"""
    is_fixed(dvar::DecisionVariable, scenario_index)

Return `true` if `dvar` is a fixed decision variable in `scenario_index`.
"""
function JuMP.is_fixed(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `is_fixed(dvar)`.")
    if state(dvar, scenario_index) == Taken
        return true
    end
    return false
end
"""
    fix(dvar::DecisionVariable, val::Number)

Fix the first-stage decision associated with `dvar` to `val`. In contexts
where `dvar` is a variable, the variable is fixed to the value. In
contexts where `dvar` is a known parameter value, the value is updated.
"""
function JuMP.fix(dvar::DecisionVariable, val::Number)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `fix(dvar, scenario_index, val)`.")
    fix(structure(owner_model(dvar)), index(dvar), stage(dvar), val)
    return nothing
end
"""
    fix(dvar::DecisionVariable, scenario_index::Integer, val::Number)

Fix the scenario-dependent decision associated with `dvar` at `scenario_index`
to `val`. In contexts where `dvar` is a variable, the variable is fixed to the
value. In contexts where `dvar` is a known parameter value, the value is updated.
"""
function JuMP.fix(dvar::DecisionVariable, scenario_index::Integer, val::Number)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `fix(dvar, val)`.")
    fix(structure(owner_model(dvar)), index(dvar), stage(dvar), scenario_index, val)
    return nothing
end
"""
    unfix(dvar::DecisionVariable)

Unfix the first-stage decision associated with `dvar`. If the decision
is already in a `NotTaken` state, this does nothing.
"""
function JuMP.unfix(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `unfix(dvar, scenario_index)`.")
    if state(dvar) == NotTaken
        # Nothing to do, just return
        return nothing
    end
    unfix(structure(owner_model(dvar)), index(dvar), stage(dvar))
    return nothing
end
"""
    unfix(dvar::DecisionVariable, scenario_index::Integer)

Unfix the scenario-dependent decision associated with `dvar`
at `scenario_index`. If the decision is already in a `NotTaken`
state, this does nothing.
"""
function JuMP.unfix(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `unfix(dvar)`.")
    if state(dvar, scenario_index) == NotTaken
        # Nothing to do, just return
        return nothing
    end
    unfix(structure(owner_model(dvar)), index(dvar), stage(dvar), scenario_index)
    return nothing
end

"""
    FixRef(dvar::DecisionVariable)

Return a constraint reference to the constraint fixing the value of the decision `dvar`. Errors
if one does not exist.
"""
function JuMP.FixRef(dvar::DecisionVariable)
    moi_fix =  MOI.ConstraintIndex{SingleDecision, MOI.EqualTo{Float64}}
    return SPConstraintRef{moi_fix, ScalarShape}(owner_model(dvar),
                                                 stage(dvar),
                                                 moi_fix(index(dvar).value),
                                                 ScalarShape())
end

function JuMP.fix_value(dvar::DecisionVariable)
    cset = MOI.get(owner_model(v), MOI.ConstraintSet(), FixRef(dvar))::MOI.EqualTo{Float64}
    return cset.value
end

function JuMP.owner_model(dvar::DecisionVariable)
    return dvar.stochasticprogram
end

struct DecisionVariableNotOwned <: Exception
    dvar::DecisionVariable
end

function JuMP.check_belongs_to_model(dvar::DecisionVariable, stochasticprogram::StochasticProgram)
    if owner_model(dvar) !== stochasticprogram
        throw(DecisionNotOwned(dvar))
    end
end
"""
    is_valid(stochasticprogram::StochasticProgram, dvar::DecisionVariable)

Return `true` if `dvar` refers to a valid first-stage decision variable in `stochasticprogram`.
"""
function JuMP.is_valid(stochasticprogram::StochasticProgram, dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `is_valid(dvar, scenario_index)`.")
    return stochasticprogram === owner_model(dvar) &&
        MOI.is_valid(structure(stochasticprogram), index(dvar), stage(dvar))
end
"""
    is_valid(stochasticprogram::StochasticProgram, dvar::DecisionVariable, scenario_index::Integer)

Return `true` if the scenario-dependent `dvar` refers to a valid decision variable in `stochasticprogram` at `scenario_index`.
"""
function JuMP.is_valid(stochasticprogram::StochasticProgram, dvar::DecisionVariable, scenario_index::Integer)::Bool
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `is_valid(dvar)`.")
    return stochasticprogram === owner_model(dvar) &&
        MOI.is_valid(structure(stochasticprogram), index(dvar), stage(dvar), scenario_index)
end
"""
    delete(stochasticprogram::StochasticProgram, dvar::DecisionVariable)

Delete the first-stage decision variable associated with `dvar` from the `stochasticprogram`.
"""
function JuMP.delete(stochasticprogram::StochasticProgram, dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `delete(stochasticprogram, dvar, scenario_index)`.")
    if stochasticprogram !== owner_model(dvar)
        error("The decision variable you are trying to delete does not " *
              "belong to the stochastic program.")
    end
    # Dispatch to structure
    decision_dispatch!(structure(owner_model(dvar)),
                       index(dvar),
                       stage(dvar)) do dref
                           JuMP.delete(owner_model(dref), dref)
                           return nothing
                       end
    return nothing
end
"""
    delete(stochasticprogram::StochasticProgram, dvar::DecisionVariable, scenario_index::Integer)

Delete the scenario-dependent decision variable associated with `dvar` from the `stochasticprogram` at `scenario_index`.
"""
function JuMP.delete(stochasticprogram::StochasticProgram, dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `delete(stochasticprogram, dvar)`.")
    if stochasticprogram !== owner_model(dvar)
        error("The decision variable you are trying to delete does not " *
              "belong to the stochastic program.")
    end
    # Dispatch to structure
    scenario_decision_dispatch!(structure(owner_model(dvar)),
                                index(dvar),
                                stage(dvar),
                                scenario_index) do dref
                                    JuMP.delete(owner_model(dref), dref)
                                end
    return nothing
end
"""
    delete(stochasticprogram::StochasticProgram, dvars::Vector{DecisionVariable})

Delete the decisions associated with `dvars` from the `stochasticprogram`.
"""
function JuMP.delete(stochasticprogram::StochasticProgram, dvars::Vector{DecisionVariable})
    all(stage.(dvars) .== stage(dvars[1])) || error("$dvars are not all from the same stage")
    stage(dvars[1]) > 1 && error("Some of $dvars are scenario dependent, consider `delete(stochasticprogram, dvars, scenario_index)`.")
    if any(stochasticprogram !== owner_model(dvar) for dvar in dvars)
        error("A decision variable you are trying to delete does not " *
              "belong to the stochastic program.")
    end
    MOI.delete(structure(stochasticprogram), index.(dvars), stage(dvars[1]))
    return nothing
end
"""
    delete(stochasticprogram::StochasticProgram, dvars::Vector{DecisionVariable}, scenario_index::Integer)

Delete the scenario-dependent decisions associated with `dvars` from the `stochasticprogram` at `scenario_index`.
"""
function JuMP.delete(stochasticprogram::StochasticProgram, dvars::Vector{DecisionVariable}, scenario_index::Integer)
    all(stage.(dvars) .== stage(dvars[1])) || error("$dvars are not all from the same stage")
    stage(dvars[1]) == 1 && error("$dvars are not scenario dependent, consider `delete(stochasticprogram, dvars)`.")
    if any(stochasticprogram !== owner_model(dvar) for dvar in dvars)
        error("A decision variable you are trying to delete does not " *
              "belong to the stochastic program.")
    end
    MOI.delete(structure(stochasticprogram), index.(dvars), stage(dvars[1]), scenario_index)
    return nothing
end
"""
    has_lower_bound(dvar::DecisionVariable)

Return `true` if the first-stage decision variable `dvar` has a lower bound.
"""
function JuMP.has_lower_bound(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `has_lower_bound(dvar, scenario_index)`.")
    # Dispatch to structure
    return decision_dispatch(JuMP.has_lower_bound,
                             structure(owner_model(dvar)),
                             index(dvar),
                             stage(dvar))::Bool
end
"""
    has_lower_bound(dvar::DecisionVariable, scenario_index::Integer)

Return `true` if the scenario-dependent decision variable `dvar` has a lower bound at `scenario_index`.
"""
function JuMP.has_lower_bound(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `has_lower_bound(dvar)`.")
    # Dispatch to structure
    return scenario_decision_dispatch(JuMP.has_lower_bound,
                                      structure(owner_model(dvar)),
                                      index(dvar),
                                      stage(dvar),
                                      scenario_index)::Bool
end
"""
    LowerBoundRef(dvar::DecisionVariable)

Return a constraint reference to the lower bound constraint of the decision variable `dvar`.
Errors if one does not exist.
"""
function JuMP.LowerBoundRef(dvar::DecisionVariable)
    moi_lb =  MOI.ConstraintIndex{SingleDecision, MOI.GreaterThan{Float64}}
    return SPConstraintRef{moi_lb, ScalarShape}(owner_model(dvar),
                                                stage(dvar),
                                                moi_lb(index(dvar).value),
                                                ScalarShape())
end
"""
    set_lower_bound(dvar::DecisionVariable)

Set the lower bound of the first-stage decision variable `dvar` to `lower`. If one does not exist, create a new lower bound constraint.
"""
function JuMP.set_lower_bound(dvar::DecisionVariable, lower::Number)
    new_set = MOI.GreaterThan(convert(Float64, lower))
    # Update proxy
    proxy_ = proxy(owner_model(dvar), stage(dvar))
    dref = DecisionRef(proxy_, index(dvar))
    set_lower_bound(dref, lower)
    # Update structure
    if stage(dvar) == 1
        # Dispatch to structure
        decision_dispatch!(JuMP.set_lower_bound,
                           structure(owner_model(dvar)),
                           index(dvar),
                           stage(dvar),
                           lower)
    else
        # Update all constraints at stage
        for scenario_index in 1:num_scenarios(owner_model(dvar), stage(dvar))
            set_lower_bound(dvar, scenario_index, lower)
        end
    end
    return nothing
end
"""
    set_lower_bound(dvar::DecisionVariable, scenario_index::Integer, lower::Number)

Set the lower bound of the scenario-dependent decision variable `dvar` at `scenario_index` to `lower`. If one does not exist, create a new lower bound constraint.
"""
function JuMP.set_lower_bound(dvar::DecisionVariable, scenario_index::Integer, lower::Number)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `set_lower_bound(dvar, lower)`.")
    new_set = MOI.GreaterThan(convert(Float64, lower))
    # Dispatch to structure
    scenario_decision_dispatch!(JuMP.set_lower_bound,
                                structure(owner_model(dvar)),
                                index(dvar),
                                stage(dvar),
                                scenario_index,
                                lower)
    return nothing
end
"""
    delete_lower_bound(dvar::DecisionVariable)

Delete the lower bound constraint of the first-stage decision variable `dvar`.
"""
function JuMP.delete_lower_bound(dvar::DecisionVariable)
    # Update proxy
    proxy_ = proxy(owner_model(dvar), stage(dvar))
    dref = DecisionRef(proxy_, index(dvar))
    delete_lower_bound(dref)
    # Update structure
    if stage(dvar) == 1
        # Dispatch to structure
        decision_dispatch!(JuMP.delete_lower_bound,
                           structure(owner_model(dvar)),
                           index(dvar),
                           stage(dvar))
    else
        # Update all constraints at stage
        for scenario_index in 1:num_scenarios(owner_model(dvar), stage(dvar))
            delete_lower_bound(dvar, scenario_index, lower)
        end
    end
    return nothing
end
"""
    delete_lower_bound(dvar::DecisionVariable, scenario_index::Integer)

Delete the lower bound constraint of the scenario-dependent decision variable `dvar` at `scenario_index`.
"""
function JuMP.delete_lower_bound(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `delete_lower_bound(dvar)`.")
    # Dispatch to structure
    scenario_decision_dispatch!(JuMP.delete_lower_bound,
                                structure(owner_model(dvar)),
                                index(dvar),
                                stage(dvar),
                                scenario_index)
    return nothing
end
"""
    lower_bound(dvar::DecisionVariable)

Return the lower bound of the first-stage decision variable `dvar`. Error if one does not exist.
"""
function JuMP.lower_bound(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `lower_bound(dvar, scenario_index)`.")
    if !has_lower_bound(dvar)
        error("Decision variable $(dvar) does not have a lower bound.")
    end
    # Dispatch to structure
    return decision_dispatch(JuMP.lower_bound,
                             structure(owner_model(dvar)),
                             index(dvar),
                             stage(dvar))::Float64
end
"""
    lower_bound(dvar::DecisionVariable, scenario_index::Integer)

Return the lower bound of the scenario-dependent decision variable `dvar` at `scenario_index`. Error if one does not exist.
"""
function JuMP.lower_bound(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `lower_bound(dvar)`.")
    if !has_lower_bound(dvar, scenario_index)
        error("Decision variable $(dvar) at $scenario_index does not have a lower bound.")
    end
    # Dispatch to structure
    return scenario_decision_dispatch(JuMP.lower_bound,
                                      structure(owner_model(dvar)),
                                      index(dvar),
                                      stage(dvar),
                                      scenario_index)::Float64
end
"""
    has_upper_bound(dvar::DecisionVariable)

Return `true` if the first-stage decision variable `dvar` has a upper bound.
"""
function JuMP.has_upper_bound(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `upper_bound(dvar, scenario_index)`.")
    # Dispatch to structure
    return decision_dispatch(JuMP.has_upper_bound,
                             structure(owner_model(dvar)),
                             index(dvar),
                             stage(dvar))::Bool
end
"""
    has_upper_bound(dvar::DecisionVariable, scenario_index::Integer)

Return `true` if the scenario-dependent decision variable `dvar` has a upper bound at `scenario_index`.
"""
function JuMP.has_upper_bound(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `upper_bound(dvar)`.")
    # Dispatch to structure
    return scenario_decision_dispatch(JuMP.has_upper_bound,
                                      structure(owner_model(dvar)),
                                      index(dvar),
                                      stage(dvar),
                                      scenario_index)::Bool
end
"""
    LowerBoundRef(dvar::DecisionVariable)

Return a constraint reference to the upper bound constraint of the decision variable `dvar`.
Errors if one does not exist.
"""
function JuMP.UpperBoundRef(dvar::DecisionVariable)
    moi_ub =  MOI.ConstraintIndex{SingleDecision, MOI.LessThan{Float64}}
    return SPConstraintRef{moi_ub, ScalarShape}(owner_model(dvar),
                                                stage(dvar),
                                                moi_ub(index(dvar).value),
                                                ScalarShape())
end
"""
    set_upper_bound(dvar::DecisionVariable, upper::Number)

Set the upper bound of the first-stage decision variable `dvar` to `upper`. If one does not exist, create a new upper bound constraint.
"""
function JuMP.set_upper_bound(dvar::DecisionVariable, upper::Number)
    new_set = MOI.LessThan(convert(Float64, upper))
    # Update proxy
    proxy_ = proxy(owner_model(dvar), stage(dvar))
    dref = DecisionRef(proxy_, index(dvar))
    set_upper_bound(dref, upper)
    # Update structure
    if stage(dvar) == 1
        # Dispatch to structure
        decision_dispatch!(JuMP.set_upper_bound,
                           structure(owner_model(dvar)),
                           index(dvar),
                           stage(dvar),
                           upper)
    else
        # Update all constraints at stage
        for scenario_index in 1:num_scenarios(owner_model(dvar), stage(dvar))
            set_upper_bound(dvar, scenario_index, upper)
        end
    end
    return nothing
end
"""
    set_upper_bound(dvar::DecisionVariable, scenario_index::Integer, upper::Number)

Set the upper bound of the scenario-dependent decision variable `dvar` at `scenario_index` to `upper`. If one does not exist, create a new upper bound constraint.
"""
function JuMP.set_upper_bound(dvar::DecisionVariable, scenario_index::Integer, upper::Number)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `set_upper_bound(dvar, upper)`.")
    new_set = MOI.LessThan(convert(Float64, upper))
    # Dispatch to structure
    scenario_decision_dispatch!(JuMP.set_upper_bound,
                                structure(owner_model(dvar)),
                                index(dvar),
                                stage(dvar),
                                scenario_index,
                                upper)
    return nothing
end
"""
    delete_upper_bound(dvar::DecisionVariable)

Delete the upper bound constraint of the first-stage decision variable `dvar`.
"""
function JuMP.delete_upper_bound(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `delete_upper_bound(dvar, scenario_index)`.")
    # Update proxy
    proxy_ = proxy(owner_model(dvar), stage(dvar))
    dref = DecisionRef(proxy_, index(dvar))
    delete_upper_bound(dref)
    # Update structure
    if stage(dvar) == 1
        # Dispatch to structure
        decision_dispatch!(JuMP.delete_upper_bound,
                           structure(owner_model(dvar)),
                           index(dvar),
                           stage(dvar))
    else
        # Update all constraints at stage
        for scenario_index in 1:num_scenarios(owner_model(dvar), stage(dvar))
            delete_upper_bound(dvar, scenario_index)
        end
    end
end
"""
    delete_upper_bound(dvar::DecisionVariable, scenario_index::Integer)

Delete the upper bound constraint of the scenario-dependent decision variable `dvar` at `scenario_index`.
"""
function JuMP.delete_upper_bound(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `delete_upper_bound(dvar)`.")
    # Dispatch to structure
    scenario_decision_dispatch!(JuMP.delete_upper_bound,
                                structure(owner_model(dvar)),
                                index(dvar),
                                stage(dvar),
                                scenario_index)
end
"""
    upper_bound(dvar::DecisionVariable)

Return the upper bound of the first-stage decision variable `dvar`. Error if one does not exist.
"""
function JuMP.upper_bound(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `upper_bound(dvar, scenario_index)`.")
    if !has_upper_bound(dvar)
        error("Decision $(dvar) does not have a upper bound.")
    end
    # Dispatch to structure
    return decision_dispatch(JuMP.upper_bound,
                             structure(owner_model(dvar)),
                             index(dvar),
                             stage(dvar))::Float64
end
"""
    upper_bound(dvar::DecisionVariable, scenario_index::Integer)

Return the upper bound of the scenario-dependent decision variable `dvar` at `scenario_index`. Error if one does not exist.
"""
function JuMP.upper_bound(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `upper_bound(dvar)`.")
    if !has_upper_bound(dvar, scenario_index)
        error("Decision $(dvar) at `scenario_index` does not have a upper bound.")
    end
    # Dispatch to structure
    return scenario_decision_dispatch(JuMP.upper_bound,
                                      structure(owner_model(dvar)),
                                      index(dvar),
                                      stage(dvar),
                                      scenario_index)::Float64
end
"""
    is_integer(dvar::DecisionVariable)

Return `true` if the first-stage decision variable `dvar` is constrained to be integer.
"""
function JuMP.is_integer(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `is_integer(dvar, scenario_index)`.")
    # Dispatch to structure
    return decision_dispatch(JuMP.is_integer,
                             structure(owner_model(dvar)),
                             index(dvar),
                             stage(dvar))::Bool
end
"""
    is_integer(dvar::DecisionVariable, scenario_index::Integer)

Return `true` if the scenario-dependent decision variable `dvar` is constrained to be integer at `scenario_index`.
"""
function JuMP.is_integer(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `is_integer(dvar)`.")
    # Dispatch to structure
    return scenario_decision_dispatch(JuMP.is_integer,
                                      structure(owner_model(dvar)),
                                      index(dvar),
                                      stage(dvar),
                                      scenario_index)::Bool
end
"""
    IntegerRef(dvar::DecisionVariable)

Return a constraint reference to the integrality constraint of the decision variable `dvar`.
Errors if one does not exist.
"""
function JuMP.IntegerRef(dvar::DecisionVariable)
    moi_int =  MOI.ConstraintIndex{SingleDecision, MOI.Integer}
    return SPConstraintRef{moi_int, ScalarShape}(owner_model(dvar),
                                                 stage(dvar),
                                                 moi_int(index(dvar).value),
                                                 ScalarShape())
end
"""
    set_integer(dvar::DecisionVariable)

Add an integrality constraint on the first-stage decision variable `dvar`.
"""
function JuMP.set_integer(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `set_integer(dvar, scenario_index)`.")
    # Update proxy
    proxy_ = proxy(owner_model(dvar), stage(dvar))
    dref = DecisionRef(proxy_, index(dvar))
    set_integer(dref)
    # Update structure
    if stage(dvar) == 1
        # Dispatch to structure
        decision_dispatch!(JuMP.set_integer,
                           structure(owner_model(dvar)),
                           index(dvar),
                           stage(dvar))
    else
        # Update all constraints at stage
        for scenario_index in 1:num_scenarios(owner_model(dvar), stage(dvar))
            set_integer(dvar, scenario_index)
        end
    end
    return nothing
end
"""
    set_integer(dvar::DecisionVariable, scenario_index::Integer)

Add an integrality constraint on the scenario-dependent decision variable `dvar` at `scenario_index`.
"""
function JuMP.set_integer(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `set_integer(dvar)`.")
    # Dispatch to structure
    scenario_decision_dispatch!(JuMP.set_integer,
                                structure(owner_model(dvar)),
                                index(dvar),
                                stage(dvar),
                                scenario_index)
    return nothing
end
"""
    unset_integer(dvar::DecisionVariable)

Delete the integrality constraint of the first-stage decision variable `dvar`.
"""
function JuMP.unset_integer(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `unset_integer(dvar, scenario_index)`.")
    # Update proxy
    proxy_ = proxy(owner_model(dvar), stage(dvar))
    dref = DecisionRef(proxy_, index(dvar))
    unset_integer(dref)
    # Update structure
    if stage(dvar) == 1
        # Dispatch to structure
        decision_dispatch!(JuMP.unset_integer,
                           structure(owner_model(dvar)),
                           index(dvar),
                           stage(dvar))
    else
        # Update all constraints at stage
        for scenario_index in 1:num_scenarios(owner_model(dvar), stage(dvar))
            unset_integer(dvar, scenario_index)
        end
    end
    return nothing
end
"""
    unset_integer(dvar::DecisionVariable, scenario_index::Integer)

Delete the integrality constraint of the scenario-dependent decision variable `dvar` at `scenario_index`.
"""
function JuMP.unset_integer(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `unset_integer(dvar)`.")
    # Dispatch to structure
    scenario_decision_dispatch!(JuMP.unset_integer,
                                structure(owner_model(dvar)),
                                index(dvar),
                                stage(dvar),
                                scenario_index)
    return nothing
end
"""
    is_binary(dvar::DecisionVariable)

Return `true` if the first-stage decision variable `dvar` is constrained to be binary.
"""
function JuMP.is_binary(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `is_binary(dvar, scenario_index)`.")
    # Dispatch to structure
    return decision_dispatch(JuMP.is_binary,
                             structure(owner_model(dvar)),
                             index(dvar),
                             stage(dvar))::Bool
end
"""
    is_binary(dvar::DecisionVariable, scenario_index::Integer)

Return `true` if the scenario-dependent decision variable `dvar` is constrained to be binary at `scenario_index`.
"""
function JuMP.is_binary(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `is_binary(dvar)`.")
    # Dispatch to structure
    return scenario_decision_dispatch(JuMP.is_binary,
                                      structure(owner_model(dvar)),
                                      index(dvar),
                                      stage(dvar),
                                      scenario_index)::Bool
end
"""
    BinaryRef(dvar::DecisionVariable)

Return a constraint reference to the binary constraint of the decision variable `dvar`.
Errors if one does not exist.
"""
function JuMP.BinaryRef(dvar::DecisionVariable)
    moi_bin =  MOI.ConstraintIndex{SingleDecision, MOI.ZeroOne}
    return SPConstraintRef{moi_bin, ScalarShape}(owner_model(dvar),
                                                 stage(dvar),
                                                 moi_bin(index(dvar).value),
                                                 ScalarShape())
end
"""
    set_binary(dvar::DecisionVariable)

Constrain the first-stage decision variable `dvar` to the set ``\\{0,1\\}``.
"""
function JuMP.set_binary(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `set_binary(dvar, scenario_index)`.")
    # Update proxy
    proxy_ = proxy(owner_model(dvar), stage(dvar))
    dref = DecisionRef(proxy_, index(dvar))
    set_binary(dref)
    # Update structure
    if stage(dvar) == 1
        # Dispatch to structure
        decision_dispatch!(JuMP.set_binary,
                           structure(owner_model(dvar)),
                           index(dvar),
                           stage(dvar))
    else
        # Update all constraints at stage
        for scenario_index in 1:num_scenarios(owner_model(dvar), stage(dvar))
            set_binary(dvar, scenario_index)
        end
    end
    return nothing
end
"""
    set_binary(dvar::DecisionVariable, scenario_index::Integer)

Constrain the scenario-dependent decision variable `dvar` to the set ``\\{0,1\\}`` at `scenario_index`.
"""
function JuMP.set_binary(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `set_binary(dvar)`.")
    # Dispatch to structure
    scenario_decision_dispatch!(JuMP.set_binary,
                                structure(owner_model(dvar)),
                                index(dvar),
                                stage(dvar),
                                scenario_index)
end
"""
    unset_binary(dvar::DecisionVariable)

Delete the binary constraint of the first-stage decision variable `dvar`.
"""
function JuMP.unset_binary(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `unset_binary(dvar, scenario_index)`.")
    # Update proxy
    proxy_ = proxy(owner_model(dvar), stage(dvar))
    dref = DecisionRef(proxy_, index(dvar))
    unset_binary(dref)
    # Update structure
    if stage(dvar) == 1
        # Dispatch to structure
        decision_dispatch!(JuMP.unset_binary,
                           structure(owner_model(dvar)),
                           index(dvar),
                           stage(dvar))
    else
        # Update all constraints at stage
        for scenario_index in 1:num_scenarios(owner_model(dvar), stage(dvar))
            unset_binary(dvar, scenario_index)
        end
    end
    return nothing
end
"""
    unset_binary(dvar::DecisionVariable, scenario_index::Integer)

Delete the binary constraint of the scenario-dependent decision variable `dvar` at `scenario_index`.
"""
function JuMP.unset_binary(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `unset_binary(dvar)`.")
    # Dispatch to structure
    scenario_decision_dispatch!(JuMP.unset_binary,
                                structure(owner_model(dvar)),
                                index(dvar),
                                stage(dvar),
                                scenario_index)
    return nothing
end
"""
    start_value(dvar::DecisionVariable)

Return the start value of the first-stage decision variable `dvar`.
"""
function JuMP.start_value(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `start_value(dvar, scenario_index)`.")
    # Dispatch to structure
    decision_dispatch(JuMP.start_value,
                      structure(owner_model(dvar)),
                      index(dvar),
                      stage(dvar))
end
"""
    start_value(dvar::DecisionVariable, scenario_index::Integer)

Return the start value of the scenario-dependent decision variable `dvar`
at `scenario_index`.
"""
function JuMP.start_value(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `start_value(dvar)`.")
    # Dispatch to structure
    scenario_decision_dispatch(JuMP.start_value,
                               structure(owner_model(dvar)),
                               index(dvar),
                               stage(dvar),
                               scenario_index)
end
"""
    set_start_value(dvar::DecisionVariable)

Set the start value of the first-stage decision variable `dvar` to `value`.
"""
function JuMP.set_start_value(dvar::DecisionVariable, value::Number)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `set_start_value(dvar, scenario_index, value)`.")
    # Update proxy
    proxy_ = proxy(owner_model(dvar), stage(dvar))
    dref = DecisionRef(proxy_, index(dvar))
    set_start_value(dref, value)
    # Dispatch to structure
    decision_dispatch!(JuMP.set_start_value,
                       structure(owner_model(dvar)),
                       index(dvar),
                       stage(dvar),
                       value)
    return nothing
end
"""
    set_start_value(dvar::DecisionVariable, scenario_index::Integer, value::Number)

Set the start value of the scenario-dependent decision variable `dvar`
at `scenario_index` to `value`.
"""
function JuMP.set_start_value(dvar::DecisionVariable, scenario_index::Integer, value::Number)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `set_start_value(dvar, value)`.")
    # Dispatch to structure
    scenario_decision_dispatch!(JuMP.set_start_value,
                                structure(owner_model(dvar)),
                                index(dvar),
                                stage(dvar),
                                scenario_index,
                                value)
end

function Base.hash(dvar::DecisionVariable, h::UInt)
    return hash(objectid(owner_model(dvar)), hash(dvar.index, h))
end

JuMP.isequal_canonical(d::DecisionVariable, other::DecisionVariable) = isequal(d, other)
function Base.isequal(dvar::DecisionVariable, other::DecisionVariable)
    return owner_model(dvar) === owner_model(other) && dvar.index == other.index
end

Base.iszero(::DecisionVariable) = false
Base.copy(dvar::DecisionVariable) = DecisionVariable(dvar.stochasticprogram, stage(dvar), dvar.index)
Base.broadcastable(dvar::DecisionVariable) = Ref(dvar)

function DecisionRef(dvar::DecisionVariable)
    stage(dvar) > 1 && error("$dvar is scenario dependent, consider `DecisionRef(dvar, scenario_index)`.")
    sp = owner_model(dvar)
    return DecisionRef(structure(sp), index(dvar))
end
function DecisionRef(dvar::DecisionVariable, scenario_index::Integer)
    stage(dvar) == 1 && error("$dvar is not scenario dependent, consider `DecisionRef(dvar)`.")
    sp = owner_model(dvar)
    return DecisionRef(structure(sp), index(dvar), stage(dvar), scenario_index)
end
function DecisionRef(dvar::DecisionVariable, at_stage::Integer, scenario_index::Integer)
    at_stage > stage(dvar) || error("$dvar can only be known after stage $(stage(dvar)).")
    sp = owner_model(dvar)
    return DecisionRef(structure(sp), index(dvar), at_stage, stage(dvar), scenario_index)
end

is_decision_type(::Type{DecisionVariable}) = true

function JuMP.moi_function_type(::Type{DecisionVariable})
    return SingleDecision
end
function JuMP.moi_function_type(::Type{<:Vector{<:DecisionVariable}})
    return VectorOfDecisions
end

"""
    relax_integrality(stochasticprogram::StochasticProgram)

Modifies `stochasticprogram` to "relax" all binary and integrality constraints on decisions and auxiliary variables.

Returns a function that can be called without any arguments to restore the
original stochasticprogram. The behavior of this function is undefined if additional
changes are made to the affected decisions and variables in the meantime.
"""
function JuMP.relax_integrality(stochasticprogram::StochasticProgram)
    unrelax = relax_integrality(structure(stochasticprogram))
    return unrelax
end
