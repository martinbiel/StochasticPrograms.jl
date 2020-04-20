struct Stage{P}
    parameters::P

    function Stage()
        return new{Nothing}(nothing)
    end

    function Stage(parameters::P) where P
        return new{P}(parameters)
    end
end
parameter_type(stage::Stage{P}) where P = P

struct StageParameters{NT <: NamedTuple}
    names::Vector{Symbol}
    defaults::NT

    function StageParameters(; kw...)
        defaults = values(kw)
        names = collect(keys(defaults))
        NT = typeof(defaults)
        return new{NT}(names, defaults)
    end

    function StageParameters(names::Vector{Symbol}; kw...)
        defaults = values(kw)
        NT = typeof(defaults)
        return new{NT}(names, defaults)
    end
end

function parameters(stage_params::StageParameters; kw...)
    d = Dict(kw)
    params = if isempty(d)
        stage_params.defaults
    else
        filter!(p -> p.first ∈ stage_params.names, d)
        merge(stage_params.defaults, d)
    end
    if length(params) != length(stage_params.names)
        missing = filter(n -> !(n ∈ keys(params)), stage_params.names)
        isare = length(missing) == 1 ? "is" : "are"
        error("Not enough parameters specified. $(join(missing, ',')) $isare missing.")
    end
    return params
end
