struct Decision end

struct DecisionRef <: JuMP.AbstractVariableRef
    model::JuMP.Model
    index::MOI.VariableIndex
end

function get_decision_variables(decision::DecisionRef)
    return get_decision_variables(decision.model)
end

# JuMP variable interface
# ========================== #
function JuMP.name(dref::DecisionRef)
    decision_variables = get_decision_variables(dref)::DecisionVariables
    return decision_variables.names[dref.index.value]
end

function decision_by_name(model::Model, name::String)
    decision_variables = get_decision_variables(dref)::DecisionVariables
    index = findfirst(decision_variables.names, name)
    index == nothing && return nothing
    return DecisionRef(model, MOI.VariableIndex(index))
end

JuMP.index(dref::DecisionRef) = dref.index

function JuMP.value(dref::DecisionRef)
    decision_variables = get_decision_variables(dref)::DecisionVariables
    return decision_variables.decisions[dref.index.value]
end

JuMP.is_fixed(::DecisionRef) = true
JuMP.unfix(::DecisionRef) = error("Decision variable cannot be unfixed.")

function JuMP.fix(dref::DecisionRef, val::Real)
    decision_variables = get_decision_variables(dref)::DecisionVariables
    decision_variables.decisions[dref] = val
    return
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
    return model === owner_model(dref)
end

JuMP.has_lower_bound(dref::DecisionRef) = false
JuMP.LowerBoundRef(dref::DecisionRef) =
    error("Decision variables do not have bounds.")
JuMP.set_lower_bound(dref::DecisionRef, lower::Number) =
    error("Decision variables do not have bounds.")
JuMP.delete_lower_bound(dref::DecisionRef) =
    error("Decision variables do not have bounds.")
JuMP.lower_bound(dref::DecisionRef) =
    error("Decision variables do not have bounds.")

JuMP.has_upper_bound(dref::DecisionRef) = false
JuMP.UpperBoundRef(dref::DecisionRef) =
    error("Decision variables do not have bounds.")
JuMP.set_upper_bound(dref::DecisionRef, lower::Number) =
    error("Decision variables do not have bounds.")
JuMP.delete_upper_bound(dref::DecisionRef) =
    error("Decision variables do not have bounds.")
JuMP.upper_bound(dref::DecisionRef) =
    error("Decision variables do not have bounds.")

JuMP.is_integer(dref::DecisionRef) = false
JuMP.set_integer(dref::DecisionRef) =
    error("Decision variables do not have integrality constraints.")
JuMP.unset_integer(dref::DecisionRef) =
    error("Decision variables do not have integrality constraints.")
JuMP.IntegerRef(dref::DecisionRef) =
    error("Decision variables do not have integrality constraints.")

JuMP.is_binary(dref::DecisionRef) = false
JuMP.set_binary(dref::DecisionRef) =
    error("Decision variables do not have binary constraints.")
JuMP.unset_binary(dref::DecisionRef) =
    error("Decision variables do not have binary constraints.")
JuMP.BinaryRef(dref::DecisionRef) =
    error("Decision variables do not have binary constraints.")

JuMP.start_value(dref::DecisionRef) =
    error("Decision variables do not have start values.")
JuMP.set_start_value(dref::DecisionRef, value::Number) =
    error("Decision variables do not have start values.")

function Base.hash(dref::DecisionRef, h::UInt)
    return hash(objectid(owner_model(dref)), hash(dref.index, h))
end
function Base.isequal(dref::DecisionRef, other::DecisionRef)
    return owner_model(dref) === owner_model(other) && dref.index == other.index
end
Base.iszero(::DecisionRef) = false
Base.copy(dref::DecisionRef) = DecisionRef(dref.model, dref.index)

# Macros
# ========================== #
function JuMP.build_variable(_error::Function, info::JuMP.VariableInfo, d::Decision)
    return d
end

function JuMP.add_variable(model::JuMP.Model, d::Decision, name::String="")
    isempty(name) && error("Name must be provided for decision variables.")
    dref = add_decision_variable(model, name)
    return dref
end
