struct MultiDiscreteNonParametricSampler{T <: Real, S <: AbstractVector{T}, A <: AliasTable} <: Sampleable{Multivariate,Discrete}
    support::Vector{S}
    aliastable::A

    function MultiDiscreteNonParametricSampler{T,S}(support::Vector{S}, probs::AbstractVector{<:Real}) where {T <: Real, S<:AbstractVector{T}}
        isempty(support) && "Empty support given."
        aliastable = AliasTable(probs)
        new{T,S,typeof(aliastable)}(support, aliastable)
    end
end

function MultiDiscreteNonParametricSampler(support::Vector{S}, probs::AbstractVector{<:Real}) where {T <: Real, S <: AbstractVector{T}}
    return MultiDiscreteNonParametricSampler{T,S}(support, probs)
end

function Base.length(s::MultiDiscreteNonParametricSampler)
    return length(s.support[1])
end
Base.eltype(::Type{<:MultiDiscreteNonParametricSampler}) = Float64

function Distributions._rand!(rng::AbstractRNG, s::MultiDiscreteNonParametricSampler, x::AbstractVector)
    @inbounds x .= s.support[rand(rng, s.aliastable)]
end

struct SMPSSampler{T <: AbstractFloat, M <: AbstractMatrix} <: AbstractSampler{SMPSScenario{T,M}}
    template::LPData{T,M}
    technology::UnitRange{Int}
    recourse::UnitRange{Int}
    random_variables::Dict{RowCol, Sampleable}
    random_vectors::Dict{Block, Tuple{Vector{RowCol}, Sampleable}}
    inclusions::Dict{RowCol, Symbol}
end

function SMPSSampler(sto::RawStoch{N}, stage::SMPSStage{T}) where {N, T <: AbstractFloat}
    2 <= stage.id <= N + 1 || error("$(stage.id) not in range 2 to $(N + 1).")
    random_variables = Dict{RowCol, Sampleable}()
    random_vectors = Dict{Block, Tuple{Vector{RowCol}, Sampleable}}()
    inclusions = Dict{RowCol, Symbol}()
    for (rowcol, ran_var) in sto.random_variables[stage.id - 1]
        inclusions[rowcol] = ran_var.inclusion
        if ran_var isa IndepDiscrete
            random_variables[rowcol] =
                DiscreteNonParametric(ran_var.support, ran_var.probabilities)
        elseif ran_var isa IndepDistribution
            if ran_var.distribution == UNIFORM
                random_variables[rowcol] =
                    Uniform(first(ran_var.parameters), second(ran_var.parameters))
            elseif ran_var.distribution == NORMAL
                random_variables[rowcol] =
                    Normal(first(ran_var.parameters), second(ran_var.parameters))
            elseif ran_var.distribution == GAMMA
                random_variables[rowcol] =
                    Gamma(first(ran_var.parameters), second(ran_var.parameters))
            elseif ran_var.distribution == BETA
                random_variables[rowcol] =
                    Beta(first(ran_var.parameters), second(ran_var.parameters))
            elseif ran_var.distribution == LOGNORM
                random_variables[rowcol] =
                    LogNormal(first(ran_var.parameters), second(ran_var.parameters))
            end
        end
    end
    for (block, ran_vec) in sto.random_vectors[stage.id - 1]
        if ran_vec isa BlockDiscrete
            isempty(ran_vec.support[1]) && error("Block $block has empty support.")
            rowcols = Vector{RowCol}()
            support = Vector{Vector{T}}()
            push!(support, Vector{T}())
            for (rowcol, val) in ran_vec.support[1]
                push!(rowcols, rowcol)
                push!(support[end], val)
                inclusions[rowcol] = ran_vec.inclusion
            end
            for remaining in ran_vec.support[2:end]
                push!(support, Vector{T}())
                for (rowcol, val) in ran_vec.support[1]
                    if haskey(remaining, rowcol)
                        push!(support[end], remaining[rowcol])
                    else
                        push!(support[end], val)
                    end
                end
            end
            random_vectors[block] =
                (rowcols, MultiDiscreteNonParametricSampler(support, ran_vec.probabilities))
        end
    end
    return SMPSSampler(stage.uncertain,
                       stage.technology,
                       stage.recourse,
                       random_variables,
                       random_vectors,
                       inclusions)
end

function (sampler::SMPSSampler{T})() where T <: AbstractFloat
    # Prepare scenario data
    Δq  = copy(sampler.template.c₁)
    A   = copy(sampler.template.A)
    Δd₁ = copy(sampler.template.d₁)
    ΔC  = copy(sampler.template.C)
    Δd₂ = copy(sampler.template.d₂)
    Δh  = copy(sampler.template.b)
    # Collect samples
    samples = Dict{RowCol,T}()
    for (rowcol, ran_var) in sampler.random_variables
        samples[rowcol] = rand(ran_var)
    end
    for (block, ran_vec) in sampler.random_vectors
        (rowcols, block_sampler) = ran_vec
        block_sample = rand(block_sampler)
        for (idx, rowcol) in enumerate(rowcols)
            samples[rowcol] = block_sample[idx]
        end
    end
    # Fill scenario data
    for (rowcol, ξ) in samples
        (row, col) = rowcol
        (i,j,type) = sampler.template.indexmap[rowcol]
        if type == OBJ
            if sampler.inclusions[rowcol] == MULTIPLY
                Δq[j] += abs(Δq[j]) * ξ
            else
                Δq[j] += ξ
            end
        elseif type == EQ
            if col == RHS
                if sampler.inclusions[rowcol] == MULTIPLY
                    Δh[i] += abs(Δh[i]) * ξ
                else
                    Δh[i] += ξ
                end
            else
                if sampler.inclusions[rowcol] == MULTIPLY
                    A[i,j] += abs(A[i,j]) * ξ
                else
                    A[i,j] += ξ
                end
            end
        elseif type == LEQ
            if col == RHS
                if sampler.inclusions[rowcol] == MULTIPLY
                    Δd₂[i] += abs(Δd₂[i]) * ξ
                else
                    Δd₂[i] += ξ
                end
            else
                if sampler.inclusions[rowcol] == MULTIPLY
                    ΔC[i,j] += abs(ΔC[i,j]) * ξ
                else
                    ΔC[i,j] += ξ
                end
            end
        elseif type == GEQ
            if col == RHS
                if sampler.inclusions[rowcol] == MULTIPLY
                    Δd₁[i] += abs(d₁[i]) * ξ
                else
                    Δd₁[i] += ξ
                end
            else
                if sampler.inclusions[rowcol] == MULTIPLY
                    ΔC[i,j] += abs(ΔC[i,j]) * ξ
                else
                    ΔC[i,j] += ξ
                end
            end
        elseif type == RANGE
            if sampler.inclusions[rowcol] == MULTIPLY
                Δd₁[i] += abs(d₁) * ξ
                Δd₂[i] += abd(d₂) * ξ
            else
                Δd₁[i] += ξ
                Δd₂[i] += ξ
            end
        end
    end
    ΔT = A[:,sampler.technology]
    ΔW = A[:,sampler.recourse]
    return SMPSScenario(Probability(1.0), Δq, ΔT, ΔW, Δh, ΔC, Δd₁, Δd₂)
end
