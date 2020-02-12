const DecisionVariable = String

struct DecisionVariables{T}
    names::Vector{DecisionVariable}
    decisions::Vector{T}

    function DecisionVariables(::Type{T}) where T <: AbstractFloat
        return new{T}(Vector{DecisionVariable}(), zeros(T))
    end

    function DecisionVariables(names::Vector{String}, ::Type{T}) where T <: AbstractFloat
        return new{T}(names, zeros(T))
    end

    function DecisionVariables(names::Vector{String}, decisions::Vector{T}) where T <: AbstractFloat
        return new{T}(names, decisions)
    end
end

function _set_names!(decision_variables::DecisionVariables{T}, names::Vector{DecisionVariable}) where T <: AbstractFloat
    empty!(decision_variables.names)
    append!(decision_variables.names, names)
    empty!(decision_variables.decisions)
    append!(decision_variables.decisions, zero(T))
    return
end

function set_decision_variables!(decision_variables::DecisionVariables{T}, origin::JuMP.Model) where T <: AbstractFloat
    resize!(decision_variables.names, num_variables(model))
    for i in 1:num_variables(model)
        decision_variables.names[i] = name(VariableRef(origin, MOI.VariableIndex(i)))
    end
    empty!(decision_variables.decisions)
    append!(decision_variables.decisions, zero(T))
    return
end

function _get_decision_variables(model::JuMP.Model)
    !haskey(model.ext, :decisionvariables) && error("No decision variables in model")
    return model.ext[:decisionvariables]
end

function add_decision_variable(model::JuMP.Model, name::String)
    decision_variables = _getdecisionvariables(model)
    index = findfirst(decision_variables.names, name)
    index == nothing && error("No matching decision variable with name $name.")
    return DecisionRef(model, MOI.VariableIndex(index))
end

function update_decision_variables!(model::JuMP.Model, x::AbstractVector)
    !haskey(model.ext, :decisionvariables) && error("No decision variables in model")
    _update_decision_variables!(model.ext[:decisionvariables], x)
    return
end

function _update_decision_variables!(decision_variables::DecisionVariables, x::AbstractVector)
    length(decision_variables.decisions) == length(x) || error("Given decision of length $(length(x)) not compatible with defined decision variables of length $(length(decision_variables.decisions)).")
    decision_variables.decisions .= x
    return
end

function Base.copy(decision_variables::DecisionVariables)
    return DecisionVariables(copy(decision_variables.names), decision_variables.decisions)
end

include("decision_variable.jl")
include("aff_expr.jl")
include("constraint.jl")
include("bridge.jl")
include("operators.jl")
