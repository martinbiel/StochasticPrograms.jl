# Variables #
# ========================== #
# Helper struct to dispatch known decision variable construction
struct AsKnown end

function JuMP.build_variable(_error::Function, info::JuMP.VariableInfo, ::AsKnown)
    return KnownDecision{Float64}(info)
end

function JuMP.build_variable(_error::Function, variable::JuMP.ScalarVariable, ::DecisionSet)
    return VariableConstrainedOnCreation(variable, SingleDecisionSet(Decision{Float64}(variable.info)))
end

function JuMP.build_variable(_error::Function, variables::Vector{<:JuMP.ScalarVariable}, ::DecisionSet)
    return VariablesConstrainedOnCreation(variables, MultipleDecisionsSet([Decision{Float64}(variable.info) for variable in variables]))
end

function JuMP.add_variable(model::Model, known::KnownDecision, name::String = "")
    decisions = get_decisions(model)
    if decisions isa IgnoreDecisions
        # Create a regular JuMP variable if decisions are not handled
        return JuMP.add_variable(model, known.scalar_variable, name)
    end
    # Set the name (if any)
    known.name = name
    # Add known decision
    index = add_known!(decisions, known, name)
    # Return created known decision as KnownRef
    return KnownRef(model, index)
end

function JuMP.add_variable(model::Model, variable::VariableConstrainedOnCreation{<:SingleDecisionSet}, name::String)
    decisions = get_decisions(model)
    if decisions isa IgnoreDecisions
        # Create a regular JuMP variable if decisions are not handled
        return JuMP.add_variable(model, variable.scalar_variable, name)
    end
    var_index, con_index = MOI.add_constrained_variable(backend(model), variable.set)
    # Map to model decisions after indices are known
    if !has_decision(decisions, var_index)
        # Store decision if is seen for the first time
        set_decision!(decisions, var_index, variable.set.decision)
    else
        # Reuse if decision has been created already
        MOI.set(backend(model), MOI.ConstraintSet(), con_index, SingleDecisionSet(decision(decisions, var_index)))
    end
    # Add any given decision constraints
    _moi_constrain_decision(backend(model), var_index, variable.scalar_variable.info)
    # Finally, set any given name
    if !isempty(name)
        MOI.set(backend(model), MOI.VariableName(), var_index, name)
    end
    # Return created decision as DecisionRef
    return DecisionRef(model, var_index)
end

function JuMP.add_variable(model::Model, variable::VariablesConstrainedOnCreation{<:MultipleDecisionsSet}, names)
    decisions = get_decisions(model)
    if decisions isa IgnoreDecisions
        # Create regular JuMP variables if decisions are not handled
        var_refs = [JuMP.add_variable(model, scalar_variable, name) for scalar_variable in variable.scalar_variables]
        return reshape_vector(var_refs, variable.shape)
    end
    var_indices, con_index = MOI.add_constrained_variables(backend(model), variable.set)
    # Map to model decisions after indices are known
    seen_decisions = Vector{Decision{Float64}}()
    for (i,var_index) in enumerate(var_indices)
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
        length(seen_decisions) == length(decision.scalar_variables) || error("Inconsistency in number of seen decisions and created variables.")
        # Update decision set for reuse
        MOI.set(backend(model), MOI.ConstraintSet(), con_index, MultipleDecisions(seen_decisions))
    end
    # Add any given decision constraints
    for (index, decision, scalar_variable) in zip(var_indices, variable.set.decisions, variable.scalar_variables)
        _moi_constrain_decision(backend(model), index, scalar_variable.info)
    end
    # Finally, set any given names
    for (var_index, name) in zip(var_indices, JuMP.vectorize(names, variable.shape))
        if !isempty(name)
            MOI.set(backend(model), MOI.VariableName(), var_index, name)
        end
    end
    # Return created decisions as DecisionRefs
    drefs = [DecisionRef(model, var_index) for var_index in var_indices]
    return reshape_vector(drefs, variable.shape)
end

function _moi_constrain_decision(backend::MOI.ModelLike, index, info)
    # We don't call the _moi* versions (e.g., _moi_set_lower_bound) because they
    # have extra checks that are not necessary for newly created variables.
    if info.has_lb
        MOI.add_constraint(backend, SingleDecision(index),
                           MOI.GreaterThan{Float64}(info.lower_bound))
    end
    if info.has_ub
        MOI.add_constraint(backend, SingleDecision(index),
                           MOI.LessThan{Float64}(info.upper_bound))
    end
    if info.has_fix
        MOI.add_constraint(backend, SingleDecision(index),
                           MOI.EqualTo{Float64}(info.fixed_value))
    end
    if info.binary
        MOI.add_constraint(backend, SingleDecision(index),
                           MOI.ZeroOne())
    end
    if info.integer
        MOI.add_constraint(backend, SingleDecision(index), MOI.Integer())
    end
    if info.has_start
        MOI.set(backend, MOI.VariablePrimalStart(), index,
                Float64(info.start))
    end
end

# Constraints #
# ========================== #
function JuMP.build_constraint(_error::Function, aff::CombinedAffExpr, set::S) where S <: Union{MOI.LessThan,MOI.GreaterThan,MOI.EqualTo}
    offset = constant(aff.variables)
    add_to_expression!(aff.variables, -offset)
    shifted_set = MOIU.shift_constant(set, -offset)
    return JuMP.ScalarConstraint(aff, shifted_set)
end

function JuMP.build_constraint(_error::Function, aff::CombinedAffExpr, lb, ub)
    JuMP.build_constraint(_error, aff, MOI.Interval(lb, ub))
end
