abstract type RandomVariable end
abstract type RandomVector end

const modes = ["INDEP", "BLOCKS"]
const inclusions = [:REPLACE, :ADD, :MULTIPLY]
const dist_options = [:UNIFORM, :NORMAL, :GAMMA, :BETA, :LOGNORM]

struct RawStoch{N}
    name::String
    random_variables::NTuple{N, Dict{RowCol, RandomVariable}}
    random_vectors::NTuple{N, Dict{Symbol, RandomVector}}

    function RawStoch(name::String, ran_vars::NTuple{N, Dict{RowCol, RandomVariable}}, ran_vectors::NTuple{N, Dict{Symbol, RandomVector}}) where N
        return new{N}(name, ran_vars, ran_vectors)
    end
end

struct IndepDiscrete{T <: AbstractFloat} <: RandomVariable
    inclusion::Symbol
    support::Vector{T}
    probabilities::Vector{T}

    function IndepDiscrete(::Type{T}, inclusion::Symbol) where T <: AbstractFloat
        inclusion in inclusions || error("Unknown keyword $inclusion")
        return new{T}(inclusion, Vector{T}(), Vector{T}())
    end
end

struct IndepDistribution{T <: AbstractFloat} <: RandomVariable
    inclusion::Symbol
    distribution::Symbol
    parameters::Pair{T}

    function IndepDistribution(inclusion::Symbol, distribution::Symbol, parameters::Pair{T}) where T <: AbstractFloat
        inclusion in inclusions || error("Unknown keyword $inclusion")
        distribution in dist_options || error("Unknown distribution $distribution")
        return new{T}(inclusion, distribution, parameters)
    end
end

struct BlockDiscrete{T <: AbstractFloat} <: RandomVector
    inclusion::Symbol
    support::Vector{Vector{RowColVal{T}}}
    probabilities::Vector{T}

    function BlockDiscrete(::Type{T}, inclusion) where T
        inclusion in inclusions || error("Unknown keyword $inclusion")
        return new{T}(inclusion, Vector{Vector{RowColVal{T}}}(), Vector{T}())
    end
end

function parse_sto(::Type{T}, tim::RawTime, filename::AbstractString; N::Integer = 2) where T <: AbstractFloat
    # Initialize auxiliary variables
    name      = "SLP"
    mode      = :STOCH
    dist      = :DISCRETE
    inclusion = :REPLACE
    N         = num_stages(tim)
    stage     = 2
    v₁        = zero(T)
    v₂        = zero(T)
    block     = :BLOCK
    # Prepare sto data
    random_vars = ntuple(Val(N-1)) do i
        Dict{RowCol, RandomVariable}()
    end
    random_vecs = ntuple(Val(N-1)) do i
        Dict{Symbol, RandomVector}()
    end
    # Parse the file
    data = open(filename) do io
        firstline = split(readline(io))
        if Symbol(firstline[1]) == :STOCH
            name = join(firstline[2:end], " ")
        else
            throw(ArgumentError("`STOCH` field is expected on the first line"))
        end
        for line in eachline(io)
            words = split(line)
            length(words) == 1 && (mode = Symbol(words[1]); continue)
            if length(words) == 2 || (length(words) == 3 && words[1] in modes)
                mode = Symbol(words[1])
                dist = Symbol(words[2])
                length(words) == 3 && (inclusion = Symbol(words[3]))
                continue
            elseif mode == :INDEP
                length(words) == 4 || length(words) == 5 || error("Malformed sto file at line $words")
                col = Symbol(words[1])
                row = Symbol(words[2])
                if length(words) == 4
                    v₁ = parse(Float64, words[3])
                    v₂ = parse(Float64, words[4])
                elseif length(words) == 5
                    v₁ = parse(Float64, words[3])
                    v₂ = parse(Float64, words[5])
                    stage_name = Symbol(words[4])
                    haskey(tim.stages, stage_name) || error("Stage name $stage_name not specified in .tim file.")
                    stage = tim.stages[stage_name]
                else
                    error("Malformed sto file at line $words")
                end
                if dist == :DISCRETE
                    # Check if random variable exists already
                    ran_var = get(random_vars[stage - 1], (row, col), nothing)
                    if ran_var === nothing
                        # Create new INDEP random variable
                        ran_var = random_vars[stage - 1][(row, col)] = IndepDiscrete(T, inclusion)
                    else
                        # Sanity check
                        ran_var isa IndepDiscrete || error("Random variable at $((row, col)) has more than one specified distribution.")
                    end
                    # Update values
                    push!(ran_var.support, v₁)
                    push!(ran_var.probabilities, v₂)
                else
                    haskey(random_vars[stage - 1], (row, col)) || error("Random variable at $((row, col)) has more than one specified distribution.")
                    random_vars[stage - 1][(row, col)] = IndepDistribution(inclusion, dist, Pair(v₁, v₂))
                end
            elseif mode == :BLOCKS
                if dist == :DISCRETE
                    if words[1] == "BL"
                        length(words) == 4 || error("Malformed sto file at line $words")
                        block = Symbol(words[2])
                        stage = Symbol(words[3])
                        prob = parse(Float64, words[4])
                        # Check if random vector exists already
                        ran_vec = get(random_vecs[stage - 1], block, nothing)
                        if ran_vec === nothing
                            # Create new DISCRETE random vector
                            ran_vec = random_vecs[stage - 1][block] = BlockDiscrete(T, inclusion)
                        else
                            # Sanity check
                            ran_vec isa BlockDiscrete || error("Random vector at $block has more than one specified distribution.")
                        end
                        # Update probability
                        push!(ran_vec.support, Vector{RowColVal{T}}())
                        push!(ran_vec.probabilities, prob)
                        continue
                    else
                        length(words) == 3 || error("Malformed sto file at line $words")
                        col = Symbol(words[1])
                        row = Symbol(words[2])
                        val = parse(Float64, words[3])
                        ran_vec = random_vecs[stage - 1][block]
                        push!(ran_vec.support[end], (row, col, val))
                    end
                else
                    error("Distribution $dist is not supported.")
                end
            elseif mode == :ENDATA
                break
            else
                throw(ArgumentError("$(mode) is not a valid word"))
            end
        end
    end
    # Return raw data
    return RawStoch(name, random_vars, random_vecs)
end
parse_sto(tim::RawTime, filename::AbstractString) = parse_sto(Float64, tim, filename)

function uncertainty_template(sto::RawStoch{N}, cor::RawCor, model::LPData{T, Matrix{T}}, stage::Integer) where {N, T}
    1 <= stage <= N || error("$(stage.id + 1) not in range 2 to $(N + 1).")
    map = model.indexmap
    # Prepare data
    Δc  = zero(model.c₁)
    ΔA  = zero(model.A)
    Δb  = zero(model.b)
    Δd₁ = zero(model.d₁)
    ΔC  = zero(model.C)
    Δd₂ = zero(model.d₂)
    # Loop over all scenarios
    for (rowcol, ran_var) in sto.random_variables[stage]
        (row, col) = rowcol
        rowsense = cor.rows[row][3]
        if row == cor.objsymbol
            # Objective
            j = map[rowcol][2]
            if ran_var.inclusion == :REPLACE
                Δc[j] = -model.c[j]
            else
                Δc[j] = model.c[j]
            end
        elseif col == :RHS
            # RHS
            i = map[rowcol][1]
            if rowsense == :eq
                if ran_var.inclusion == :REPLACE
                    Δb[i] = -model.b[i]
                else
                    Δb[i] = model.b[i]
                end
            elseif rowsense == :leq
                if ran_var.inclusion == :REPLACE
                    Δd₂[i] = -model.d₂[i]
                    haskey(cor.ranges, row) && (Δd₁[i] = -model.d₁[i])
                else
                    Δd₂[i] = model.d₂[i]
                    haskey(cor.ranges, row) && (Δd₁[i] = model.d₁[i])
                end
            elseif rowsense == :geq
                if ran_var.inclusion == :REPLACE
                    Δd₁[i] = -model.d₁[i]
                    haskey(cor.ranges, row) && (Δd₂[i] = -model.d₂[i])
                else
                    Δd₁[i] = model.d₁[i]
                    haskey(cor.ranges, row) && (Δd₂[i] = model.d₂[i])
                end
            end
        else
            # Matrix coeffs
            (i, j, _) = map[rowcol]
            if rowsense == :eq
                if ran_var.inclusion == :REPLACE
                    ΔA[i,j] = -model.A[i,j]
                else
                    ΔA[i] = model.A[i,j]
                end
            else
                if ran_var.inclusion == :REPLACE
                    ΔC[i,j] = -model.C[i,j]
                else
                    ΔC[i,j] = model.C[i,j]
                end
            end
        end
    end
    # Return template
    return LPData(T, Δc, zero(T), ΔA, Δb, Δd₁, ΔC, Δd₂, model.lb, model.ub, model.indexmap)
end

function uncertainty_template(sto::RawStoch{N}, cor::RawCor, model::LPData{T, SparseMatrixCSC{T,Int}}, stage::Integer) where {N, T}
    1 <= stage <= N || error("$(stage.id + 1) not in range 2 to $(N + 1).")
    map = model.indexmap
    # Get sizes
    n   = size(model.A, 2)
    m₁  = size(model.A, 1)
    m₂  = size(model.C, 1)
    # Prepare vectors
    Δc  = zero(model.c₁)
    Δb  = zero(model.b)
    Δd₁ = zero(model.d₁)
    Δd₂ = zero(model.d₂)
    # Prepare matrices
    ΔAᵢ = Vector{Int}()
    ΔAⱼ = Vector{Int}()
    ΔAᵥ = Vector{T}()
    ΔCᵢ = Vector{Int}()
    ΔCⱼ = Vector{Int}()
    ΔCᵥ = Vector{T}()
    # Loop over all scenarios
    for (rowcol, ran_var) in sto.random_variables[stage]
        (row, col) = rowcol
        rowsense = cor.rows[row][3]
        if row == cor.objsymbol
            # Objective
            j = map[rowcol][2]
            if ran_var.inclusion == :REPLACE
                Δc[j] = -model.c[j]
            else
                Δc[j] = model.c[j]
            end
        elseif col == :RHS
            # RHS
            i = map[rowcol][1]
            if rowsense == :eq
                if ran_var.inclusion == :REPLACE
                    Δb[i] = -model.b[i]
                else
                    Δb[i] = model.b[i]
                end
            elseif rowsense == :leq
                if ran_var.inclusion == :REPLACE
                    Δd₂[i] = -model.d₂[i]
                    haskey(cor.ranges, row) && (Δd₁[i] = -model.d₂[i])
                else
                    Δd₂[i] = model.d₂[i]
                    haskey(cor.ranges, row) && (Δd₁[i] = model.d₂[i])
                end
            elseif rowsense == :geq
                if ran_var.inclusion == :REPLACE
                    Δd₁[i] = -model.d₁[i]
                    haskey(cor.ranges, row) && (Δd₂[i] = -model.d₁[i])
                else
                    Δd₁[i] = model.d₁[i]
                    haskey(cor.ranges, row) && (Δd₂[i] = model.d₁[i])
                end
            end
        else
            # Matrix coeffs
            (i, j, _) = map[rowcol]
            if rowsense == :eq
                push!(ΔAᵢ, i)
                push!(ΔAⱼ, j)
                if ran_var.inclusion == :REPLACE
                    push!(ΔAᵥ, -model.A[i,j])
                else
                    push!(ΔAᵥ, model.A[i,j])
                end
            else
                push!(ΔCᵢ, i)
                push!(ΔCⱼ, j)
                if ran_var.inclusion == :REPLACE
                    push!(ΔCᵥ, -model.C[i,j])
                else
                    push!(ΔCᵥ, model.C[i,j])
                end
            end
        end
    end
    # Create sparse structures
    ΔA  = sparse(ΔAᵢ, ΔAⱼ, ΔAᵥ, m₁, n)
    ΔC  = sparse(ΔCᵢ, ΔCⱼ, ΔCᵥ, m₂, n)
    # Return template
    return LPData(T, Δc, zero(T), ΔA, Δb, Δd₁, ΔC, Δd₂, model.lb, model.ub, model.indexmap)
end
