# Problem evaluation #
# ========================== #
function _eval_first_stage(stochasticprogram::StochasticProgram, x::AbstractVector)
    first_stage = get_stage_one(stochasticprogram)
    return eval_objective(first_stage.obj, x)
end
function _eval_second_stages(stochasticprogram::TwoStageStochasticProgram{S,SP},
                             x::AbstractVector,
                             optimizer_factory::OptimizerFactory) where {S, SP <: ScenarioProblems}
    sp = scenarioproblems(stochasticprogram)
    update_decision_variables!(decision_variables(sp), x)
    return outcome_mean(sp, optimizer_factory)
end
function _eval_second_stages(stochasticprogram::TwoStageStochasticProgram{S,SP},
                             x::AbstractVector,
                             optimizer_factory::OptimizerFactory) where {S, SP <: DScenarioProblems}
    Qs = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async Qs[i] = remotecall_fetch((sp, x, optimizer)->begin
                scenarioproblems = fetch(sp)
                isempty(scenarioproblems.scenarios) && return 0.0
                update_decision_variables!(decision_variables(scenarioproblems), x)
                return outcome_mean(scenarioproblems, optimizer)
            end,
            w,
            stochasticprogram.scenarioproblems[w-1],
            x)
        end
    end
    return sum(Qs)
end
function _stat_eval_second_stages(stochasticprogram::TwoStageStochasticProgram{S,SP},
                                  x::AbstractVector,
                                  optimizer_factory::OptimizerFactory) where {S, SP <: ScenarioProblems}
    sp = scenarioproblems(stochasticprogram)
    update_decision_variables!(decision_variables(sp), x)
    𝔼Q, σ² = welford(sp, optimizer_factory)
    return 𝔼Q, sqrt(σ²)
end
function _stat_eval_second_stages(stochasticprogram::TwoStageStochasticProgram{S,SP},
                                  x::AbstractVector,
                                  optimizer_factory::OptimizerFactory) where {S, SP <: DScenarioProblems}
    partial_welfords = Vector{Tuple{Float64,Float64,Int}}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_welfords[i] = remotecall_fetch((sp,x,optimizer)->begin
                scenarioproblems = fetch(sp)
                isempty(scenarioproblems.scenarios) && return zero(eltype(x)), zero(eltype(x)), zero(Int)
                update_decision_variables!(scenarioproblems, x)
                return (welford(scenarioproblems, optimizer)..., length(scenarioproblems.scenarios))
            end,
            w,
            stochasticprogram.scenarioproblems[w-1],
            x,
            optimizer_factory)
        end
    end
    𝔼Q, σ², _ = reduce(aggregate_welford, partial_welfords)
    return 𝔼Q, sqrt(σ²)
end
function _eval(stochasticprogram::StochasticProgram{2},
               x::AbstractVector,
               optimizer_factory::OptimizerFactory)
    xlength = decision_length(stochasticprogram)
    length(x) == xlength || error("Incorrect length of given decision vector, has ", length(x), " should be ", xlength)
    all(.!(isnan.(x))) || error("Given decision vector has NaN elements")
    cᵀx = _eval_first_stage(stochasticprogram, x)
    𝔼Q = _eval_second_stages(stochasticprogram, x, optimizer_factory)
    return cᵀx+𝔼Q
end
# Mean/variance calculations #
# ========================== #
function outcome_mean(scenarioproblems::ScenarioProblems, optimizer_factory::OptimizerFactory)
    N = nsubproblems(scenarioproblems)
    Qs = zeros(N)
    for i in 1:N
        outcome = subproblem(scenarioproblems, i)
        set_optimizer(outcome, optimizer_factory)
        optimize!(outcome)
        π = probability(scenario(scenarioproblems, i))
        Qs[i] = π*objective_value(outcome)
        # if status != :Optimal
        #     if status == :Infeasible
        #         Qs[i] = outcome.objSense == :Max ? -Inf : Inf
        #     elseif status == :Unbounded
        #         Qs[i] = outcome.objSense == :Max ? Inf : -Inf
        #     else
        #         error("Outcome model could not be solved, returned status: $status")
        #     end
        # else
        #     π = probability(scenario(scenarioproblems, i))
        #     Qs[i] = π*objective_value(outcome)
        #     end
        # end
    end
    return sum(Qs)
end
function welford(scenarioproblems::ScenarioProblems, optimizer_factory::OptimizerFactory)
    Q̄ₖ = 0
    Sₖ = 0
    N = length(nsubproblems(scenarioproblems))
    for k = 1:N
        Q̄ₖ₋₁ = Q̄ₖ
        problem = subproblem(scenarioproblems, k)
        set_optimizer(problem, optimizerfactory)
        optimize!(problem)
        Q = getobjectivevalue(problem)
        # Q = if status != :Optimal
        #     Q = if status == :Infeasible
        #         problem.objSense == :Max ? -Inf : Inf
        #     elseif status == :Unbounded
        #         problem.objSense == :Max ? Inf : -Inf
        #     else
        #         error("Outcome model could not be solved, returned status: $status")
        #     end
        # else
        #     Q = getobjectivevalue(problem)
        # end
        Q̄ₖ = Q̄ₖ + (Q-Q̄ₖ)/k
        Sₖ = Sₖ + (Q-Q̄ₖ)*(Q-Q̄ₖ₋₁)
    end
    return Q̄ₖ, Sₖ/(N-1)
end
function aggregate_welford(left::Tuple, right::Tuple)
    x̄ₗ, σₗ², nₗ = left
    x̄ᵣ, σᵣ², nᵣ = right
    δ = x̄ᵣ-x̄ₗ
    N = nₗ+nᵣ
    x̄ = (nₗ*x̄ₗ+nᵣ*x̄ᵣ)/N
    Sₗ = σₗ²*(nₗ-1)
    Sᵣ = σᵣ²*(nᵣ-1)
    S = Sₗ+Sᵣ+nₗ*nᵣ/N*δ^2
    return (x̄, S/(N-1), N)
end
# Evaluation API #
# ========================== #
"""
    evaluate_decision(stochasticprogram::TwoStageStochasticProgram,
                      decision::AbstractVector,
                      optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)

Evaluate the first-stage `decision` in `stochasticprogram`.

In other words, evaluate the first-stage objective at `decision` and solve outcome models of `decision` for every available scenario. Optionally, supply a capable `optimizer_factory` to solve the outcome models. Otherwise, any previously set solver will be used.
"""
function evaluate_decision(stochasticprogram::StochasticProgram{2},
                           decision::AbstractVector,
                           optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    # Use cached optimizer if available
    supplied_optimizer = pick_optimizer(stochasticprogram, optimizer_factory)
    # Abort if no optimizer was given
    if supplied_optimizer == nothing
        error("Cannot evaluate decision without an optimizer.")
    end
    return _eval(stochasticprogram, decision, supplied_optimizer)
end
"""
    evaluate_decision(stochasticprogram::TwoStageStochasticProgram,
                      decision::AbstractVector,
                      scenario::AbstractScenario,
                      optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)

Evaluate the result of taking the first-stage `decision` if `scenario` is the actual outcome in `stochasticprogram`.
"""
function evaluate_decision(stochasticprogram::StochasticProgram{2},
                           decision::AbstractVector,
                           scenario::AbstractScenario,
                           optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    # Use cached optimizer if available
    supplied_optimizer = pick_optimizer(stochasticprogram, optimizer_factory)
    # Abort if no optimizer was given
    if supplied_optimizer == nothing
        error("Cannot evaluate decision without an optimizer.")
    end
    outcome = outcome_model(stochasticprogram, decision, scenario, supplied_optimizer)
    status = optimize!(outcome)
    if status == :Optimal
        return _eval_first_stage(stochasticprogram, decision) + objective_value(outcome)
    end
    error("Outcome model could not be solved, returned status: $status")
end
"""
    evaluate_decision(stochasticmodel::StochasticModel{2},
                      decision::AbstractVector,
                      sampler::AbstractSampler,
                      optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                      confidence = 0.95,
                      N = 1000)

Return a statistical estimate of the objective of the two-stage `stochasticmodel` at `decision` in the form of a confidence interval at level `confidence`, over the scenario distribution induced by `sampler`.

In other words, evaluate `decision` on a sampled model of size `N`. Generate an confidence interval using the sample variance of the evaluation.

See also: [`confidence_interval`](@ref)
"""
function evaluate_decision(stochasticmodel::StochasticModel{2},
                           decision::AbstractVector,
                           sampler::AbstractSampler,
                           optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                           confidence::AbstractFloat = 0.95,
                           Ñ::Integer = 1000,
                           kw...)
    CI = let eval_model = sample(stochasticmodel, sampler, Ñ, defer = true; kw...)
        # Condidence level
        α = 1-confidence
        cᵀx = _eval_first_stage(eval_model, decision)
        𝔼Q, σ = _stat_eval_second_stages(eval_model, decision, optimizer_factory)
        z = quantile(Normal(0,1), 1-α)
        L = cᵀx + 𝔼Q - z*σ/sqrt(Ñ)
        U = cᵀx + 𝔼Q + z*σ/sqrt(Ñ)
        remove_scenarios!(eval_model)
        return ConfidenceInterval(L, U, confidence)
    end
    return CI
end
"""
    lower_bound(stochasticmodel::StochasticModel{2},
                sampler::AbstractSampler,
                optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                confidence = 0.95,
                N = 100,
                M = 10)

Generate a confidence interval around a lower bound on the true optimum of the two-stage `stochasticmodel` at level `confidence`, over the scenario distribution induced by `sampler`.

`N` is the size of the sampled models used to generate the interval and generally governs how tight it is. `M` is the number of sampled models.
"""
function lower_bound(stochasticmodel::StochasticModel{2},
                     sampler::AbstractSampler,
                     optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                     confidence::AbstractFloat = 0.95,
                     N::Integer = 100,
                     M::Integer = 10,
                     log = true,
                     keep = true,
                     offset = 0,
                     indent::Int = 0,
                     kw...)
    # Condidence level
    α = 1-confidence
    # Lower bound
    Qs = Vector{Float64}(undef, M)
    progress = Progress(M, 0.0, "$(repeat(" ", indent))Lower CI    ")
    log && sleep(0.1)
    log && ProgressMeter.update!(progress, 0, keep = false, offset = offset)
    for i = 1:M
        let sampled_model = sample(stochasticmodel, sampler, N; kw...)
            Qs[i] = VRP(sampled_model, solver = solver)
            remove_scenarios!(sampled_model)
            remove_subproblems!(sampled_model)
        end
        log && ProgressMeter.update!(progress, i, keep = keep, offset = offset)
    end
    Q̂ = mean(Qs)
    σ = std(Qs)
    t = quantile(TDist(M-1), 1-α)
    L = Q̂ - t*σ/sqrt(M)
    U = Q̂ + t*σ/sqrt(M)
    return ConfidenceInterval(L, U, 1-α)
end
"""
    upper_bound(stochasticmodel::StochasticModel{2},
                sampler::AbstractSampler,
                optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                confidence = 0.95,
                N = 100,
                T = 10,
                n = 1000)

Generate a confidence interval around an upper of the true optimum of the two-stage `stochasticmodel` at level `confidence`, over the scenario distribution induced by `sampler`.

`N` is the size of the sampled model used to generate a candidate decision. `Ñ` is the size of each sampled model and `T` is the number of sampled models.
"""
function upper_bound(stochasticmodel::StochasticModel{2},
                     sampler::AbstractSampler,
                     optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                     confidence::AbstractFloat = 0.95,
                     N::Integer = 100,
                     T::Integer = 10,
                     Ñ::Integer = 1000,
                     log = true,
                     keep = true,
                     offset = 0,
                     indent::Int = 0,
                     kw...)
    # Condidence level
    α = 1-confidence
    # decision generation
    sampled_model = sample(stochasticmodel, sampler, N; kw...)
    optimize!(sampled_model, solver = solver)
    x̂ = optimal_decision(sampled_model)
    return upper_bound(stochasticmodel, x̂, sampler; solver = solver, confidence = confidence, T = T, Ñ = Ñ, log = log, keep = keep, offset = offset, indent = indent, kw...)
end
"""
    upper_bound(stochasticmodel::StochasticModel{2},
                x::AbstractVector,
                sampler::AbstractSampler,
                optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                confidence = 0.95,
                T = 10,
                Ñ = 1000)

Generate a confidence interval around an upper bound of the expected value of the decision `x` in the two-stage `stochasticmodel` at level `confidence`, over the scenario distribution induced by `sampler`.

`Ñ` is the size of each sampled model and `T` is the number of sampled models.
"""
function upper_bound(stochasticmodel::StochasticModel{2},
                     x::AbstractVector,
                     sampler::AbstractSampler,
                     optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                     confidence::AbstractFloat = 0.95,
                     T::Integer = 10,
                     Ñ::Integer = 1000,
                     log = true,
                     keep = true,
                     offset = 0,
                     indent::Int = 0,
                     kw...)
    # Condidence level
    α = 1-confidence
    Qs = Vector{Float64}(undef, T)
    progress = Progress(T, 0.0, "$(repeat(" ", indent))Upper CI    ")
    log && sleep(0.1)
    log && ProgressMeter.update!(progress, 0, keep = false, offset = offset)
    for i = 1:T
        let eval_model = sample(stochasticmodel, sampler, Ñ, defer = true; kw...)
            Qs[i] = evaluate_decision(eval_model, x; solver = solver)
            remove_scenarios!(eval_model)
        end
        log && ProgressMeter.update!(progress, i, keep = keep, offset = offset)
    end
    Q̂ = mean(Qs)
    σ = std(Qs)
    t = quantile(TDist(T-1), 1-α)
    L = Q̂ - t*σ/sqrt(T)
    U = Q̂ + t*σ/sqrt(T)
    return ConfidenceInterval(L, U, 1-α)
end
"""
    confidence_interval(stochasticmodel::StochasticModel{2},
                        sampler::AbstractSampler,
                        optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                        confidence = 0.9,
                        N = 100,
                        M = 10,
                        T = 10)

Generate a confidence interval around the true optimum of the two-stage `stochasticmodel` at level `confidence` using SAA, over the scenario distribution induced by `sampler`.

`N` is the size of the sampled models used to generate the interval and generally governs how tight it is. `M` is the number of sampled models used in the lower bound calculation, and `T` is the number of sampled models used in the upper bound calculation.
"""
function confidence_interval(stochasticmodel::StochasticModel{2},
                             sampler::AbstractSampler,
                             optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                             confidence::AbstractFloat = 0.9,
                             N::Integer = 100,
                             M::Integer = 10,
                             T::Integer = 10,
                             Ñ::Integer = 1000,
                             log = true,
                             keep = true,
                             offset = 0,
                             indent::Int = 0,
                             kw...)
    # Condidence level
    α = (1-confidence)/2
    # Lower bound
    lower_CI = lower_bound(stochasticmodel, sampler; solver = solver, confidence = 1-α, N = N, M = M, log = log, keep = keep, offset = offset, indent = indent, kw...)
    L = lower(lower_CI)
    # Upper bound
    upper_CI = upper_bound(stochasticmodel, sampler; solver = solver, confidence = 1-α, N = N, T = T, Ñ = Ñ, log = log, keep = keep, offset = offset, indent = indent, kw...)
    U = upper(upper_CI)
    return ConfidenceInterval(L, U, confidence)
end
"""
    gap(stochasticmodel::StochasticModel{2},
        x::AbstractVector,
        sampler::AbstractSampler,
        optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
        confidence = 0.9,
        N = 100,
        M = 10,
        T = 10)

Generate a confidence interval around the gap between the result of using decison `x` and true optimum of the two-stage `stochasticmodel` at level `confidence` using SAA, over the scenario distribution induced by `sampler`.

`N` is the size of the SAA models used to generate the interval and generally governs how tight it is. `M` is the number of sampled models used in the lower bound calculation, and `T` is the number of sampled models used in the upper bound calculation.
"""
function gap(stochasticmodel::StochasticModel{2},
             x::AbstractVector,
             sampler::AbstractSampler,
             optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
             confidence::AbstractFloat = 0.9,
             N::Integer = 100,
             M::Integer = 10,
             T::Integer = 10,
             Ñ::Integer = 1000,
             log = true,
             keep = true,
             offset = 0,
             indent::Int = 0,
             kw...)
    # Condidence level
    α = (1-confidence)/2
    # Lower bound
    lower_CI = lower_bound(stochasticmodel, sampler; solver = solver, confidence = 1-α, N = N, M = M, log = log, keep = keep, offset = offset, indent = indent, kw...)
    L = lower(lower_CI)
    # Upper bound
    upper_CI = upper_bound(stochasticmodel, x, sampler; solver = solver, confidence = 1-α, N = N, T = T, Ñ = Ñ, log = log, keep = keep, offset = offset, indent = indent, kw...)
    U = upper(upper_CI)
    return ConfidenceInterval(0., U-L, confidence)
end
# ========================== #
