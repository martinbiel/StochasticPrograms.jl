# Problem evaluation #
# ========================== #
function eval_first_stage(stochasticprogram::StochasticProgram, x::AbstractVector)
    first_stage = get_stage_one(stochasticprogram)
    return evaluate_objective(objective_function(first_stage), x)
end
# Evaluation API #
# ========================== #
"""
    evaluate_decision(stochasticprogram::TwoStageStochasticProgram, decision::AbstractVector)

Evaluate the first-stage `decision` in `stochasticprogram`.

In other words, evaluate the first-stage objective at `decision` and solve outcome models of `decision` for every available scenario. The supplied `decision` must match the defined decision variables in `stochasticprogram`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
"""
function evaluate_decision(stochasticprogram::TwoStageStochasticProgram, decision::AbstractVector)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(stochasticprogram.optimizer)
    # Ensure stochastic program has been generated at this point
    if deferred(stochasticprogram)
        generate!(stochasticprogram)
    end
    # Sanity checks on given decision vector
    all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
    # Dispatch evaluation on stochastic structure
    return evaluate_decision(structure(stochasticprogram), decision)
end
"""
    statistically_valuate_decision(stochasticprogram::TwoStageStochasticProgram, decision::AbstractVector)

Statistically evaluate the first-stage `decision` in `stochasticprogram`, returning the evaluated value and the spread over the scenarios.

The supplied `decision` must match the defined decision variables in `stochasticprogram`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
"""
function statistically_valuate_decision(stochasticprogram::TwoStageStochasticProgram, decision::AbstractVector)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(stochasticprogram.optimizer)
    # Ensure stochastic program has been generated at this point
    if deferred(stochasticprogram)
        generate!(stochasticprogram)
    end
    # Sanity checks on given decision vector
    all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
    # Dispatch evaluation on stochastic structure
    return statistically_valuate_decision(structure(stochasticprogram), decision)
end
"""
    evaluate_decision(stochasticprogram::TwoStageStochasticProgram,
                      decision::AbstractVector,
                      scenario::AbstractScenario;
                      optimizer = nothing)

Evaluate the result of taking the first-stage `decision` if `scenario` is the actual outcome in `stochasticprogram`. The supplied `decision` must match the defined decision variables in `stochasticprogram`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
"""
function evaluate_decision(stochasticprogram::TwoStageStochasticProgram,
                           decision::AbstractVector,
                           scenario::AbstractScenario)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(stochasticprogram.optimizer)
    # Sanity checks on given decision vector
    length(decision) == decision_length(stochasticprogram) || error("Incorrect length of given decision vector, has ", length(decision), " should be ", decision_length(stochasticprogram))
    all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
    # Generate and solve outcome model
    outcome = outcome_model(stochasticprogram, decision, scenario, sub_optimizer(stochasticprogram))
    optimize!(outcome)
    status = termination_status(outcome)
    if status != MOI.OPTIMAL
        if status == MOI.INFEASIBLE
            return objective_sense(outcome) == MOI.MAX_SENSE ? -Inf : Inf
        elseif status == MOI.DUAL_INFEASIBLE
            return objective_sense(outcome) == MOI.MAX_SENSE ? Inf : -Inf
        else
            error("Outcome model could not be solved, returned status: $status")
        end
    else
        return objective_value(outcome)
    end
end
"""
    evaluate_decision(stochasticmodel::StochasticModel{2},
                      decision::AbstractVector,
                      sampler::AbstractSampler;
                      optimizer = nothing;
                      confidence = 0.95,
                      N = 1000)

Return a statistical estimate of the objective of the two-stage `stochasticmodel` at `decision` in the form of a confidence interval at level `confidence`, over the scenario distribution induced by `sampler`.

In other words, evaluate `decision` on a sampled model of size `N`. Generate an confidence interval using the sample variance of the evaluation.

The supplied `decision` must match the defined decision variables in `stochasticmodel`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

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
    CI = let eval_model = sample(stochasticmodel, sampler, Ñ; optimizer = optimizer_constructor(stochasticmodel), kw...)
        # Sanity checks on given decision vector
        length(decision) == decision_length(eval_model) || error("Incorrect length of given decision vector, has ", length(decision), " should be ", decision_length(eval_model))
        all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
        # Initialize after checks
        initialize!(eval_model)
        # Condidence level
        α = 1-confidence
        𝔼Q, σ = statistically_evalute_decision(eval_model, decision)
        z = quantile(Normal(0,1), 1-α)
        L = 𝔼Q - z*σ/sqrt(Ñ)
        U = 𝔼Q + z*σ/sqrt(Ñ)
        # Clear memory from temporary model
        clear!(eval_model)
        return ConfidenceInterval(L, U, confidence)
    end
    return CI
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
            # Clear memory from temporary model
            clear!(sampled_model)
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
                decision::AbstractVector,
                sampler::AbstractSampler;
                confidence = 0.95,
                T = 10,
                Ñ = 1000)

Generate a confidence interval around an upper bound of the expected value of `decision` in the two-stage `stochasticmodel` at level `confidence`, over the scenario distribution induced by `sampler`.

`Ñ` is the size of each sampled model and `T` is the number of sampled models.

The supplied `decision` must match the defined decision variables in `stochasticmodel`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
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
        let eval_model = sample(stochasticmodel, sampler, Ñ; optimizer = optimizer_constructor(stochasticmodel), defer = true, kw...)
            # Sanity checks on given decision vector
            length(decision) == decision_length(eval_model) || error("Incorrect length of given decision vector, has ", length(decision), " should be ", decision_length(eval_model))
            all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
            # Initialize after checks
            initialize!(eval_model)
            # Evaluate on sampled model
            Qs[i] = evaluate_decision(eval_model, decision)
            # Clear memory from temporary model
            clear!(eval_model)
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
        decision::UnionAbstractVector,
        sampler::AbstractSampler;
        confidence = 0.9,
        N = 100,
        M = 10,
        T = 10)

Generate a confidence interval around the gap between the result of using `decision` and the true optimum of the two-stage `stochasticmodel` at level `confidence` using SAA, over the scenario distribution induced by `sampler`.

`N` is the size of the SAA models used to generate the interval and generally governs how tight it is. `M` is the number of sampled models used in the lower bound calculation, and `T` is the number of sampled models used in the upper bound calculation.

The supplied `decision` must match the defined decision variables in `stochasticmodel`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
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
