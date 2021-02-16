function MOI.get(prox::AbstractProx, param::RawProxParameter)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(prox.parameters)))
        error("Unrecognized parameter name: $(name) for prox $(typeof(prox)).")
    end
    return getfield(prox.parameters, name)
end

function MOI.set(prox::AbstractProx, param::RawProxParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(prox.parameters)))
        error("Unrecognized parameter name: $(name) for prox $(typeof(prox)).")
    end
    setfield!(prox.parameters, name, value)
    return nothing
end
