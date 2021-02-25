function MOI.get(boosting::AbstractBoosting, param::RawBoostingParameter)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(boosting.parameters)))
        error("Unrecognized parameter name: $(name) for boosting $(typeof(boosting)).")
    end
    return getfield(boosting.parameters, name)
end

function MOI.set(boosting::AbstractBoosting, param::RawBoostingParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(boosting.parameters)))
        error("Unrecognized parameter name: $(name) for boosting $(typeof(boosting)).")
    end
    setfield!(boosting.parameters, name, value)
    return nothing
end
