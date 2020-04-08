const DecisionVariable = String

struct DecisionVariables{T}
    names::Vector{DecisionVariable}
    decisions::Vector{T}

    function DecisionVariables(::Type{T}) where T <: AbstractFloat
        return new{T}(Vector{DecisionVariable}(), Vector{T}())
    end

    function DecisionVariables(names::Vector{String}, ::Type{T}) where T <: AbstractFloat
        return new{T}(names, zeros(T, length(names)))
    end

    function DecisionVariables(names::Vector{String}, decisions::Vector{T}) where T <: AbstractFloat
        return new{T}(names, decisions)
    end
end

function decision_names(decision_variables::DecisionVariables)
    return decision_variables.names
end

function decisions(decision_variables::DecisionVariables)
    return decision_variables.decisions
end

function ndecisions(decision_variables::DecisionVariables)
    return length(decision_variables.names)
end

function set_decision_variables!(decision_variables::DecisionVariables{T}, names::Vector{DecisionVariable}) where T <: AbstractFloat
    empty!(decision_variables.names)
    append!(decision_variables.names, names)
    empty!(decision_variables.decisions)
    append!(decision_variables.decisions, zeros(T, length(names)))
    return nothing
end

function set_decision_variables!(decision_variables::DecisionVariables{T}, origin::JuMP.Model) where T <: AbstractFloat
    n = num_variables(origin)
    resize!(decision_variables.names, n)
    for i in 1:n
        decision_variables.names[i] = name(VariableRef(origin, MOI.VariableIndex(i)))
    end
    empty!(decision_variables.decisions)
    append!(decision_variables.decisions, zeros(T, n))
    return nothing
end

function get_decision_variables(model::JuMP.Model)
    !haskey(model.ext, :decisionvariables) && error("No decision variables in model")
    return model.ext[:decisionvariables]
end

function clear_decision_variables!(decision_variables::DecisionVariables)
    empty!(decision_variables.names)
    empty!(decision_variables.decisions)
    return nothing
end

function add_decision_variable!(model::JuMP.Model, name::String)
    decision_variables = get_decision_variables(model)
    index = findfirst(d -> d == name, decision_variables.names)
    if index == nothing
        index = new_decision_variable!(decision_variables, name)
    end
    return DecisionRef(model, MOI.VariableIndex(index))
end

function new_decision_variable!(decision_variables::DecisionVariables{T}, name::String) where T <: AbstractFloat
    push!(decision_variables.names, name)
    push!(decision_variables.decisions, zero(T))
    return ndecisions(decision_variables)
end

function extract_decision_variables(model::JuMP.Model, decision_variables::DecisionVariables{T}) where T <: AbstractFloat
    termination_status(model) == MOI.OPTIMAL || error("Model is not optimized, cannot extract decision variables.")
    length(decision_variables.names) > 0 || error("No decision variables.")
    decision = DecisionVariables(decision_names(decision_variables), T)
    for (i,dvar) in enumerate(decision_names(decision))
        var = variable_by_name(model, dvar)
        var == nothing && error("Decision variable $dvar not in given model.")
        decision.decisions[i] = value(var)
    end
    return decision
end

function update_decision_variables!(model::JuMP.Model, x::AbstractVector)
    !haskey(model.ext, :decisionvariables) && error("No decision variables in model")
    update_decision_variables!(model.ext[:decisionvariables], x)
    return nothing
end

function update_decision_variables!(decision_variables::DecisionVariables, x::AbstractVector)
    ndecisions(decision_variables) == length(x) || error("Given decision of length $(length(x)) not compatible with number of defined decision variables ndecisions(decision_variables).")
    decision_variables.decisions .= x
    return nothing
end

function Base.copy(decision_variables::DecisionVariables)
    return DecisionVariables(copy(decision_names(decision_variables)), copy(decisions(decision_variables)))
end

function Base.show(io::IO, decision_variables::DecisionVariables)
    println(io, "Decision variables")
    print(io, join(decision_names(decision_variables), " "))
end

function Base.print(io::IO, decision_variables::DecisionVariables)
    println(io, "Decision variables")
    for (dvar, value) in zip(decision_names(decision_variables), decisions(decision_variables))
        println(io, "$dvar = $value")
    end
end

include("decision_variable.jl")
include("aff_expr.jl")
include("constraint.jl")
include("bridge.jl")
include("operators.jl")
include("mutable_arithmetics.jl")
