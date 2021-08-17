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

struct RawCor{T <: AbstractFloat}
    name::String
    n::Int
    m₁::Int
    m₂::Int
    vars::OrderedDict{Col, Int}
    rows::OrderedDict{Row, Tuple{Int,Int,Symbol}}
    cols::OrderedDict{Col, Vector{Pair{Symbol,T}}}
    rhs::Dict{Row, T}
    ranges::Dict{Row, T}
    bounds::OrderedDict{Col, Vector{Pair{Symbol,T}}}
    objgiven::Bool
    objname::Symbol
    rhsname::Symbol

    function RawCor(n::Integer, m₁::Integer, m₂::Integer,
                    vars::OrderedDict{Col, Int}, rows::OrderedDict{Row, Tuple{Int,Int,Symbol}},
                    cols::OrderedDict{Col, Vector{Pair{Symbol,T}}}, rhs::Dict{Row, T},
                    ranges::Dict{Row, T}, bounds::OrderedDict{Col, Vector{Pair{Symbol,T}}};
                    objgiven::Bool = false,
                    objname::Symbol = OBJ,
                    rhsname::Symbol = RHS,
                    name::String = "LP") where T <: AbstractFloat
        return new{T}(name,
                      n, m₁, m₂,
                      vars, rows, cols,
                      rhs, ranges, bounds,
                      objgiven, objname, rhsname)
    end
end

function parse_cor(::Type{T}, filename::AbstractString) where T <: AbstractFloat
    # Initialize auxiliary variables
    name       = "SLP"
    mode       = NAME
    rowidx     = 1
    eqrowidx   = 0
    ineqrowidx = 0
    varidx     = 1
    objgiven   = false
    objname    = OBJ
    rhsname    = RHS
    # Define sections
    vars    = OrderedDict{Col, Int}()
    rows    = OrderedDict{Row, Tuple{Int,Int,Symbol}}()
    cols    = OrderedDict{Col, Vector{Pair{Symbol,T}}}()
    rhs     = Dict{Row, T}()
    ranges  = Dict{Row, T}()
    bounds  = OrderedDict{Col, Vector{Pair{Symbol,T}}}()
    # Parse the file
    open(filename) do io
        firstline = split(readline(io))
        if Symbol(firstline[1]) == NAME
            name = join(firstline[2:end], " ")
        else
            throw(ArgumentError("`NAME` field is expected on the first line."))
        end
        for line in eachline(io)
            if mode == END
                # Parse finished
                break
            end
            words = split(line)
            first_word = Symbol(words[1])
            if first_word in COR_MODES && first_word != mode
                mode = first_word
                continue
            end
            if mode == ROWS
                rowsym = Symbol(words[2])
                rows[rowsym] =
                    words[1] == "N" ? (objgiven = true; objname = rowsym; (rowidx, 0, OBJ)) :
                    words[1] == "L" ? (ineqrowidx += 1; (rowidx, ineqrowidx, LEQ))            :
                    words[1] == "G" ? (ineqrowidx += 1; (rowidx, ineqrowidx, GEQ))            :
                    (eqrowidx   += 1; (rowidx, eqrowidx, EQ))
                rowidx += 1
            elseif mode == COLUMNS
                var = Symbol(words[1])
                if get!(vars, var, 0) == 0
                    vars[var] = varidx
                    varidx    += 1
                end
                for idx = 2:2:length(words)
                    push!(get!(cols, var, Pair{Symbol,T}[]),
                          Pair(Symbol(words[idx]), convert(T, parse(Float64, words[idx+1]))))
                end
            elseif mode == RHS
                _rhsname = Symbol(words[1])
                if _rhsname  != RHS && rhsname == RHS
                    rhsname = _rhsname
                end
                rhsname == _rhsname || error("Multiple RHS names given.")
                for idx = 2:2:length(words)
                    rhs[Symbol(words[idx])] = convert(T, parse(Float64, words[idx+1]))
                end
            elseif mode == RANGES
                for idx = 2:2:length(words)
                    ranges[Symbol(words[idx])] = convert(T, parse(Float64, words[idx+1]))
                end
            elseif mode == BOUNDS
                var = Symbol(words[3])
                bnd = words[1] == "LO" ? LOWER :
                      words[1] == "UP" ? UPPER :
                      words[1] == "BV" ? BINARY :
                      words[1] == "I"  ? INTEGER :
                      words[1] == "LI" ? INTEGER_LOWER :
                      words[1] == "UI" ? INTEGER_UPPER :
                      words[1] == "FR" ? FREE  : FIXED
                push!(get!(bounds, var, Pair{Symbol,T}[]),
                      Pair(bnd, convert(T, parse(Float64, bnd in [FREE, BINARY, INTEGER] ? "0" : words[4]))))
            else
                throw(ArgumentError("$(mode) is not a valid cor file mode."))
            end
        end
    end
    # Return raw data
    return RawCor(varidx - 1,
                  eqrowidx,
                  ineqrowidx,
                  vars,
                  rows,
                  cols,
                  rhs,
                  ranges,
                  bounds;
                  objgiven = objgiven,
                  objname = objname,
                  rhsname = rhsname,
                  name = name)
end
parse_cor(filename::AbstractString) = parse_cor(Float64, filename)

function sparsity(cor::RawCor)
    return 1 - length(cor.cols) / (cor.n * (cor.m₁ + cor.m₂))
end
