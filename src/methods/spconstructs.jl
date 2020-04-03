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
               optimizer)
end
function _WS(stage_one_generator::Function,
             stage_two_generator::Function,
             stage_one_params::Any,
             stage_two_params::Any,
             scenario::AbstractScenario,
             optimizer_constructor)
    ws_model = optimizer_constructor == nothing ? Model() : Model(optimizer_constructor)
    stage_one_generator(ws_model, stage_one_params)
    ws_obj = copy(objective_function(ws_model))
    stage_two_generator(ws_model, stage_two_params, scenario)
    ws_obj += objective_function(ws_model)
    set_objective_function(ws_model, ws_obj)
    return ws_model
end
"""
    WS_decision(stochasticprogram::TwoStageStochasticProgram, scenario::AbstractScenario, optimizer_constructor = nothing)

Calculate the optimizer of the **wait-and-see** (`WS`) model of the two-stage `stochasticprogram`, corresponding to `scenario`.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`WS`](@ref)
"""
function WS_decision(stochasticprogram::StochasticProgram{2}, scenario::AbstractScenario)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    # Solve WS model for supplied scenario
    ws_model = WS(stochasticprogram, scenario, optimizer = moi_optimizer(stochasticprogram))
    JuMP.optimize!(ws_model)
    # Return WS decision
    decision = ws_model.colVal[1:decision_length(stochasticprogram)]
    if any(isnan.(decision))
        warn("Optimal decision not defined. Check that the EVP model was properly solved.")
    end
    return decision
end
"""
    EWS(stochasticprogram::StochasticProgram)

Calculate the **expected wait-and-see result** (`EWS`) of the `stochasticprogram`.

In other words, calculate the expectated result of all possible wait-and-see models, using the provided scenarios in `stochasticprogram`.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`VRP`](@ref), [`WS`](@ref)
"""
function EWS(stochasticprogram::StochasticProgram{2})
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    # Solve all possible WS models and compute EWS
    return _EWS(stochasticprogram)
end
"""
    EWS(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler, optimizer_constructor = nothing; confidence = 0.95, N::Integer = 1000)

Approximately calculate the **expected wait-and-see result** (`EWS`) of the two-stage `stochasticmodel` to the given `confidence` level, over the scenario distribution induced by `sampler`.

Supply a capable `optimizer_factory` to solve the intermediate problems. `N` is the number of scenarios to sample.

See also: [`VRP`](@ref), [`WS`](@ref)
"""
function EWS(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; confidence::AbstractFloat = 0.95, N::Integer)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    # Generate a sample model and statistically evaluate EWS
    sp = sample(stochasticmodel, sampler, N; optimizer = optimizer_constructor(stochasticprogram))
    𝔼WS, σ = _stat_EWS(sp, optimizer_factory)
    z = quantile(Normal(0,1), confidence)
    L = 𝔼WS - z*σ/sqrt(N)
    U = 𝔼WS + z*σ/sqrt(N)
    return ConfidenceInterval(L, U, confidence)
end
function _EWS(stochasticprogram::TwoStageStochasticProgram{T,S,SP}) where {T <: AbstractFloat, S, SP <: ScenarioProblems}
    return sum([begin
                ws = _WS(stochasticprogram.generator[:stage_1],
                         stochasticprogram.generator[:stage_2],
                         stage_parameters(stochasticprogram, 1),
                         stage_parameters(stochasticprogram, 2),
                         scenario,
                         moi_optimizer(stochasticprogram))
                JuMP.optimize!(ws)
                probability(scenario)*objective_value(ws)
                end for scenario in scenarios(stochasticprogram.scenarioproblems)])
end
function _EWS(stochasticprogram::TwoStageStochasticProgram{T,S,SP}) where {T <: AbstractFloat, S, SP <: DScenarioProblems}
    partial_ews = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_ews[i] = remotecall_fetch((sp,stage_one_generator,stage_two_generator,stage_one_params,stage_two_params,optimizer)->begin
                scenarioproblems = fetch(sp)
                isempty(scenarioproblems.scenarios) && return zero(T)
                return sum([begin
                            ws = _WS(stage_one_generator,
                                     stage_two_generator,
                                     stage_one_params,
                                     stage_two_params,
                                     scenario,
                                     optimizer)
                            JuMP.optimize!(ws)
                            probability(scenario)*objective_value(ws)
                            end for scenario in scenarioproblems.scenarios])
                end,
                w,
                stochasticprogram.scenarioproblems[w-1],
                stochasticprogram.generator[:stage_1],
                stochasticprogram.generator[:stage_2],
                stage_parameters(stochasticprogram, 1),
                stage_parameters(stochasticprogram, 2),
                moi_optimizer(stochasticprogram))
        end
    end
    return sum(partial_ews)
end
function _stat_EWS(stochasticprogram::TwoStageStochasticProgram{S,SP}) where {S, SP <: ScenarioProblems}
    ws_models = [WS(stochasticprogram, scenario, moi_optimizer(stochasticprogram)) for senario in scenarios(stochasticprogram)]
    𝔼WS, σ² = welford(ws_models)
    return 𝔼WS, sqrt(σ²)
end
function _stat_EWS(stochasticprogram::TwoStageStochasticProgram{S,SP}) where {S, SP <: DScenarioProblems}
    partial_welfords = Vector{Tuple{Float64,Float64,Int}}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_welfords[i] = remotecall_fetch((sp,stage_one_generator,stage_two_generator,stage_one_params,stage_two_params,optimizer)->begin
                scenarioproblems = fetch(sp)
                isempty(scenarioproblems.scenarios) && return zero(eltype(x)), zero(eltype(x))
                ws_models = [_WS(stage_one_generator,
                                 stage_two_generator,
                                 stage_one_params,
                                 stage_two_params,
                                 scenario,
                                 optimizer) for scenario in scenarioproblems.scenarios]
                return (welford(ws_models)..., length(scenarioproblems.scenarios))
            end,
            w,
            stochasticprogram.scenarioproblems[w-1],
            stochasticprogram.generator[:stage_1_vars],
            stochasticprogram.generator[:stage_2],
            stage_parameters(stochasticprogram, 1),
            stage_parameters(stochasticprogram, 2),
            moi_optimizer(stochasticprogram))
        end
    end
    𝔼WS, σ², _ = reduce(aggregate_welford, partial_welfords)
    return 𝔼WS, sqrt(σ²)
end
"""
    DEP(stochasticprogram::TwoStageStochasticProgram; optimizer = nothing)

Generate the **deterministically equivalent problem** (`DEP`) of the two-stage `stochasticprogram`, unless a cached version already exists.

In other words, generate the extended form the `stochasticprogram` as a single JuMP model. Optionally, a capable `optimizer` can be supplied to `DEP`.

See also: [`VRP`](@ref), [`WS`](@ref)
"""
function DEP(stochasticprogram::StochasticProgram{2}; optimizer = nothing)
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
    dep = optimizer == nothing ? Model() : Model(optimizer)
    _generate_deterministic_equivalent!(stochasticprogram, dep)
    cache[:dep] = dep
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
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    # Solve DEP
    optimize!(stochasticprogram)
    # Return optimal value
    return optimal_value(stochasticprogram)
end
"""
    VRP(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; confidence = 0.95)

Return a confidence interval around the **value of the recouse problem** (`VRP`) of `stochasticmodel` to the given `confidence` level.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`EVPI`](@ref), [`VSS`](@ref), [`EWS`](@ref)
"""
function VRP(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; confidence::AbstractFloat = 0.95)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticmodel))
    # Optimize stochastic model using sample-based method
    ss = optimize!(stochasticmodel, sampler; confidence = confidence)
    return confidence_interval(ss)
end
"""
    EVPI(stochasticprogram::TwoStageStochasticProgram)

Calculate the **expected value of perfect information** (`EVPI`) of the two-stage `stochasticprogram`.

In other words, calculate the gap between `VRP` and `EWS`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`VRP`](@ref), [`EWS`](@ref), [`VSS`](@ref)
"""
function EVPI(stochasticprogram::StochasticProgram{2})
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    # Calculate VRP
    vrp = VRP(stochasticprogram)
    # Solve all possible WS models and calculate EWS
    ews = _EWS(stochasticprogram)
    # Return EVPI = EWS-VRP
    return abs(ews-vrp)
end
"""
    EVPI(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; confidence = 0.95)

Approximately calculate the **expected value of perfect information** (`EVPI`) of the two-stage `stochasticmodel` to the given `confidence` level, over the scenario distribution induced by `sampler`.

In other words, calculate confidence intervals around `VRP` and `EWS`. If they do not overlap, the EVPI is statistically significant, and a confidence interval is calculated and returned. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`VRP`](@ref), [`EWS`](@ref), [`VSS`](@ref)
"""
function EVPI(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; confidence::AbstractFloat = 0.95, tol::AbstractFloat = 1e-1, kwargs...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticmodel))
    # Condidence level
    α = (1-confidence)/2
    # Calculate confidence interval around VRP
    ss = optimize!(stochasticmodel, sampler; confidence = 1-α, tol = tol, kwargs...)
    vrp = confidence_interval(ss)
    # EWS solution of the corresponding size
    ews = EWS(stochasticmodel, sampler; confidence = 1-α, N = ss.N)
    try
        evpi = ConfidenceInterval(lower(ews) - upper(vrp), upper(ews) - lower(vrp), confidence)
        lower(evpi) >= -tol || error()
        return evpi
    catch
        @warn "EVPI is not statistically significant to the chosen confidence level and tolerance"
        return ConfidenceInterval(-Inf, Inf, 1.0)
    end
end
"""
    EVP(stochasticprogram::TwoStageStochasticProgram; optimizer = nothing)

Generate the **expected value problem** (`EVP`) of the two-stage `stochasticprogram`.

In other words, generate a wait-and-see model corresponding to the expected scenario over all available scenarios in `stochasticprogram`. Optionally, a capable `optimizer` can be supplied to `WS`.

See also: [`EVP_decision`](@ref), [`EEV`](@ref), [`EV`](@ref), [`WS`](@ref)
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
    ev_model = WS(stochasticprogram, expected(stochasticprogram), optimizer = optimizer)
    # Cache EVP
    cache[:evp] = ev_model
    # Return EVP
    return ev_model
end
"""
    EVP_decision(stochasticprogram::TwoStageStochasticProgram)

Calculate the optimizer of the `EVP` of the two-stage `stochasticprogram`.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`EVP`](@ref), [`EV`](@ref), [`EEV`](@ref)
"""
function EVP_decision(stochasticprogram::StochasticProgram{2})
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    # Solve EVP
    evp = EVP(stochasticprogram, optimizer = moi_optimizer(stochasticprogram))
    JuMP.optimize!(evp)
    # Return EVP decision
    decision = extract_decision_variables(evp, decision_variables(stochasticprogram, 1))
    if any(isnan.(decision))
        warn("Optimal decision not defined. Check that the EVP model was properly solved.")
    end
    return decision
end
"""
    EV(stochasticprogram::TwoStageStochasticProgram)

Calculate the optimal value of the `EVP` of the two-stage `stochasticprogram`.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`EVP`](@ref), [`EVP_decision`](@ref), [`EEV`](@ref)
"""
function EV(stochasticprogram::StochasticProgram{2})
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    # Solve EVP model
    evp = EVP(stochasticprogram, optimizer = moi_optimizer(stochasticprogram))
    JuMP.optimize!(evp)
    # Return optimal value
    return getobjectivevalue(evp)
end
"""
    EEV(stochasticprogram::TwoStageStochasticProgram)

Calculate the **expected value of the expected value solution** (`EEV`) of the two-stage `stochasticprogram`.

In other words, evaluate the `EVP` decision. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`EVP`](@ref), [`EV`](@ref)
"""
function EEV(stochasticprogram::StochasticProgram{2})
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    # Solve EVP model
    evp_decision = EVP_decision(stochasticprogram)
    # Calculate EEV by evaluating the EVP decision
    eev = evaluate_decision(stochasticprogram, evp_decision)
    # Return EEV
    return eev
end
"""
    EEV(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; confidence = 0.95, N::Integer = 100, Ñ::Integer = 1000)

Approximately calculate the **expected value of the expected value decision** (`EEV`) of the two-stage `stochasticmodel` to the given `confidence` level, over the scenario distribution induced by `sampler`.

`N` is the number of scenarios to sample in order to determine the EVP decision and `Ñ` is the number of samples in the out-of-sample evaluation of the EVP decision.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`EVP`](@ref), [`EV`](@ref)
"""
function EEV(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; confidence::AbstractFloat = 0.95, N::Integer = 100, Ñ::Integer = 1000)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    sp = sample(stochasticmodel, sampler, N)
    x̄ = EVP_decision(sp, optimizer_factory)
    return evaluate_decision(stochasticmodel, x̄, sampler, optimizer_factory; confidence = confidence, Ñ = Ñ)
end
"""
    VSS(stochasticprogram::TwoStageStochasticProgram)

Calculate the **value of the stochastic solution** (`VSS`) of the two-stage `stochasticprogram`.

In other words, calculate the gap between `EEV` and `VRP`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
"""
function VSS(stochasticprogram::StochasticProgram{2})
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    # Solve EVP and determine EEV
    eev = EEV(stochasticprogram)
    # Calculate VRP
    vrp = VRP(stochasticprogram)
    # Return VSS = VRP-EEV
    return abs(vrp-eev)
end
"""
    VSS(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; confidence = 0.95, Ñ::Integer = 1000)

Approximately calculate the **value of the stochastic solution** (`VSS`) of the two-stage `stochasticmodel` to the given `confidence` level, over the scenario distribution induced by `sampler`.

In other words, calculate confidence intervals around `EEV` and `VRP`. If they do not overlap, the VSS is statistically significant, and a confidence interval is calculated and returned. `Ñ` is the number of samples in the out-of-sample evaluation of EEV.

If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`VRP`](@ref), [`EEV`](@ref), [`EVPI`](@ref)
"""
function VSS(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; confidence::AbstractFloat = 0.95, Ñ::Integer = 1000, tol::AbstractFloat = 1e-1, kwargs...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    # Condidence level
    α = (1-confidence)/2
    # Calculate confidence interval around VRP
    ss = optimize!(stochasticmodel, sampler; confidence = 1-α, Ñ = Ñ, tol = tol, kwargs...)
    vrp = confidence_interval(ss)
    # Calculate confidence interval around EEV
    eev = EEV(stochasticmodel, sampler; confidence = 1-α, N = ss.N, Ñ = Ñ)
    try
        vss = ConfidenceInterval(lower(vrp) - upper(eev), upper(vrp) - lower(eev), confidence)
        lower(vss) >= -tol || error()
        return vss
    catch
        @warn "VSS is not statistically significant to the chosen confidence level and tolerance"
        return ConfidenceInterval(-Inf, Inf, 1.0)
    end
end
# ========================== #
