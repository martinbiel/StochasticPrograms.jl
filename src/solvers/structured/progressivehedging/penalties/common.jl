function MOI.get(regularizer::AbstractPenalizer, param::RawPenalizationParameter)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(penalizer)))
        error("Unrecognized parameter name: $(name) for penalizer $(typeof(penalizer)).")
    end
    return getfield(penalizer, name)
end

function MOI.set(penalizer::AbstractPenalizer, param::RawPenalizationParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(penalizer)))
        error("Unrecognized parameter name: $(name) for penalizer $(typeof(penalizer)).")
    end
    setfield!(penalizer, name, value)
    return nothing
end
