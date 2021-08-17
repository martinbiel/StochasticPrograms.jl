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

# Variables #
# ========================== #
function JuMP.build_variable(_error::Function, variable::JuMP.ScalarVariable, set::DecisionSet)
    return VariableConstrainedOnCreation(variable, decision_set(variable, set))
end

function JuMP.build_variable(_error::Function, variables::Vector{<:JuMP.ScalarVariable}, set::DecisionSet)
    return VariablesConstrainedOnCreation(variables, decision_set(variables, set))
end

function JuMP.build_variable(_error::Function, variable::JuMP.ScalarVariable, set::KnownSet)
    return VariableConstrainedOnCreation(variable, decision_set(variable, set))
end

function JuMP.build_variable(_error::Function, variables::Vector{<:JuMP.ScalarVariable}, set::KnownSet)
    return VariablesConstrainedOnCreation(variables, decision_set(variables, set))
end

function JuMP.add_variable(model::Model, variable::VariableConstrainedOnCreation{<:SingleDecisionSet}, name::String)
    decisions = get_decisions(model)
    if decisions isa IgnoreDecisions
        # Create a regular JuMP variable if decisions are not handled
        return JuMP.add_variable(model, variable.scalar_variable, name)
    end
    var_index, con_index = MOI.add_constrained_variable(backend(model), variable.set)
    set_stage!(decisions, var_index, variable.set.stage)
    # Map to model decisions after indices are known
    if !has_decision(decisions, var_index)
        # Store decision if is seen for the first time
        set_decision!(decisions, var_index, variable.set.decision)
    else
        # Reuse if decision has been created already
        MOI.set(backend(model), MOI.ConstraintSet(), con_index, reuse(variable.set, decision(decisions, var_index)))
    end
    # Add any given decision constraints
    if state(variable.set.decision) != Known
        _moi_constrain_decision(backend(model), decisions, var_index, variable.scalar_variable.info, variable.set)
    end
    # Finally, set any given name
    if !isempty(name)
        MOI.set(backend(model), MOI.VariableName(), var_index, name)
    end
    # Return created decision as DecisionRef
    return DecisionRef(model, var_index)
end

function JuMP.add_variable(model::Model, variable::VariablesConstrainedOnCreation{<:MultipleDecisionSet}, names)
    decisions = get_decisions(model)
    if decisions isa IgnoreDecisions
        # Create regular JuMP variables if decisions are not handled
        var_refs = map(zip(variable.scalar_variables, names)) do (scalar_variable, name)
            JuMP.add_variable(model, scalar_variable, name)
        end
        return reshape_vector(var_refs, variable.shape)
    end
    if variable.set.constraint isa NoSpecifiedConstraint
        # Sufficient to use single decision bridges if decisions
        # are not initially constrained.
        refs = map(zip(variable.scalar_variables, variable.set.decisions, names)) do (scalar_variable, decision, name)
            set = SingleDecisionSet(variable.set.stage, decision, variable.set.constraint, variable.set.is_recourse)
            add_variable(model, VariableConstrainedOnCreation(scalar_variable, set), name)
        end
        return reshape_vector(refs, variable.shape)
    else
        var_indices, con_index = MOI.add_constrained_variables(backend(model), variable.set)
        # Map to model decisions after indices are known
        seen_decisions = Vector{Decision{Float64}}()
        for (i, var_index) in enumerate(var_indices)
            set_stage!(decisions, var_index, variable.set.stage)
            if !has_decision(decisions, var_index)
                # Store decision if is seen for the first time
                set_decision!(decisions, var_index, variable.set.decisions[i])
            else
                # Reuse if decision has been created already
                push!(seen_decisions, decision(decisions, var_index))
            end
        end
        if !isempty(seen_decisions)
            # Sanity check
            length(seen_decisions) == length(variable.scalar_variables) || error("Inconsistency in number of seen decisions and created variables.")
            # Update decision set for reuse
            MOI.set(backend(model), MOI.ConstraintSet(), con_index, reuse(variable.set, seen_decisions))
        end
        # Add any given decision constraints
        for (index, scalar_variable, decision) in zip(var_indices, variable.scalar_variables, variable.set.decisions)
            if decision.state != Known
                _moi_constrain_decision(backend(model), decisions, index, scalar_variable.info, variable.set)
            end
        end
        # Finally, set any given names
        for (var_index, name) in zip(var_indices, JuMP.vectorize(names, variable.shape))
            if !isempty(name)
                MOI.set(backend(model), MOI.VariableName(), var_index, name)
            end
        end
        # Return created decisions as DecisionRef
        refs = map(var_indices) do index
            DecisionRef(model, index)
        end
        return reshape_vector(refs, variable.shape)
    end
end

# Containers #
# ========================== #
struct DecisionArray{A <: AbstractArray, S <: Union{DecisionSet, KnownSet}}
    array::A
    set::S

    function DecisionArray(array::AbstractArray, set::Union{DecisionSet, KnownSet})
        A = typeof(array)
        S = typeof(set)
        return new{A, S}(array, set)
    end
end

struct DecisionDenseAxisArray{A <: DenseAxisArray, S <: Union{DecisionSet, KnownSet}}
    array::A
    set::S

    function DecisionDenseAxisArray(array::DenseAxisArray, set::Union{DecisionSet, KnownSet})
        A = typeof(array)
        S = typeof(set)
        return new{A, S}(array, set)
    end
end

struct DecisionSparseAxisArray{A <: SparseAxisArray, S <: Union{DecisionSet, KnownSet}}
    array::A
    set::S

    function DecisionSparseAxisArray(array::SparseAxisArray, set::Union{DecisionSet, KnownSet})
        A = typeof(array)
        S = typeof(set)
        return new{A, S}(array, set)
    end
end

function JuMP.build_variable(_error::Function, variables::AbstractArray{<:JuMP.ScalarVariable}, set::Union{DecisionSet,KnownSet})
    return DecisionArray(variables, set)
end

function JuMP.build_variable(_error::Function, variables::DenseAxisArray{<:JuMP.ScalarVariable}, set::Union{DecisionSet,KnownSet})
    return DecisionDenseAxisArray(variables, set)
end

function JuMP.build_variable(_error::Function, variables::SparseAxisArray{<:JuMP.ScalarVariable}, set::Union{DecisionSet,KnownSet})
    return DecisionSparseAxisArray(variables, set)
end

function JuMP.add_variable(model::Model, variable::DecisionArray, names::AbstractArray{String})
    array = variable.array
    refs = Array{DecisionRef}(undef, size(array))
    for idx in eachindex(array)
        var = array[idx]
        refs[idx] = JuMP.add_variable(model,
                                      VariableConstrainedOnCreation(var, decision_set(var, variable.set)),
                                      names[idx])
    end
    return refs
end

function JuMP.add_variable(model::Model, variable::DecisionDenseAxisArray, names::DenseAxisArray{String})
    array = variable.array
    refs = DenseAxisArray{DecisionRef}(undef, array.axes...)
    for idx in eachindex(array)
        var = array[idx]
        refs[idx] = JuMP.add_variable(model,
                                      VariableConstrainedOnCreation(var, decision_set(var, variable.set)),
                                      names[idx])
    end
    return refs
end

function JuMP.add_variable(model::Model,
                           variable::DecisionSparseAxisArray{SparseAxisArray{T,N,K}},
                           names::SparseAxisArray{String}) where {T, N, K}
    refs = SparseAxisArray(Dict{K,DecisionRef}())
    for (idx, var) in variable.array.data
        refs[idx] = JuMP.add_variable(model,
                                      VariableConstrainedOnCreation(var, decision_set(var, variable.set)),
                                      names[idx])
    end
    return refs
end

# Constraints #
# ========================== #
function JuMP._functionize(dref::DecisionRef)
    return convert(DecisionAffExpr{Float64}, dref)
end
function JuMP._functionize(drefs::AbstractArray{DecisionRef})
    return JuMP._functionize.(drefs)
end

function JuMP.build_constraint(_error::Function, aff::Union{DecisionAffExpr, DecisionQuadExpr}, set::MOI.AbstractScalarSet)
    offset = constant(aff.variables)
    JuMP.add_to_expression!(aff.variables, -offset)
    shifted_set = MOIU.shift_constant(set, -offset)
    return JuMP.ScalarConstraint(aff, shifted_set)
end

function JuMP.build_constraint(_error::Function, aff::Union{DecisionAffExpr, DecisionQuadExpr}, lb::Real, ub::Real)
    JuMP.build_constraint(_error, aff, MOI.Interval(lb, ub))
end

function JuMP.add_constraint(model::Model,
                             constraint::ScalarConstraint{DecisionRef, S},
                             name::String = "") where S <: MOI.AbstractScalarSet
    decisions = get_decisions(model)::Decisions
    check_belongs_to_model(constraint, model)
    ci = CI{SingleDecision, S}(moi_function(constraint).decision.value)
    inner = moi_add_constraint(backend(model), moi_function(constraint), moi_set(constraint))
    map_constraint!(decisions, ci, inner)
    con_ref = ConstraintRef(model, inner, shape(constraint))
    if !isempty(name)
        set_name(con_ref, name)
    end
    return con_ref
end

# Helper function #
# ========================== #
function _moi_constrain_decision(backend::MOI.ModelLike,
                                 decisions::Decisions,
                                 index::MOI.VariableIndex,
                                 info::VariableInfo,
                                 set::Union{SingleDecisionSet, MultipleDecisionSet})
    nothing_added = true
    if info.has_lb
        ci = CI{SingleDecision, MOI.GreaterThan{Float64}}(index.value)
        inner = MOI.add_constraint(backend, SingleDecision(index),
                                   MOI.GreaterThan{Float64}(info.lower_bound))
        map_constraint!(decisions, ci, inner)
        nothing_added &= false
    end
    if info.has_ub
        ci = CI{SingleDecision, MOI.LessThan{Float64}}(index.value)
        inner = MOI.add_constraint(backend, SingleDecision(index),
                                   MOI.LessThan{Float64}(info.upper_bound))
        map_constraint!(decisions, ci, inner)
        nothing_added &= false
    end
    if info.has_fix
        ci = CI{SingleDecision, MOI.EqualTo{Float64}}(index.value)
        inner = MOI.add_constraint(backend, SingleDecision(index),
                                   MOI.EqualTo{Float64}(info.fixed_value))
        map_constraint!(decisions, ci, inner)
        nothing_added &= false
    end
    if info.binary
        ci = CI{SingleDecision, MOI.ZeroOne}(index.value)
        inner = MOI.add_constraint(backend, SingleDecision(index),
                                   MOI.ZeroOne())
        map_constraint!(decisions, ci, inner)
        nothing_added &= false
    end
    if info.integer
        ci = CI{SingleDecision, MOI.Integer}(index.value)
        inner = MOI.add_constraint(backend, SingleDecision(index), MOI.Integer())
        map_constraint!(decisions, ci, inner)
        nothing_added &= false
    end
    if info.has_start
        MOI.set(backend, MOI.VariablePrimalStart(), index,
                Float64(info.start))
        nothing_added &= false
    end
    return nothing
end
