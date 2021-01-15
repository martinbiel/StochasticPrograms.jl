struct SMPSModel{N, T <: AbstractFloat, M <: AbstractMatrix}
    raw::RawSMPS{T}
    stages::NTuple{N, SMPSStage{T,M}}

    function SMPSModel(raw::RawSMPS{T}, stages::NTuple{N, SMPSStage{T,M}}) where {N, T <: AbstractFloat, M <: AbstractMatrix}
        return new{N,T,M}(raw, stages)
    end
end

function SMPSModel(raw::RawSMPS)
    N = length(raw.tim.stages)
    constructor = sparsity(raw.cor) >= 0.5 ? SparseLPData : LPData
    stages = ntuple(Val(N)) do i
        parse_stage(raw, i, N, constructor)
    end
    return SMPSModel(raw, stages)
end

function parse_stage(raw::RawSMPS, stage::Integer, N::Integer, constructor)
    1 <= stage <= N || error("$(stage.id) not in range 1 to $N.")
    # Get required data
    tim = raw.tim
    cor = raw.cor
    sto = raw.sto
    if stage == 1
        # Get row and column of the given stage
        row = tim.row_delims[stage]
        col = tim.col_delims[stage]
        # Compute the rowrange up to the next stage
        next_row = tim.row_delims[stage + 1]
        rowrange = collect(keys(cor.rows))[cor.rows[row][1]:cor.rows[next_row][1]-1]
        # Compute the colrange up to the next stage
        next_col = tim.col_delims[stage + 1]
        colrange = collect(keys(cor.vars))[cor.vars[col]:cor.vars[next_col]-1]
        # Extract first-stage model
        model = constructor(cor; colrange = colrange, rowrange = rowrange, include_constant = true)
        # Return stage
        return SMPSStage(model)
    else
        # Get row and column of the current stage
        row = tim.row_delims[stage]
        col = tim.col_delims[stage]
        # and the column of the previous stage
        prev_col = tim.col_delims[stage - 1]
        # Compute the rowrange up to the next stage
        rowrange = if stage < N
            next_row = tim.row_delims[stage + 1]
            rowrange = collect(keys(cor.rows))[cor.rows[row][1]:cor.rows[next_row][1]-1]
        else
            rowrange = collect(keys(cor.rows))[cor.rows[row][1]:end]
        end
        # Compute the colrange from the previos stage up to the next stage
        colrange = if stage < N
            next_col = tim.col_delims[stage + 1]
            colrange = collect(keys(cor.vars))[cor.vars[prev_col]:cor.vars[next_col]-1]
        else
            colrange = collect(keys(cor.vars))[cor.vars[prev_col]:end]
        end
        # Extract second-stage model
        model = constructor(cor; colrange = colrange, rowrange = rowrange)
        # Compute technology and recourse ranges
        delim      = findfirst(x -> x == col, colrange)
        technology = 1:delim-1
        recourse   = delim:length(colrange)
        # Extract uncertainty perturbation
        uncertainty = uncertainty_template(sto, cor, model, stage - 1)
        # Return stage
        return SMPSStage(stage, model, uncertainty, technology, recourse)
    end
end

function stochastic_model(smps::SMPSModel{2})
    # Create stochastic model
    sm = @stochastic_model begin
        @stage 1 begin
            @parameters begin
                data = smps.stages[1]
            end
            # Unpack first-stage SMPS data
            n    = data.model.indexmap.n
            m₂   = data.model.indexmap.m₂
            c₁   = data.model.c₁
            c₂   = data.model.c₂
            A    = data.model.A
            b    = data.model.b
            C, d = canonical(data.model.C,
                             data.model.d₁,
                             data.model.d₂)
            lb   = data.model.lb
            ub   = data.model.ub
            bin  = data.model.is_binary
            int  = data.model.is_integer
            # Define all first-stage variables as decisions
            if any(isfinite.(lb))
                if any(isfinite.(ub))
                    # Double bounds
                    @decision(model, lb[i] <= x[i in 1:n] <= ub[i])
                else
                    # Lower bounds
                    @decision(model, x[i in 1:n] >= lb[i])
                end
            elseif any(isfinite.(ub))
                # Upper bounds
                @decision(model, x[i in 1:n] <= ub[i])
            else
                # Free
                @decision(model, x[i in 1:n])
            end
            # Add any binary or integer restrictions
            for i in 1:n
                if bin[i]
                    @constraint(model, x[i] in MOI.ZeroOne())
                elseif int[i]
                    @constraint(model, x[i] in MOI.Integer())
                end
            end
            # Define objective and constraints
            if any(abs.(c₁) .> sqrt(eps())) || abs(c₂) > sqrt(eps())
                @objective(model, Min, dot(c₁, x) + c₂)
            end
            if length(A) > 0 && length(b) > 0
                @constraint(model, A * x .== b)
            end
            if length(C) > 0 && length(d) > 0
                @constraint(model, C * x .- d in MOI.Nonpositives(m₂))
            end
        end
        @stage 2 begin
            @parameters begin
                data = smps.stages[2]
            end
            @uncertain Δq ΔT ΔW Δh ΔC Δd₁ Δd₂ from SMPSScenario
            # Unpack first-stage SMPS data
            n    = length(data.recourse)
            m₂   = data.model.indexmap.m₂
            q    = data.model.c₁[data.recourse]
            Δq   = Δq[data.recourse]
            T    = data.model.A[:, data.technology]
            W    = data.model.A[:, data.recourse]
            h    = data.model.b
            C̃, h̃ = canonical(data.model.C + ΔC,
                             data.model.d₁ + Δd₁,
                             data.model.d₂ + Δd₂)
            T̃    = C̃[:, data.technology]
            W̃    = C̃[:, data.recourse]
            lb   = data.model.lb[data.recourse]
            ub   = data.model.ub[data.recourse]
            bin  = data.model.is_binary[data.recourse]
            int  = data.model.is_integer[data.recourse]
            # Define all recourse variables
            if any(isfinite.(lb))
                if any(isfinite.(ub))
                    # Double bounds
                    @recourse(model, lb[i] <= y[i in 1:n] <= ub[i])
                else
                    # Lower bounds
                    @recourse(model, y[i in 1:n] >= lb[i])
                end
            elseif any(isfinite.(ub))
                # Upper bounds
                @recourse(model, y[i in 1:n] <= ub[i])
            else
                # Free
                @recourse(model, y[i in 1:n])
            end
            # Add any binary or integer restrictions
            for i in 1:n
                if bin[i]
                    @constraint(model, y[i] in MOI.ZeroOne())
                elseif int[i]
                    @constraint(model, y[i] in MOI.Integer())
                end
            end
            # Define objective and constraints
            @objective(model, Min, dot((q + Δq), y))
            if (length(T) > 0 || length(W) > 0) && length(h) > 0
                @constraint(model, (T + ΔT) * x + (W + ΔW) * y .== (h + Δh))
            end
            if (length(T̃) > 0 || length(W̃) > 0) && length(h̃) > 0
                @constraint(model, T̃ * x + W̃ * y - h̃ in MOI.Nonpositives(m₂))
            end
        end
    end
    return sm
end
