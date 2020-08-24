function Base.read(io::IO, ::Type{SMPSModel})
    raw = read(io, RawSMPS)
    return SMPSModel(raw)
end

function Base.read(io::IO, ::Type{StochasticModel})
    smps::SMPSModel{2} = read(io, SMPSModel)
    return stochastic_model(smps)
end

function Base.read(io::IO, ::Type{SMPSSampler})
    smps::SMPSModel{2} = read(io, SMPSModel)
    return SMPSSampler(smps.raw.sto, smps.stages[2])
end

function Base.read(io::IO,
                   ::Type{StochasticProgram};
                   num_scenarios::Integer = 1000,
                   instantiation::StochasticInstantiation = StochasticPrograms.UnspecifiedInstantiation(),
                   optimizer = nothing,
                   defer::Bool = false,
                   direct_model::Bool = false,
                   kw...)
    smps::SMPSModel{2} = read(io, SMPSModel)
    sm = stochastic_model(smps)
    sampler = SMPSSampler(smps.raw.sto, smps.stages[2])
    return instantiate(sm, sampler, num_scenarios; instantiation, optimizer, defer, direct_model, kw...)
end
Base.read(filename::AbstractString, ::Type{StochasticProgram}; kw...) = open(io -> read(io, StochasticProgram; kw...), filename)
