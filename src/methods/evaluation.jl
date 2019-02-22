# Problem evaluation #
# ========================== #
function _eval_first_stage(stochasticprogram::StochasticProgram, x::AbstractVector)
    first_stage = get_stage_one(stochasticprogram)
    return eval_objective(first_stage.obj, x)
end
function _eval_second_stage(stochasticprogram::StochasticProgram, x::AbstractVector, scenario::AbstractScenario, solver::MPB.AbstractMathProgSolver)
    outcome = outcome_model(stochasticprogram, scenario, x, solver)
    solve(outcome)
    return probability(scenario)*getobjectivevalue(outcome)
end
function _eval_second_stages(stochasticprogram::StochasticProgram{D₁,D₂,S,ScenarioProblems{D₂,S}},
                             x::AbstractVector,
                             solver::MPB.AbstractMathProgSolver) where {D₁, D₂, S <: AbstractScenario}
    outcome_generator = scenario -> _outcome_model(stochasticprogram.generator[:stage_1_vars],
                                                   stochasticprogram.generator[:stage_2],
                                                   stochasticprogram.first_stage.data,
                                                   stage_data(stochasticprogram.scenarioproblems),
                                                   scenario,
                                                   x,
                                                   solver)
   return outcome_mean(outcome_generator, scenarios(stochasticprogram))
end
function _eval_second_stages(stochasticprogram::StochasticProgram{D₁,D₂,S,DScenarioProblems{D₂,S}},
                             x::AbstractVector,
                             solver::MPB.AbstractMathProgSolver) where {D₁, D₂, S <: AbstractScenario}
    Qs = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async Qs[i] = remotecall_fetch((sp,stage_one_generator,stage_two_generator,x,first_stage,solver)->begin
                scenarioproblems = fetch(sp)
                isempty(scenarioproblems.scenarios) && return zero(eltype(x))
                outcome_generator = scenario -> _outcome_model(stage_one_generator,
                                                               stage_two_generator,
                                                               first_stage,
                                                               stage_data(scenarioproblems),
                                                               scenario,
                                                               x,
                                                               solver)
                return outcome_mean(outcome_generator, scenarioproblems.scenarios)
            end,
            w,
            stochasticprogram.scenarioproblems[w-1],
            stochasticprogram.generator[:stage_1_vars],
            stochasticprogram.generator[:stage_2],
            x,
            stochasticprogram.first_stage.data,
            solver)
        end
    end
    return sum(Qs)
end
function _stat_eval_second_stages(stochasticprogram::StochasticProgram{D₁,D₂,S,ScenarioProblems{D₂,S}},
                                  x::AbstractVector,
                                  solver::MPB.AbstractMathProgSolver) where {D₁, D₂, S <: AbstractScenario}
    N = nscenarios(stochasticprogram)
    outcome_generator = scenario -> _outcome_model(stochasticprogram.generator[:stage_1_vars],
                                                   stochasticprogram.generator[:stage_2],
                                                   stochasticprogram.first_stage.data,
                                                   stage_data(stochasticprogram.scenarioproblems),
                                                   scenario,
                                                   x,
                                                   solver)
    𝔼Q, σ² = outcome_welford(outcome_generator, scenarios(stochasticprogram))
    return 𝔼Q, sqrt(σ²)
end
function _stat_eval_second_stages(stochasticprogram::StochasticProgram{D₁,D₂,S,DScenarioProblems{D₂,S}},
                                  x::AbstractVector,
                                  solver::MPB.AbstractMathProgSolver) where {D₁, D₂, S <: AbstractScenario}
    N = nscenarios(stochasticprogram)
    partial_welfords = Vector{Tuple{Float64,Float64,Int}}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_welfords[i] = remotecall_fetch((sp,stage_one_generator,stage_two_generator,x,first_stage,solver)->begin
                scenarioproblems = fetch(sp)
                isempty(scenarioproblems.scenarios) && return zero(eltype(x)), zero(eltype(x))
                outcome_generator = scenario -> _outcome_model(stage_one_generator,
                                                               stage_two_generator,
                                                               first_stage,
                                                               stage_data(scenarioproblems),
                                                               scenario,
                                                               x,
                                                               solver)
                return (outcome_welford(outcome_generator, scenarioproblems.scenarios)..., length(scenarioproblems.scenarios))
            end,
            w,
            stochasticprogram.scenarioproblems[w-1],
            stochasticprogram.generator[:stage_1_vars],
            stochasticprogram.generator[:stage_2],
            x,
            stochasticprogram.first_stage.data,
            solver)
        end
    end
    𝔼Q, σ², _ = reduce(aggregate_welford, partial_welfords)
    return 𝔼Q, sqrt(σ²)
end
function _eval(stochasticprogram::StochasticProgram, x::AbstractVector, solver::MPB.AbstractMathProgSolver)
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
    evaluate_decision(stochasticprogram::StochasticProgram,
                      x::AbstractVector;
                      solver = JuMP.UnsetSolver())

Evaluate the first stage decision `x` in `stochasticprogram`.

In other words, evaluate the first stage objective at `x` and solve outcome models of `x` for every available scenario. Optionally, supply a capable `solver` to solve the outcome models. Otherwise, any previously set solver will be used.
"""
function evaluate_decision(stochasticprogram::StochasticProgram, x::AbstractVector; solver::SPSolverType = JuMP.UnsetSolver())
    # Use cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Abort if no solver was given
    if isa(supplied_solver, JuMP.UnsetSolver)
        error("Cannot evaluate decision without a solver.")
    end
    return _eval(stochasticprogram, x, internal_solver(supplied_solver))
end
"""
    evaluate_decision(stochasticprogram::StochasticProgram,
                      scenario::AbstractScenario,
                      x::AbstractVector;
                      solver = JuMP.UnsetSolver())

Evaluate the result of taking the first stage decision `x` if `scenario` is the actual outcome in `stochasticprogram`.
"""
function evaluate_decision(stochasticprogram::StochasticProgram, scenario::AbstractScenario, x::AbstractVector; solver::SPSolverType = JuMP.UnsetSolver())
    # Use cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Abort if no solver was given
    if isa(supplied_solver, JuMP.UnsetSolver)
        error("Cannot evaluate decision without a solver.")
    end
    outcome = _outcome_model(stochasticprogram.generator[:stage_1_vars],
                             stochasticprogram.generator[:stage_2],
                             stochasticprogram.first_stage.data,
                             stage_data(stochasticprogram.scenarioproblems),
                             scenario,
                             x,
                             solver)
    status = solve(outcome)
    if status == :Optimal
        return _eval_first_stage(stochasticprogram, x) + getobjectivevalue(outcome)
    end
    error("Outcome model could not be solved, returned status: $status")
end
"""
    evaluate_decision(stochasticmodel::StochasticModel,
                      x::AbstractVector,
                      sampler::AbstractSampler;
                      solver = JuMP.UnsetSolver(),
                      confidence = 0.95,
                      N = 1000)

Return a statistical estimate of the objective of `stochasticprogram` at `x`, and an upper bound at level `confidence`, when the underlying scenario distribution is inferred by `sampler`.

In other words, evaluate `x` on an SAA model of size `N`. Generate an upper bound using the sample variance of the evaluation.
"""
function evaluate_decision(stochasticmodel::StochasticModel, x::AbstractVector, sampler::AbstractSampler{S}; solver::SPSolverType = JuMP.UnsetSolver(), confidence::AbstractFloat = 0.95, N::Integer = 1000) where {S <: AbstractScenario}
    eval_model = SAA(stochasticmodel, sampler, N)
    # Condidence level
    α = 1-confidence
    # Upper bound
    cᵀx = _eval_first_stage(eval_model, x)
    𝔼Q, σ = _stat_eval_second_stages(eval_model, x, internal_solver(solver))
    U = cᵀx + 𝔼Q + quantile(Normal(0,1), 1-α)*σ

    return cᵀx + 𝔼Q, U
end
"""
    lower_bound(stochasticmodel::StochasticModel,
                sampler::AbstractSampler;
                solver = JuMP.UnsetSolver(),
                confidence = 0.95,
                N = 100,
                M = 10)

Generate a lower bound of the true optimum of `stochasticprogram` at level `confidence`, when the underlying scenario distribution is inferred by `sampler`.

In other words, solve and evaluate `M` SAA models of size `N` to generate a statistic estimate.
"""
function lower_bound(stochasticmodel::StochasticModel, sampler::AbstractSampler{S}; solver::SPSolverType = JuMP.UnsetSolver(), confidence::AbstractFloat = 0.95, N::Integer = 100, M::Integer = 10) where {S <: AbstractScenario}
    # Condidence level
    α = 1-confidence
    # Lower bound
    Qs = Vector{Float64}(undef, M)
    for i = 1:M
        saa = SAA(stochasticmodel, sampler, N)
        Qs[i] = VRP(saa, solver = solver)
    end
    Q̂ = mean(Qs)
    σ² = (1/(M*(M-1)))*sum([(Q-Q̂)^2 for Q in Qs])

    return Q̂ - quantile(TDist(M-1), 1-α)*sqrt(σ²)
end
"""
    confidence_interval(stochasticmodel::StochasticModel,
                        sampler::AbstractSampler;
                        solver = JuMP.UnsetSolver(),
                        confidence = 0.9,
                        N = 100,
                        M = 10)

Generate a confidence interval around the true optimum of `stochasticprogram` at level `confidence`, when the underlying scenario distribution is inferred by `sampler`.

`N` is the size of the SAA models used to generate the interval and generally governs how tight it is. `M` is the amount of samples used to compute the lower bound.
"""
function confidence_interval(stochasticmodel::StochasticModel, sampler::AbstractSampler{S}; solver::SPSolverType = JuMP.UnsetSolver(), confidence::AbstractFloat = 0.9, N::Integer = 100, M::Integer = 10) where {S <: AbstractScenario}
    α = (1-confidence)/2
    L = lower_bound(stochasticmodel, sampler; solver = solver, confidence = 1-α, N = N, M = M)
    saa = SAA(stochasticmodel, sampler, N)
    optimize!(saa, solver = solver)
    x̂ = optimal_decision(saa)
    Q, U = evaluate_decision(stochasticmodel, x̂, sampler; solver = solver, confidence = 1-α)
    return L, U
end
# ========================== #
