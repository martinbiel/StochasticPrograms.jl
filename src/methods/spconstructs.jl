# SP Constructs #
# ========================== #
"""
    WS(stochasticprogram::TwoStageStochasticProgram, scenario::AbstractScenarioaData, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing)

Generate a **wait-and-see** (`WS`) model of the two-stage `stochasticprogram`, corresponding to `scenario`.

In other words, generate the first stage and the second stage of the `stochasticprogram` as if `scenario` is known to occur. Optionally, a capable `optimizer_factory` can be supplied to `WS`. Otherwise, any previously set optimizer will be used.

See also: [`DEP`](@ref), [`EVP`](@ref)
"""
function WS(stochasticprogram::StochasticProgram{2}, scenario::AbstractScenario, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    # Use cached optimizer if available
    supplied_optimizer = pick_optimizer(stochasticprogram, optimizer_factory)
    # Check that the required generators have been defined
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Consider @stage 2.")
    # Return WS model
    return _WS(generator(stochasticprogram,:stage_1), generator(stochasticprogram,:stage_2), stage_parameters(stochasticprogram, 1), stage_parameters(stochasticprogram, 2), scenario, supplied_solver)
end
function _WS(stage_one_generator::Function,
             stage_two_generator::Function,
             stage_one_params::Any,
             stage_two_params::Any,
             scenario::AbstractScenario,
             optimizer_factory::OptimizerFactory)
    ws_model = optimizer_factory == nothing ? Model() : Model(optimizer_factory)
    stage_one_generator(ws_model, stage_one_params)
    ws_obj = copy(objective_function(ws_model))
    stage_two_generator(ws_model, stage_two_params, scenario, ws_model)
    ws_obj += objective_function(ws_model)
    set_objective_function(ws_model, ws_obj)
    return ws_model
end
"""
    WS_decision(stochasticprogram::TwoStageStochasticProgram, scenario::AbstractScenario, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing)

Calculate the optimizer of the **wait-and-see** (`WS`) model of the two-stage `stochasticprogram`, corresponding to `scenario`.

Optionally, supply a capable `optimizer_factory` to solve the wait-and-see problem. The default behaviour is to rely on any previously set optimizer.

See also: [`WS`](@ref)
"""
function WS_decision(stochasticprogram::StochasticProgram{2}, scenario::AbstractScenario, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    # Use cached optimizer if available
    supplied_optimizer = pick_optimizer(stochasticprogram, optimizer_factory)
    # Abort if no optimizer was given
    if supplied_optimizer == nothing
        error("Cannot compute WS decision without an optimizer.")
    end
    # Solve WS model for supplied scenario
    ws_model = WS(stochasticprogram, scenario, solver = solver)
    solve(ws_model)
    # Return WS decision
    decision = ws_model.colVal[1:decision_length(stochasticprogram)]
    if any(isnan.(decision))
        warn("Optimal decision not defined. Check that the EVP model was properly solved.")
    end
    return decision
end
"""
    EWS(stochasticprogram::StochasticProgram, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing)

Calculate the **expected wait-and-see result** (`EWS`) of the `stochasticprogram`.

In other words, calculate the expectated result of all possible wait-and-see models, using the provided scenarios in `stochasticprogram`. Optionally, a capable `optimizer_factory` can be supplied to solve the intermediate problems. Otherwise, any previously set optimizer will be used.

See also: [`VRP`](@ref), [`WS`](@ref)
"""
function EWS(stochasticprogram::StochasticProgram{2}, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    # Use cached optimizer if available
    supplied_optimizer = pick_optimizer(stochasticprogram, optimizer_factory)
    # Abort if no optimizer was given
    if supplied_optimizer == nothing
        error("Cannot evaluate EWS without an optimizer.")
    end
    # Solve all possible WS models and compute EWS
    return _EWS(stochasticprogram, internal_solver(supplied_solver))
end
"""
    EWS(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing; confidence = 0.95, N::Integer = 1000)

Approximately calculate the **expected wait-and-see result** (`EWS`) of the two-stage `stochasticmodel` to the given `confidence` level, over the scenario distribution induced by `sampler`.

Supply a capable `optimizer_factory` to solve the intermediate problems. `N` is the number of scenarios to sample.

See also: [`VRP`](@ref), [`WS`](@ref)
"""
function EWS(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing; confidence::AbstractFloat = 0.95, N::Integer)
    # Abort if no optimizer was given
    if optimizer_factory == nothing
        error("Cannot evaluate EWS without an optimizer.")
    end
    sp = sample(stochasticmodel, sampler, N)
    𝔼WS, σ = _stat_EWS(sp, optimizer_factory)
    z = quantile(Normal(0,1), confidence)
    L = 𝔼WS - z*σ/sqrt(N)
    U = 𝔼WS + z*σ/sqrt(N)
    return ConfidenceInterval(L, U, confidence)
end
function _EWS(stochasticprogram::TwoStageStochasticProgram{S,SP}, optimizer_factory::OptimizerFactory) where {S, SP <: ScenarioProblems}
    return sum([begin
                ws = _WS(stochasticprogram.generator[:stage_1],
                         stochasticprogram.generator[:stage_2],
                         stage_parameters(stochasticprogram, 1),
                         stage_parameters(stochasticprogram, 2),
                         scenario,
                         optimizer_factory)
                optimize!(ws)
                probability(scenario)*getobjectivevalue(ws)
                end for scenario in scenarios(stochasticprogram.scenarioproblems)])
end
function _EWS(stochasticprogram::TwoStageStochasticProgram{S,SP}, optimizer_factory::OptimizerFactory) where {S, SP <: DScenarioProblems}
    partial_ews = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_ews[i] = remotecall_fetch((sp,stage_one_generator,stage_two_generator,stage_one_params,stage_two_params,optimizer_factory)->begin
                scenarioproblems = fetch(sp)
                isempty(scenarioproblems.scenarios) && return 0.0
                return sum([begin
                            ws = _WS(stage_one_generator,
                                     stage_two_generator,
                                     stage_one_params,
                                     stage_two_params,
                                     scenario,
                                     optimizer_factory)
                            optimize!(ws)
                            probability(scenario)*getobjectivevalue(ws)
                            end for scenario in scenarioproblems.scenarios])
                end,
                w,
                stochasticprogram.scenarioproblems[w-1],
                stochasticprogram.generator[:stage_1],
                stochasticprogram.generator[:stage_2],
                stage_parameters(stochasticprogram, 1),
                stage_parameters(stochasticprogram, 2),
                optimizer_factory)
        end
    end
    return sum(partial_ews)
end
function _stat_EWS(stochasticprogram::TwoStageStochasticProgram{S,SP},
                   optimizer_factory::OptimizerFactory) where {S, SP <: ScenarioProblems}
    ws_generator = scenario -> WS(stochasticprogram, scenario, optimizer_factory)
    𝔼WS, σ² = welford(ws_generator, scenarios(stochasticprogram))
    return 𝔼WS, sqrt(σ²)
end
function _stat_EWS(stochasticprogram::TwoStageStochasticProgram{S,SP},
                        solver::MOI.AbstractOptimizer) where {S, SP <: DScenarioProblems}
    partial_welfords = Vector{Tuple{Float64,Float64,Int}}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_welfords[i] = remotecall_fetch((sp,stage_one_generator,stage_two_generator,stage_one_params,stage_two_params,solver)->begin
                scenarioproblems = fetch(sp)
                isempty(scenarioproblems.scenarios) && return zero(eltype(x)), zero(eltype(x))
                ws_generator = scenario -> _WS(stage_one_generator,
                                               stage_two_generator,
                                               stage_one_params,
                                               stage_two_params,
                                               scenario;
                                               solver = solver)
                return (welford(ws_generator, scenarioproblems.scenarios)..., length(scenarioproblems.scenarios))
            end,
            w,
            stochasticprogram.scenarioproblems[w-1],
            stochasticprogram.generator[:stage_1_vars],
            stochasticprogram.generator[:stage_2],
            stage_parameters(stochasticprogram, 1),
            stage_parameters(stochasticprogram, 2),
            solver)
        end
    end
    𝔼WS, σ², _ = reduce(aggregate_welford, partial_welfords)
    return 𝔼WS, sqrt(σ²)
end
"""
    DEP(stochasticprogram::TwoStageStochasticProgram, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing)

Generate the **deterministically equivalent problem** (`DEP`) of the two-stage `stochasticprogram`.

In other words, generate the extended form the `stochasticprogram` as a single JuMP model. Optionally, a capable `optimizer_factory` can be supplied to `DEP`. Otherwise, any previously set optimizer will be used.

See also: [`VRP`](@ref), [`WS`](@ref)
"""
function DEP(stochasticprogram::StochasticProgram{2}, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    # Use cached optimizer if available
    supplied_optimizer = pick_optimizer(stochasticprogram, optimizer_factory)
    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:dep)
        dep = cache[:dep]
        return dep
    end
    # Check that the required generators have been defined
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Consider @stage 2.")
    # Define first-stage problem
    dep_model = Model()
    generator(stochasticprogram, :stage_1)(dep_model, stage_parameters(stochasticprogram, 1))
    dep_obj = objective_function(dep_model)
    # Define second-stage problems, renaming variables according to scenario.
    stage_two_params = stage_parameters(stochasticprogram, 2)
    visited_objs = collect(keys(object_dictionary(dep_model)))
    for (i, scenario) in enumerate(scenarios(stochasticprogram))
        generator(stochasticprogram,:stage_2)(dep_model, stage_two_params, scenario, dep_model)
        dep_obj += probability(scenario)*objective_function(dep_model)
        for (objkey,obj) ∈ filter(kv->kv.first ∉ visited_objs, object_dictionary(dep_model))
            newkey = if isa(obj, VariableRef)
                varname = add_subscript(name(obj), i)
                set_name(obj, varname)
                newkey = Symbol(varname)
            elseif isa(obj, AbstractArray{<:VariableRef})
                arrayname = add_subscript(objkey, i)
                for var in obj
                    splitname = split(name(var), "[")
                    varname = @sprintf("%s[%s", add_subscript(splitname[1],i), splitname[2])
                    set_name(var, varname)
                end
                newkey = Symbol(arrayname)
            elseif isa(obj,JuMP.ConstraintRef)
                arrayname = add_subscript(objkey, i)
                newkey = Symbol(arrayname)
            elseif isa(obj, AbstractArray{<:ConstraintRef})
                arrayname = add_subscript(objkey, i)
                newkey = Symbol(arrayname)
            else
                continue
            end
            dep_model.obj_dict[newkey] = obj
            delete!(dep_model.obj_dict, objkey)
            push!(visited_objs, newkey)
        end
    end
    set_objective_function(dep_model, dep_obj)
    # Cache DEP
    cache[:dep] = dep_model
    # Return DEP
    return dep_model
end
"""
    VRP(stochasticprogram::StochasticProgram, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing)

Calculate the **value of the recouse problem** (`VRP`) in `stochasticprogram`.

In other words, optimize the stochastic program and return the optimal value. Optionally, supply a capable `optimizer_factory` to optimize the stochastic program. Otherwise, any previously set optimizer will be used.

See also: [`EVPI`](@ref), [`EWS`](@ref)
"""
function VRP(stochasticprogram::StochasticProgram, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    # Use cached optimizer if available
    supplied_optimizer = pick_optimizer(stochasticprogram, optimizer_factory)
    # Abort if no optimizer was given
    if supplied_optimizer == nothing
        error("Cannot evaluate decision without an optimizer.")
    end
    # Solve DEP
    optimize!(stochasticprogram, supplied_optimizer)
    # Return optimal value
    return optimal_value(stochasticprogram)
end
"""
    VRP(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing; confidence = 0.95)

Return a confidence interval around the **value of the recouse problem** (`VRP`) of `stochasticmodel` to the given `confidence` level.

Optionally, supply a capable `optimizer_factory` to optimize the stochastic program. Otherwise, any previously set optimizer will be used.

See also: [`EVPI`](@ref), [`VSS`](@ref), [`EWS`](@ref)
"""
function VRP(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing; confidence::AbstractFloat = 0.95)
    # Abort if no optimizer was given
    if optimizer_factory == nothing
        error("Cannot evaluate VRP without an optimizer.")
    end
    ss = optimize!(stochasticmodel, sampler; solver = solver, confidence = confidence)
    return confidence_interval(ss)
end
"""
    EVPI(stochasticprogram::TwoStageStochasticProgram, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing)

Calculate the **expected value of perfect information** (`EVPI`) of the two-stage `stochasticprogram`.

In other words, calculate the gap between `VRP` and `EWS`. Optionally, supply a capable `optimizer_factory` to solve the intermediate problems. Otherwise, any previously set optimizer will be used.

See also: [`VRP`](@ref), [`EWS`](@ref), [`VSS`](@ref)
"""
function EVPI(stochasticprogram::StochasticProgram{2}, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    # Use cached optimizer if available
    supplied_optimizer = pick_optimizer(stochasticprogram, optimizer_factory)
    # Abort if no optimizer was given
    if supplied_optimizer == nothing
        error("Cannot evaluate EVPI without an optimizer.")
    end
    # Calculate VRP
    vrp = VRP(stochasticprogram, solver=supplied_solver)
    # Solve all possible WS models and calculate EWS
    ews = _EWS(stochasticprogram, internal_solver(supplied_solver))
    # Return EVPI = EWS-VRP
    return abs(ews-vrp)
end
"""
    EVPI(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing; confidence = 0.95)

Approximately calculate the **expected value of perfect information** (`EVPI`) of the two-stage `stochasticmodel` to the given `confidence` level, over the scenario distribution induced by `sampler`.

In other words, calculate confidence intervals around `VRP` and `EWS`. If they do not overlap, the EVPI is statistically significant, and a confidence interval is calculated and returned. Optionally, supply a capable `optimizer_factory` to solve the intermediate problems. Otherwise, any previously set optimizer will be used.

See also: [`VRP`](@ref), [`EWS`](@ref), [`VSS`](@ref)
"""
function EVPI(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing; confidence::AbstractFloat = 0.95, tol::AbstractFloat = 1e-1, kwargs...)
    # Abort if no optimizer was given
    if optimizer_factory == nothing
        error("Cannot evaluate EVPI without an optimizer.")
    end
    # Condidence level
    α = (1-confidence)/2
    # Calculate confidence interval around VRP
    ss = optimize!(stochasticmodel, sampler, optimizer_factory; confidence = 1-α, tol = tol, kwargs...)
    vrp = confidence_interval(ss)
    # EWS solution of the corresponding size
    ews = EWS(stochasticmodel, sampler, optimizer_factory; confidence = 1-α, N = ss.N)
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
    EVP(stochasticprogram::TwoStageStochasticProgram, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing)

Generate the **expected value problem** (`EVP`) of the two-stage `stochasticprogram`.

In other words, generate a wait-and-see model corresponding to the expected scenario over all available scenarios in `stochasticprogram`. Optionally, supply a capable `optimizer_factory` to `EVP`. Otherwise, any previously set optimizer will be used.

See also: [`EVP_decision`](@ref), [`EEV`](@ref), [`EV`](@ref), [`WS`](@ref)
"""
function EVP(stochasticprogram::StochasticProgram{2}, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    # Use cached optimizer if available
    supplied_optimizer = pick_optimizer(stochasticprogram, optimizer_factory)
    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:evp)
        evp = cache[:evp]
        setsolver(evp, supplied_solver)
        return evp
    end
    # Create EVP as a wait-and-see model of the expected scenario
    ev_model = WS(stochasticprogram, expected(stochasticprogram), supplied_optimizer)
    # Cache EVP
    cache[:evp] = ev_model
    # Return EVP
    return ev_model
end
"""
    EVP_decision(stochasticprogram::TwoStageStochasticProgram, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing)

Calculate the optimizer of the `EVP` of the two-stage `stochasticprogram`.

Optionally, supply a capable `optimizer_factory` to solve the expected value problem. The default behaviour is to rely on any previously set optimizer.

See also: [`EVP`](@ref), [`EV`](@ref), [`EEV`](@ref)
"""
function EVP_decision(stochasticprogram::StochasticProgram{2}, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    # Use cached optimizer if available
    supplied_optimizer = pick_optimizer(stochasticprogram, optimizer_factory)
    # Abort if no optimizer was given
    if supplied_optimizer == nothing
        error("Cannot comput EVP decision without an optimizer.")
    end
    # Solve EVP
    evp = EVP(stochasticprogram, supplied_optimizer)
    solve(evp)
    # Return EVP decision
    decision = evp.colVal[1:decision_length(stochasticprogram)]
    if any(isnan.(decision))
        warn("Optimal decision not defined. Check that the EVP model was properly solved.")
    end
    return decision
end
"""
    EV(stochasticprogram::TwoStageStochasticProgram, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing)

Calculate the optimal value of the `EVP` of the two-stage `stochasticprogram`.

Optionally, supply a capable `optimizer_factory` to solve the expected value problem. The default behaviour is to rely on any previously set optimizer.

See also: [`EVP`](@ref), [`EVP_decision`](@ref), [`EEV`](@ref)
"""
function EV(stochasticprogram::StochasticProgram{2}, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    # Use cached optimizer if available
    supplied_optimizer = pick_optimizer(stochasticprogram, optimizer_factory)
    # Abort if no optimizer was given
    if supplied_optimizer == nothing
        error("Cannot evaluate EV without an optimizer.")
    end
    # Solve EVP model
    evp = EVP(stochasticprogram, supplied_optimizer)
    solve(evp)
    # Return optimal value
    return getobjectivevalue(evp)
end
"""
    EEV(stochasticprogram::TwoStageStochasticProgram, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing)

Calculate the **expected value of the expected value solution** (`EEV`) of the two-stage `stochasticprogram`.

In other words, evaluate the `EVP` decision. Optionally, supply a capable `optimizer_factory` to solve the intermediate problems. The default behaviour is to rely on any previously set optimizer.

See also: [`EVP`](@ref), [`EV`](@ref)
"""
function EEV(stochasticprogram::StochasticProgram{2}, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    # Use cached optimizer if available
    supplied_optimizer = pick_optimizer(stochasticprogram, optimizer_factory)
    # Abort if no optimizer was given
    if supplied_optimizer == nothing
        error("Cannot evaluate EEV without an optimizer.")
    end
    # Solve EVP model
    evp_decision = EVP_decision(stochasticprogram, supplied_optimizer)
    # Calculate EEV by evaluating the EVP decision
    eev = evaluate_decision(stochasticprogram, evp_decision, supplied_optimizer)
    # Return EEV
    return eev
end
"""
    EEV(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing; confidence = 0.95, N::Integer = 100, Ñ::Integer = 1000)

Approximately calculate the **expected value of the expected value decision** (`EEV`) of the two-stage `stochasticmodel` to the given `confidence` level, over the scenario distribution induced by `sampler`.

Supply a capable `optimizer_factory` to solve the intermediate problems. `N` is the number of scenarios to sample in order to determine the EVP decision and `Ñ` is the number of samples in the out-of-sample evaluation of the EVP decision.

See also: [`EVP`](@ref), [`EV`](@ref)
"""
function EEV(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing; confidence::AbstractFloat = 0.95, N::Integer = 100, Ñ::Integer = 1000)
    # Abort if no optimizer was given
    if optimizer_factory == nothing
        error("Cannot evaluate EEV without an optimizer.")
    end
    sp = sample(stochasticmodel, sampler, N)
    x̄ = EVP_decision(sp, optimizer_factory)
    return evaluate_decision(stochasticmodel, x̄, sampler, optimizer_factory; confidence = confidence, Ñ = Ñ)
end
"""
    VSS(stochasticprogram::TwoStageStochasticProgram, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing)

Calculate the **value of the stochastic solution** (`VSS`) of the two-stage `stochasticprogram`.

In other words, calculate the gap between `EEV` and `VRP`. Optionally, supply a capable `optimizer_factory` to solve the intermediate problems. The default behaviour is to rely on any previously set optimizer.
"""
function VSS(stochasticprogram::StochasticProgram{2}, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing)
    # Use cached optimizer if available
    supplied_optimizer = pick_optimizer(stochasticprogram, optimizer_factory)
    # Abort if no optimizer was given
    if supplied_optimizer == nothing
        error("Cannot evaluate VSS without an optimizer.")
    end
    # Solve EVP and determine EEV
    eev = EEV(stochasticprogram, supplied_optimizer)
    # Calculate VRP
    vrp = VRP(stochasticprogram, supplied_optimizer)
    # Return VSS = VRP-EEV
    return abs(vrp-eev)
end
"""
    VSS(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler, optimizer_factory:::Union{Nothing, OptimizerFactory)} = nothing; confidence = 0.95, Ñ::Integer = 1000)

Approximately calculate the **value of the stochastic solution** (`VSS`) of the two-stage `stochasticmodel` to the given `confidence` level, over the scenario distribution induced by `sampler`.

In other words, calculate confidence intervals around `EEV` and `VRP`. If they do not overlap, the VSS is statistically significant, and a confidence interval is calculated and returned. Optionally, supply a capable `optimizer_factory` to solve the intermediate problems. Otherwise, any previously set optimizer will be used. `Ñ` is the number of samples in the out-of-sample evaluation of EEV.

See also: [`VRP`](@ref), [`EEV`](@ref), [`EVPI`](@ref)
"""
function VSS(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler, optimizer_factory::Union{Nothing, OptimizerFactory} = nothing; confidence::AbstractFloat = 0.95, Ñ::Integer = 1000, tol::AbstractFloat = 1e-1, kwargs...)
    # Abort if no optimizer was given
    if optimizer_factory == nothing
        error("Cannot evaluate VSS without an optimizer.")
    end
    # Condidence level
    α = (1-confidence)/2
    # Calculate confidence interval around VRP
    ss = optimize!(stochasticmodel, sampler, optimizer_factory; confidence = 1-α, Ñ = Ñ, tol = tol, kwargs...)
    vrp = confidence_interval(ss)
    # Calculate confidence interval around EEV
    eev = EEV(stochasticmodel, sampler, optimizer_factory; confidence = 1-α, N = ss.N, Ñ = Ñ)
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
