"""
    DecisionRef <: AbstractVariableRef

Holds a reference to the model and the corresponding MOI.VariableIndex.
"""
struct DecisionRef <: JuMP.AbstractVariableRef
    model::JuMP.Model
    index::MOI.VariableIndex
end
"""
    KnownRef <: AbstractVariableRef

Holds a reference to the model and the corresponding MOI.VariableIndex.
"""
struct KnownRef <: JuMP.AbstractVariableRef
    model::JuMP.Model
    index::MOI.VariableIndex
end

# Getters (model) #
# ========================== #
function get_decisions(model::JuMP.Model)
    !haskey(model.ext, :decisions) && return IgnoreDecisions()
    return model.ext[:decisions]
end

function all_decisions(model::JuMP.Model)
    decisions = get_decisions(model)::Decisions
    return all_decisions(decisions)
end

function all_known_decisions(model::JuMP.Model)
    decisions = get_decisions(model)::Decisions
    return all_known_decisions(decisions)
end
"""
    all_decision_variables(model::JuMP.Model)

Returns a list of all decisions currently in the `model`. The decisions are
ordered by creation time.
"""
function all_decision_variables(model::JuMP.Model)
    decisions = get_decisions(model)::Decisions
    return map(decisions.undecided) do index
        DecisionRef(model, index)
    end
end
"""
    all_known_decision_variables(model::JuMP.Model)

Returns a list of all known decisions currently in the `model`. The decisions are
ordered by creation time.
"""
function all_known_decision_variables(model::JuMP.Model)
    decisions = get_decisions(model)::Decisions
    return map(decisions.knowns) do index
        KnownRef(model, index)
    end
end
"""
    num_decisions(model::JuMP.Model)

Return the number of decisions in `model`.
"""
function num_decisions(model::JuMP.Model)
    decisions = get_decisions(model)::Decisions
    return num_decisions(decisions)
end
"""
    num_decisions(model::JuMP.Model)

Return the number of known decisions in `model`.
"""
function num_known_decisions(model::JuMP.Model)
    decisions = get_decisions(model)::Decisions
    return num_known_decisions(decisions)
end


# Getters (refs) #
# ========================== #
function get_decisions(dref::DecisionRef)
    return get_decisions(dref.model)
end

function get_decisions(kref::KnownRef)
    return get_decisions(kref.model)
end
"""
    decision(dref::Union{DecisionRef, KnownRef})

Return the internal `Decision` associated with `dref`.
"""
function decision(dref::Union{DecisionRef, KnownRef})
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
    end
    # Update objective and constraints in model
    update_decisions!(model, DecisionsStateChange())
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
        end
    end
    # Update objective and constraints in model (if needed)
    need_update && update_decisions!(model, DecisionsStateChange())
    return nothing
end

function update_decisions!(model::JuMP.Model)
    update_decisions!(model, DecisionsStateChange())
end

function update_known_decisions!(model::JuMP.Model)
    decisions = get_decisions(model)
    if decisions isa IgnoreDecisions
        # Nothing to do if decisions are ignored
        # @warn ?
        return nothing
    end
    # Update states
    update_decisions!(model, KnownValuesChange())
    return nothing
end

function update_known_decisions!(model::JuMP.Model, krefs::Vector{KnownRef}, vals::AbstractVector)
    decisions = get_decisions(model)
    if decisions isa IgnoreDecisions
        # Nothing to do if decisions are ignored
        # @warn ?
        return nothing
    end
    # Check that all given decisions are in model
    map(kref -> check_belongs_to_model(kref, model), krefs)
    # Check decision length
    length(krefs) == length(vals) || error("Given decision of length $(length(vals)) not compatible with number of defined known decision variables $(length(krefs)).")
    # Update decisions
    for (kref, val) in zip(krefs, vals)
        d = decision(kref)
        # Update value
        d.value = val
    end
    # Update states
    update_decisions!(model, KnownValuesChange())
    return nothing
end

function update_known_decisions!(model::JuMP.Model, vals::AbstractVector)
    decisions = get_decisions(model)
    if decisions isa IgnoreDecisions
        # Nothing to do if decisions are ignored
        # @warn ?
        return nothing
    end
    # Update values
    update_known_decisions!(decisions, vals)
    # Update states
    update_decisions!(model, KnownValuesChange())
    return nothing
end

# JuMP variable interface #
# ========================== #
function MOI.get(model::JuMP.Model, attr::MOI.AbstractVariableAttribute,
                 dref::Union{DecisionRef, KnownRef})
    check_belongs_to_model(dref, model)
    if MOI.is_set_by_optimize(attr)
        return JuMP._moi_get_result(backend(model), attr, index(dref))
    else
        return MOI.get(backend(model), attr, index(dref))
    end
end

function MOI.set(model::Model, attr::MOI.AbstractVariableAttribute,
                 dref::Union{DecisionRef, KnownRef}, value)
    check_belongs_to_model(dref, model)
    MOI.set(backend(model), attr, index(dref), value)
    return nothing
end

JuMP.name(dref::DecisionRef) = MOI.get(owner_model(dref), MOI.VariableName(), dref)::String
JuMP.name(kref::KnownRef) = MOI.get(owner_model(kref), MOI.VariableName(), kref)::String

function JuMP.set_name(dref::DecisionRef, name::String)
    return MOI.set(owner_model(dref), MOI.VariableName(), dref, name)
end
function JuMP.set_name(kref::KnownRef, name::String)
    return MOI.set(owner_model(dref), MOI.VariableName(), kref, name)
end

function decision_by_name(model::Model, name::String)
    index = MOI.get(backend(model), MOI.VariableIndex, name)
    if index isa Nothing
        return nothing
    else
        return DecisionRef(model, index)
    end
end

function known_decision_by_name(model::Model, name::String)
    index = MOI.get(backend(model), MOI.VariableIndex, name)
    if index isa Nothing
        return nothing
    else
        return KnownRef(model, index)
    end
end

JuMP.index(dref::DecisionRef) = dref.index
JuMP.index(kref::KnownRef) = kref.index

function JuMP.value(dref::DecisionRef; result::Int = 1)::Float64
    if state(dref) == Taken
        # If decision has been fixed the value can be fetched
        # directly
        decision(dref).value
    end
    return MOI.get(owner_model(dref), MOI.VariablePrimal(result), dref)
end

function JuMP.value(kref::KnownRef)::Float64
    decisions = get_decisions(kref)::Decisions
    return decision_value(decisions, index(kref))
end

function JuMP.is_fixed(dref::DecisionRef)
    if state(dref) == Taken
        return true
    end
    return false
end

JuMP.is_fixed(kref::KnownRef) = true

function JuMP.unfix(dref::DecisionRef)
    if state(dref) == NotTaken
        # Nothing to do, just return
        return nothing
    end
    d = decision(dref)
    # Update state
    d.state = NotTaken
    # Prepare modification
    change = DecisionStateChange(index(dref), NotTaken, -value(dref))
    # Update objective and constraints
    update_decisions!(JuMP.owner_model(dref), change)
    return nothing
end

function JuMP.unfix(kref::KnownRef)
    error("Decision with known value cannot be unfixed.")
end
"""
    fix(dref::DecisionRef, val::Number)

Fix the decision associated with `dref` to `val`.

See also [`unfix`](@ref).
"""
function JuMP.fix(dref::DecisionRef, val::Number)
    d = decision(dref)
    if state(dref) == NotTaken
        # Prepare modification
        change = DecisionStateChange(index(dref), Taken, val)
        # Update state
        d.state = Taken
        # Update value
        d.value = val
    else
        # Prepare modification
        change = DecisionStateChange(index(dref), Taken, val - d.value)
        # Just update value
        d.value = val
    end
    # Update objective and constraints
    update_decisions!(JuMP.owner_model(dref), change)
    return nothing
end
"""
    fix(kref::KnownRef, val::Number)

Update the known decision value of `kref` to `val`.
"""
function JuMP.fix(kref::KnownRef, val::Number)
    d = decision(kref)
    # Prepare modification
    change = KnownValueChange(index(kref), val - decision_value(d))
    # Update known value
    d.value = val
    # Update objective and constraints
    update_decisions!(JuMP.owner_model(kref), change)
    return nothing
end

function JuMP.delete(model::JuMP.Model, dref::DecisionRef)
    if model !== owner_model(dref)
        error("The decision you are trying to delete does not " *
              "belong to the model.")
    end
    # TODO What to do here?
end

function JuMP.delete(model::JuMP.Model, kref::KnownRef)
    if model !== owner_model(kref)
        error("The known decision you are trying to delete does not " *
              "belong to the model.")
    end
    # TODO What to do here?
end

JuMP.owner_model(dref::DecisionRef) = dref.model
JuMP.owner_model(kref::KnownRef) = kref.model

struct DecisionNotOwned <: Exception
    dref::DecisionRef
end

struct KnownDecisionNotOwned <: Exception
    kref::KnownRef
end

function JuMP.check_belongs_to_model(dref::DecisionRef, model::AbstractModel)
    if owner_model(dref) !== model
        throw(DecisionNotOwned(dref))
    end
end

function JuMP.check_belongs_to_model(kref::KnownRef, model::AbstractModel)
    if owner_model(kref) !== model
        throw(KnownDecisionNotOwned(kref))
    end
end

function JuMP.is_valid(model::Model, dref::DecisionRef)
    return model === owner_model(dref)
end

function JuMP.is_valid(model::Model, kref::KnownRef)
    return model === owner_model(kref)
end

function JuMP.has_lower_bound(dref::DecisionRef)
    index = MOI.ConstraintIndex{SingleDecision, MOI.GreaterThan{Float64}}(index(dref).value)
    return MOI.is_valid(backend(owner_model(dref)), index)
end
function JuMP.LowerBoundRef(dref::DecisionRef)
    moi_lb =  MOI.ConstraintIndex{SingleDecision, MOI.GreaterThan{Float64}}
    index = moi_lb(index(dref).value)
    return ConstraintRef{JuMP.Model, moi_lb, ScalarShape}(owner_model(dref),
                                                          index,
                                                          ScalarShape())
end
function JuMP.set_lower_bound(dref::Decision, lower::Number)
    new_set = MOI.GreaterThan(convert(Float64, lower))
    if has_lower_bound(dref)
        cindex = MOI.ConstraintIndex{SingleDecision, MOI.GreaterThan{Float64}}(index(dref).value)
        MOI.set(backend(owner_model(dref)), MOI.ConstraintSet(), cindex, new_set)
    else
        MOI.add_constraint(backend(owner_model(dref)), SingleDecision(index(dref)), new_set)
    end
    return nothing
end
function JuMP.delete_lower_bound(dref::DecisionRef)
    JuMP.delete(owner_model(dref), LowerBoundRef(dref))
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
    index = MOI.ConstraintIndex{SingleDecision, MOI.LessThan{Float64}}(index(dref).value)
    return MOI.is_valid(backend(owner_model(dref)), index)
end
function JuMP.UpperBoundRef(dref::DecisionRef)
    moi_ub =  MOI.ConstraintIndex{SingleDecision, MOI.LessThan{Float64}}
    index = moi_ub(index(dref).value)
    return ConstraintRef{JuMP.Model, moi_ub, ScalarShape}(owner_model(dref),
                                                          index,
                                                          ScalarShape())
end
function JuMP.set_upper_bound(dref::DecisionRef, lower::Number)
    new_set = MOI.LessThan(convert(Float64, lower))
    if has_upper_bound(dref)
        cindex = MOI.ConstraintIndex{SingleDecision, MOI.LessThan{Float64}}(index(dref).value)
        MOI.set(backend(owner_model(dref)), MOI.ConstraintSet(), cindex, new_set)
    else
        MOI.add_constraint(backend(owner_model(dref)), SingleDecision(index(dref)), new_set)
    end
    return nothing
end
function JuMP.delete_upper_bound(dref::DecisionRef)
    JuMP.delete(owner_model(dref), UpperBoundRef(dref))
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
    index = MOI.ConstraintIndex{SingleDecision, MOI.Integer}(index(dref).value)
    return MOI.is_valid(backend(owner_model(dref)), index)
end
function JuMP.set_integer(dref::DecisionRef)
    if is_integer(dref)
        return nothing
    elseif is_binary(dref)
        error("Cannot set the decision $(dref) to integer as it is already binary.")
    else
        MOI.add_constraint(backend(owner_model(dref)), SingleDecision(index(dref)), MOI.Integer())
    end
end
function unset_integer(dref::DecisionRef)
    JuMP.delete(owner_model(dref), IntegerRef(dref))
    return nothing
end
function JuMP.IntegerRef(dref::DecisionRef)
    moi_int =  MOI.ConstraintIndex{SingleDecision, MOI.Integer}
    index = moi_int(index(dref).value)
    return ConstraintRef{JuMP.Model, moi_int, ScalarShape}(owner_model(dref),
                                                           index,
                                                           ScalarShape())
end

function JuMP.is_binary(dref::DecisionRef)
    index = MOI.ConstraintIndex{SingleDecision, MOI.ZeroOne}(index(dref).value)
    return MOI.is_valid(backend(owner_model(dref)), index)
end
function JuMP.set_binary(dref::DecisionRef)
    if is_binary(dref)
        return nothing
    elseif is_integer(dref)
        error("Cannot set the decision $(dref) to binary as it is already integer.")
    else
        MOI.add_constraint(backend(owner_model(dref)), SingleDecision(index(dref)), MOI.ZeroOne())
    end
end
function unset_binary(dref::DecisionRef)
    JuMP.delete(owner_model(dref), BinaryRef(dref))
    return nothing
end
function JuMP.BinaryRef(dref::DecisionRef)
    moi_bin =  MOI.ConstraintIndex{SingleDecision, MOI.ZeroOne}
    index = moi_bin(index(dref).value)
    return ConstraintRef{JuMP.Model, moi_bin, ScalarShape}(owner_model(dref),
                                                           index,
                                                           ScalarShape())
end

function JuMP.start_value(dref::DecisionRef)
    return MOI.get(owner_model(dref), MOI.VariablePrimalStart(), dref)
end
function JuMP.set_start_value(dref::DecisionRef, value::Number)
    MOI.set(owner_model(dref), MOI.VariablePrimalStart(), dref, Float64(value))
end

JuMP.has_lower_bound(kref::KnownRef) = false
JuMP.LowerBoundRef(kref::KnownRef) = error("Known decision does not have bounds.")
JuMP.set_lower_bound(kref::KnownRef, lower::Number) = error("Known decision does not have bounds.")
JuMP.delete_lower_bound(kref::KnownRef) = error("Known decision does not have bounds.")
JuMP.lower_bound(kref::KnownRef) = error("Known decision does not have bounds.")

JuMP.has_upper_bound(kref::KnownRef) = false
JuMP.UpperBoundRef(kref::KnownRef) = error("Known decision does not have bounds.")
JuMP.set_upper_bound(kref::KnownRef, lower::Number) = error("Known decision does not have bounds.")
JuMP.delete_upper_bound(kref::KnownRef) = error("Known decision does not have bounds.")
JuMP.upper_bound(kref::KnownRef) = error("Known decision does not have bounds.")

JuMP.is_integer(kref::KnownRef) = false
JuMP.set_integer(kref::KnownRef) = error("Known decision does not have integrality constraints.")
JuMP.unset_integer(kref::KnownRef) = error("Known decision does not have integrality constraints.")
JuMP.IntegerRef(kref::KnownRef) = error("Known decision does not have integrality constraints.")

JuMP.is_binary(kref::KnownRef) = false
JuMP.set_binary(kref::KnownRef) = error("Known decision does not have binary constraints.")
JuMP.unset_binary(kref::KnownRef) = error("Known decision does not have binary constraints.")
JuMP.BinaryRef(kref::KnownRef) = error("Known decision does not have binary constraints.")

JuMP.start_value(kref::KnownRef) = error("Known decision does not have start values.")
JuMP.set_start_value(kref::KnownRef, value::Number) = error("Known decision does not have start values.")

function Base.hash(dref::DecisionRef, h::UInt)
    return hash(objectid(owner_model(dref)), hash(dref.index, h))
end
function Base.hash(kref::KnownRef, h::UInt)
    return hash(objectid(owner_model(kref)), hash(kref.index, h))
end

JuMP.isequal_canonical(d::DecisionRef, other::DecisionRef) = isequal(d, other)
function Base.isequal(dref::DecisionRef, other::DecisionRef)
    return owner_model(dref) === owner_model(other) && dref.index == other.index
end
JuMP.isequal_canonical(k::KnownRef, other::KnownRef) = isequal(k, other)
function Base.isequal(kref::KnownRef, other::KnownRef)
    return owner_model(kref) === owner_model(other) && kref.index == other.index
end

Base.iszero(::DecisionRef) = false
Base.copy(dref::DecisionRef) = DecisionRef(dref.model, dref.index)
Base.broadcastable(dref::DecisionRef) = Ref(dref)

Base.iszero(::KnownRef) = false
Base.copy(kref::KnownRef) = KnownRef(dref.model, dref.index)
Base.broadcastable(kref::KnownRef) = Ref(kref)

# JuMP copy interface #
# ========================== #
function JuMP.copy_extension_data(decisions::Decisions, dest::Model, src::Model)
    new_decisions = Decisions()
    for dref in all_decision_variables(src)
        set_decision!(new_decisions, index(dref), decision(dref))
    end
    for kref in all_known_decision_variables(src)
        set_known_decision!(new_decisions, index(kref), decision(kref))
    end
    return new_decisions
end

function Base.getindex(reference_map::JuMP.ReferenceMap, dref::DecisionRef)
    return DecisionRef(reference_map.model,
                       reference_map.index_map[index(dref)])
end

function Base.getindex(reference_map::JuMP.ReferenceMap, kref::KnownRef)
    return DecisionRef(reference_map.model,
                       reference_map.index_map[index(kref)])
end
