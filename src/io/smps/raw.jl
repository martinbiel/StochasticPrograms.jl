struct RawSMPS{T <: AbstractFloat}
    name::String
    tim::RawTime
    cor::RawCor{T}
    sto::RawStoch

    function RawSMPS(tim::RawTime, cor::RawCor{T}, sto::RawStoch) where T <: AbstractFloat
        tim.name == cor.name && tim.name == sto.name || error("Inconsistent names of SMPS files.")
        return new{T}(tim.name, tim, cor, sto)
    end
end

function Base.read(io::IO, ::Type{RawSMPS})
    # Get filepath
    m = match(r"<file (.*).smps>", io.name)
    m === nothing && error("SMPS specification is malformed. Correct filename usage: /path/to/smps/files.smps")
    path = only(m.captures)
    # Parse tim file
    timfile = path * ".tim"
    tim = parse_tim(timfile)
    # Parse cor file
    corfile = path * ".cor"
    cor = parse_cor(corfile)
    # Parse sto file
    stofile = path * ".sto"
    sto = parse_sto(tim, cor, stofile)
    return RawSMPS(tim, cor, sto)
end

function Base.read(io::IO, ::Type{RawSMPS{T}}) where T <: AbstractFloat
    # Get filepath
    m = match(r"<file (.*).smps>", io.name)
    m === nothing && error("SMPS specification is malformed. Correct filename usage: /path/to/smps/files.smps")
    path = only(m.captures)
    # Parse tim file
    timfile = path * ".tim"
    tim = parse_tim(T, timfile)
    # Parse cor file
    corfile = path * ".cor"
    cor = parse_cor(T, corfile)
    # Parse sto file
    stofile = path * ".sto"
    sto = parse_sto(T, tim, cor, io)
    return RawSMPS(tim, cor, sto)
end
