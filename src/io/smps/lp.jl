struct IndexMap
    n::Int
    m₁::Int
    m₂::Int
    map::Dict{RowCol, IdxGroup}

    function IndexMap(n::Integer, m₁::Integer, m₂::Integer)
        return new(n, m₁, m₂, Dict{RowCol, IdxGroup}())
    end
end
Base.setindex!(map::IndexMap, val::IdxGroup, key::RowCol) = setindex!(map.map, val, key)
Base.getindex(map::IndexMap, key::RowCol) = getindex(map.map, key)

struct LPData{T <: AbstractFloat, M <: AbstractMatrix}
    c₁::Vector{T}
    c₂::T
    A::M
    b::Vector{T}
    d₁::Vector{T}
    C::M
    d₂::Vector{T}
    lb::Vector{T}
    ub::Vector{T}
    is_binary::Vector{Bool}
    is_integer::Vector{Bool}
    indexmap::IndexMap

    function LPData(::Type{T}, ::Type{<:Matrix}, n::Int, m₁::Int, m₂::Int) where T <: AbstractFloat
        return new{T, Matrix{T}}(
            zeros(T, n),
            zero(T),
            zeros(T, m₁, n),
            zeros(T, m₁),
            fill(convert(T, -Inf), m₂),
            zeros(T, m₂, n),
            fill(convert(T, Inf), m₂),
            fill(convert(T, -Inf), n),
            fill(convert(T, Inf), n),
            fill(false, n),
            fill(false, n),
            IndexMap(n, m₁, m₂))
    end

    function LPData(::Type{T}, ::Type{<:SparseMatrixCSC}, n::Int, m₁::Int, m₂::Int) where T <: AbstractFloat
        return new{T, SparseMatrixCSC{T,Int}}(
            zeros(T, n),
            zero(T),
            spzeros(T, m₁, n),
            zeros(T, m₁),
            fill(convert(T, -Inf), m₂),
            spzeros(T, m₂, n),
            fill(convert(T, Inf), m₂),
            fill(convert(T, -Inf), n),
            fill(convert(T, Inf), n),
            fill(false, n),
            fill(false, n),
            IndexMap(n, m₁, m₂))
    end

    function LPData(::Type{T}, c₁::AbstractVector, c₂::Real,
                    A::AbstractMatrix, b::AbstractVector,
                    d₁::AbstractVector, C::AbstractMatrix, d₂::AbstractVector,
                    lb::AbstractVector, ub::AbstractVector,
                    is_binary::AbstractVector, is_integer::AbstractVector,
                    map::IndexMap) where T <: AbstractFloat
        A_ = convert(Matrix{T}, A)
        C_ = convert(Matrix{T}, C)
        # Sanity check
        _lpcheck(c₁, c₂, A, b, d₁, C, d₂, lb, ub, is_binary, is_integer)
        # Return data
        return new{T, Matrix{T}}(c₁, c₂, A_, b, d₁, C_, d₂, lb, ub, is_binary, is_integer, map)
    end

    function LPData(::Type{T}, c₁::AbstractVector, c₂::Real,
                    A::AbstractSparseMatrix, b::AbstractVector,
                    d₁::AbstractVector, C::AbstractSparseMatrix, d₂::AbstractVector,
                    lb::AbstractVector, ub::AbstractVector,
                    is_binary::AbstractVector, is_integer::AbstractVector,
                    map::IndexMap) where T <: AbstractFloat
        A_ = convert(SparseMatrixCSC{T}, A)
        C_ = convert(SparseMatrixCSC{T}, C)
        # Sanity check
        _lpcheck(c₁, c₂, A, b, d₁, C, d₂, lb, ub, is_binary, is_integer)
        # Return data
        return new{T, SparseMatrixCSC{T,Int}}(c₁, c₂, A_, b, d₁, C_, d₂, lb, ub, is_binary, is_integer, map)
    end
end

LPData(n::Int, m₁::Int, m₂::Int) =
    LPData(Float64, Matrix, n, m₁, m₂)
LPData(t::Type{T}) where T <: AbstractFloat =
    LPData(t, 0, 0, 0)
LPData() =
    LPData(Float64)

SparseLPData(n::Int, m₁::Int, m₂::Int) =
    LPData(Float64, SparseMatrixCSC, n, m₁, m₂)
SparseLPData(t::Type{T}) where T <: AbstractFloat =
    SparseLPData(t, 0, 0, 0)
SparseLPData() =
    SparseLPData(Float64)

function _lpcheck(c₁::AbstractVector, c₂::Real,
                  A::AbstractMatrix, b::AbstractVector,
                  d₁::AbstractVector, C::AbstractMatrix, d₂::AbstractVector,
                  lb::AbstractVector, ub::AbstractVector,
                  is_binary::AbstractVector, is_integer::AbstractVector)
    n₁ = length(c₁)
    m₁, n₂ = size(A)
    m₂, n₃ = size(C)

    if n₁ ≠ n₂
        throw(DomainError(A ,"LPData: `A` must have $(n₁) columns, has $(n₂)"))
    elseif m₁ ≠ length(b)
        throw(DomainError(b ,"LPData: `b` must have $(m₁) elements, , has $(length(b))"))
    elseif n₁ ≠ n₃
        throw(DomainError(D ,"LPData: `D` must have $(n₁) columns, , has $(n₃)"))
    elseif m₂ ≠ length(d₁) || m₂ ≠ length(d₂)
        throw(DomainError(d ,"LPData: `d₁` and `d₂` must have $(m₂) elements, has $(length(d₁)) and $(length(d₂))"))
    elseif n₁ ≠ length(lb) || n₁ ≠ length(ub)
        throw(DomainError((lb, ub) ,"LPData: Both `lb` and `ub` must have $(n₁) elements, , has $(length(lb)) and $(length(ub))"))
    elseif n₁ ≠ length(is_binary) || n₁ ≠ length(is_integer)
        throw(DomainError((lb, ub) ,"LPData: Both `is_binary` and `is_integer` must have $(n₁) elements, , has $(length(is_binary)) and $(length(is_integer))"))
    end
end

function LPData(c₁::AbstractVector, c₂::Real,
                A::AbstractMatrix, b::AbstractVector,
                d₁::AbstractVector, C::AbstractMatrix, d₂::AbstractVector,
                lb::AbstractVector, ub::AbstractVector,
                is_binary::AbstractVector, is_integer::AbstractVector,
                map::IndexMap)
    return LPData(Float64, c₁, c₂, A, b, d₁, C, d₂, lb, ub, is_binary, is_integer, map)
end

function LPData(cor::RawCor{T};
                colrange = collect(keys(cor.cols)),
                rowrange = collect(keys(cor.rows)),
                include_constant = false) where T <: AbstractFloat
    # Compute sizes
    n = length(colrange)
    m₁ = count(x -> x[3] == EQ, [cor.rows[row] for row in rowrange])
    m₂ = length(rowrange) - m₁
    # Prepare index map
    map = IndexMap(n, m₁, m₂)
    # Prepare matrices
    c₁ = zeros(T, n)
    c₂ = zero(T)
    A  = zeros(T, m₁, n)
    b  = zeros(T, m₁)
    d₁ = fill(convert(T, -Inf), m₂)
    C  = zeros(T, m₂, n)
    d₂ = fill(convert(T, Inf), m₂)
    lb = zeros(T, n)
    ub = fill(convert(T, Inf), n)
    is_binary = fill(false, n)
    is_integer = fill(false, n)
    # Aux counters
    ncols = 0
    neqrows = 0
    nineqrows = 0
    for (row, rowval) in cor.rows
        if row in rowrange
            break
        end
        if rowval[3] == EQ
            neqrows += 1
        elseif rowval[3] == LEQ || rowval[3] == GEQ
            nineqrows += 1
        end
    end
    # Fill (in)equalities with ranges
    for (col, val) in cor.cols
        col in colrange || (ncols += 1; continue)
        colidx = cor.vars[col]
        for (row, rowval) in val
            row in rowrange || continue
            idx, rowidx, rowsense = cor.rows[row]
            rowcol = (row, col)
            if rowidx == 0
                j = colidx - ncols
                c₁[j] = rowval
                map[rowcol] = (0,j,OBJ)
            elseif rowsense == EQ
                i = rowidx - neqrows
                j = colidx - ncols
                A[i, j] = rowval
                b[i] = get(cor.rhs, row, zero(T))
                map[rowcol] = (i,j,EQ)
                map[(row,RHS)] = (i,0,EQ)
            elseif rowsense == LEQ
                i = rowidx - nineqrows
                j = colidx - ncols
                C[i, j] = rowval
                d₂[i] = get(cor.rhs, row, zero(T))
                map[rowcol] = (i,j,LEQ)
                map[(row,RHS)] = (i,0,LEQ)
                if haskey(cor.ranges, row)
                    d₁[i] = d₂[i] - abs(cor.ranges[row])
                    map[rowcol] = (i,j,RANGE)
                    map[(row,RHS)] = (i,0,RANGE)
                end
            else
                i = rowidx - nineqrows
                j = colidx - ncols
                C[i, j] = rowval
                d₁[i] = get(cor.rhs, row, zero(T))
                map[rowcol] = (i,j,GEQ)
                map[(row,RHS)] = (i,0,GEQ)
                if haskey(cor.ranges, rowsymbol)
                    d₂[i] = d₁[i] + abs(cor.ranges[row])
                    map[rowcol] = (i,j,RANGE)
                    map[(row,RHS)] = (i,0,RANGE)
                end
            end
        end
    end
    # Get any objective constant
    if cor.objgiven && include_constant
        c₂ = -get(cor.rhs, cor.objname, zero(T))
    end
    # Fill bounds
    fill_bounds!(cor, lb, ub, is_binary, is_integer, colrange, map)
    # Return the problem
    return LPData(T, c₁, c₂, A, b, d₁, C, d₂, lb, ub, is_binary, is_integer, map)
end

function SparseLPData(cor::RawCor{T};
                      colrange = collect(keys(cor.cols)),
                      rowrange = collect(keys(cor.rows)),
                      include_constant = false) where T <: AbstractFloat
    # Compute sizes
    n = length(colrange)
    m₁ = count(x -> x[3] == EQ, [cor.rows[row] for row in rowrange])
    m₂ = length(rowrange) - m₁
    # Prepare index map
    map = IndexMap(n, m₁, m₂)
    # Prepare vectors
    c₁ = zeros(T, n)
    c₂ = zero(T)
    b  = zeros(T, m₁)
    d₁ = fill(convert(T, -Inf), m₂)
    d₂ = fill(convert(T, Inf), m₂)
    lb = zeros(T, n)
    ub = fill(convert(T, Inf), n)
    is_binary = fill(false, n)
    is_integer = fill(false, n)
    # Prepare matrices
    Aᵢ = Vector{Int}()
    Aⱼ = Vector{Int}()
    Aᵥ = Vector{T}()
    Cᵢ = Vector{Int}()
    Cⱼ = Vector{Int}()
    Cᵥ = Vector{T}()
    # Aux counters
    ncols = 0
    neqrows = 0
    nineqrows = 0
    for (row, rowval) in cor.rows
        if row in rowrange
            break
        end
        if rowval[3] == EQ
            neqrows += 1
        elseif rowval[3] == LEQ || rowval[3] == GEQ
            nineqrows += 1
        end
    end
    # Fill (in)equalities with ranges
    for (col, val) in cor.cols
        col in colrange || (ncols += 1; continue)
        colidx = cor.vars[col]
        for (row, rowval) in val
            row in rowrange || row == cor.objname || continue
            idx, rowidx, rowsense = cor.rows[row]
            rowcol = (row, col)
            if rowidx == 0
                j = colidx - ncols
                c₁[j] = rowval
                map[rowcol] = (0,j,OBJ)
            elseif rowsense == EQ
                i = rowidx - neqrows
                j = colidx - ncols
                push!(Aᵢ, i)
                push!(Aⱼ, j)
                push!(Aᵥ, rowval)
                b[i] = get(cor.rhs, row, zero(T))
                map[rowcol] = (i,j,EQ)
                map[(row,RHS)] = (i,0,EQ)
            elseif rowsense == LEQ
                i = rowidx - nineqrows
                j = colidx - ncols
                push!(Cᵢ, i)
                push!(Cⱼ, j)
                push!(Cᵥ, rowval)
                d₂[i] = get(cor.rhs, row, zero(T))
                map[rowcol] = (i,j,LEQ)
                map[(row,RHS)] = (i,0,LEQ)
                if haskey(cor.ranges, row)
                    d₁[i] = d₂[i] - abs(cor.ranges[row])
                    map[rowcol] = (i,j,RANGE)
                    map[(row,RHS)] = (i,0,RANGE)
                end
            else
                i = rowidx - nineqrows
                j = colidx - ncols
                push!(Cᵢ, i)
                push!(Cⱼ, j)
                push!(Cᵥ, rowval)
                d₁[i] = get(cor.rhs, row, zero(T))
                map[rowcol] = (i,j,GEQ)
                map[(row,RHS)] = (i,0,GEQ)
                if haskey(cor.ranges, row)
                    d₂[i] = d₁[i] - abs(cor.ranges[row])
                    map[rowcol] = (i,j,RANGE)
                    map[(row,RHS)] = (i,0,RANGE)
                end
            end
        end
    end
    # Create sparse structures
    A  = sparse(Aᵢ, Aⱼ, Aᵥ, m₁, n)
    C  = sparse(Cᵢ, Cⱼ, Cᵥ, m₂, n)
    # Get any objective constant
    if cor.objgiven && include_constant
        c₂ = -get(cor.rhs, cor.objname, zero(T))
    end
    # Fill bounds
    fill_bounds!(cor, lb, ub, is_binary, is_integer, colrange, map)
    # Return the problem
    return LPData(T, c₁, c₂, A, b, d₁, C, d₂, lb, ub, is_binary, is_integer, map)
end

function fill_bounds!(cor::RawCor{T}, lb, ub, is_binary, is_integer, colrange, map) where T <: AbstractFloat
    ncols = 0
    for (col, val) in cor.bounds
        col in colrange || (ncols += 1; continue)
        colidx = cor.vars[col]
        j = colidx - ncols
        for (bndtype, bndval) in val
            if bndtype == LOWER
                lb[j] = bndval
                map[(LOWER,col)] = (0,j,GEQ)
            elseif bndtype == UPPER
                ub[j] = bndval
                map[(UPPER,col)] = (0,j,LEQ)
            elseif bndtype == FIXED
                lb[j] = ub[j] = bndval
                map[(FIXED,col)] = (0,j,LEQ)
                map[(FIXED,col)] = (0,j,GEQ)
            elseif bndtype == BINARY
                is_binary[j] = true
                lb[j] = convert(T, -Inf)
                map[(BINARY,col)] = (0,j,BINARY)
            elseif bndtype == INTEGER
                is_integer[j] = true
                lb[j] = convert(T, -Inf)
                map[(INTEGER,col)] = (0,j,INTEGER)
            elseif bndtype == INTEGER_LOWER
                is_integer[j] = true
                lb[j] = bndval
                map[(INTEGER,col)] = (0,j,INTEGER_LOWER)
            elseif bndtype == INTEGER_UPPER
                is_integer[j] = true
                ub[j] = bndval
                map[(INTEGER,col)] = (0,j,INTEGER_UPPER)
            else
                lb[j] = convert(T, -Inf)
                map[(FREE,col)] = (0,j,FREE)
            end
        end
    end
    return nothing
end

function canonical(C::AbstractMatrix{T}, d₁::AbstractVector{T}, d₂::AbstractVector{T}) where T <: AbstractFloat
    i₁      = isfinite.(d₁)
    i₂      = isfinite.(d₂)
    m₁, m₂  = sum(i₁), sum(i₂)
    m       = m₁ + m₂
    m == 0 && return zero(C), zero(d₁)
    C̃       = zeros(T, m, size(C, 2))
    d̃       = zeros(T, m)
    C̃[1:m₁,:]        = -C[i₁, :]
    d̃[1:m₁]          = -d₁[i₁]
    C̃[(m₁+1):end,:]  = C[i₂,:]
    d̃[(m₁+1):end]    = d₂[i₂]
    return C̃, d̃
end

function canonical(C::AbstractSparseMatrix{T}, d₁::AbstractVector{T}, d₂::AbstractVector{T}) where T <: AbstractFloat
    # Convert to canonical form
    i₁     = isfinite.(d₁)
    i₂     = isfinite.(d₂)
    m₁, m₂ = sum(i₁), sum(i₂)
    m      = m₁ + m₂
    m == 0 && return zero(C), zero(d₁)
    C̃ᵢ     = Vector{Int}()
    C̃ⱼ     = Vector{Int}()
    C̃ᵥ     = Vector{T}()
    d̃      = zeros(T, m)
    rows   = rowvals(C)
    vals   = nonzeros(C)
    for col in 1:size(C, 2)
        for j in nzrange(C, col)
            row = rows[j]
            if i₁[row]
                idx = count(i -> i, i₁[1:row])
                push!(C̃ᵢ, idx)
                push!(C̃ⱼ, col)
                push!(C̃ᵥ, -vals[j])
                d̃[idx] = -d₁[row]
            end
            if i₂[row]
                idx = count(i -> i, i₂[1:row])
                push!(C̃ᵢ, m₁ + idx)
                push!(C̃ⱼ, col)
                push!(C̃ᵥ, vals[j])
                d̃[m₁ + idx] = d₂[row]
            end
        end
    end
    C̃ = sparse(C̃ᵢ, C̃ⱼ, C̃ᵥ, m, size(C, 2))
    return C̃, d̃
end
