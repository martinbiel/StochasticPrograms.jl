# MIT License
#
# Copyright (c) 2018 Martin Biel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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
