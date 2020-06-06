# API (Two-stage) #
# ========================== #
"""
    instantiate(stochasticmodel::StochasticModel{2},
                scenarios::Vector{<:AbstractScenario};
                instantiation::StochasticInstantiation = UnspecifiedInstantiation(),
                optimizer = nothing;
                defer::Bool = false,
                kw...)

Instantiate a new two-stage stochastic program using the model definition stored in the two-stage `stochasticmodel`, and the given collection of `scenarios`.
"""
function instantiate(sm::StochasticModel{2},
                     scenarios::Vector{<:AbstractScenario};
                     instantiation::StochasticInstantiation = UnspecifiedInstantiation(),
                     optimizer = nothing,
                     defer::Bool = false,
                     direct_model::Bool = false,
                     kw...)
    sp = StochasticProgram(parameters(sm.parameters[1]; kw...),
                           parameters(sm.parameters[2]; kw...),
                           scenarios,
                           instantiation,
                           optimizer)
    # Generate model recipes
    sm.generator(sp)
    # Return deterministic equivalent as JuMP model if direct model has been requested
    if direct_model
        optimizer(sp) isa MOI.AbstractOptimizer || error("MOI optimizer required to create direct model.")
        model = direct_model(optimizer_constructor(sp))
        model.ext[:decisions] = IgnoreDecisionS()
        _generate_deterministic_equivalent!(sp, model)
        return model
    end
    # Generate stochastic program if not deferred
    if !defer
        generate!(sp)
    end
    return sp
end
"""
    instantiate(stochasticmodel::StochasticModel{2};
                instantiation::StochasticInstantiation = UnspecifiedInstantiation(),
                optimizer = nothing,
                scenariotype::Type{S} = Scenario,
                defer::Bool = false,
                kw...) where S <: AbstractScenario

Instantiate a deferred two-stage stochastic program using the model definition stored in the two-stage `stochasticmodel` over the scenario type `S`.
"""
function instantiate(sm::StochasticModel{2};
                     instantiation::StochasticInstantiation = UnspecifiedInstantiation(),
                     optimizer = nothing,
                     scenariotype::Type{S} = Scenario,
                     kw...) where S <: AbstractScenario
    sp = StochasticProgram(parameters(sm.parameters[1]; kw...),
                           parameters(sm.parameters[2]; kw...),
                           scenariotype,
                           instantiation,
                           optimizer)
    # Generate model recipes
    sm.generator(sp)
    return sp
end
"""
    instantiate(stochasticmodel::StochasticModel,
                scenarios::Vector{<:AbstractScenario};
                instantiation::StochasticInstantiation = UnspecifiedInstantiation(),
                optimizer = nothing,
                defer::Bool = false,
                kw...)

Instantiate a new stochastic program using the model definition stored in `stochasticmodel`, and the given collection of `scenarios`.
"""
function instantiate(sm::StochasticModel{N},
                     scenarios::NTuple{M,Vector{<:AbstractScenario}};
                     instantiation::StochasticInstantiation = UnspecifiedInstantiation(),
                     optimizer = nothing,
                     defer::Bool = false,
                     kw...) where {N,M}
    M == N - 1 || error("Inconsistent number of stages $N and number of scenario types $M")
    stages = ntuple(Val(N)) do i
        Stage(parameters(sm.parameters[i]; kw...))
    end
    sp = StochasticProgram(stages,
                           scenarios,
                           instantiation,
                           optimizer)
    # Generate model recipes
    sm.generator(sp)
    # Generate stochastic program if not deferred
    if !defer
        generate!(sp)
    end
    return sp
end
"""
    sample(stochasticmodel::StochasticModel,
           sampler::AbstractSampler,
           n::Integer;
           instantiation::StochasticInstantiation = UnspecifiedInstantiation(),
           optimizer = nothing,
           defer::Bool = false,
           kw...)

Generate a sampled instance of size `n` using the model stored in the two-stage `stochasticmodel`, and the provided `sampler`.

Optionally, a capable `optimizer` can be supplied to `sample`. Otherwise, any previously set solver will be used.

See also: [`sample!`](@ref)
"""
function sample(sm::StochasticModel{2},
                sampler::AbstractSampler{S},
                n::Integer;
                instantiation::StochasticInstantiation = UnspecifiedInstantiation(),
                optimizer = nothing,
                defer::Bool = false,
                kw...) where S <: AbstractScenario
    # Create new stochastic program instance
    sp = StochasticProgram(parameters(sm.parameters[1]; kw...),
                           parameters(sm.parameters[2]; kw...),
                           S,
                           instantiation,
                           optimizer)
    # Generate model recipes
    sm.generator(sp)
    # Sample n scenarios
    add_scenarios!(sp, n) do
        return sample(sampler, 1/n)
    end
    # Generate stochastic program if not deferred
    if !defer
        generate!(sp)
    end
    # Return the sample instance
    return sp
end
function sample(sm::StochasticModel{2},
                sampler::AbstractSampler{S},
                solution::StochasticSolution;
                instantiation::StochasticInstantiation = UnspecifiedInstantiation(),
                optimizer = nothing,
                defer::Bool = false,
                kw...) where S <: AbstractScenario
    if optimizer == nothing
        error("Cannot generate sample from stochastic solution without an optimizer.")
    end
    n = 16
    CI = confidence_interval(solution)
    α = 1 - confidence(CI)
    while !(confidence_interval(sm, sampler, optimizer; N = n, M = M, confidence = 1-α) ⊆ CI)
        n = n * 2
    end
    return sample(sm, sampler, n; instantiation = instantiation, optimizer = optimizer, defer = defer, kw...)
end
"""
    optimize!(stochasticprogram::StochasticProgram)

Optimize the `stochasticprogram` in expectation. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

## Examples

The following solves the stochastic program `sp` using the L-shaped algorithm.

```julia
using LShapedSolvers
using GLPKMathProgInterface

set_optimizer!(sp, LShapedOptimizer)
optimize!(sp);

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

set_optimizer!(sp, GLPK.Optimizer)
optimize!(sp)

:Optimal
```

See also: [`VRP`](@ref)
"""
function JuMP.optimize!(stochasticprogram::TwoStageStochasticProgram; crash::AbstractCrash = Crash.None(), kwargs...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Ensure stochastic program has been initialized at this point
    if deferred(stochasticprogram)
        generate!(stochasticprogram)
    end
    # Crash initial decision
    x₀ = crash(stochasticprogram)
    # Switch on solver type
    return optimize!(structure(stochasticprogram), optimizer(stochasticprogram), x₀; kwargs...)
end
function JuMP.termination_status(stochasticprogram::StochasticProgram)
    return MOI.get(stochasticprogram, MOI.TerminationStatus())::MOI.TerminationStatusCode
end
function JuMP.objective_sense(stochasticprogram::StochasticProgram)
    return MOI.get(stochasticprogram, MOI.ObjectiveSense())::MOI.OptimizationSense
end
"""
    optimal_decision(stochasticprogram::StochasticProgram)

Return the optimal first stage decision of `stochasticprogram`, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::TwoStageStochasticProgram)
    if termination_status(stochasticprogram) == MOI.OPTIMIZE_NOT_CALLED
        throw(OptimizeNotCalled())
    end
    return JuMP.value.(all_decision_variables(stochasticprogram))
end
"""
    optimal_recourse_decision(stochasticprogram::TwoStageStochasticProgram, i::Integer)

Return the optimal recourse decision of `stochasticprogram` corresponding to the `i`th scenario, after a call to `optimize!(stochasticprogram)`.
"""
# function optimal_recourse_decision(stochasticprogram::TwoStageStochasticProgram, i::Integer)
#     return _optimal_recourse_decision(stochasticprogram, i, provided_optimizer(stochasticprogram))
# end
# function _optimal_recourse_decision(stochasticprogram::TwoStageStochasticProgram, i::Integer, ::OptimizerProvided)
#     dep = DEP(stochasticprogram)
#     status = termination_status(dep)
#     if status != MOI.OPTIMAL
#         if status == MOI.OPTIMIZE_NOT_CALLED
#             throw(OptimizeNotCalled())
#         elseif status == MOI.INFEASIBLE
#             @warn "Stochastic program is infeasible"
#         elseif status == MOI.DUAL_INFEASIBLE
#             @warn "Stochastic program is unbounded"
#         else
#             error("Stochastic program model could not be solved, returned status: $status")
#         end
#     end
#     temp = copy(decision_variables(stochasticprogram, 2))
#     for (i,dvar) in enumerate(decision_names(temp))
#         temp.names[i] = add_subscript(dvar, i)
#     end
#     decision = extract_decision_variables(dep, temp)
#     decision.names .= decision_names(decision_variables(stochasticprogram, 2))
#     return decision
# end
"""
    optimal_recourse_decision(stochasticprogram::TwoStageStochasticProgram,
                              decision::Union{AbstractVector, DecisionVariables},
                              scenario::AbstractScenario)

Return the optimal recourse decision of `stochasticprogram` corresponding to the given `scenario`, after taking the given `decision`. The supplied `decision` must be of type `AbstractVector` or `DecisionVariables`, and must match the defined decision variables in `stochasticprogram`. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.
"""
# function optimal_recourse_decision(stochasticprogram::TwoStageStochasticProgram,
#                                    decision::Vector{Decision},
#                                    scenario::AbstractScenario)
#     # Sanity checks on given decision vector

#     return optimal_recourse_decision(stochasticprogram, decisions(decision), scenario)
# end
# function optimal_recourse_decision(stochasticprogram::TwoStageStochasticProgram,
#                                    decision::AbstractVector,
#                                    scenario::AbstractScenario)
#     # Throw NoOptimizer error if no recognized optimizer has been provided
#     check_provided_optimizer(stochasticprogram.optimizer)
#     # Sanity checks on given decision vector
#     length(decision) == decision_length(stochasticprogram) || error("Incorrect length of given decision vector, has ", length(decision), " should be ", decision_length(stochasticprogram))
#     all(.!(isnan.(decision))) || error("Given decision vector has NaN elements")
#     # Generate and solve outcome model
#     outcome = outcome_model(stochasticprogram, decision, scenario; optimizer = moi_optimizer(stochasticprogram))
#     optimize!(outcome)
#     status = termination_status(outcome)
#     if status != MOI.OPTIMAL
#         if status == MOI.OPTIMIZE_NOT_CALLED
#             throw(OptimizeNotCalled())
#         elseif status == MOI.INFEASIBLE
#             @warn "Outcome is infeasible"
#         elseif status == MOI.DUAL_INFEASIBLE
#             @warn "Outcome is unbounded"
#         else
#             error("Outcome model could not be solved, returned status: $status")
#         end
#     end
#     decision = extract_decision_variables(outcome, decision_variables(stochasticprogram, 2))
#     return decision
# end
"""
    objective_value(stochasticprogram::StochasticProgram; result::Int = 1)

Return the objective value associated with result index result of the most-recent solution returned by the solver. Returns the value of the recourse problem after a call to `optimize!(stochasticprogram)`, or the result of taking the decision `x` after a call to `evaluate_decision(stochasticprogram, x)`
"""
function JuMP.objective_value(stochasticprogram::StochasticProgram; result::Int = 1)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Switch on termination status
    status = JuMP.termination_status(stochasticprogram)
    if status != MOI.OPTIMAL
        if status == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        elseif status == MOI.INFEASIBLE
            @warn "Stochastic program is infeasible"
            return objective_sense(stochasticprogram) == MOI.MAX_SENSE ? -Inf : Inf
        elseif status == MOI.DUAL_INFEASIBLE
            @warn "Stochastic program is unbounded"
            return objective_sense(stochasticprogram) == MOI.MAX_SENSE ? Inf : -Inf
        else
            error("Stochastic program could not be solved, returned status: $status")
        end
    end
    return return MOI.get(optimizer(stochasticprogram), MOI.ObjectiveValue(result))
end
"""
    optimize!(stochasticmodel::StochasticModel, sampler::AbstractSampler; confidence::AbstractFloat = 0.95, kwargs...)

Approximately optimize the `stochasticmodel` using when the underlying scenario distribution is inferred by `sampler` and return a `StochasticSolution` with the given `confidence` level. If an optimizer has not been set yet (see [`set_optimizer!`](@ref)), a `NoOptimizer` error is thrown.

See also: [`StochasticSolution`](@ref)
"""
# function JuMP.optimize!(stochasticmodel::StochasticModel,
#                         sampler::AbstractSampler;
#                         confidence::AbstractFloat = 0.95,
#                         kwargs...)
#     # Throw NoOptimizer error if no recognized optimizer has been provided
#     check_provided_optimizer(provided_optimizer(stochasticmodel))
#     # Switch on solver type
#     return _optimize!(stochasticmodel, sampler, confidence, provided_optimizer(stochasticmodel); kwargs...)
# end
# function _optimize!(stochasticmodel::StochasticModel,
#                     sampler::AbstractSampler,
#                     confidence::AbstractFloat,
#                     ::Union{OptimizerProvided, StructuredOptimizerProvided};
#                     kwargs...)
#     # Default to SAA algorithm if standard optimizers have been provided
#     stochasticmodel.optimizer.optimizer = SAA()
#     return optimize_sampled!(optimizer(stochasticmodel), stochasticmodel, sampler, confidence; kwargs...)
# end
# function _optimize!(stochasticmodel::StochasticModel,
#                     sampler::AbstractSampler,
#                     confidence::AbstractFloat,
#                     ::SampledOptimizerProvided;
#                     kwargs...)
#     return optimize_sampled!(optimizer(stochasticmodel), stochasticmodel, sampler, confidence; kwargs...)
# end
# function JuMP.termination_status(stochasticmodel::StochasticModel)
#     return _termination_status(stochasticmodel, provided_optimizer(stochasticmodel))
# end
# function _termination_status(stochasticmodel::StochasticModel, ::Union{NoOptimizerProvided, UnrecognizedOptimizerProvided})
#     return MOI.OPTIMIZE_NOT_CALLED
# end
# function _termination_status(stochasticmodel::StochasticModel, ::Union{OptimizerProvided, StructuredOptimizerProvided, SampledOptimizerProvided})
#     return termination_status(optimizer(stochasticmodel))
# end
# """
#     optimal_decision(stochasticmodel::StochasticModel)

# Return the optimal first stage decision of `stochasticmodel`, after a call to `optimize!(stochasticmodel)`.
# """
# function optimal_decision(stochasticmodel::StochasticModel)
#     # Throw NoOptimizer error if no recognized optimizer has been provided
#     check_provided_optimizer(provided_optimizer(stochasticmodel))
#     return optimal_decision(optimizer(stochasticmodel))
# end
# """
#     optimal_value(stochasticmodel::StochasticModel)

# Return the optimal value of `stochasticmodel`, after a call to `optimize!(stochasticmodel)`.
# """
# function optimal_value(stochasticmodel::StochasticModel)
#     # Throw NoOptimizer error if no recognized optimizer has been provided
#     check_provided_optimizer(provided_optimizer(stochasticmodel))
#     return optimal_value(optimizer(stochasticmodel))
# end
"""
    stage_parameters(stochasticprogram::StochasticProgram, s::Integer)

Return the parameters at stage `s` in `stochasticprogram`.
"""
function stage_parameters(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    return stochasticprogram.stages[s].parameters
end
"""
    decision(stochasticprogram::StochasticProgram, index::MOI.VariableIndex)

Return the current value of the first-stage decision at `index` of `stochasticprogram`.
"""
function decision(stochasticprogram::StochasticProgram, index::MOI.VariableIndex)
    return decision(structure(stochasticprogram), index)
end
"""
    decision(stochasticprogram::StochasticProgram)

Return the current first-stage decision values of `stochasticprogram`.
"""
function decision(stochasticprogram::StochasticProgram)
    return JuMP.value(all_decision_variables(stochasticprogram))
end
"""
    all_decision_variables(stochasticprogram::StochasticProgram{N}) where N

Returns a list of all decisions currently in the `stochasticprogram`. The decisions are
ordered by creation time.
"""
function all_decision_variables(stochasticprogram::StochasticProgram)
    return map(all_decisions(structure(stochasticprogram))) do index
        DecisionVariable(stochasticprogram, index)
    end
end
"""
    structure(stochasticprogram::StochasticProgram)

Return the underlying structure of the `stochasticprogram`.
"""
function structure(stochasticprogram::StochasticProgram)
    return stochasticprogram.structure
end
"""
    structure_name(stochasticprogram::StochasticProgram)

Return the name of the underlying structure of the `stochasticprogram`.
"""
function structure_name(stochasticprogram::StochasticProgram)
    return structure_name(structure(stochasticprogram))
end
"""
    num_decisions(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the number of decisions at stage `s` in the `stochasticprogram`.
"""
function num_decisions(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 2 to $N.")
    # There are never any decisions at the final stage
    s == N && return 0
    return num_decisions(structure(stochasticprogram), s)
end
"""
    num_decisions(stochasticprogram::TwoStageStochasticProgram)

Return the number of first-stage decision of `stochasticprogram`.
"""
function num_decisions(stochasticprogram::TwoStageStochasticProgram)
    return num_decisions(stochasticprogram, 1)
end
"""
    first_stage(stochasticprogram::StochasticProgram)

Return the first stage of `stochasticprogram`.
"""
function first_stage(stochasticprogram::StochasticProgram; optimizer = nothing)
    return first_stage(stochasticprogram, structure(stochasticprogram); optimizer = optimizer)
end
function first_stage(stochasticprogram::StochasticProgram, ::AbstractStochasticStructure; optimizer = nothing)
    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache, :stage_1)
        stage_one = cache[:stage_1]
        optimizer != nothing && set_optimizer(stage_one, optimizer)
        return stage_one
    end
    # Check that the required generators have been defined
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    # Generate and cache first stage
    generate_stage_one!(stochasticprogram)
    stage_one = cache[:stage_1]
    optimizer != nothing && set_optimizer(stage_one, optimizer)
    return stage_one
end
"""
    first_stage_nconstraints(stochasticprogram::StochasticProgram)

Return the number of constraints in the the first stage of `stochasticprogram`.
"""
function first_stage_nconstraints(stochasticprogram::StochasticProgram)
    !haskey(stochasticprogram.problemcache, :stage_1) && return 0
    first_stage = get_stage_one(stochasticprogram)
    return num_constraints(first_stage)
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
    scenario(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)

Return the `i`th scenario of stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function scenario(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)
    return scenario(structure(stochasticprogram), i, s)
end
"""
    scenarios(stochasticprogram::StochasticProgram, s::Integer = 2)

Return an array of all scenarios of the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function scenarios(stochasticprogram::StochasticProgram, s::Integer = 2)
    return scenarios(structure(stochasticprogram), s)
end
"""
    expected(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the exected scenario of all scenarios of the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function expected(stochasticprogram::StochasticProgram, s::Integer = 2)
    return expected(structure(stochasticprogram), s)
end
"""
    scenariotype(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the type of the scenario structure associated with `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function scenariotype(stochasticprogram::StochasticProgram, s::Integer = 2)
    return scenariotype(structure(stochasticprogram), s)
end
"""
    probability(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)

Return the probability of scenario `i`th scenario in the `stochasticprogram` at stage `s` occuring. Defaults to the second stage.
"""
function probability(stochasticprogram::StochasticProgram, i::Integer, s::Integer = 2)
    return probability(structure(stochasticprogram), i, s)
end
"""
    stage_probability(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the probability of any scenario in the `stochasticprogram` at stage `s` occuring. A well defined model should return 1. Defaults to the second stage.
"""
function stage_probability(stochasticprogram::StochasticProgram, s::Integer = 2)
    return stage_probability(structure(stochasticprogram), s)
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
    return subproblem(structure(stochasticprogram), s, i)
end
"""
    subproblems(stochasticprogram::StochasticProgram, s::Integer = 2)

Return an array of all subproblems of the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function subproblems(stochasticprogram::StochasticProgram, s::Integer = 2)
    return subproblems(structure(stochasticprogram), s)
end
"""
    num_subproblems(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the number of subproblems in the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function num_subproblems(stochasticprogram::StochasticProgram, s::Integer = 2)
    s == 1 && return 0
    return num_subproblems(structure(stochasticprogram), s)
end
"""
    num_scenarios(stochasticprogram::StochasticProgram, s::Integer = 2)

Return the number of scenarios in the `stochasticprogram` at stage `s`. Defaults to the second stage.
"""
function num_scenarios(stochasticprogram::StochasticProgram, s::Integer = 2)
    s == 1 && return 0
    return num_scenarios(structure(stochasticprogram), s)
end
"""
    num_stages(stochasticprogram::StochasticProgram)

Return the number of stages in `stochasticprogram`.
"""
num_stages(::StochasticProgram{N}) where N = N
"""
    distributed(stochasticprogram::StochasticProgram, s::Integer = 2)

Return true if the `stochasticprogram` is memory distributed at stage `s`. Defaults to the second stage.
"""
distributed(stochasticprogram::StochasticProgram, s::Integer = 2) = distributed(structure(stochasticprogram), s)
"""
    deferred(stochasticprogram::StochasticProgram)

Return true if `stochasticprogram` is not fully generated.
"""
deferred(stochasticprogram::StochasticProgram) = num_scenarios(stochasticprogram) == 0 || deferred(structure(stochasticprogram))
"""
    optimizer_constructor(stochasticmodel::StochasticModel)

Return any optimizer constructor supplied to the `stochasticmodel`.
"""
function optimizer_constructor(stochasticmodel::StochasticModel)
    return stochasticmodel.optimizer.optimizer_constructor
end
"""
    optimizer_constructor(stochasticprogram::StochasticProgram)

Return any optimizer constructor supplied to the `stochasticprogram`.
"""
function optimizer_constructor(stochasticprogram::StochasticProgram)
    return stochasticprogram.optimizer.optimizer_constructor
end
"""
    optimizer_name(stochasticmodel::StochasticModel)

Return the currently provided optimizer type of `stochasticmodel`.
"""
function optimizer_name(stochasticmodel::StochasticModel)
    return optimizer_name(optimizer(stochasticmodel))
end
"""
    optimizer_name(stochasticprogram::StochasticProgram)

Return the currently provided optimizer type of `stochasticprogram`.
"""
function optimizer_name(stochasticprogram::StochasticProgram)
    deferred(stochasticprogram) && return "Uninitialized"
    return optimizer_name(optimizer(stochasticprogram))
end
function optimizer_name(optimizer::MOI.AbstractOptimizer)
    if JuMP.moi_mode(optimizer) != DIRECT && MOIU.state(optimizer) == MOIU.NO_OPTIMIZER
        return "No optimizer attached."
    end
    return JuMP._try_get_solver_name(optimizer)
end
"""
    master_optimizer(stochasticprogram::StochasticProgram)

Return a MOI optimizer using the currently provided optimizer of `stochasticprogram`.
"""
function master_optimizer(stochasticprogram::StochasticProgram)
    return master_optimizer(stochasticprogram.optimizer)
end
"""
    subproblem_optimizer(stochasticprogram::StochasticProgram)

Return a MOI optimizer for solving subproblems using the currently provided optimizer of `stochasticprogram`.
"""
function subproblem_optimizer(stochasticprogram::StochasticProgram)
    return subproblem_optimizer(stochasticprogram.optimizer)
end
"""
    optimizer(stochasticprogram::StochasticProgram)

Return the optimizer attached to `stochasticprogram`.
"""
function optimizer(stochasticprogram::StochasticProgram)
    return stochasticprogram.optimizer.optimizer
end
"""
    optimizer(stochasticmodel::StochasticModel)

Return the optimizer attached to `stochasticmodel`.
"""
function optimizer(stochasticmodel::StochasticModel)
    return stochasticmodel.optimizer.optimizer
end
"""
    get_optimizer_attribute(stochasticprogram::StochasticProgram, name::String)

Return the value associated with the solver-specific attribute named `name`.

See also: [`set_optimizer_attribute!`](@ref), [`set_optimizer_attributes!`](@ref).
"""
function get_optimizer_attribute(stochasticprogram::StochasticProgram, name::String)
    return get_optimizer_attribute(stochasticprogram, MOI.RawParameter(name))
end

"""
    get_optimizer_attribute(
        stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute
    )

Return the value of the solver-specific attribute `attr` in `stochasticprogram`.

See also: [`set_optimizer_attribute!`](@ref), [`set_optimizer_attributes!`](@ref).
"""
function get_optimizer_attribute(
    stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute
)
    return MOI.get(stochasticprogram, attr)
end

# ========================== #

# Setters
# ========================== #
"""
    set_optimizer!(stochasticmodel::StochasticModel, optimizer)

Set the optimizer of the `stochasticmodel`.
"""
function set_optimizer!(stochasticmodel::StochasticModel, optimizer)
    stochasticmodel.optimizer.optimizer_constructor = optimizer
    return nothing
end
"""
    set_optimizer!(stochasticprogram::StochasticProgram, optimizer)

Set the optimizer of the `stochasticprogram`.
"""
function JuMP.set_optimizer(stochasticprogram::StochasticProgram, optimizer)
    set_optimizer!(stochasticprogram.optimizer, optimizer)
    master_opt = master_optimizer(stochasticprogram)
    if master_opt != nothing
        set_master_optimizer!(structure(stochasticprogram), master_opt)
    end
    sub_opt = subproblem_optimizer(stochasticprogram)
    if sub_opt != nothing
        set_subproblem_optimizer!(structure(stochasticprogram), sub_opt)
    end
    return nothing
end
function JuMP.set_optimizer_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, MOI.RawParameter(name), value)
end
function JuMP.set_optimizer_attribute(stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute, value)
    return MOI.set(stochasticprogram, attr, value)
end
function set_optimizer_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_optimizer_attribute(stochasticprogram, name, value)
    end
end
function JuMP.set_silent(stochasticprogram::StochasticProgram)
    return MOI.set(stochasticprogram, MOI.Silent(), true)
end
function JuMP.unset_silent(stochasticprogram::StochasticProgram)
    return MOI.set(stochasticprogram, MOI.Silent(), false)
end
"""
    add_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario, stage::Integer = 2)

Store the second stage `scenario` in the `stochasticprogram` at `stage`. Defaults to the second stage.

If the `stochasticprogram` is distributed, the scenario will be defined on the node that currently has the fewest scenarios.
"""
function add_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario, stage::Integer = 2)
    add_scenario!(structure(stochasticprogram), stage, scenario)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_worker_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario, w::Integer, stage::Integer = 2)

Store the second stage `scenario` in worker node `w` of the `stochasticprogram` at `stage`. Defaults to the second stage.
"""
function add_worker_scenario!(stochasticprogram::StochasticProgram, scenario::AbstractScenario, w::Integer, stage::Integer = 2)
    add_scenario!(structure(stochasticprogram), stage, scenario, w)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, stage::Integer = 2)

Store the second stage scenario returned by `scenariogenerator` in the second stage of the `stochasticprogram`. Defaults to the second stage. If the `stochasticprogram` is distributed, the scenario will be defined on the node that currently has the fewest scenarios.
"""
function add_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, stage::Integer = 2)
    add_scenario!(scenariogenerator, structure(stochasticprogram), stage)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_worker_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, w::Integer, stage::Integer = 2)

Store the second stage scenario returned by `scenariogenerator` in worker node `w` of the `stochasticprogram` at `stage`. Defaults to the second stage.
"""
function add_worker_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, w::Integer, stage::Integer = 2)
    add_scenario!(scenariogenerator, structure(stochasticprogram), stage, w)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}, stage::Integer = 2)

Store the collection of second stage `scenarios` in the `stochasticprogram` at `stage`. Defaults to the second stage. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function add_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}, stage::Integer = 2)
    add_scenarios!(structure(stochasticprogram), scenarios, stage)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_worker_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}, w::Integer, stage::Integer = 2; defer::Bool = false)

Store the collection of second stage `scenarios` in in worker node `w` of the `stochasticprogram` at `stage`. Defaults to the second stage.
"""
function add_worker_scenarios!(stochasticprogram::StochasticProgram, scenarios::Vector{<:AbstractScenario}, w::Integer, stage::Integer = 2)
    add_scenarios!(structure(stochasticprogram), stage, scenarios, w)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, n::Integer, stage::Integer = 2; defer::Bool = false)

Generate `n` second-stage scenarios using `scenariogenerator`and store in the `stochasticprogram` at `stage`. Defaults to the second stage. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function add_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, n::Integer, stage::Integer = 2)
    add_scenarios!(scenariogenerator, structure(stochasticprogram), n, stage)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_worker_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, n::Integer, w::Integer, stage::Integer = 2; defer::Bool = false)

Generate `n` second-stage scenarios using `scenariogenerator`and store them in worker node `w` of the `stochasticprogram` at `stage`. Defaults to the second stage.
"""
function add_worker_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, n::Integer, w::Integer, stage::Integer = 2)
    add_scenarios!(scenariogenerator, structure(stochasticprogram), n, w, stage)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    sample!(stochasticprogram::StochasticProgram, sampler::AbstractSampler, n::Integer, stage::Integer = 2)

Sample `n` scenarios using `sampler` and add to the `stochasticprogram` at `stage`. Defaults to the second stage. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function sample!(stochasticprogram::StochasticProgram, sampler::AbstractSampler, n::Integer, stage::Integer = 2)
    sample!(structure(stochasticprogram), sampler, n, stage)
    return stochasticprogram
end
# ========================== #
