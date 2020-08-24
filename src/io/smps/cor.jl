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
    objsymbol::Symbol

    function RawCor(n::Integer, m₁::Integer, m₂::Integer,
                    vars::OrderedDict{Col, Int}, rows::OrderedDict{Row, Tuple{Int,Int,Symbol}},
                    cols::OrderedDict{Col, Vector{Pair{Symbol,T}}}, rhs::Dict{Row, T},
                    ranges::Dict{Row, T}, bounds::OrderedDict{Col, Vector{Pair{Symbol,T}}};
                    objgiven::Bool = false,
                    objsymbol::Symbol = :obj,
                    name::String = "LP") where T <: AbstractFloat
        return new{T}(name,
                      n, m₁, m₂,
                      vars, rows, cols,
                      rhs, ranges, bounds,
                      objgiven, objsymbol)
    end
end

function parse_cor(::Type{T}, filename::AbstractString) where T <: AbstractFloat
    # Initialize auxiliary variables
    name       = "SLP"
    mode       = :NAME
    rowidx     = 1
    eqrowidx   = 0
    ineqrowidx = 0
    varidx     = 1
    objgiven   = false
    objsymbol  = :obj
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
        if Symbol(firstline[1]) == :NAME
            name = join(firstline[2:end], " ")
        else
            throw(ArgumentError("`NAME` field is expected on the first line"))
        end
        for line in eachline(io)
            words = split(line)
            length(words) == 1 && (mode = Symbol(words[1]); continue)
            if mode == :ROWS
                rowsym = Symbol(words[2])
                rows[rowsym] =
                    words[1] == "N" ? (objgiven = true; objsymbol = rowsym; (rowidx, 0, :obj)) :
                    words[1] == "L" ? (ineqrowidx += 1; (rowidx, ineqrowidx, :leq))             :
                    words[1] == "G" ? (ineqrowidx += 1; (rowidx, ineqrowidx, :geq))           :
                    (eqrowidx   += 1; (rowidx, eqrowidx, :eq))
                rowidx += 1
            elseif mode == :COLUMNS
                var = Symbol(words[1])
                if get!(vars, var, 0) == 0
                    vars[var] = varidx
                    varidx    += 1
                end
                for idx = 2:2:length(words)
                    push!(get!(cols, var, Pair{Symbol,T}[]),
                          Pair(Symbol(words[idx]), convert(T, parse(Float64, words[idx+1]))))
                end
            elseif mode == :RHS
                for idx = 2:2:length(words)
                    rhs[Symbol(words[idx])] = convert(T, parse(Float64, words[idx+1]))
                end
            elseif mode == :RANGES
                for idx = 2:2:length(words)
                    ranges[Symbol(words[idx])] = convert(T, parse(Float64, words[idx+1]))
                end
            elseif mode == :BOUNDS
                var = Symbol(words[3])
                bnd = words[1] == "LO" ? :lower :
                    words[1] == "UP" ? :upper :
                    words[1] == "FR" ? :free  : :fixed
                push!(get!(bounds, var, Pair{Symbol,T}[]),
                      Pair(bnd, convert(T, parse(Float64, bnd == :free ? "0" : words[4]))))
            elseif mode == :ENDATA
                break
            else
                throw(ArgumentError("$(mode) is not a valid word"))
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
                  objgiven,
                  objsymbol,
                  name)
end
parse_cor(filename::AbstractString) = parse_cor(Float64, filename)

function sparsity(cor::RawCor)
    return 1 - length(cor.cols) / (cor.n * (cor.m₁ + cor.m₂))
end
