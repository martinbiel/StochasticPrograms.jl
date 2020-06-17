# Stochastic programming constructs #
# ========================== #
"""
    WS(stochasticprogram::TwoStageStochasticProgram, scenario::AbstractScenarioaData; optimizer = nothing)

Generate a **wait-and-see** (`WS`) model of the two-stage `stochasticprogram`, corresponding to `scenario`.

In other words, generate the first stage and the second stage of the `stochasticprogram` as if `scenario` is known to occur. Optionally, a capable `optimizer` can be supplied to `WS`.

See also: [`DEP`](@ref), [`EVP`](@ref)
"""
function WS(stochasticprogram::StochasticProgram{2}, scenario::AbstractScenario; optimizer = nothing)
    # Check that the required generators have been defined
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Consider @stage 2.")
    # Return WS model
    return _WS(generator(stochasticprogram,:stage_1),
               generator(stochasticprogram,:stage_2),
               stage_parameters(stochasticprogram, 1),
               stage_parameters(stochasticprogram, 2),
               scenario,
               Decisions(),
               optimizer)
end
function _WS(stage_one_generator::Function,
             stage_two_generator::Function,
             stage_one_params::Any,
             stage_two_params::Any,
             scenario::AbstractScenario,
             decisions::Decisions,
             optimizer_constructor)
    ws_model = optimizer_constructor == nothing ? Model() : Model(optimizer_constructor)
    # Prepare decisions
    ws_model.ext[:decisions] = decisions
    add_decision_bridges!(ws_model)
    # Generate first stage and cache objective
    stage_one_generator(ws_model, stage_one_params)
    ws_obj = copy(objective_function(ws_model))
    ws_sense = objective_sense(ws_model)
    ws_sense = ws_sense == MOI.FEASIBILITY_SENSE ? MOI.MIN_SENSE : ws_sense
    # Generate second stage and finalize objective
    stage_two_generator(ws_model, stage_two_params, scenario)
    if ws_sense == objective_sense(ws_model)
        ws_obj += objective_function(ws_model)
    else
        ws_obj -= objective_function(ws_model)
    end
    set_objective_function(ws_model, ws_obj)
    set_objective_sense(ws_model, ws_sense)
    return ws_model
end
"""
    wait_and_see_decision(stochasticprogram::TwoStageStochasticProgram, scenario::AbstractScenario, optimizer_constructor = nothing)

Calculate the optimizer of the **wait-and-see** (`WS`) model of the two-stage `stochasticprogram`, corresponding to `scenario`.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`WS`](@ref)
"""
function wait_and_see_decision(stochasticprogram::StochasticProgram{2}, scenario::AbstractScenario)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Solve WS model for supplied scenario
    ws_model = WS(stochasticprogram, scenario, optimizer = subproblem_optimizer(stochasticprogram))
    optimize!(ws_model)
    # Return WS decision
    return JuMP.value.(all_decision_variables(ws_model))
end
"""
    EWS(stochasticprogram::StochasticProgram)

Calculate the **expected wait-and-see result** (`EWS`) of the `stochasticprogram`.

In other words, calculate the expectated result of all possible wait-and-see models, using the provided scenarios in `stochasticprogram`.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`VRP`](@ref), [`WS`](@ref)
"""
function EWS(stochasticprogram::StochasticProgram)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Solve all possible WS models and compute EWS
    return EWS(stochasticprogram, structure(stochasticprogram))
end
# Default implementation
function EWS(stochasticprogram::StochasticProgram, structure::AbstractStochasticStructure)
    return mapreduce(+, scenarios(stochasticprogram)) do scenario
        ws = _WS(stochasticprogram.generator[:stage_1],
                 stochasticprogram.generator[:stage_2],
                 stage_parameters(stochasticprogram, 1),
                 stage_parameters(stochasticprogram, 2),
                 scenario,
                 Decisions(),
                 subproblem_optimizer(stochasticprogram))
        optimize!(ws)
        probability(scenario)*objective_value(ws)
    end
end
"""
    EWS(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler)

Approximately calculate the **expected wait-and-see result** (`EWS`) of the two-stage `stochasticmodel` to the current confidence level, over the scenario distribution induced by `sampler`.

The attribute [`NumEWSSamples`](@ref) is the size of the sampled models used to generate the interval and generally governs how tight it is. The confidence level can be set through the [`Confidence`](@ref) attribute.

If a sample-based optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`VRP`](@ref), [`WS`](@ref)
"""
function EWS(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticmodel.optimizer)
    # Get instance optimizer
    optimizer = MOI.get(stochasticmodel, InstanceOptimizer())
    # Get parameters
    confidence = MOI.get(stochasticmodel, Confidence())
    N = MOI.get(stochasticmodel, NumEWSSamples())
    # Generate a sample model and statistically evaluate EWS
    let eval_model = instantiate(stochasticmodel, sampler, N; optimizer = optimizer)
        𝔼WS, σ² = statistical_EWS(eval_model, structure(eval_model))
        σ = sqrt(σ²)
        z = quantile(Normal(0,1), confidence)
        L = 𝔼WS - z * σ / sqrt(N)
        U = 𝔼WS + z * σ / sqrt(N)
        return ConfidenceInterval(L, U, confidence)
    end
end
# Default implementation
function statistical_EWS(stochasticprogram::StochasticProgram, structure::AbstractStochasticStructure)
    ws_models = map(scenarios(stochasticprogram)) do scenario
        ws = _WS(stochasticprogram.generator[:stage_1],
                 stochasticprogram.generator[:stage_2],
                 stage_parameters(stochasticprogram, 1),
                 stage_parameters(stochasticprogram, 2),
                 scenario,
                 Decisions(),
                 subproblem_optimizer(stochasticprogram))
    end
    return welford(ws_models, probability.(scenarios(stochasticprogram)))
end
"""
    DEP(stochasticprogram::TwoStageStochasticProgram; optimizer = nothing)

Generate the **deterministically equivalent problem** (`DEP`) of the two-stage `stochasticprogram`, unless a cached version already exists.

In other words, generate the extended form the `stochasticprogram` as a single JuMP model. Optionally, a capable `optimizer` can be supplied to `DEP`.

See also: [`VRP`](@ref), [`WS`](@ref)
"""
function DEP(stochasticprogram::StochasticProgram{2}; optimizer = nothing)
    return DEP(stochasticprogram, structure(stochasticprogram); optimizer = optimizer)
end
function DEP(stochasticprogram::StochasticProgram{2}, ::AbstractStochasticStructure; optimizer = nothing)
    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache, :dep)
        dep = cache[:dep]
        optimizer != nothing && set_optimizer(dep, optimizer)
        return dep
    end
    # Check that the required generators have been defined
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Consider @stage 2.")
    # Generate and cache deterministic equivalent
    dep = StochasticStructure(scenario_types(stochasticprogram), Deterministic())
    generate!(stochasticprogram, dep)
    cache[:dep] = dep.model
    # Return DEP
    return dep
end
"""
    VRP(stochasticprogram::StochasticProgram)

Calculate the **value of the recouse problem** (`VRP`) in `stochasticprogram`.

In other words, optimize the stochastic program and return the optimal value.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`EVPI`](@ref), [`EWS`](@ref)
"""
function VRP(stochasticprogram::StochasticProgram)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Solve DEP
    optimize!(stochasticprogram)
    # Return optimal value
    return objective_value(stochasticprogram)
end
"""
    VRP(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; confidence = 0.95)

Return a confidence interval around the **value of the recouse problem** (`VRP`) of `stochasticmodel` to the given `confidence` level.

If a sample-based optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`EVPI`](@ref), [`VSS`](@ref), [`EWS`](@ref)
"""
function VRP(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticmodel.optimizer)
    # Optimize stochastic model using sample-based method
    optimize!(stochasticmodel, sampler)
    return objective_value(stochasticmodel)
end
"""
    EVPI(stochasticprogram::TwoStageStochasticProgram)

Calculate the **expected value of perfect information** (`EVPI`) of the two-stage `stochasticprogram`.

In other words, calculate the gap between `VRP` and `EWS`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`VRP`](@ref), [`EWS`](@ref), [`VSS`](@ref)
"""
function EVPI(stochasticprogram::StochasticProgram{2})
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Calculate VRP
    vrp = VRP(stochasticprogram)
    # Solve all possible WS models and calculate EWS
    ews = EWS(stochasticprogram)
    # Return EVPI = EWS - VRP
    return abs(ews-vrp)
end
"""
    EVPI(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler)

Approximately calculate the **expected value of perfect information** (`EVPI`) of the two-stage `stochasticmodel` to the current confidence level, over the scenario distribution induced by `sampler`.

In other words, calculate confidence intervals around `VRP` and `EWS`. If they do not overlap, the EVPI is statistically significant, and a confidence interval is calculated and returned.

The attribute [`NumSamples`](@ref) is the size of the sampled models used to generate the interval and generally governs how tight it is. The attribute [`NumLowerTrials`](@ref) is the number of sampled models used in the lower bound calculation and the attribute [`NumUpperTrials`](@ref) is the number of sampled models used in the upper bound calculation. The attribute [`NumEvalsamples`](@ref) is the size of the sampled models used in the upper bound calculation. The confidence level can be set through the [`Confidence`](@ref) attribute.

If a sample-based optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`VRP`](@ref), [`EWS`](@ref), [`VSS`](@ref)
"""
function EVPI(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticmodel.optimizer)
    # Get parameters
    confidence = MOI.get(stochasticmodel, Confidence())
    # Modify confidence for two-sided interval
    α = (1-confidence)/2
    MOI.set(stochasticmodel, Confidence(), 1 - α)
    # Calculate confidence interval around VRP
    optimize!(stochasticmodel, sampler)
    # Check return status
    status = termination_status(stochasticmodel)
    if status != MOI.OPTIMAL
        error("Stochastic model could not be solved to optimality, returned status $status.")
    end
    vrp = objective_value(stochasticmodel)
    # EWS solution of the corresponding size
    ews = EWS(stochasticmodel, sampler)
    # Restore confidence level
    MOI.set(stochasticmodel, Confidence(), confidence)
    # Check overlap
    if (upper(vrp) >= lower(ews) + eps() && upper(ews) >= lower(vrp) + eps()) ||
       (lower(vrp) <= upper(ews) - eps() && upper(vrp) >= lower(ews) + eps())
        @warn "EVPI is not statistically significant to the chosen confidence level and tolerance"
        # Return confidence interval as tolerance around zero
        tolerance = MOI.get(stochasticmodel, RelativeTolerance())
        return ConfidenceInterval(-tolerance, tolerance, confidence)
    end
    # Switch on sign
    if lower(ews) >= upper(vrp)
        # Return confidence interval around EVPI
        return ConfidenceInterval(lower(ews) - upper(vrp), upper(ews) - lower(vrp), confidence)
    else
        # Return confidence interval around EVPI
        return ConfidenceInterval(lower(vrp) - upper(ews), upper(vrp) - lower(ews), confidence)
    end
end
"""
    EVP(stochasticprogram::TwoStageStochasticProgram; optimizer = nothing)

Generate the **expected value problem** (`EVP`) of the two-stage `stochasticprogram`.

In other words, generate a wait-and-see model corresponding to the expected scenario over all available scenarios in `stochasticprogram`. Optionally, a capable `optimizer` can be supplied to `WS`.

See also: [`expected_value_decision`](@ref), [`EEV`](@ref), [`EV`](@ref), [`WS`](@ref)
"""
function EVP(stochasticprogram::StochasticProgram{2}; optimizer = nothing)
    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:evp)
        evp = cache[:evp]
        optimizer != nothing && set_optimizer(evp, optimizer)
        return evp
    end
    # Create EVP as a wait-and-see model of the expected scenario
    ev_model = WS(stochasticprogram, expected(stochasticprogram).scenario, optimizer = optimizer)
    # Cache EVP
    cache[:evp] = ev_model
    # Return EVP
    return ev_model
end
"""
    expected_value_decision(stochasticprogram::TwoStageStochasticProgram)

Calculate the optimizer of the `EVP` of the two-stage `stochasticprogram`.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`EVP`](@ref), [`EV`](@ref), [`EEV`](@ref)
"""
function expected_value_decision(stochasticprogram::StochasticProgram{2})
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Solve EVP
    evp = EVP(stochasticprogram, optimizer = master_optimizer(stochasticprogram))
    optimize!(evp)
    # Return EVP decision
    return JuMP.value.(all_decision_variables(evp))
end
"""
    EV(stochasticprogram::TwoStageStochasticProgram)

Calculate the optimal value of the `EVP` of the two-stage `stochasticprogram`.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`EVP`](@ref), [`expected_value_decision`](@ref), [`EEV`](@ref)
"""
function EV(stochasticprogram::StochasticProgram{2})
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Solve EVP model
    evp = EVP(stochasticprogram, optimizer = master_optimizer(stochasticprogram))
    optimize!(evp)
    # Return optimal value
    return objective_value(evp)
end
"""
    EEV(stochasticprogram::TwoStageStochasticProgram)

Calculate the **expected value of the expected value solution** (`EEV`) of the two-stage `stochasticprogram`.

In other words, evaluate the `EVP` decision. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`EVP`](@ref), [`EV`](@ref)
"""
function EEV(stochasticprogram::StochasticProgram{2})
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Solve EVP model
    evp_decision = expected_value_decision(stochasticprogram)
    # Calculate EEV by evaluating the EVP decision
    eev = evaluate_decision(stochasticprogram, evp_decision)
    # Return EEV
    return eev
end
"""
    EEV(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler)

Approximately calculate the **expected value of the expected value decision** (`EEV`) of the two-stage `stochasticmodel` to the current confidence level, over the scenario distribution induced by `sampler`.

The attribute [`NumEEVSamples`](@ref) is the size of the sampled models used in the eev calculation. The confidence level can be set through the [`Confidence`](@ref) attribute.

If a sample-based optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`EVP`](@ref), [`EV`](@ref)
"""
function EEV(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticmodel.optimizer)
    # Get the instance optimizer
    optimizer = MOI.get(stochasticmodel, InstanceOptimizer())
    # Get parameters
    confidence = MOI.get(stochasticmodel, Confidence())
    N = MOI.get(stochasticmodel, NumSamples())
    # Generate expected value decision
    sp = instantiate(stochasticmodel, sampler, N, optimizer = optimizer)
    x̄ = expected_value_decision(sp)
    # Evaluate expected value decision
    M = MOI.get(stochasticmodel, NumEvalSamples())
    MOI.set(stochasticmodel, NumEvalSamples(), MOI.get(stochasticmodel, NumEEVSamples()))
    eev = evaluate_decision(stochasticmodel, x̄, sampler)
    # Restore NumEvalSamples()
    MOI.set(stochasticmodel, NumEvalSamples(), M)
    # Return EEV
    return eev
end
"""
    VSS(stochasticprogram::TwoStageStochasticProgram)

Calculate the **value of the stochastic solution** (`VSS`) of the two-stage `stochasticprogram`.

In other words, calculate the gap between `EEV` and `VRP`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
"""
function VSS(stochasticprogram::StochasticProgram{2})
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Solve EVP and determine EEV
    eev = EEV(stochasticprogram)
    # Calculate VRP
    vrp = VRP(stochasticprogram)
    # Return VSS = VRP-EEV
    return abs(vrp-eev)
end
"""
    VSS(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler)

Approximately calculate the **value of the stochastic solution** (`VSS`) of the two-stage `stochasticmodel` to the current confidence level, over the scenario distribution induced by `sampler`.

In other words, calculate confidence intervals around `EEV` and `VRP`. If they do not overlap, the VSS is statistically significant, and a confidence interval is calculated and returned. `Ñ` is the number of samples in the out-of-sample evaluation of EEV.

The attribute [`NumSamples`](@ref) is the size of the sampled models used to generate the interval and generally governs how tight it is. The same size is used to generate the expected value decision. The attribute [`NumLowerTrials`](@ref) is the number of sampled models used in the lower bound calculation and the attribute [`NumUpperTrials`](@ref) is the number of sampled models used in the upper bound calculation. The attribute [`NumEvalSamples`](@ref) is the size of the sampled models used in the upper bound calculation and the attribute [`NumEEVSamples`] is the size of the sampled models used in the `EEV` calculation. The confidence level can be set through the [`Confidence`](@ref) attribute.

If a sample-based optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`VRP`](@ref), [`EEV`](@ref), [`EVPI`](@ref)
"""
function VSS(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; confidence::AbstractFloat = 0.95, Ñ::Integer = 1000, tol::AbstractFloat = 1e-1, kw...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticmodel.optimizer)
    # Get parameters
    confidence = MOI.get(stochasticmodel, Confidence())
    # Modify confidence for two-sided interval
    α = (1-confidence)/2
    MOI.set(stochasticmodel, Confidence(), 1 - α)
    # Calculate confidence interval around VRP
    optimize!(stochasticmodel, sampler)
    # Check return status
    status = termination_status(stochasticmodel)
    if status != MOI.OPTIMAL
        error("Stochastic model could not be solved to optimality, returned status $status.")
    end
    vrp = objective_value(stochasticmodel)
    # Calculate confidence interval around EEV
    eev = EEV(stochasticmodel, sampler)
    # Restore confidence level
    MOI.set(stochasticmodel, Confidence(), confidence)
    # Check overlap
    if (upper(eev) >= lower(vrp) + eps() && upper(vrp) >= lower(eev) + eps()) ||
       (lower(eev) <= upper(vrp) - eps() && upper(eev) >= lower(vrp) + eps())
        @warn "VSS is not statistically significant to the chosen confidence level and tolerance"
        # Return confidence interval as tolerance around zero
        tolerance = MOI.get(stochasticmodel, RelativeTolerance())
        return ConfidenceInterval(-tolerance, tolerance, confidence)
    end
    # Switch on sign
    if lower(vrp) >= upper(eev)
        # Return confidence interval around VSS
        return ConfidenceInterval(lower(vrp) - upper(eev), upper(vrp) - lower(eev), confidence)
    else
        # Return confidence interval around VSS
        return ConfidenceInterval(lower(eev) - upper(vrp), upper(eev) - lower(vrp), confidence)
    end
end
# ========================== #
