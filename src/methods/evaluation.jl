# Problem evaluation #
# ========================== #
function _eval_first_stage(stochasticprogram::StochasticProgram, x::AbstractVector)
    first_stage = get_stage_one(stochasticprogram)
    return evaluate_objective(objective_function(first_stage), x)
end
function _eval_second_stages(stochasticprogram::TwoStageStochasticProgram{T,S,SP},
                             x::AbstractVector) where {T <: AbstractFloat, S , SP <: ScenarioProblems}
    sp = scenarioproblems(stochasticprogram)
    update_decision_variables!(decision_variables(stochasticprogram), x)
    return outcome_mean(sp)
end
function _eval_second_stages(stochasticprogram::TwoStageStochasticProgram{T,S,SP},
                             x::AbstractVector) where {T <: AbstractFloat, S, SP <: DScenarioProblems}
    Qs = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async Qs[i] = remotecall_fetch((sp, x)->begin
                scenarioproblems = fetch(sp)
                isempty(scenarioproblems.scenarios) && return zero(T)
                update_decision_variables!(decision_variables(scenarioproblems), x)
                return outcome_mean(scenarioproblems)
            end,
            w,
            stochasticprogram.scenarioproblems[w-1],
            x)
        end
    end
    return sum(Qs)
end
function _stat_eval_second_stages(stochasticprogram::TwoStageStochasticProgram{S,SP},
                                  x::AbstractVector) where {S, SP <: ScenarioProblems}
    sp = scenarioproblems(stochasticprogram)
    update_decision_variables!(decision_variables(sp), x)
    𝔼Q, σ² = welford(sp.problems)
    return 𝔼Q, sqrt(σ²)
end
function _stat_eval_second_stages(stochasticprogram::TwoStageStochasticProgram{S,SP},
                                  x::AbstractVector) where {S, SP <: DScenarioProblems}
    partial_welfords = Vector{Tuple{Float64,Float64,Int}}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_welfords[i] = remotecall_fetch((sp,x)->begin
                scenarioproblems = fetch(sp)
                isempty(scenarioproblems.scenarios) && return zero(eltype(x)), zero(eltype(x)), zero(Int)
                update_decision_variables!(scenarioproblems, x)
                return (welford(scenarioproblems.problems)..., length(scenarioproblems.scenarios))
            end,
            w,
            stochasticprogram.scenarioproblems[w-1],
            x)
        end
    end
    𝔼Q, σ², _ = reduce(aggregate_welford, partial_welfords)
    return 𝔼Q, sqrt(σ²)
end
# Mean/variance calculations #
# ========================== #
function outcome_mean(scenarioproblems::ScenarioProblems)
    N = nsubproblems(scenarioproblems)
    Qs = zeros(N)
    for i in 1:N
        outcome = subproblem(scenarioproblems, i)
        try
            optimize!(outcome)
            status = termination_status(outcome)
            if status != MOI.OPTIMAL
                if status == MOI.INFEASIBLE
                    Qs[i] = objective_sense(outcome) == MOI.MAX_SENSE ? -Inf : Inf
                elseif status == MOI.DUAL_INFEASIBLE
                    Qs[i] = objective_sense(outcome) == MOI.MAX_SENSE ? Inf : -Inf
                else
                    error("Outcome model could not be solved, returned status: $status")
                end
            else
                π = probability(scenario(scenarioproblems, i))
                Qs[i] = π*objective_value(outcome)
            end
        catch error
            if isa(error, NoOptimizer)
                @warn "No optimizer set, cannot solve outcome model."
                rethrow(NoOptimizer())
            else
                @warn "Outcome model could not be solved."
                rethrow(error)
            end
        end
    end
    return sum(Qs)
end
function welford(subproblems::Vector{JuMP.Model})
    Q̄ₖ = 0
    Sₖ = 0
    N = length(subproblems)
    for k = 1:N
        Q̄ₖ₋₁ = Q̄ₖ
        problem = subproblems[k]
        try
            optimize!(problem)
            status = termination_status(problem)
            Q = if status != MOI.OPTIMAL
                Q = if status == MOI.INFEASIBLE
                    Qs[i] = objective_sense(outcome) == MOI.MAX_SENSE ? -Inf : Inf
                elseif status == MOI.DUAL_INFEASIBLE
                    Qs[i] = objective_sense(outcome) == MOI.MAX_SENSE ? Inf : -Inf
                else
                    error("Outcome model could not be solved, returned status: $status")
                end
            else
                Q = objective_value(problem)
            end
            Q̄ₖ = Q̄ₖ + (Q-Q̄ₖ)/k
            Sₖ = Sₖ + (Q-Q̄ₖ)*(Q-Q̄ₖ₋₁)
        catch error
            if isa(error, NoOptimizer)
                @warn "No optimizer set, cannot solve outcome model."
                rethrow(NoOptimizer())
            else
                @warn "Outcome model could not be solved."
                rethrow(error)
            end
        end
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
    evaluate_decision(stochasticprogram::TwoStageStochasticProgram, decision::Union{AbstractVector, DecisionVariables)

Evaluate the first-stage `decision` in `stochasticprogram`.

In other words, evaluate the first-stage objective at `decision` and solve outcome models of `decision` for every available scenario. The supplied `decision` must be of type `AbstractVector` or `DecisionVariables`, and must match the defined decision variables in `stochasticprogram`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
"""
function evaluate_decision(stochasticprogram::StochasticProgram{2}, decision::AbstractVector)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    # Ensure stochastic program has been generated at this point
    if deferred(stochasticprogram)
        generate!(stochasticprogram)
    end
    # Sanity checks on given decision vector
    length(decision) == decision_length(stochasticprogram) || error("Incorrect length of given decision vector, has ", length(decision), " should be ", decision_length(stochasticprogram))
    all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
    # Evalaute decision stage-wise
    cᵀx = _eval_first_stage(stochasticprogram, decision)
    𝔼Q = _eval_second_stages(stochasticprogram, decision)
    return return cᵀx+𝔼Q
end
function evaluate_decision(stochasticprogram::StochasticProgram{2}, decision::DecisionVariables)
    decision_names(decision_variables(stochasticprogram)) == decision_names(decision) || error("Given decision does not match decision variables in stochastic program.")
    return evaluate_decision(stochasticprogram, decisions(decision))
end
"""
    evaluate_decision(stochasticprogram::TwoStageStochasticProgram,
                      decision::Union{AbstractVector, DecisionVariables},
                      scenario::AbstractScenario;
                      optimizer = nothing)

Evaluate the result of taking the first-stage `decision` if `scenario` is the actual outcome in `stochasticprogram`. The supplied `decision` must be of type `AbstractVector` or `DecisionVariables`, and must match the defined decision variables in `stochasticprogram`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
"""
function evaluate_decision(stochasticprogram::StochasticProgram{2},
                           decision::AbstractVector,
                           scenario::AbstractScenario)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    # Sanity checks on given decision vector
    length(decision) == decision_length(stochasticprogram) || error("Incorrect length of given decision vector, has ", length(decision), " should be ", decision_length(stochasticprogram))
    all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
    # Generate and solve outcome model
    outcome = outcome_model(stochasticprogram, decision, scenario, moi_optimizer(stochasticprogram))
    optimize!(outcome)
    if status == :Optimal
        return _eval_first_stage(stochasticprogram, decision) + objective_value(outcome)
    end
    error("Outcome model could not be solved, returned status: $status")
end
function evaluate_decision(stochasticprogram::StochasticProgram{2},
                           decision::DecisionVariables,
                           scenario::AbstractScenario)
    decision_names(decision_variables(stochasticprogram)) .== decision_names(decision) || error("Given decision does not match decision variables in stochastic program.")
    return evaluate_decision(stochasticprogram, decisions(decision), scenario)
end
"""
    evaluate_decision(stochasticmodel::StochasticModel{2},
                      decision::Union{AbstractVector, DecisionVariables},
                      sampler::AbstractSampler;
                      optimizer = nothing;
                      confidence = 0.95,
                      N = 1000)

Return a statistical estimate of the objective of the two-stage `stochasticmodel` at `decision` in the form of a confidence interval at level `confidence`, over the scenario distribution induced by `sampler`.

In other words, evaluate `decision` on a sampled model of size `N`. Generate an confidence interval using the sample variance of the evaluation.

The supplied `decision` must be of type `AbstractVector` or `DecisionVariables`, and must match the defined decision variables in `stochasticmodel`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`confidence_interval`](@ref)
"""
function evaluate_decision(stochasticmodel::StochasticModel{2},
                           decision::AbstractVector,
                           sampler::AbstractSampler;
                           confidence::AbstractFloat = 0.95,
                           Ñ::Integer = 1000,
                           kw...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticmodel))
    # Calculate confidence interval using provided optimizer
    CI = let eval_model = sample(stochasticmodel, sampler, Ñ; optimizer = moi_optimizer(stochasticmodel), defer = true, kw...)
        # Sanity checks on given decision vector
        length(decision) == decision_length(eval_model) || error("Incorrect length of given decision vector, has ", length(decision), " should be ", decision_length(eval_model))
        all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
        # Initialize after checks
        initialize!(eval_model)
        # Condidence level
        α = 1-confidence
        cᵀx = _eval_first_stage(eval_model, decision)
        𝔼Q, σ = _stat_eval_second_stages(eval_model, decision)
        z = quantile(Normal(0,1), 1-α)
        L = cᵀx + 𝔼Q - z*σ/sqrt(Ñ)
        U = cᵀx + 𝔼Q + z*σ/sqrt(Ñ)
        remove_scenarios!(eval_model)
        return ConfidenceInterval(L, U, confidence)
    end
    return CI
end
function evaluate_decision(stochasticmodel::StochasticModel{2},
                           decision::DecisionVariables,
                           sampler::AbstractSampler;
                           kw...)
    return evaluate_decision(stochasticmodel, decisions(decision), sampler; kw...)
end
"""
    lower_bound(stochasticmodel::StochasticModel{2},
                sampler::AbstractSampler;
                confidence = 0.95,
                N = 100,
                M = 10)

Generate a confidence interval around a lower bound on the true optimum of the two-stage `stochasticmodel` at level `confidence`, over the scenario distribution induced by `sampler`.

`N` is the size of the sampled models used to generate the interval and generally governs how tight it is. `M` is the number of sampled models.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
"""
function lower_bound(stochasticmodel::StochasticModel{2},
                     sampler::AbstractSampler;
                     confidence::AbstractFloat = 0.95,
                     N::Integer = 100,
                     M::Integer = 10,
                     log = true,
                     keep = true,
                     offset = 0,
                     indent::Int = 0,
                     kw...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticmodel))
    # Condidence level
    α = 1-confidence
    # Lower bound
    Qs = Vector{Float64}(undef, M)
    progress = Progress(M, 0.0, "$(repeat(" ", indent))Lower CI    ")
    log && sleep(0.1)
    log && ProgressMeter.update!(progress, 0, keep = false, offset = offset)
    for i = 1:M
        let sampled_model = sample(stochasticmodel, sampler, N; optimizer = optimizer_constructor(stochasticmodel), kw...)
            Qs[i] = VRP(sampled_model)
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
                sampler::AbstractSampler;
                confidence = 0.95,
                N = 100,
                T = 10,
                n = 1000)

Generate a confidence interval around an upper of the true optimum of the two-stage `stochasticmodel` at level `confidence`, over the scenario distribution induced by `sampler`.

`N` is the size of the sampled model used to generate a candidate decision. `Ñ` is the size of each sampled model and `T` is the number of sampled models.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
"""
function upper_bound(stochasticmodel::StochasticModel{2},
                     sampler::AbstractSampler;
                     confidence::AbstractFloat = 0.95,
                     N::Integer = 100,
                     T::Integer = 10,
                     Ñ::Integer = 1000,
                     log = true,
                     keep = true,
                     offset = 0,
                     indent::Int = 0,
                     kw...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticmodel))
    # Condidence level
    α = 1-confidence
    # decision generation
    sampled_model = sample(stochasticmodel, sampler, N; optimizer = optimizer_constructor(stochasticmodel), kw...)
    optimize!(sampled_model)
    x̂ = optimal_decision(sampled_model)
    return upper_bound(stochasticmodel, x̂, sampler; confidence = confidence, T = T, Ñ = Ñ, log = log, keep = keep, offset = offset, indent = indent, kw...)
end
"""
    upper_bound(stochasticmodel::StochasticModel{2},
                decision::Union{AbstractVector, DecisionVariables},
                sampler::AbstractSampler;
                confidence = 0.95,
                T = 10,
                Ñ = 1000)

Generate a confidence interval around an upper bound of the expected value of `decision` in the two-stage `stochasticmodel` at level `confidence`, over the scenario distribution induced by `sampler`.

`Ñ` is the size of each sampled model and `T` is the number of sampled models.

The supplied `decision` must be of type `AbstractVector` or `DecisionVariables`, and must match the defined decision variables in `stochasticmodel`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
"""
function upper_bound(stochasticmodel::StochasticModel{2},
                     decision::AbstractVector,
                     sampler::AbstractSampler;
                     confidence::AbstractFloat = 0.95,
                     T::Integer = 10,
                     Ñ::Integer = 1000,
                     log = true,
                     keep = true,
                     offset = 0,
                     indent::Int = 0,
                     kw...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticmodel))
    # Condidence level
    α = 1-confidence
    Qs = Vector{Float64}(undef, T)
    progress = Progress(T, 0.0, "$(repeat(" ", indent))Upper CI    ")
    log && sleep(0.1)
    log && ProgressMeter.update!(progress, 0, keep = false, offset = offset)
    for i = 1:T
        let eval_model = sample(stochasticmodel, sampler, Ñ; optimizer = moi_optimizer(stochasticmodel), defer = true, kw...)
            # Sanity checks on given decision vector
            length(decision) == decision_length(eval_model) || error("Incorrect length of given decision vector, has ", length(decision), " should be ", decision_length(eval_model))
            all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
            # Initialize after checks
            initialize!(eval_model)
            # Evaluate on sampled model
            Qs[i] = evaluate_decision(eval_model, decision)
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
function upper_bound(stochasticmodel::StochasticModel{2},
                     decision::DecisionVariables,
                     sampler::AbstractSampler;
                     kw...)
    return upper_bound(stochasticmodel, decisions(decision), sampler; kw...)
end
"""
    confidence_interval(stochasticmodel::StochasticModel{2},
                        sampler::AbstractSampler;
                        confidence = 0.9,
                        N = 100,
                        M = 10,
                        T = 10)

Generate a confidence interval around the true optimum of the two-stage `stochasticmodel` at level `confidence` using SAA, over the scenario distribution induced by `sampler`.

`N` is the size of the sampled models used to generate the interval and generally governs how tight it is. `M` is the number of sampled models used in the lower bound calculation, and `T` is the number of sampled models used in the upper bound calculation.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
"""
function confidence_interval(stochasticmodel::StochasticModel{2},
                             sampler::AbstractSampler;
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
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticmodel))
    # Condidence level
    α = (1-confidence)/2
    # Lower bound
    lower_CI = lower_bound(stochasticmodel, sampler; confidence = 1-α, N = N, M = M, log = log, keep = keep, offset = offset, indent = indent, kw...)
    L = lower(lower_CI)
    # Upper bound
    upper_CI = upper_bound(stochasticmodel, sampler; confidence = 1-α, N = N, T = T, Ñ = Ñ, log = log, keep = keep, offset = offset, indent = indent, kw...)
    U = upper(upper_CI)
    return ConfidenceInterval(L, U, confidence)
end
"""
    gap(stochasticmodel::StochasticModel{2},
        decision::Union{AbstractVector, DecisionVariables},
        sampler::AbstractSampler;
        confidence = 0.9,
        N = 100,
        M = 10,
        T = 10)

Generate a confidence interval around the gap between the result of using `decision` and the true optimum of the two-stage `stochasticmodel` at level `confidence` using SAA, over the scenario distribution induced by `sampler`.

`N` is the size of the SAA models used to generate the interval and generally governs how tight it is. `M` is the number of sampled models used in the lower bound calculation, and `T` is the number of sampled models used in the upper bound calculation.

The supplied `decision` must be of type `AbstractVector` or `DecisionVariables`, and must match the defined decision variables in `stochasticmodel`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
"""
function gap(stochasticmodel::StochasticModel{2},
             decision::AbstractVector,
             sampler::AbstractSampler;
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
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticmodel))
    # Condidence level
    α = (1-confidence)/2
    # Lower bound
    lower_CI = lower_bound(stochasticmodel, sampler; confidence = 1-α, N = N, M = M, log = log, keep = keep, offset = offset, indent = indent, kw...)
    L = lower(lower_CI)
    # Upper bound
    upper_CI = upper_bound(stochasticmodel, x, sampler; confidence = 1-α, N = N, T = T, Ñ = Ñ, log = log, keep = keep, offset = offset, indent = indent, kw...)
    U = upper(upper_CI)
    return ConfidenceInterval(0., U-L, confidence)
end
function gap(stochasticmodel::StochasticModel{2},
             decision::DecisionVariables,
             sampler::AbstractSampler;
             kw...)
    return gap(stochasticmodel, decisions(decision), sampler; kw...)
end
# ========================== #
