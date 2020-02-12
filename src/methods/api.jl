# API (Two-stage) #
# ========================== #
"""
    instantiate(stochasticmodel::StochasticModel{2},
                scenarios::Vector{<:AbstractScenario},
                optimizer_constructor = nothing;
                procs::Vector{Int} = workers(),
                float_type::AbstractFloat = Float64,
                kw...)

Instantiate a new two-stage stochastic program using the model definition stored in the two-stage `stochasticmodel`, and the given collection of `scenarios`.
"""
function instantiate(sm::StochasticModel{2},
                     scenarios::Vector{<:AbstractScenario},
                     optimizer_constructor = nothing;
                     procs::Vector{Int} = workers(),
                     float_type::AbstractFloat = Float64,
                     kw...)
    sp = StochasticProgram(parameters(sm.parameters[1]; kw...),
                           parameters(sm.parameters[2]; kw...),
                           float_type,
                           scenarios,
                           procs,
                           optimizer_factory)
    sm.generator(sp)
    return sp
end
"""
    instantiate(stochasticmodel::StochasticModel{2},
                optimizer_constructor = nothing;
                scenariotype::Type{S} = Scenario,
                procs::Vector{Int} = workers(),
                float_type::AbstractFloat = Float64,
                kw...) where S <: AbstractScenario

Instantiate a deferred two-stage stochastic program using the model definition stored in the two-stage `stochasticmodel` over the scenario type `S`.
"""
function instantiate(sm::StochasticModel{2},
                     optimizer_constructor = nothing;
                     scenariotype::Type{S} = Scenario,
                     procs::Vector{Int} = workers(),
                     float_type::AbstractFloat = Float64,
                     kw...) where S <: AbstractScenario
    sp = StochasticProgram(parameters(sm.parameters[1]; kw...),
                           parameters(sm.parameters[2]; kw...),
                           float_type,
                           scenariotype,
                           procs,
                           optimizer_factory)
    sm.generator(sp)
    initialize!(sp)
    return sp
end
"""
    instantiate(stochasticmodel::StochasticModel,
                scenarios::Vector{<:AbstractScenario},
                optimizer_constructor = nothing;
                procs::Vector{Int} = workers(),
                float_type::AbstractFloat = Float64,
                kw...)

Instantiate a new stochastic program using the model definition stored in `stochasticmodel`, and the given collection of `scenarios`.
"""
function instantiate(sm::StochasticModel{N},
                     scenarios::NTuple{M,Vector{<:AbstractScenario}},
                     optimizer_constructor = nothing;
                     procs::Vector{Int} = workers(),
                     float_type::AbstractFloat = Float64,
                     kw...) where {N,M}
    M == N - 1 || error("Inconsistent number of stages $N and number of scenario types $M")
    params = ntuple(Val(N)) do i
        parameters(sm.parameters[i]; kw...)
    end
    sp = StochasticProgram(params,
                           float_type,
                           scenarios,
                           procs,
                           optimizer_factory)
    sm.generator(sp)
    # Initialize model
    initialize!(sp)
    return sp
end
"""
    sample(stochasticmodel::StochasticModel,
           sampler::AbstractSampler,
           n::Integer,
           optimizer_constructor = nothing;
           procs::Vector{Int} = workers(),
           float_type::AbstractFloat = Float64,
           kw...)

Generate a sampled instance of size `n` using the model stored in the two-stage `stochasticmodel`, and the provided `sampler`.

Optionally, a capable `solver` can be supplied to `sample`. Otherwise, any previously set solver will be used.

See also: [`sample!`](@ref)
"""
function sample(sm::StochasticModel{2},
                sampler::AbstractSampler{S},
                n::Integer,
                optimizer_constructor = nothing;
                procs::Vector{Int} = workers(),
                float_type::AbstractFloat = Float64,
                kw...) where S <: AbstractScenario
    # Create new stochastic program instance
    sp = StochasticProgram(parameters(sm.parameters[1]; kw...),
                           parameters(sm.parameters[2]; kw...),
                           float_type,
                           S,
                           procs,
                           optimizer_factory)
    sm.generator(sp)
    # Sample n scenarios
    add_scenarios!(sp, n) do
        return sample(sampler, 1/n)
    end
    # Initialize model
    initialize!(sp)
    # Return the sample instance
    return sp
end
function sample(sm::StochasticModel{2},
                sampler::AbstractSampler{S},
                n::Integer,
                optimizer_constructor = nothing;
                procs::Vector{Int} = workers(),
                float_type::AbstractFloat = Float64,
                kw...) where S <: Scenario
    # Create new stochastic program instance
    sp = StochasticProgram(parameters(sm.parameters[1]; kw...),
                           parameters(sm.parameters[2]; kw...),
                           float_type,
                           typeof(sample(sampler)),
                           procs,
                           optimizer_factory)
    sm.generator(sp)
    # Sample n scenarios
    add_scenarios!(sp, n) do
        return sample(sampler, 1/n)
    end
    # Initialize model
    initialize!(sp)
    # Return the sample instance
    return sp
end
function sample(sm::StochasticModel{2},
                sampler::AbstractSampler{S},
                solution::StochasticSolution,
                optimizer_constructor = nothing;
                procs::Vector{Int} = workers(),
                float_type::AbstractFloat = Float64,
                kw...) where S <: AbstractScenario
    if optimizer_factory == nothing
        error("Cannot generate sample from stochastic solution without an optimizer.")
    end
    n = 16
    CI = confidence_interval(solution)
    α = 1 - confidence(CI)
    while !(confidence_interval(sm, sampler, optimizer_factory; N = n, M = M, confidence = 1-α) ⊆ CI)
        n = n * 2
    end
    return sample(sm, sampler, n, optimizer_factory; float_type = float_type, procs = procs)
end
"""
    optimize!(stochasticprogram::StochasticProgram, optimizer_factory::Union{Nothing, OptimizerFactory};)

Optimize the `stochasticprogram` in expectation using `solver`.

## Examples

The following solves the stochastic program `sp` using the L-shaped algorithm.

```julia
using LShapedSolvers
using GLPKMathProgInterface

optimize!(sp, solver = LShapedSolver(:ls, GLPKSolverLP()));

# output

L-Shaped Gap  Time: 0:00:01 (4 iterations)
  Objective:       -855.8333333333339
  Gap:             0.0
  Number of cuts:  7
:Optimal
```

The following solves the stochastic program `sp` using GLPK on the extended form.

```julia
using GLPKMathProgInterface

optimize!(sp, solver = GLPKSolverLP())

:Optimal
```

See also: [`VRP`](@ref)
"""
function optimize!(stochasticprogram::StochasticProgram{2},
                   optimizer_constructor = nothing;
                   kwargs...)
    if deferred(stochasticprogram)
        generate!(stochasticprogram)
    end
    # Prefer cached optimizer if available
    supplied_optimizer = pick_optimizer(stochasticprogram, optimizer_factory)
    # Abort if no solver was given
    if supplied_optimizer == nothing
        error("Cannot optimize without an optimizer.")
    end
    # Switch on solver type
    return _optimize!(stochasticprogram, supplied_optimizer; kwargs...)
end
function _optimize!(stochasticprogram::StochasticProgram{2}, optimizer::MOI.AbstractOptimizer; kwargs...)
    # Standard mathoptinterface solver. Fallback to solving DEP, relying on JuMP.
    dep = DEP(stochasticprogram; optimizer = optimizer)
    status = solve(dep; kwargs...)
    stochasticprogram.spsolver.internal_model = dep.internalModel
    if status ∈ [:Optimal, :Infeasible, :Unbounded]
        fill_solution!(stochasticprogram)
    end
    return status
end
function _optimize!(stochasticprogram::StochasticProgram{2}, optimizer::AbstractStructuredOptimizer; kwargs...)
    # Use structured optimizer
    structuredmodel = StructuredModel(stochasticprogram, optimizer)
    stochasticprogram.spsolver.internal_model = structuredmodel
    status = optimize_structured!(structuredmodel)
    if status ∈ [:Optimal, :Infeasible, :Unbounded]
        fill_solution!(stochasticprogram, structuredmodel)
    end
    # Now safe to generate the objective value of the stochastic program
    calculate_objective_value!(stochasticprogram)
    return status
end
"""
    optimize!(stochasticmodel::StochasticModel, sampler::AbstractSampler, optimizer_factory::Union{Nothing, OptimizerFactory};, confidence::AbstractFloat = 0.95, kwargs...)

Approximately optimize the `stochasticmodel` using `solver` when the underlying scenario distribution is inferred by `sampler` and return a `StochasticSolution` with the given `confidence` level.

See also: [`StochasticSolution`](@ref)
"""
function optimize!(stochasticmodel::StochasticModel,
                   sampler::AbstractSampler,
                   optimizer_constructor = nothing;
                   confidence::AbstractFloat = 0.95,
                   kwargs...)
    # Abort if no solver was given
    if optimizer_factory == nothing
        error("Cannot optimize without an optimizer.")
    end
    # Switch on solver type
    return _optimize!(stochasticmodel, sampler, optimizer_factory(), confidence; kwargs...)
end
function _optimize!(stochasticmodel::StochasticModel,
                    sampler::AbstractSampler,
                    optimizer::Union{MOI.AbstractOptimizer, AbstractStructuredOptimizer},
                    confidence::AbstractFloat;
                    kwargs...)
    return _optimize!(stochasticmodel, sampler, SAA(optimizer), confidence; kwargs...)
end
function _optimize!(stochasticmodel::StochasticModel,
                    sampler::AbstractSampler,
                    optimizer::AbstractSampledOptimizer,
                    confidence::AbstractFloat;
                    kwargs...)
    sampledmodel = SampledModel(stochasticmodel, optimizer)
    status = optimize_sampled!(sampledmodel, sampler, confidence; kwargs...)
    stochasticmodel.spsolver.internal_model = sampledmodel
    if status != :Optimal
        @warn "Optimal solution not found. Returned status $status"
    end
    return stochastic_solution(sampledmodel)
end
"""
    optimal_decision(stochasticprogram::StochasticProgram)

Return the optimal first stage decision of `stochasticprogram`, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::StochasticProgram)
    decision = get_stage_one(stochasticprogram).colVal
    if any(isnan.(decision))
        @warn "Optimal decision not defined. Check that the model was properly solved."
    end
    return decision
end
"""
    optimal_decision(stochasticprogram::StochasticProgram, var::Symbol)

Return the optimal first stage variable `var` of `stochasticprogram`, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::StochasticProgram, var::Symbol)
    return getvalue(get_stage_one(stochasticprogram).objDict[var])
end
"""
    optimal_decision(stochasticprogram::StochasticProgram, i::Integer)

Return the optimal second stage decision of `stochasticprogram` in the `i`th scenario, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::StochasticProgram, i::Integer)
    submodel = subproblem(stochasticprogram, i)
    decision = submodel.colVal
    if any(isnan.(decision))
        @warn "Optimal decision not defined in subproblem $i. Check that the model was properly solved."
    end
    return decision
end
"""
    optimal_decision(stochasticprogram::StochasticProgram, var::Symbol)

Return the optimal second stage variable `var` of `stochasticprogram` in the `i`th scenario, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::StochasticProgram, i::Integer, var::Symbol)
    submodel = subproblem(stochasticprogram, i)
    return getvalue(submodel.objDict[var])
end
"""
    optimal_value(stochasticprogram::StochasticProgram)

Return the optimal value of `stochasticprogram`, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_value(stochasticprogram::StochasticProgram)
    return get_stage_one(stochasticprogram).objVal
end
"""
    optimal_value(stochasticprogram::StochasticProgram, i::Integer)

Return the optimal value of the `i`th subproblem in `stochasticprogram`, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_value(stochasticprogram::StochasticProgram, i::Integer)
    submodel = subproblem(stochasticprogram, i)
    return submodel.objVal
end
"""
    stage_parameters(stochasticprogram::StochasticProgram, s::Integer)

Return the parameters at stage `s` in `stochasticprogram`.
"""
function stage_parameters(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    return stochasticprogram.stages[s].parameters
end
"""
    decision_variables(stochasticprogram::StochasticProgram, s::Integer)

Return the decision variables of stage `s` in `stochasticprogram`.
"""
function decision_variables(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    s == N && error("The final stage does not have decision variables")
    1 <= s <= N || error("Stage $s not in range 1 to $(N - 1).")
    return stochasticprogram.decision_variables[s]
end
"""
    decision_variables(stochasticprogram::TwoStageStochasticProgram)

Return the decision variables of `stochasticprogram`.
"""
function decision_variables(stochasticprogram::StochasticProgram{2}, s::Integer = 1) where N
    s == 2 && error("The second stage does not have decision variables")
    s == 1 || error("Stage $s not available in two-stage model.")
    return stochasticprogram.decision_variables[s]
end
"""
    scenarioproblems(stochasticprogram::StochasticProgram, s::Integer)

Return the scenario problems at stage `s` in `stochasticprogram`.
"""
function scenarioproblems(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 < s <= N || error("Stage $s not in range 2 to $N.")
    return stochasticprogram.scenarioproblems[s-1]
end
"""
    scenarioproblems(stochasticprogram::TwoStageStochasticProgram)

Return the scenario problems in `stochasticprogram`.
"""
function scenarioproblems(stochasticprogram::StochasticProgram{2}, s::Integer = 2)
    s == 1 && error("Stage 1 does not have scenario problems.")
    s == 2 || error("Stage $s not available in two-stage model.")
    return stochasticprogram.scenarioproblems
end
"""
    decision_length(stochasticprogram::StochasticProgram, s::Integer)

Return the length of the decision at stage `s` in the `stochasticprogram`.
"""
function decision_length(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    if s == 1
        haskey(stochasticprogram.problemcache, :stage_1) || return 0
        return num_variables(stochasticprogram.problemcache[:stage_1])
    end
    nsubproblems(stochasticprogram, s) == 0 && return 0
    return recourse_length(scenarioproblems(stochasticprogram, s))
end
"""
    decision_length(stochasticprogram::TwoStageStochasticProgram)

Return the length of the first-stage decision of the two-stage `stochasticprogram`.
"""
function decision_length(stochasticprogram::StochasticProgram{2})
    return decision_length(stochasticprogram, 1)
end
"""
    first_stage_nconstraints(stochasticprogram::StochasticProgram)

Return the number of constraints in the the first stage of `stochasticprogram`.
"""
function first_stage_nconstraints(stochasticprogram::StochasticProgram)
    !haskey(stochasticprogram.problemcache, :stage_1) && return 0
    first_stage = get_stage_one(stochasticprogram)
    return length(first_stage.linconstr)
end
"""
    first_stage_dims(stochasticprogram::StochasticProgram)

Return a the number of variables and the number of constraints in the the first stage of `stochasticprogram` as a tuple.
"""
function first_stage_dims(stochasticprogram::StochasticProgram)
    !haskey(stochasticprogram.problemcache, :stage_1) && return 0, 0
    first_stage = get_stage_one(stochasticprogram)
    return num_constraints(first_stage), num_variables(first_stage)
end
"""
    recourse_length(stochasticprogram::TwoStageStochasticProgram)

Return the length of the second-stage decision in the two-stage `stochasticprogram`.
"""
function recourse_length(stochasticprogram::StochasticProgram{2})
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Consider @second_stage.")
    nsubproblems(stochasticprogram) == 0 && return 0
    return recourse_length(scenarioproblems(stochasticprogram))
end
"""
    scenario(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)


Return the `i`th scenario of stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function scenario(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)
    return scenario(scenarioproblems(stochasticprogram, s), i)
end
"""
    scenarios(stochasticprogram::StochasticProgram, s::Integer = 2)

Return an array of all scenarios of the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function scenarios(stochasticprogram::StochasticProgram, s::Integer = 2)
    return scenarios(scenarioproblems(stochasticprogram, s))
end
"""
    expected(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the exected scenario of all scenarios of the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function expected(stochasticprogram::StochasticProgram, s::Integer = 2)
    return expected(scenarioproblems(stochasticprogram, s)).scenario
end
"""
    scenariotype(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the type of the scenario structure associated with `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function scenariotype(stochasticprogram::StochasticProgram, s::Integer = 2)
    return scenariotype(scenarioproblems(stochasticprogram, s))
end
"""
    probability(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)

Return the probability of scenario `i`th scenario in the `stochasticprogram` at stage `s` occuring. Defaults to the second stage.
"""
function probability(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)
    return probability(scenario(stochasticprogram, i, s))
end
"""
    stage_probability(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the probability of any scenario in the `stochasticprogram` at stage `s` occuring. A well defined model should return 1. Defaults to the second stage.
"""
function stage_probability(stochasticprogram::StochasticProgram, s::Integer = 2)
    return probability(scenarioproblems(stochasticprogram, s))
end
"""
    has_generator(stochasticprogram::StochasticProgram, key::Symbol)

Return true if a problem generator with `key` exists in `stochasticprogram`.
"""
function has_generator(stochasticprogram::StochasticProgram, key::Symbol)
    return haskey(stochasticprogram.generator, key)
end
"""
    generator(stochasticprogram::StochasticProgram, key::Symbol)

Return the problem generator associated with `key` in `stochasticprogram`.
"""
function generator(stochasticprogram::StochasticProgram, key::Symbol)
    return stochasticprogram.generator[key]
end
"""
    subproblem(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)

Return the `i`th subproblem of the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function subproblem(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)
    return subproblem(scenarioproblems(stochasticprogram, s), i)
end
"""
    subproblems(stochasticprogram::StochasticProgram, s::Integer = 2)

Return an array of all subproblems of the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function subproblems(stochasticprogram::StochasticProgram, s::Integer = 2)
    return subproblems(scenarioproblems(stochasticprogram, s))
end
"""
    nsubproblems(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the number of subproblems in the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function nsubproblems(stochasticprogram::StochasticProgram, s::Integer = 2)
    s == 1 && return 0
    return nsubproblems(scenarioproblems(stochasticprogram, s))
end
"""
    masterterms(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)

Return the first stage terms appearing in scenario `i` in the `stochasticprogram` at stage `s`. Defaults to the second stage.

The master terms are given in sparse format as an array of tuples `(row,col,coeff)` which specify the occurance of master problem variables in the second stage constraints.
"""
function masterterms(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)
    return masterterms(scenarioproblems(stochasticprogram, s), i)
end
"""
    nscenarios(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the number of scenarios in the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function nscenarios(stochasticprogram::StochasticProgram, s::Integer = 2)
    s == 1 && return 0
    return nscenarios(scenarioproblems(stochasticprogram, s))
end
"""
    nstages(stochasticprogram::StochasticProgram)

Return the number of stages in `stochasticprogram`.
"""
nstages(::StochasticProgram{N}) where N = N
"""
    distributed(stochasticprogram::StochasticProgram, s::Integer = 2)

Return true if the `stochasticprogram` is memory distributed at stage `s`. Defaults to the second stage.
"""
distributed(stochasticprogram::StochasticProgram, s::Integer = 2) = distributed(scenarioproblems(stochasticprogram, s))
"""
    deferred(stochasticprogram::StochasticProgram)

Return true if `stochasticprogram` is not fully generated.
"""
deferred(stochasticprogram::StochasticProgram{N}) where N = deferred(stochasticprogram, Val(N))
deferred(stochasticprogram::StochasticProgram, ::Val{1}) = deferred_first_stage(stochasticprogram)
function deferred(stochasticprogram::StochasticProgram, ::Val{N}) where N
    return deferred_stage(stochasticprogram, N) || deferred(stochasticprogram, Val(N-1))
end
deferred_first_stage(stochasticprogram::StochasticProgram) = has_generator(stochasticprogram, :stage_1) && !haskey(stochasticprogram.problemcache, :stage_1)
function deferred_stage(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    s == 1 && return deferred_first_stage(stochasticprogram)
    nsubproblems(stochasticprogram, s) < nscenarios(stochasticprogram, s)
end
"""
        optimizer_constructor(stochasticprogram::StochasticProgram)

    Return any optimizer constructor supplied to the `stochasticprogram`.
    """
function optimizer_constructor(stochasticprogram::StochasticProgram)
    return stochasticprogram.optimizer.optimizer_constructor
end
"""
    provided_optimizer(stochasticprogram::StochasticProgram)

Return the currently provided optimizer type of `stochasticprogram`.
"""
function provided_optimizer(stochasticprogram::StochasticProgram)
    return provided_optimizer(optimizer_constructor(stochasticprogram))
end
"""
    optimizer(stochasticprogram::StochasticProgram)

Return, if any, the optimizer attached to `stochasticprogram`.
"""
function optimizer(stochasticprogram::StochasticProgram)
    _check_provided_optimizer(provided_optimizer(stochasticprogram))
    if deferred(stochasticprogram)
        @warn "The stochastic program is deffered. Consider `initialize!`"
        return nothing
    end
    return stochasticprogram.optimizer.optimizer
end
# ========================== #

# Setters
# ========================== #
"""
    set_sp_optimizer!(stochasticprogram::StochasticProgram, optimizer_factory::OptimizerFactory)

Set the optimizer of the `stochasticprogram`.
"""
function set_sp_optimizer!(stochasticprogram::StochasticProgram, optimizer_factory::OptimizerFactory)
    stochasticprogram.sp_optimizer.sp_optimizer_factory = optimizer_factory
    nothing
end
"""
    add_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario, stage::Integer = 2; defer::Bool = false)

Store the second stage `scenario` in the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called. If the `stochasticprogram` is distributed, the scenario will be defined on the node that currently has the fewest scenarios.
"""
function add_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario, stage::Integer = 2; defer::Bool = false)
    add_scenario!(scenarioproblems(stochasticprogram, stage), scenario)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_worker_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario, w::Integer, stage::Integer = 2; defer::Bool = false)

Store the second stage `scenario` in worker node `w` of the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called.
"""
function add_worker_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario, w::Integer, stage::Integer = 2; defer::Bool = false)
    add_scenario!(scenarioproblems(stochasticprogram, stage), scenario, w)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, stage::Integer = 2; defer::Bool = false)

Store the second stage scenario returned by `scenariogenerator` in the second stage of the `stochasticprogram`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called. If the `stochasticprogram` is distributed, the scenario will be defined on the node that currently has the fewest scenarios.
"""
function add_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, stage::Integer = 2; defer::Bool = false)
    add_scenario!(scenariogenerator, scenarioproblems(stochasticprogram, stage))
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_worker_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, w::Integer, stage::Integer = 2; defer::Bool = false)

Store the second stage scenario returned by `scenariogenerator` in worker node `w` of the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called.
"""
function add_worker_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, w::Integer, stage::Integer = 2; defer::Bool = false)
    add_scenario!(scenariogenerator, scenarioproblems(stochasticprogram, stage), w)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}, stage::Integer = 2; defer::Bool = false)

Store the collection of second stage `scenarios` in the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}, stage::Integer = 2; defer::Bool = false)
    add_scenarios!(scenarioproblems(stochasticprogram, stage), scenarios)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_worker_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}, w::Integer, stage::Integer = 2; defer::Bool = false)

Store the collection of second stage `scenarios` in in worker node `w` of the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called.
"""
function add_worker_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}, w::Integer, stage::Integer = 2; defer::Bool = false)
    add_scenarios!(scenarioproblems(stochasticprogram, stage), scenarios, w)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, n::Integer, stage::Integer = 2; defer::Bool = false)

Generate `n` second-stage scenarios using `scenariogenerator`and store in the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function add_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, n::Integer, stage::Integer = 2; defer::Bool = false)
    add_scenarios!(scenariogenerator, scenarioproblems(stochasticprogram, stage), n)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    add_worker_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, n::Integer, w::Integer, stage::Integer = 2; defer::Bool = false)

Generate `n` second-stage scenarios using `scenariogenerator`and store them in worker node `w` of the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called.
"""
function add_worker_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, n::Integer, w::Integer, stage::Integer = 2; defer::Bool = false)
    add_scenarios!(scenariogenerator, scenarioproblems(stochasticprogram, stage), n, w)
    invalidate_cache!(stochasticprogram)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
"""
    sample!(stochasticprogram::StochasticProgram, sampler::AbstractSampler, n::Integer, stage::Integer = 2; defer::Bool = false)

Sample `n` scenarios using `sampler` and add to the `stochasticprogram` at `stage`. Defaults to the second stage.

If `defer` is true, then model creation is deferred until `generate!(stochasticprogram)` is called. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function sample!(stochasticprogram::StochasticProgram, sampler::AbstractSampler, n::Integer, stage::Integer = 2; defer::Bool = false)
    sample!(scenarioproblems(stochasticprogram, stage), sampler, n)
    if !defer
        generate!(stochasticprogram)
    end
    return stochasticprogram
end
# ========================== #
