struct SMPSSampler{T <: AbstractFloat, M <: AbstractMatrix} <: AbstractSampler{SMPSScenario{T,M}}
    template::LPData{T,M}
    technology::UnitRange{Int}
    recourse::UnitRange{Int}
    random_variables::Dict{RowCol, Sampleable}
    inclusions::Dict{RowCol, Symbol}
end

function SMPSSampler(sto::RawStoch{N}, stage::SMPSStage) where N
    2 <= stage.id <= N + 1 || error("$(stage.id) not in range 2 to $(N + 1).")
    random_variables = Dict{RowCol, Sampleable}()
    inclusions = Dict{RowCol, Symbol}()
    for (rowcol, ran_var) in sto.random_variables[stage.id - 1]
        inclusions[rowcol] = ran_var.inclusion
        if ran_var isa IndepDiscrete
            random_variables[rowcol] =
                DiscreteNonParametric(ran_var.support, ran_var.probabilities)
        elseif ran_var isa IndepDistribution
            if ran_var.distribution == :UNIFORM
                random_variables[rowcol] =
                    Uniform(first(ran_var.parameters), second(ran_var.parameters))
            elseif ran_var.distribution == :NORMAL
                random_variables[rowcol] =
                    Normal(first(ran_var.parameters), second(ran_var.parameters))
            elseif ran_var.distribution == :GAMMA
                random_variables[rowcol] =
                    Gamma(first(ran_var.parameters), second(ran_var.parameters))
            elseif ran_var.distribution == :BETA
                random_variables[rowcol] =
                    Beta(first(ran_var.parameters), second(ran_var.parameters))
            elseif ran_var.distribution == :LOGNORM
                random_variables[rowcol] =
                    LogNormal(first(ran_var.parameters), second(ran_var.parameters))
            end
        end
    end
    return SMPSSampler(stage.uncertain,
                       stage.technology,
                       stage.recourse,
                       random_variables,
                       inclusions)
end

function (sampler::SMPSSampler)()
    # Prepare scenario data
    Δq  = copy(sampler.template.c₁[sampler.recourse])
    A   = copy(sampler.template.A)
    Δd₁ = copy(sampler.template.d₁)
    ΔC  = copy(sampler.template.C)
    Δd₂ = copy(sampler.template.d₂)
    Δh  = copy(sampler.template.b)
    for (rowcol, ran_var) in sampler.random_variables
        (row, col) = rowcol
        (i,j,type) = sampler.template.indexmap[rowcol]
        if type == :obj
            if sampler.inclusions[rowcol] == :MULTIPLY
                Δq[j] += abs(Δq[j]) * rand(ran_var)
            else
                Δq[j] += rand(ran_var)
            end
        elseif type == :eq
            if col == :RHS
                if sampler.inclusions[rowcol] == :MULTIPLY
                    Δh[i] += abs(Δh[i]) * rand(ran_var)
                else
                    Δh[i] += rand(ran_var)
                end
            else
                if sampler.inclusions[rowcol] == :MULTIPLY
                    A[i,j] += abs(A[i,j]) * rand(ran_var)
                else
                    A[i,j] += rand(ran_var)
                end
            end
        elseif type == :leq
            if col == :RHS
                if sampler.inclusions[rowcol] == :MULTIPLY
                    Δd₂[i] += abs(Δd₂[i]) * rand(ran_var)
                else
                    Δd₂[i] += rand(ran_var)
                end
            else
                if sampler.inclusions[rowcol] == :MULTIPLY
                    ΔC[i,j] += abs(ΔC[i,j]) * rand(ran_var)
                else
                    ΔC[i,j] += rand(ran_var)
                end
            end
        elseif type == :geq
            if col == :RHS
                if sampler.inclusions[rowcol] == :MULTIPLY
                    Δd₁[i] += abs(d₁[i]) * rand(ran_var)
                else
                    Δd₁[i] += rand(ran_var)
                end
            else
                if sampler.inclusions[rowcol] == :MULTIPLY
                    ΔC[i,j] += abs(ΔC[i,j]) * rand!(ran_var)
                else
                    ΔC[i,j] += rand(ran_var)
                end
            end
        elseif type == :range
            if sampler.inclusions[rowcol] == :MULTIPLY
                Δd₁[i] += abs(d₁) * rand(ran_var)
                Δd₂[i] += abd(d₂) * rand(ran_var)
            else
                Δd₁[i] += rand(ran_var)
                Δd₂[i] += rand(ran_var)
            end
        end
    end
    ΔT = A[:,sampler.technology]
    ΔW = A[:,sampler.recourse]
    return SMPSScenario(Probability(1.0), Δq, ΔT, ΔW, Δh, ΔC, Δd₁, Δd₂)
end
