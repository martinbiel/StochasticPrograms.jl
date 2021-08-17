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
