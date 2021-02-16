function MOI.get(step::AbstractStepSize, param::RawStepParameter)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(step.parameters)))
        error("Unrecognized parameter name: $(name) for step $(typeof(step)).")
    end
    return getfield(step.parameters, name)
end

function MOI.set(step::AbstractStepSize, param::RawStepParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(step.parameters)))
        error("Unrecognized parameter name: $(name) for step $(typeof(step)).")
    end
    setfield!(step.parameters, name, value)
    return nothing
end
