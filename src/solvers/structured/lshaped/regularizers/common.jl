# Common
# ------------------------------------------------------------
function MOI.get(regularizer::AbstractRegularizer, param::RawRegularizationParameter)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(regularizer.parameters)))
        error("Unrecognized parameter name: $(name) for regularizer $(typeof(regularizer)).")
    end
    return getfield(regularizer.parameters, name)
end

function MOI.set(regularizer::AbstractRegularizer, param::RawRegularizationParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(regularizer.parameters)))
        error("Unrecognized parameter name: $(name) for regularizer $(typeof(regularizer)).")
    end
    setfield!(regularizer.parameters, name, value)
    return nothing
end

function add_projection_targets!(regularization::AbstractRegularization, model::MOI.AbstractOptimizer)
    ξ = regularization.ξ
    for i in eachindex(ξ)
        name = add_subscript(:ξ, i)
        var_index, _ = MOI.add_constrained_variable(model, SingleKnownSet(1, ξ[i]))
        set_known_decision!(regularization.decisions, var_index, ξ[i])
        MOI.set(model, MOI.VariableName(), var_index, name)
        regularization.projection_targets[i] = var_index
    end
    return nothing
end

function decision(::AbstractLShaped, regularization::AbstractRegularization)
    return map(regularization.ξ) do ξᵢ
        ξᵢ.value
    end
end

function objective_value(::AbstractLShaped, regularization::AbstractRegularization)
    return regularization.data.Q̃
end

function gap(lshaped::AbstractLShaped, regularization::AbstractRegularization)
    @unpack θ = lshaped.data
    @unpack Q̃ = regularization.data
    return abs(θ-Q̃)/(abs(Q̃)+1e-10)
end

function process_cut!(lshaped::AbstractLShaped, cut::AbstractHyperPlane, ::AbstractRegularization)
    return nothing
end
