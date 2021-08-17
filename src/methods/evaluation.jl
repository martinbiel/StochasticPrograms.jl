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

# Problem evaluation #
# ========================== #
function eval_first_stage(stochasticprogram::StochasticProgram, x::AbstractVector)
    first_stage = stage_one_model(stochasticprogram; optimizer = master_optimizer(stochasticprogram))
    return evaluate_objective(objective_function(first_stage), x)
end
# Evaluation API #
# ========================== #
"""
    evaluate_decision(stochasticprogram::TwoStageStochasticProgram, decision::AbstractVector)

Evaluate the first-stage `decision` in `stochasticprogram`.

In other words, evaluate the first-stage objective at `decision` and solve outcome models of `decision` for every available scenario. The supplied `decision` must match the defined decision variables in `stochasticprogram`. If a optimal solution to `stochasticprogram` has been determined, but [`cache_solution!`](@ref) has not been called, then the solution will be overwritten by this call. If an optimizer has not been set yet (see [`set_optimizer`](@ref)), a `NoOptimizer` error is thrown.
"""
function evaluate_decision(stochasticprogram::TwoStageStochasticProgram, decision::AbstractVector)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Ensure stochastic program has been generated at this point
    if deferred(stochasticprogram)
        generate!(stochasticprogram)
    end
    # Sanity checks on given decision vector
    all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
    # Restore structure (if necessary)
    restore_structure!(stochasticprogram.optimizer)
    # Dispatch evaluation on stochastic structure
    return evaluate_decision(structure(stochasticprogram), decision)
end
"""
    statistically_evaluate_decision(stochasticprogram::TwoStageStochasticProgram, decision::AbstractVector)

Statistically evaluate the first-stage `decision` in `stochasticprogram`, returning the evaluated value and the spread over the scenarios.

The supplied `decision` must match the defined decision variables in `stochasticprogram`. If an optimizer has not been set yet (see [`set_optimizer`](@ref)), a `NoOptimizer` error is thrown.
"""
function statistically_evaluate_decision(stochasticprogram::TwoStageStochasticProgram, decision::AbstractVector)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Ensure stochastic program has been generated at this point
    if deferred(stochasticprogram)
        generate!(stochasticprogram)
    end
    # Sanity checks on given decision vector
    all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
    # Dispatch evaluation on stochastic structure
    return statistically_evaluate_decision(structure(stochasticprogram), decision)
end
"""
    evaluate_decision(stochasticprogram::TwoStageStochasticProgram, decision::AbstractVector, scenario::AbstractScenario)

Evaluate the result of taking the first-stage `decision` if `scenario` is the actual outcome in `stochasticprogram`. The supplied `decision` must match the defined decision variables in `stochasticprogram`. If an optimizer has not been set yet (see [`set_optimizer`](@ref)), a `NoOptimizer` error is thrown.
"""
function evaluate_decision(stochasticprogram::TwoStageStochasticProgram,
                           decision::AbstractVector,
                           scenario::AbstractScenario)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Sanity checks on given decision vector
    length(decision) == num_decisions(stochasticprogram) || error("Incorrect length of given decision vector, has ", length(decision), " should be ", num_decisions(stochasticprogram))
    all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
    # Generate and solve outcome model
    outcome = outcome_model(stochasticprogram, decision, scenario; optimizer = subproblem_optimizer(stochasticprogram))
    optimize!(outcome)
    status = termination_status(outcome)
    if status in AcceptableTermination
        return objective_value(outcome)
    else
        if status == MOI.INFEASIBLE
            return objective_sense(outcome) == MOI.MAX_SENSE ? -Inf : Inf
        elseif status == MOI.DUAL_INFEASIBLE
            return objective_sense(outcome) == MOI.MAX_SENSE ? Inf : -Inf
        else
            error("Outcome model could not be solved, returned status: $status")
        end
    end
end
"""
    recourse_decision(stochasticprogram::TwoStageStochasticProgram, decision::AbstractVector, scenario::AbstractScenario)

Determine the optimal recourse decision after taking the first-stage `decision` if `scenario` is the actual outcome in `stochasticprogram`. The supplied `decision` must match the defined decision variables in `stochasticprogram`. If an optimizer has not been set yet (see [`set_optimizer`](@ref)), a `NoOptimizer` error is thrown.
"""
function recourse_decision(stochasticprogram::TwoStageStochasticProgram,
                           decision::AbstractVector,
                           scenario::AbstractScenario)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Sanity checks on given decision vector
    length(decision) == num_decisions(stochasticprogram) || error("Incorrect length of given decision vector, has ", length(decision), " should be ", num_decisions(stochasticprogram))
    all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
    # Generate and solve outcome model
    outcome = outcome_model(stochasticprogram, decision, scenario; optimizer = subproblem_optimizer(stochasticprogram))
    optimize!(outcome)
    return JuMP.value.(all_decision_variables(outcome)[end])
end
"""
    evaluate_decision(stochasticmodel::StochasticModel{2}, decision::AbstractVector, sampler::AbstractSampler; kw...)

Return a statistical estimate of the objective of the two-stage `stochasticmodel` at `decision` in the form of a confidence interval at the current confidence level, over the scenario distribution induced by `sampler`.

In other words, evaluate `decision` on a sampled model and generate an confidence interval using the sample variance of the evaluation. The confidence level can be set through the [`Confidence`](@ref) attribute and the sample size can be set through the [`NumEvalSamples`](@ref) attribute.

The supplied `decision` must match the defined decision variables in `stochasticmodel`. If a sample-based optimizer has not been set yet (see [`set_optimizer`](@ref)), a `NoOptimizer` error is thrown.

See also: [`confidence_interval`](@ref)
"""
function evaluate_decision(stochasticmodel::StochasticModel{2}, decision::AbstractVector, sampler::AbstractSampler; kw...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticmodel.optimizer)
    # Get instance optimizer
    optimizer = MOI.get(stochasticmodel, InstanceOptimizer())
    # Get parameters
    confidence = MOI.get(stochasticmodel, Confidence())
    N = MOI.get(stochasticmodel, NumEvalSamples())
    # Calculate confidence interval using provided optimizer
    CI = let eval_model = instantiate(stochasticmodel, sampler, N; optimizer = optimizer, kw...)
        # Silence output
        MOI.set(eval_model, MOI.Silent(), true)
        # Sanity checks on given decision vector
        length(decision) == num_decisions(eval_model) || error("Incorrect length of given decision vector, has ", length(decision), " should be ", num_decisions(eval_model))
        all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
        # Confidence level
        α = 1 - confidence
        𝔼Q, σ = statistically_evaluate_decision(eval_model, decision)
        z = quantile(Normal(0,1), 1 - α)
        L = 𝔼Q - z * σ / sqrt(N)
        U = 𝔼Q + z * σ / sqrt(N)
        # Clear memory from temporary model
        clear!(eval_model)
        return ConfidenceInterval(L, U, confidence)
    end
    return CI
end
"""
    lower_confidence_interval(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; kw...)

Generate a confidence interval around a lower bound on the true optimum of the two-stage `stochasticmodel` at the current confidence level, over the scenario distribution induced by `sampler`.

The attribute [`NumSamples`](@ref) is the size of the sampled models used to generate the interval and generally governs how tight it is. The attribute [`NumLowerTrials`](@ref) is the number of sampled models. The confidence level can be set through the [`Confidence`](@ref) attribute.

If a sample-based optimizer has not been set yet (see [`set_optimizer`](@ref)), a `NoOptimizer` error is thrown.
"""
function lower_confidence_interval(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; kw...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticmodel.optimizer)
    # Get the instance optimizer
    optimizer = MOI.get(stochasticmodel, InstanceOptimizer())
    # Get parameters
    confidence = MOI.get(stochasticmodel, Confidence())
    α = 1 - confidence
    N = MOI.get(stochasticmodel, NumSamples())
    M = MOI.get(stochasticmodel, NumLowerTrials())
    log = MOI.get(stochasticmodel, MOI.RawParameter("log"))
    keep = MOI.get(stochasticmodel, MOI.RawParameter("keep"))
    offset = MOI.get(stochasticmodel, MOI.RawParameter("offset"))
    indent = MOI.get(stochasticmodel, MOI.RawParameter("indent"))
    # Lower bound
    Qs = Vector{Float64}(undef, M)
    progress = Progress(M, 0.0, "$(repeat(" ", indent))Lower CI    ")
    log && sleep(0.1)
    log && ProgressMeter.update!(progress, 0, keep = false, offset = offset)
    for i = 1:M
        let sampled_model = instantiate(stochasticmodel, sampler, N; optimizer = optimizer, kw...)
            Qs[i] = VRP(sampled_model)
            # Clear memory from temporary model
            clear!(sampled_model)
        end
        log && ProgressMeter.update!(progress, i, keep = keep, offset = offset)
    end
    Q̂ = mean(Qs)
    σ = std(Qs)
    t = quantile(TDist(M-1), 1-α)
    L = Q̂ - t * σ / sqrt(M)
    U = Q̂ + t * σ / sqrt(M)
    return ConfidenceInterval(L, U, 1-α)
end
"""
    upper_confidence_interval(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; kw...)

Generate a confidence interval around an upper bound of the true optimum of the two-stage `stochasticmodel` at the current confidence level, over the scenario distribution induced by `sampler`, by generating and evaluating a candidate decision.

The attribute [`NumSamples`](@ref) is the size of the sampled model used to generate a candidate decision. The attribute [`NumUpperTrials`](@ref) is the number of sampled models and the attribute [`NumEvalSamples`](@ref) is the size of the evaluation models. The confidence level can be set through the [`Confidence`](@ref) attribute.

If a sample-based optimizer has not been set yet (see [`set_optimizer`](@ref)), a `NoOptimizer` error is thrown.
"""
function upper_confidence_interval(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; kw...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticmodel.optimizer)
    # Get the instance optimizer
    optimizer = MOI.get(stochasticmodel, InstanceOptimizer())
    # Get parameters
    confidence = MOI.get(stochasticmodel, Confidence())
    α = 1 - confidence
    num_samples = MOI.get(stochasticmodel, NumSamples())
    # decision generation
    sampled_model = instantiate(stochasticmodel,
                                sampler,
                                num_samples;
                                optimizer = optimizer,
                                kw...)
    # Optimize
    optimize!(sampled_model)
    x̂ = optimal_decision(sampled_model)
    return upper_confidence_interval(stochasticmodel, x̂, sampler; kw...)
end
"""
    upper_confidence_interval(stochasticmodel::StochasticModel{2}, decision::AbstractVector, sampler::AbstractSampler; kw...)

Generate a confidence interval around an upper bound of the expected value of `decision` in the two-stage `stochasticmodel` at the current confidence level, over the scenario distribution induced by `sampler`.

The attribute [`NumUpperTrials`](@ref) is the number of sampled models and the attribute [`NumEvalSamples`](@ref) is the size of the evaluation models. The confidence level can be set through the [`Confidence`](@ref) attribute.

The supplied `decision` must match the defined decision variables in `stochasticmodel`. If an optimizer has not been set yet (see [`set_optimizer`](@ref)), a `NoOptimizer` error is thrown.
"""
function upper_confidence_interval(stochasticmodel::StochasticModel{2}, decision::AbstractVector, sampler::AbstractSampler, kw...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticmodel.optimizer)
    # Get the instance optimizer
    optimizer = MOI.get(stochasticmodel, InstanceOptimizer())
    # Get parameters
    confidence = MOI.get(stochasticmodel, Confidence())
    α = 1 - confidence
    N = MOI.get(stochasticmodel, NumEvalSamples())
    N = max(N, MOI.get(stochasticmodel, NumSamples()))
    T = MOI.get(stochasticmodel, NumUpperTrials())
    log = MOI.get(stochasticmodel, MOI.RawParameter("log"))
    keep = MOI.get(stochasticmodel, MOI.RawParameter("keep"))
    offset = MOI.get(stochasticmodel, MOI.RawParameter("offset"))
    indent = MOI.get(stochasticmodel, MOI.RawParameter("indent"))
    # Generate upper bound
    Q = Vector{Float64}(undef, T)
    progress = Progress(T, 0.0, "$(repeat(" ", indent))Upper CI    ")
    log && sleep(0.1)
    log && ProgressMeter.update!(progress, 0, keep = false, offset = offset - 1)
    for i = 1:T
        let eval_model = instantiate(stochasticmodel, sampler, N; optimizer = optimizer, kw...)
            # Silence output
            MOI.set(eval_model, MOI.Silent(), true)
            # Sanity checks on given decision vector
            length(decision) == num_decisions(eval_model) || error("Incorrect length of given decision vector, has ", length(decision), " should be ", num_decisions(eval_model))
            all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
            # Evaluate on sampled model
            Q[i] = evaluate_decision(eval_model, decision)
            # Clear memory from temporary model
            clear!(eval_model)
        end
        log && ProgressMeter.update!(progress, i, keep = keep, offset = offset - 1)
    end
    Q̂ = mean(Q)
    σ = std(Q)
    t = quantile(TDist(T - 1), 1 - α)
    L = Q̂ - t * σ / sqrt(T)
    U = Q̂ + t * σ / sqrt(T)
    return ConfidenceInterval(L, U, 1 - α)
end
"""
    confidence_interval(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler)

Generate a confidence interval around the true optimum of the two-stage `stochasticmodel` at level `confidence` using SAA, over the scenario distribution induced by `sampler`.

The attribute [`NumSamples`](@ref) is the size of the sampled models used to generate the interval and generally governs how tight it is. The attribute [`NumLowerTrials`](@ref) is the number of sampled models used in the lower bound calculation and the attribute [`NumUpperTrials`](@ref) is the number of sampled models used in the upper bound calculation. The attribute [`NumEvalSamples`](@ref) is the size of the sampled models used in the upper bound calculation. The confidence level can be set through the [`Confidence`](@ref) attribute.

If a sample-based optimizer has not been set yet (see [`set_optimizer`](@ref)), a `NoOptimizer` error is thrown.
"""
function confidence_interval(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; kw...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticmodel.optimizer)
    # Confidence level
    confidence = MOI.get(stochasticmodel, Confidence())
    # Modify confidence for two-sided interval
    α = (1 - confidence)/2
    MOI.set(stochasticmodel, Confidence(), 1 - α)
    # Lower bound
    lower_CI = lower_confidence_interval(stochasticmodel, sampler; kw...)
    L = lower(lower_CI)
    # Upper bound
    upper_CI = upper_confidence_interval(stochasticmodel, sampler; kw...)
    U = upper(upper_CI)
    # Restore confidence level
    MOI.set(stochasticmodel, Confidence(), confidence)
    # Check if confidence interval is valid
    if U <= L
        @warn "Could not calculate confidence interval at current level of confidence and sample size"
        return ConfidenceInterval(-Inf, Inf, confidence)
    end
    # Return confidence interval
    return ConfidenceInterval(L, U, confidence)
end
"""
    gap(stochasticmodel::StochasticModel{2}, decision::UnionAbstractVector, sampler::AbstractSampler)

Generate a confidence interval around the gap between the result of using `decision` and the true optimum of the two-stage `stochasticmodel` at the current confidence level, over the scenario distribution induced by `sampler`.

The attribute [`NumSamples`](@ref) is the size of the sampled models used to generate the interval and generally governs how tight it is. The attribute [`NumLowerTrials`](@ref) is the number of sampled models used in the lower bound calculation and the attribute [`NumUpperTrials`](@ref) is the number of sampled models used in the upper bound calculation. The attribute [`NumEvalSamples`](@ref) is the size of the sampled models used in the upper bound calculation. The confidence level can be set through the [`Confidence`](@ref) attribute.

The supplied `decision` must match the defined decision variables in `stochasticmodel`. If a sample-based optimizer has not been set yet (see [`set_optimizer`](@ref)), a `NoOptimizer` error is thrown.
"""
function gap(stochasticmodel::StochasticModel{2}, decision::AbstractVector, sampler::AbstractSampler; kw...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticmodel.optimizer)
    # Confidence level
    confidence = MOI.get(stochasticmodel, Confidence())
    # Modify confidence for two-sided interval
    α = (1-confidence)/2
    MOI.set(stochasticmodel, Confidence(), 1 - α)
    # Lower bound
    lower_CI = lower_confidence_interval(stochasticmodel, sampler; kw...)
    L = lower(lower_CI)
    # Upper bound
    upper_CI = upper_confidence_interval(stochasticmodel, decision, sampler; kw...)
    U = upper(upper_CI)
    # Restore confidence level
    MOI.set(stochasticmodel, Confidence(), confidence)
    # Return confidence interval
    return ConfidenceInterval(0., U - L, confidence)
end
