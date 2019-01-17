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
    Qs = _second_stage_objectives(stochasticprogram, x, solver)
    return sum([probability(scenario)*Qs[i] for (i,scenario) in enumerate(scenarios(stochasticprogram))])
end
function _eval_second_stages(stochasticprogram::StochasticProgram{D₁,D₂,S,DScenarioProblems{D₂,S}},
                             x::AbstractVector,
                             solver::MPB.AbstractMathProgSolver) where {D₁, D₂, S <: AbstractScenario}
    active_workers = Vector{Future}(undef,nworkers())
    objectives = _second_stage_objectives(stochasticprogram, x, solver)
    for w in workers()
        active_workers[w-1] = remotecall((sp,objectives)->begin
                                         scenarioproblems = fetch(sp)
                                         Qs = fetch(objectives)
                                         isempty(Qs) && return zero(eltype(x))
                                         return sum([probability(scenario)*Qs[i] for (i,scenario) in enumerate(scenarioproblems.scenarios)])
                                         end,
                                         w,
                                         stochasticprogram.scenarioproblems[w-1],
                                         objectives[w-1])
    end
    map(wait, active_workers)
    return sum(fetch.(active_workers))
end
function _stat_eval_second_stages(stochasticprogram::StochasticProgram{D₁,D₂,S,ScenarioProblems{D₂,S}},
                                  x::AbstractVector,
                                  solver::MPB.AbstractMathProgSolver) where {D₁, D₂, S <: AbstractScenario}
    N = nscenarios(stochasticprogram)
    Qs = _second_stage_objectives(stochasticprogram, x, solver)
    𝔼Q = sum([probability(scenario)*Qs[i] for (i,scenario) in enumerate(scenarios(stochasticprogram))])
    σ² = (1/(N*(N-1)))*sum([(Q-𝔼Q)^2 for Q in Qs])
    return 𝔼Q, sqrt(σ²)
end
function _stat_eval_second_stages(stochasticprogram::StochasticProgram{D₁,D₂,S,DScenarioProblems{D₂,S}},
                                  x::AbstractVector,
                                  solver::MPB.AbstractMathProgSolver) where {D₁, D₂, S <: AbstractScenario}
    N = nscenarios(stochasticprogram)
    active_workers = Vector{Future}(undef,nworkers())
    objectives = _second_stage_objectives(stochasticprogram, x, solver)
    for w in workers()
        active_workers[w-1] = remotecall((sp,objectives)->begin
                                         scenarioproblems = fetch(sp)
                                         Qs = fetch(objectives)
                                         isempty(scenarioproblems.scenarios) && return zero(eltype(x))
                                         return [probability(scenario)*Qs[i] for (i,scenario) in enumerate(scenarioproblems.scenarios)]
                                         end,
                                         w,
                                         stochasticprogram.scenarioproblems[w-1],
                                         objectives[w-1])
    end
    map(wait, active_workers)
    𝔼Q = sum(fetch.(active_workers))
    for w in workers()
        active_workers[w-1] = remotecall((objectives,𝔼Q)->begin
                                         scenarioproblems = fetch(sp)
                                         Qs = fetch(objectives)
                                         isempty(scenarioproblems.scenarios) && return zero(eltype(x))
                                         return sum([(Q-𝔼Q)^2 for Q in Qs])
                                         end,
                                         w,
                                         objectives[w-1],
                                         𝔼Q)
    end
    map(wait, active_workers)
    σ² = (1/(N*(N-1)))*sum(fetch.(active_workers))
    return 𝔼Q, sqrt(σ²)
end
function _second_stage_objectives(stochasticprogram::StochasticProgram{D₁,D₂,S,ScenarioProblems{D₂,S}},
                                  x::AbstractVector,
                                  solver::MPB.AbstractMathProgSolver) where {D₁, D₂, S <: AbstractScenario}
    return [begin
            outcome = _outcome_model(stochasticprogram.generator[:stage_1_vars],
                                     stochasticprogram.generator[:stage_2],
                                     stochasticprogram.first_stage.data,
                                     stage_data(stochasticprogram.scenarioproblems),
                                     scenario,
                                     x,
                                     solver)
            status = solve(outcome)
            if status != :Optimal
            error("Outcome model could not be solved, returned status: $status")
            end
            getobjectivevalue(outcome)
            end for scenario in scenarios(stochasticprogram.scenarioproblems)]
end
function _second_stage_objectives(stochasticprogram::StochasticProgram{D₁,D₂,S,DScenarioProblems{D₂,S}},
                                  x::AbstractVector,
                                  solver::MPB.AbstractMathProgSolver) where {D₁, D₂, S <: AbstractScenario}
    objectives = Vector{Future}(undef,nworkers())
    for w in workers()
        objectives[w-1] = remotecall((sp,stage_one_generator,stage_two_generator,x,first_stage,second_stage,solver)->begin
                                     scenarioproblems = fetch(sp)
                                     isempty(scenarioproblems.scenarios) && return Vector{eltype(x)}()
                                     return [begin
                                             outcome = _outcome_model(stage_one_generator,
                                                                      stage_two_generator,
                                                                      first_stage,
                                                                      second_stage,
                                                                      scenario,
                                                                      x,
                                                                      solver)
                                             status = solve(outcome)
                                             if status != :Optimal
                                             error("Outcome model could not be solved, returned status: $status")
                                             end
                                             getobjectivevalue(outcome)
                                             end for scenario in scenarioproblems.scenarios]
                                     end,
                                     w,
                                     stochasticprogram.scenarioproblems[w-1],
                                     stochasticprogram.generator[:stage_1_vars],
                                     stochasticprogram.generator[:stage_2],
                                     x,
                                     stochasticprogram.first_stage.data,
                                     stage_data(stochasticprogram.scenarioproblems),
                                     solver)
    end
    return objectives
end
function _eval(stochasticprogram::StochasticProgram, x::AbstractVector, solver::MPB.AbstractMathProgSolver)
    xlength = decision_length(stochasticprogram)
    length(x) == xlength || error("Incorrect length of given decision vector, has ", length(x), " should be ", xlength)
    all(.!(isnan.(x))) || error("Given decision vector has NaN elements")
    cᵀx = _eval_first_stage(stochasticprogram, x)
    𝔼Q = _eval_second_stages(stochasticprogram, x, solver)
    return cᵀx+𝔼Q
end
"""
    evaluate_decision(stochasticprogram::StochasticProgram,
                      x::AbstractVector;
                      solver = JuMP.UnsetSolver())

Evaluate the first stage decision `x` in `stochasticprogram`.

In other words, evaluate the first stage objective at `x` and solve outcome models of `x` for every available scenario. Optionally, supply a capable `solver` to solve the outcome models. Otherwise, any previously set solver will be used.
"""
function evaluate_decision(stochasticprogram::StochasticProgram, x::AbstractVector; solver::MPB.AbstractMathProgSolver = JuMP.UnsetSolver())
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
function evaluate_decision(stochasticprogram::StochasticProgram, scenario::AbstractScenario, x::AbstractVector; solver::MPB.AbstractMathProgSolver = JuMP.UnsetSolver())
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
                      confidence = 0.9,
                      N = 1000)

Return a statistical estimate of the objective of `stochasticprogram` at `x`, and an upper bound at level `confidence`, when the underlying scenario distribution is inferred by `sampler`.

In other words, evaluate `x` on an SSA model of size `N`. Generate an upper bound using the sample variance of the evaluation.
"""
function evaluate_decision(stochasticmodel::StochasticModel, x::AbstractVector, sampler::AbstractSampler{S}; solver::MPB.AbstractMathProgSolver = JuMP.UnsetSolver(), confidence::AbstractFloat = 0.95, N::Integer = 1000) where {S <: AbstractScenario}
    eval_model = SSA(stochasticmodel, sampler, N)
    # Condidence level
    α = (1-confidence)/2
    # Upper bound
    cᵀx = _eval_first_stage(eval_model, x)
    𝔼Q, σ = _stat_eval_second_stages(eval_model, x, internal_solver(supplied_solver))
    U = cᵀx + 𝔼Q + quantile(Normal(0,1), 1-α)*σ

    return cᵀx + 𝔼Q, U
end
"""
    lower_bound(stochasticmodel::StochasticModel,
                x::AbstractVector,
                sampler::AbstractSampler;
                solver = JuMP.UnsetSolver(),
                confidence = 0.9,
                N = 100,
                M = 10)

Generate a lower bound of the true optimum of `stochasticprogram` at level `confidence`, when the underlying scenario distribution is inferred by `sampler`.
"""
function lower_bound(stochasticmodel::StochasticModel, sampler::AbstractSampler{S}; solver::MPB.AbstractMathProgSolver = JuMP.UnsetSolver(), confidence::AbstractFloat = 0.95, N::Integer = 100, M::Integer) where {S <: AbstractScenario}
    # Lower bound
    Qs = Vector{Float64}(undef, M)
    for i = 1:M
        ssa = SSA(stochasticmodel, sampler, N)
        Qs[i] = VRP(ssa, solver = supplied_solver)
    end
    Q̂ = mean(Qs)
    σ² = (1/(M*(M-1)))*sum([(Q-Q̂)^2 for Q in Qs])

    return Q̂ - quantile(TDist(M-1), 1-α)*sqrt(σ²)
end
# ========================== #
