struct DecisionVariable{SP <: StochasticProgram} <: JuMP.AbstractVariableRef
    stochasticprogram::SP
    index::MOI.VariableIndex
end

# Getters #
# ========================== #
function get_decisions(dvar::DecisionVariable)
    return decisions(structure(owner_model(dvar)))
end

function decision(dvar::DecisionVariable)
    decisions = get_decisions(dvar)::Decisions
    return decision(decisions, index(dvar))
end

function state(dvar::DecisionVariable)
    return decision(dvar).state
end

# Setters #
# ========================== #
function take_decisions!(stochasticprogram::StochasticProgram, dvars::Vector{DecisionVariable}, vals::AbstractVector)
    # Check that all given decisions are in model
    map(dvar -> check_belongs_to_model(dvar, stochasticprogram), dvars)
    # Check decision length
    length(dvars) == length(vals) || error("Given decision of length $(length(vals)) not compatible with number of decision variables $(length(dvars)).")
    # Update decisions
    for (dvar, val) in zip(dvars, vals)
        d = decision(dvar)
        # Update state
        d.state = Taken
        # Update value
        d.value = val
    end
    # Update objective and constraints in model
    update_decisions!(stochasticprogram, DecisionsStateChange())
    return nothing
end

function untake_decisions!(model::JuMP.Model, dvars::Vector{DecisionVariable})
    # Check that all given decisions are in model
    map(dvar -> check_belongs_to_model(dvar, model), dvars)
    # Update decisions
    need_update = false
    for dvar in dvars
        d = decision(dvar)
        if state(d) == Taken
            need_update |= true
            # Update state
            d.state = NotTaken
        end
    end
    # Update objective and constraints in model (if needed)
    need_update && update_decisions!(stochasticprogram, DecisionsStateChange())
    return nothing
end

function update_decisions!(stochasticprogram::StochasticProgram, change::DecisionModification)
    update_decisions!(structure(stochasticprogram), change)
end

# JuMP overloads #
# ========================== #
function JuMP.delete(stochasticprogram::StochasticProgram, dvar::DecisionVariable)
    if stochasticprogram !== owner_model(dvar)
        error("The decision variable you are trying to delete does not " *
              "belong to the stochastic program.")
    end
    MOI.delete(structure(stochasticprogram), index(dvar))
end

function delete(stochasticprogram::StochasticProgram, con_ref::ConstraintRef{<:StochasticProgram})
    if stochasticprogram !== con_ref.model
        error("The constraint reference you are trying to delete does not " *
              "belong to the stochasticprogram.")
    end
    MOI.delete(structure(sto), index(con_ref))
end

# MOI #
# ========================== #
function MOI.get(stochasticprogram::StochasticProgram, attr::MOI.AbstractVariableAttribute,
                 dvar::DecisionVariable)
    check_belongs_to_model(dvar, stochasticprogram)
    if MOI.is_set_by_optimize(attr)
        check_provided_optimizer(stochasticprogram.optimizer)
        if MOI.get(stochasticprogram, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        end
        return MOI.get(optimizer(stochasticprogram), attr, index(dvar))
    end
    return MOI.get(structure(stochasticprogram), attr, index(dvar))
end
function MOI.get(stochasticprogram::StochasticProgram, attr::MOI.AbstractConstraintAttribute,
                 cr::ConstraintRef{<:StochasticProgram})
    check_belongs_to_model(cr, stochasticprogram)
    if MOI.is_set_by_optimize(attr)
        check_provided_optimizer(stochasticprogram.optimizer)
        if MOI.get(stochasticprogram, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        end
        return MOI.get(optimizer(stochasticprogram), attr, index(cr))
    else
        return MOI.get(structure(stochasticprogram), attr, index(cr))
    end
end

function MOI.set(stochasticprogram::StochasticProgram, attr::MOI.AbstractVariableAttribute,
                 dvar::DecisionVariable, value)
    check_belongs_to_model(dvar, stochasticprogram)
    MOI.set(structure(stochasticprogram), attr, index(dvar), value)
    return nothing
end
function MOI.set(stochasticprogram::StochasticProgram, attr::MOI.AbstractConstraintAttribute,
                 cr::ConstraintRef, value)
    check_belongs_to_model(cr, stochasticprogram)
    MOI.set(structure(stochasticprogram), attr, index(cr), value)
end

# JuMP variable interface #
# ========================== #
JuMP.name(dvar::DecisionVariable) = MOI.get(owner_model(dvar), MOI.VariableName(), dvar)::String
function JuMP.set_name(dvar::DecisionVariable, name::String)
    return MOI.set(owner_model(dvar), MOI.VariableName(), dvar, name)
end

function decision_by_name(stochasticprogram::StochasticProgram, name::String)
    index = MOI.get(structure(stochasticprogram), MOI.VariableIndex, name)
    if index isa Nothing
        return nothing
    else
        return DecisionVariable(stochasticprogram, index)
    end
end

JuMP.index(dvar::DecisionVariable) = dvar.index

function JuMP.value(dvar::DecisionVariable; result::Int = 1)::Float64
    d = decision(dvar)
    if d.state == Taken
        # If decision has been fixed the value can be fetched
        # directly
        return d.value
    end
    return MOI.get(owner_model(dvar), MOI.VariablePrimal(result), dvar)
end

function JuMP.is_fixed(dvar::DecisionVariable)
    if state(dvar) == Taken
        return true
    end
    return false
end

function JuMP.unfix(dvar::DecisionVariable)
    if state(dvar) == NotTaken
        # Nothing to do, just return
        return nothing
    end
    d = decision(dvar)
    # Update state
    d.state = NotTaken
    # Prepare modification
    change = DecisionStateChange(index(dvar), NotTaken, -value(dvar))
    # Update objective and constraints
    update_decisions!(JuMP.owner_model(dvar), change)
    return nothing
end

function JuMP.fix(dvar::DecisionVariable, val::Number)
    d = decision(dvar)
    if state(dvar) == NotTaken
        # Prepare modification
        change = DecisionStateChange(index(dvar), Taken, val)
        # Update state
        d.state = Taken
        # Update value
        d.value = val
    else
        # Prepare modification
        change = DecisionStateChange(index(dvar), Taken, val - d.value)
        # Just update value
        d.value = val
    end
    # Update objective and constraints
    update_decisions!(JuMP.owner_model(dvar), change)
    return nothing
end

JuMP.owner_model(dvar::DecisionVariable) = dvar.stochasticprogram

struct DecisionVariableNotOwned <: Exception
    dvar::DecisionVariable
end

function JuMP.check_belongs_to_model(dvar::DecisionVariable, stochasticprogram::StochasticProgram)
    if owner_model(dvar) !== stochasticprogram
        throw(DecisionNotOwned(dvar))
    end
end

function JuMP.is_valid(stochasticprogram::StochasticProgram, dvar::DecisionVariable)
    return stochasticprogram === owner_model(dvar)
end

function JuMP.has_lower_bound(dvar::DecisionVariable)
    index = MOI.ConstraintIndex{SingleDecision, MOI.GreaterThan{Float64}}(index(dvar).value)
    return MOI.is_valid(structure(owner_model(dvar)), index)
end
function JuMP.LowerBoundRef(dvar::DecisionVariable)
    moi_lb =  MOI.ConstraintIndex{SingleDecision, MOI.GreaterThan{Float64}}
    index = moi_lb(index(dvar).value)
    sp = owner_model(dvar)
    SP = typeof(sp)
    return ConstraintRef{SP, moi_lb, ScalarShape}(sp,
                                                  index,
                                                  ScalarShape())
end
function JuMP.set_lower_bound(dvar::DecisionVariable, lower::Number)
    new_set = MOI.GreaterThan(convert(Float64, lower))
    if has_lower_bound(dvar)
        cindex = MOI.ConstraintIndex{SingleDecision, MOI.GreaterThan{Float64}}(index(dvar).value)
        MOI.set(structure(owner_model(dvar)), MOI.ConstraintSet(), cindex, new_set)
    else
        MOI.add_constraint(structure(owner_model(dvar)), SingleDecision(index(dvar)), new_set)
    end
    return nothing
end
function JuMP.delete_lower_bound(dvar::DecisionVariable)
    JuMP.delete(owner_model(dvar), LowerBoundRef(dvar))
end
function JuMP.lower_bound(dvar::DecisionVariable)
    if !has_lower_bound(dvar)
        error("Decision variable $(dvar) does not have a lower bound.")
    end
    cset = MOI.get(structure(owner_model(dvar)), MOI.ConstraintSet(),
                   LowerBoundRef(dvar))::MOI.GreaterThan{Float64}
    return cset.lower
end

function JuMP.has_upper_bound(dvar::DecisionVariable)
    index = MOI.ConstraintIndex{SingleDecision, MOI.LessThan{Float64}}(index(dvar).value)
    return MOI.is_valid(structure(owner_model(dvar)), index)
end
function JuMP.UpperBoundRef(dvar::DecisionVariable)
    moi_ub =  MOI.ConstraintIndex{SingleDecision, MOI.LessThan{Float64}}
    index = moi_ub(index(dvar).value)
    sp = owner_model(dvar)
    SP = typeof(sp)
    return ConstraintRef{SP, moi_ub, ScalarShape}(sp,
                                                  index,
                                                  ScalarShape())
end
function JuMP.set_upper_bound(dvar::DecisionVariable, lower::Number)
    new_set = MOI.LessThan(convert(Float64, lower))
    if has_upper_bound(dvar)
        cindex = MOI.ConstraintIndex{SingleDecision, MOI.LessThan{Float64}}(index(dvar).value)
        MOI.set(structure(owner_model(dvar)), MOI.ConstraintSet(), cindex, new_set)
    else
        MOI.add_constraint(structure(owner_model(dvar)), SingleDecision(index(dvar)), new_set)
    end
    return nothing
end
function JuMP.delete_upper_bound(dvar::DecisionVariable)
    JuMP.delete(owner_model(dvar), UpperBoundRef(dvar))
end
function JuMP.upper_bound(dvar::DecisionVariable)
    if !has_upper_bound(dvar)
        error("Decision $(dvar) does not have a upper bound.")
    end
    cset = MOI.get(structure(owner_model(dvar)), MOI.ConstraintSet(),
                   UpperBoundRef(dvar))::MOI.LessThan{Float64}
    return cset.upper
end

function JuMP.is_integer(dvar::DecisionVariable)
    index = MOI.ConstraintIndex{SingleDecision, MOI.Integer}(index(dvar).value)
    return MOI.is_valid(structure(owner_model(dvar)), index)
end
function JuMP.set_integer(dvar::DecisionVariable)
    if is_integer(dvar)
        return nothing
    elseif is_binary(dvar)
        error("Cannot set the decision $(dvar) to integer as it is already binary.")
    else
        MOI.add_constraint(structure(owner_model(dvar)), SingleDecision(index(dvar)), MOI.Integer())
    end
end
function unset_integer(dvar::DecisionVariable)
    JuMP.delete(owner_model(dvar), IntegerRef(dvar))
    return nothing
end
function JuMP.IntegerRef(dvar::DecisionVariable)
    moi_int =  MOI.ConstraintIndex{SingleDecision, MOI.Integer}
    index = moi_int(index(dvar).value)
    sp = owner_model(dvar)
    SP = typeof(sp)
    return ConstraintRef{SP, moi_int, ScalarShape}(sp,
                                                   index,
                                                   ScalarShape())
end

function JuMP.is_binary(dvar::DecisionVariable)
    index = MOI.ConstraintIndex{SingleDecision, MOI.ZeroOne}(index(dvar).value)
    return MOI.is_valid(structure(owner_model(dvar)), index)
end
function JuMP.set_binary(dvar::DecisionVariable)
    if is_binary(dvar)
        return nothing
    elseif is_integer(dvar)
        error("Cannot set the decision $(dvar) to binary as it is already integer.")
    else
        MOI.add_constraint(structure(owner_model(dvar)), SingleDecision(index(dvar)), MOI.ZeroOne())
    end
end
function unset_binary(dvar::DecisionVariable)
    JuMP.delete(owner_model(dvar), BinaryRef(dvar))
    return nothing
end
function JuMP.BinaryRef(dvar::DecisionVariable)
    moi_bin =  MOI.ConstraintIndex{SingleDecision, MOI.ZeroOne}
    index = moi_bin(index(dvar).value)
    sp = owner_model(dvar)
    SP = typeof(sp)
    return ConstraintRef{SP, moi_bin, ScalarShape}(sp,
                                                   index,
                                                   ScalarShape())
end

function JuMP.start_value(dvar::DecisionVariable)
    return MOI.get(owner_model(dvar), MOI.VariablePrimalStart(), dvar)
end
function JuMP.set_start_value(dvar::DecisionVariable, value::Number)
    MOI.set(owner_model(dvar), MOI.VariablePrimalStart(), dvar, Float64(value))
end

function Base.hash(dvar::DecisionVariable, h::UInt)
    return hash(objectid(owner_model(dvar)), hash(dvar.index, h))
end

JuMP.isequal_canonical(d::DecisionVariable, other::DecisionVariable) = isequal(d, other)
function Base.isequal(dvar::DecisionVariable, other::DecisionVariable)
    return owner_model(dvar) === owner_model(other) && dvar.index == other.index
end

Base.iszero(::DecisionVariable) = false
Base.copy(dvar::DecisionVariable) = DecisionVariable(dvar.stochasticprogram, dvar.index)
Base.broadcastable(dvar::DecisionVariable) = Ref(dvar)
