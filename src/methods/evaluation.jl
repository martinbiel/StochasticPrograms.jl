# Problem evaluation #
# ========================== #
function _eval_first_stage(stochasticprogram::StochasticProgram, x::AbstractVector)
    first_stage = get_stage_one(stochasticprogram)
    return eval_objective(first_stage.obj, x)
end
function _eval_second_stage(stochasticprogram::TwoStageStochasticProgram, x::AbstractVector, scenario::AbstractScenario, solver::MPB.AbstractMathProgSolver)
    outcome = outcome_model(stochasticprogram, x, scenario, solver)
    solve(outcome)
    return probability(scenario)*getobjectivevalue(outcome)
end
function _eval_second_stages(stochasticprogram::TwoStageStochasticProgram{S,SP},
                             x::AbstractVector,
                             solver::MPB.AbstractMathProgSolver) where {S, SP <: ScenarioProblems}
    outcome_generator = scenario -> outcome_model(stochasticprogram, x, scenario; solver = solver)
    return outcome_mean(outcome_generator, scenarios(stochasticprogram))
end
function _eval_second_stages(stochasticprogram::TwoStageStochasticProgram{S,SP},
                             x::AbstractVector,
                             solver::MPB.AbstractMathProgSolver) where {S, SP <: DScenarioProblems}
    Qs = Vector{Float64}(undef, nworkers())
    outcome_generator = scenario -> outcome_model(stochasticprogram, x, scenario; solver = solver)
    @sync begin
        for (i,w) in enumerate(workers())
            @async Qs[i] = remotecall_fetch((sp,outcome_generator)->begin
                scenarioproblems = fetch(sp)
                isempty(scenarioproblems.scenarios) && return 0.0
                return outcome_mean(outcome_generator, scenarioproblems.scenarios)
            end,
            w,
            stochasticprogram.scenarioproblems[w-1],
            outcome_generator)
        end
    end
    return sum(Qs)
end
function _stat_eval_second_stages(stochasticprogram::TwoStageStochasticProgram{S,SP},
                                  x::AbstractVector,
                                  solver::MPB.AbstractMathProgSolver) where {S, SP <: ScenarioProblems}
    N = nscenarios(stochasticprogram)
    outcome_generator = scenario -> outcome_model(stochasticprogram, x, scenario; solver = solver)
    𝔼Q, σ² = outcome_welford(outcome_generator, scenarios(stochasticprogram))
    return 𝔼Q, sqrt(σ²)
end
function _stat_eval_second_stages(stochasticprogram::TwoStageStochasticProgram{S,SP},
                                  x::AbstractVector,
                                  solver::MPB.AbstractMathProgSolver) where {S, SP <: DScenarioProblems}
    N = nscenarios(stochasticprogram)
    partial_welfords = Vector{Tuple{Float64,Float64,Int}}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_welfords[i] = remotecall_fetch((sp,stage_one_generator,stage_two_generator,stage_one_params,stage_two_params,x,solver)->begin
                scenarioproblems = fetch(sp)
                isempty(scenarioproblems.scenarios) && return zero(eltype(x)), zero(eltype(x))
                    outcome_generator = scenario -> begin
                        outcome_model = Model(solver = solver)
                        _outcome_model!(outcome_model,
                                        stage_one_generator,
                                        stage_two_generator,
                                        stage_one_params,
                                        stage_two_params,
                                        x,
                                        scenario)
                        return outcome_model
                   end
                   return (outcome_welford(outcome_generator, scenarioproblems.scenarios)..., length(scenarioproblems.scenarios))
            end,
            w,
            stochasticprogram.scenarioproblems[w-1],
            stochasticprogram.generator[:stage_1_vars],
            stochasticprogram.generator[:stage_2],
            stage_parameters(stochasticprogram, 1),
            stage_parameters(stochasticprogram, 2),
            x,
            solver)
        end
    end
    𝔼Q, σ², _ = reduce(aggregate_welford, partial_welfords)
    return 𝔼Q, sqrt(σ²)
end
function _eval(stochasticprogram::StochasticProgram{2}, x::AbstractVector, solver::MPB.AbstractMathProgSolver)
    xlength = decision_length(stochasticprogram)
    length(x) == xlength || error("Incorrect length of given decision vector, has ", length(x), " should be ", xlength)
    all(.!(isnan.(x))) || error("Given decision vector has NaN elements")
    cᵀx = _eval_first_stage(stochasticprogram, x)
    𝔼Q = _eval_second_stages(stochasticprogram, x, solver)
    return cᵀx+𝔼Q
end
# Mean/variance calculations #
# ========================== #
function outcome_mean(outcome_generator::Function, scenarios::Vector{<:AbstractScenario})
    Qs = zeros(length(scenarios))
    for (i,scenario) in enumerate(scenarios)
        outcome = outcome_generator(scenario)
        status = solve(outcome)
        if status != :Optimal
            error("Outcome model could not be solved, returned status: $status")
        end
        Qs[i] = probability(scenario)*getobjectivevalue(outcome)
    end
    return sum(Qs)
end
function outcome_welford(outcome_generator::Function, scenarios::Vector{<:AbstractScenario})
    Q̄ₖ = 0
    Sₖ = 0
    N = length(scenarios)
    for k = 1:N
        Q̄ₖ₋₁ = Q̄ₖ
        outcome = outcome_generator(scenarios[k])
        status = solve(outcome)
        if status != :Optimal
            error("Outcome model could not be solved, returned status: $status")
        end
        Q = getobjectivevalue(outcome)
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
                      decision::AbstractVector;
                      solver = JuMP.UnsetSolver())

Evaluate the first-stage `decision` in `stochasticprogram`.

In other words, evaluate the first-stage objective at `decision` and solve outcome models of `decision` for every available scenario. Optionally, supply a capable `solver` to solve the outcome models. Otherwise, any previously set solver will be used.
"""
function evaluate_decision(stochasticprogram::StochasticProgram{2}, decision::AbstractVector; solver::SPSolverType = JuMP.UnsetSolver())
    # Use cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Abort if no solver was given
    if isa(supplied_solver, JuMP.UnsetSolver)
        error("Cannot evaluate decision without a solver.")
    end
    return _eval(stochasticprogram, decision, internal_solver(supplied_solver))
end
"""
    evaluate_decision(stochasticprogram::TwoStageStochasticProgram,
                      decision::AbstractVector,
                      scenario::AbstractScenario;
                      solver = JuMP.UnsetSolver())

Evaluate the result of taking the first-stage `decision` if `scenario` is the actual outcome in `stochasticprogram`.
"""
function evaluate_decision(stochasticprogram::StochasticProgram{2},
                           decision::AbstractVector,
                           scenario::AbstractScenario;
                           solver::SPSolverType = JuMP.UnsetSolver())
    # Use cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Abort if no solver was given
    if isa(supplied_solver, JuMP.UnsetSolver)
        error("Cannot evaluate decision without a solver.")
    end
    outcome = outcome_model(stochasticprogram, decision, scenario; solver = solver)
    status = solve(outcome)
    if status == :Optimal
        return _eval_first_stage(stochasticprogram, decision) + getobjectivevalue(outcome)
    end
    error("Outcome model could not be solved, returned status: $status")
end
"""
    evaluate_decision(stochasticmodel::StochasticModel{2},
                      decision::AbstractVector,
                      sampler::AbstractSampler;
                      solver = JuMP.UnsetSolver(),
                      confidence = 0.9,
                      n = 1000,
                      N = 100,
                      M = 10)

Return a statistical estimate of the objective of the two-stage `stochasticmodel` at `decision` in the form of a confidence interval at level `confidence`, when the underlying scenario distribution is inferred by `sampler`.

In other words, evaluate `decision` on an SAA model of size `n`. Generate an upper bound using the sample variance of the evaluation. The lower bound is calculated from the lower bound around the true optimum generated by `confidence_interval`

See also: [`confidence_interval`](@ref)
"""
function evaluate_decision(stochasticmodel::StochasticModel{2},
                           decision::AbstractVector,
                           sampler::AbstractSampler{S};
                           solver::SPSolverType = JuMP.UnsetSolver(),
                           confidence::AbstractFloat = 0.9,
                           n::Integer = 1000,
                           N::Integer = 100,
                           M::Integer = 10,
                           kw...) where S <: AbstractScenario
    eval_model = SAA(stochasticmodel, sampler, n; kw...)
    # Condidence level
    α = (1-confidence)/2
    # Compute confidence interval around true optimum for lower bound
    CI = confidence_interval(stochasticmodel, sampler; solver = solver, confidence = 1-α, N = N, M = M)
    L = lower(CI)
    # Upper bound
    cᵀx = _eval_first_stage(eval_model, decision)
    𝔼Q, σ = _stat_eval_second_stages(eval_model, decision, internal_solver(solver))
    U = cᵀx + 𝔼Q + quantile(Normal(0,1), 1-α)*σ
    return ConfidenceInterval(L, U, confidence)
end
"""
    confidence_interval(stochasticmodel::StochasticModel{2},
                        sampler::AbstractSampler;
                        solver = JuMP.UnsetSolver(),
                        confidence = 0.95,
                        N = 100,
                        M = 10)

Generate a confidence interval around the true optimum of the two-stage `stochasticmodel` at level `confidence`, when the underlying scenario distribution is inferred by `sampler`.

`N` is the size of the SAA models used to generate the interval and generally governs how tight it is. `M` is the amount of SAA samples used.
"""
function confidence_interval(stochasticmodel::StochasticModel{2}, sampler::AbstractSampler; solver::SPSolverType = JuMP.UnsetSolver(), confidence::AbstractFloat = 0.95, N::Integer = 100, M::Integer = 10, kw...)
    # Condidence level
    α = 1-confidence
    # Lower bound
    Qs = Vector{Float64}(undef, M)
    for i = 1:M
        saa = SAA(stochasticmodel, sampler, N; kw...)
        Qs[i] = VRP(saa, solver = solver)
    end
    Q̂ = mean(Qs)
    σ = std(Qs)
    t = quantile(TDist(M-1), 1-α)
    L = Q̂ - t*σ
    U = Q̂ + t*σ
    return ConfidenceInterval(L, U, 1-α)
end
# ========================== #
