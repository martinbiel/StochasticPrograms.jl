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

# API (Two-stage) #
# ========================== #
"""
    instantiate(stochasticmodel::StochasticModel{2},
                scenarios::Vector{<:AbstractScenario};
                instantiation::StochasticInstantiation = UnspecifiedInstantiation(),
                optimizer = nothing;
                defer::Bool = false,
                kw...)

Instantiate a two-stage stochastic program using the model definition stored in the two-stage `stochasticmodel`, and the given collection of `scenarios`. Optionally, supply an `optimizer`. If no explicit `instantiation` is provided, the structure is induced by the optimizer. The structure is `Deterministic` by default.
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
        model.ext[:decisions] = IgnoreDecisions()
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
                scenario_type::Type{S} = Scenario,
                defer::Bool = false,
                kw...) where S <: AbstractScenario

Instantiate a deferred two-stage stochastic program using the model definition stored in the two-stage `stochasticmodel` over the scenario type `S`. Optionally, supply an `optimizer`. If no explicit `instantiation` is provided, the structure is induced by the optimizer. The structure is `Deterministic` by default.
"""
function instantiate(sm::StochasticModel{2};
                     instantiation::StochasticInstantiation = UnspecifiedInstantiation(),
                     optimizer = nothing,
                     scenario_type::Type{S} = Scenario,
                     kw...) where S <: AbstractScenario
    sp = StochasticProgram(parameters(sm.parameters[1]; kw...),
                           parameters(sm.parameters[2]; kw...),
                           scenario_type,
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

Instantiate a stochastic program using the model definition stored in `stochasticmodel`, and the given collection of `scenarios`. Optionally, supply an `optimizer`. If no explicit `instantiation` is provided, the structure is induced by the optimizer. The structure is `Deterministic` by default.
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
    instantiate(stochasticmodel::StochasticModel,
                sampler::AbstractSampler,
                n::Integer;
                instantiation::StochasticInstantiation = UnspecifiedInstantiation(),
                optimizer = nothing,
                defer::Bool = false,
                kw...)

Generate a sampled instance of size `n` using the model stored in the two-stage `stochasticmodel`, and the provided `sampler`. Optionally, supply an `optimizer`. If no explicit `instantiation` is provided, the structure is induced by the optimizer. The structure is `Deterministic` by default.

"""
function instantiate(stochasticmodel::StochasticModel{2},
                     sampler::AbstractSampler{S},
                     n::Integer;
                     instantiation::StochasticInstantiation = UnspecifiedInstantiation(),
                     optimizer = nothing,
                     defer::Bool = false,
                     kw...) where S <: AbstractScenario
    # Create new stochastic program instance
    sp = StochasticProgram(parameters(stochasticmodel.parameters[1]; kw...),
                           parameters(stochasticmodel.parameters[2]; kw...),
                           S,
                           instantiation,
                           optimizer)
    # Generate model recipes
    stochasticmodel.generator(sp)
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
function instantiate(stochasticmodel::StochasticModel{2},
                     sampler::AbstractSampler{Scenario},
                     n::Integer;
                     instantiation::StochasticInstantiation = UnspecifiedInstantiation(),
                     optimizer = nothing,
                     defer::Bool = false,
                     kw...)
    # Get concrete scenario type
    S = typeof(sampler())
    # Create new stochastic program instance
    sp = StochasticProgram(parameters(stochasticmodel.parameters[1]; kw...),
                           parameters(stochasticmodel.parameters[2]; kw...),
                           S,
                           instantiation,
                           optimizer)
    # Generate model recipes
    stochasticmodel.generator(sp)
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
"""
    optimize!(stochasticprogram::StochasticProgram; crash::AbstractCrash = Crash.None(), cache::Bool = false; kw...)

Optimize the `stochasticprogram` in expectation. If an optimizer has not been set yet (see [`set_optimizer`](@ref)), a `NoOptimizer` error is thrown. An optional crash procedure can be set to warm-start. Setting the `cache` flag to true will, upon sucessful termination, try to cache the solution values for all relevant attributes in the model. The values will then persist after future `evaluate` calls that would otherwise overwrite the optimal solution.

## Examples

The following solves the stochastic program `sp` using the L-shaped algorithm.

```julia
set_optimizer(sp, LShaped.Optimizer)
set_optimizer_attribute(sp, MasterOptimizer(), GLPK.Optimizer)
set_optimizer_attribute(sp, SubProblemOptimizer(), GLPK.Optimizer)
optimize!(sp);

# output

L-Shaped Gap  Time: 0:00:02 (6 iterations)
  Objective:       -855.8333333333358
  Gap:             0.0
  Number of cuts:  8
  Iterations:      6
```

The following solves the stochastic program `sp` using GLPK on the extended form.

```julia
using GLPK

set_optimizer(sp, GLPK.Optimizer)
optimize!(sp)

```

See also: [`VRP`](@ref)
"""
function JuMP.optimize!(stochasticprogram::TwoStageStochasticProgram; crash::AbstractCrash = Crash.None(), cache::Bool = false, kw...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Ensure stochastic program has been initialized at this point
    if deferred(stochasticprogram)
        generate!(stochasticprogram)
    end
    # Crash initial decision
    x₀ = crash(stochasticprogram)
    # Switch on structure and solver type
    optimize!(structure(stochasticprogram), optimizer(stochasticprogram), x₀; kw...)
    # Cache solution (if requested)
    if cache
        cache_solution!(stochasticprogram, structure(stochasticprogram), optimizer(stochasticprogram))
    end
    return nothing
end
"""
    cache_solution!(stochasticprogram::StochasticProgram)

Cache the optimal solution, including as many model/variable/constraints attributes as possible, after a call to [`optimize!`](@ref)
"""
function cache_solution!(stochasticprogram::StochasticProgram)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Throw if optimize! has not been called
    if MOI.get(stochasticprogram, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
        throw(OptimizeNotCalled())
    end
    # Defer to structure
    cache_solution!(stochasticprogram, structure(stochasticprogram), optimizer(stochasticprogram))
    return nothing
end
"""
    termination_status(stochasticprogram::StochasticProgram)

Return the reason why the solver of the `stochasticprogram` stopped.
"""
function JuMP.termination_status(stochasticprogram::StochasticProgram)
    return MOI.get(stochasticprogram, MOI.TerminationStatus())::MOI.TerminationStatusCode
end
"""
    termination_status(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)

Return the reason why the solver of the node at stage `stage` and scenario `scenario_index`
stopped.
"""
function JuMP.termination_status(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)
    attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.TerminationStatus())
    return MOI.get(stochasticprogram, attr)::MOI.TerminationStatusCode
end
"""
    termination_status(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer)

Return the reason why the solver of scenario `scenario_index` stopped.
"""
function JuMP.termination_status(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer)
    return terminationstatus(stochasticprogram, 2, scenario_index)
end
"""
    raw_status(stochasticprogram::StochasticProgram)

Return the reason why the solver of the `stochasticprogram` stopped in its own words.
"""
function JuMP.raw_status(stochasticprogram::StochasticProgram)
    return MOI.get(stochasticprogram, MOI.RawStatusString())
end
"""
    raw_status(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)

Return the reason why the solver of the node at stage `stage` and scenario `scenario_index`
stopped in its own words.
"""
function JuMP.raw_status(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)
    attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.RawStatusString())
    return MOI.get(stochasticprogram, attr)
end
"""
    raw_status(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer)

Return the reason why the solver of scenario `scenario_index` stopped in its own words.
"""
function JuMP.raw_status(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer)
    return raw_status(stochasticprogram, 2, scenario_index)
end
"""
    primal_status(stochasticprogram::StochasticProgram; result::Int = 1)

Return the status of the most recent primal solution of the solver of
the `stochasticprogram`.
"""
function JuMP.primal_status(stochasticprogram::StochasticProgram; result::Int = 1)
    return MOI.get(stochasticprogram, MOI.PrimalStatus(result))::MOI.ResultStatusCode
end
"""
    primal_status(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer; result::Int = 1)

Return the status of the most recent primal solution of the solver of
the node at stage `stage` and scenario `scenario_index`.
"""
function JuMP.primal_status(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer; result::Int = 1)
    attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.PrimalStatus(result))
    return MOI.get(stochasticprogram, attr)::MOI.ResultStatusCode
end
"""
    primal_status(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer; result::Int = 1)

Return the status of the most recent primal solution of the solver of
the scenario `scenario_index`.
"""
function JuMP.primal_status(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer; result::Int = 1)
    return primal_status(stochasticprogram, 2, scenario_index; result = result)
end
"""
    dual_status(stochasticprogram::StochasticProgram; result::Int = 1)

Return the status of the most recent dual solution of the solver of
the `stochasticprogram`.
"""
function JuMP.dual_status(stochasticprogram::StochasticProgram; result::Int = 1)
    return MOI.get(stochasticprogram, MOI.DualStatus(result))::MOI.ResultStatusCode
end
"""
    dual_status(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer; result::Int = 1)

Return the status of the most recent dual solution of the solver of
the node at stage `stage` and scenario `scenario_index`.
"""
function JuMP.dual_status(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer; result::Int = 1)
    attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.DualStatus(result))
    return MOI.get(stochasticprogram, attr)::MOI.ResultStatusCode
end
"""
    dual_status(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer; result::Int = 1)

Return the status of the most recent dual solution of the solver of
scenario `scenario_index`.
"""
function JuMP.dual_status(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer; result::Int = 1)
    return dual_status(stochasticprogram, 2, scenario_index; result = result)
end
"""
    solve_time(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)

If available, returns the solve time reported by the solver of
the `stochasticprogram`.
"""
function JuMP.solve_time(stochasticprogram::StochasticProgram)
    return MOI.get(stochasticprogram, MOI.SolveTimeSec())
end
"""
    solve_time(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)

If available, returns the solve time reported by the solver of
the node at stage `stage` and scenario `scenario_index`.
"""
function JuMP.solve_time(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)
    attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.SolveTimeSec())
    return MOI.get(stochasticprogram, attr)
end
"""
    solve_time(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer)

If available, returns the solve time reported by the solver of
scenario `scenario_index`.
"""
function JuMP.solve_time(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer)
    return solve_time(stochasticprogram, 2, scenario_index)
end
"""
    optimal_decision(stochasticprogram::StochasticProgram)

Return the optimal first stage decision of `stochasticprogram`, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::StochasticProgram)
    if termination_status(stochasticprogram) == MOI.OPTIMIZE_NOT_CALLED
        throw(OptimizeNotCalled())
    end
    return JuMP.value.(all_decision_variables(stochasticprogram, 1))
end
"""
    optimal_decision(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)

Return the optimal decision in the node at stage `stage` and scenario `scenario_index`
of `stochasticprogram`, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)
    if termination_status(stochasticprogram, stage, scenario_index) == MOI.OPTIMIZE_NOT_CALLED
        throw(OptimizeNotCalled())
    end
    return JuMP.value.(all_decision_variables(stochasticprogram, stage), scenario_index)
end
"""
    optimal_decision(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer)

Return the optimal decision in scenario `scenario_index` of the two-stage `stochasticprogram`,
after a call to `optimize!(stochasticprogram)`.
"""
function optimal_decision(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer)
    return optimal_decision(stochasticprogram, 2, scenario_index)
end
"""
    optimal_recourse_decision(stochasticprogram::StochasticProgram, scenario_index::Integer)

Return the optimal recourse decision in the final stage of `stochasticprogram` in
the scenario `scenario_index`, after a call to `optimize!(stochasticprogram)`.
"""
function optimal_recourse_decision(stochasticprogram::StochasticProgram{N}, scenario_index::Integer) where N
    return optimal_decision(stochasticprogram, N, scenario_index)
end
"""
    optimize!(stochasticmodel::StochasticModel, sampler::AbstractSampler; crash::AbstractCrash = Crash.None(), kw...)

Approximately optimize the `stochasticmodel` when the underlying scenario distribution is inferred by `sampler`. If an optimizer has not been set yet (see [`set_optimizer`](@ref)), a `NoOptimizer` error is thrown.
"""
function JuMP.optimize!(stochasticmodel::StochasticModel,
                        sampler::AbstractSampler;
                        crash::AbstractCrash = Crash.None(),
                        kw...)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticmodel.optimizer)
    # Crash initial decision
    x₀ = crash(stochasticmodel, sampler)
    # Switch on solver type
    return _optimize!(stochasticmodel, sampler, optimizer(stochasticmodel), x₀; kw...)
end
function _optimize!(stochasticmodel::StochasticModel, sampler::AbstractSampler, optimizer::AbstractSampledOptimizer, x₀; kw...)
    # Load optimizer
    load_model!(optimizer, stochasticmodel, sampler, x₀)
    # Run sample-based optimization procedure
    MOI.optimize!(optimizer)
    return nothing
end
function JuMP.termination_status(stochasticmodel::StochasticModel)
    return MOI.get(stochasticmodel, MOI.TerminationStatus())::MOI.TerminationStatusCode
end
function JuMP.objective_sense(stochasticmodel::StochasticModel)
    return MOI.get(stochasticmodel, MOI.ObjectiveSense())::MOI.OptimizationSense
end
"""
    optimal_decision(stochasticmodel::StochasticModel)

Return the optimal first stage decision of `stochasticmodel`, after a call to `optimize!(stochasticmodel)`.
"""
function optimal_decision(stochasticmodel::StochasticModel)
    if termination_status(stochasticmodel) == MOI.OPTIMIZE_NOT_CALLED
        throw(OptimizeNotCalled())
    end
    return optimal_decision(instance(stochasticmodel))
end
"""
    objective_value(stochasticmodel::StochasticModel; result::Int = 1)

Returns a confidence interval around the value of the recourse problem after a call to `optimize!(stochasticmodel)`.
"""
function JuMP.objective_value(stochasticmodel::StochasticModel; result::Int = 1)
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticmodel.optimizer)
    # Switch on termination status
    status = JuMP.termination_status(stochasticmodel)
    if status in AcceptableTermination
        return MOI.get(stochasticmodel, MOI.ObjectiveValue(result))
    else
        if status == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        elseif status == MOI.INFEASIBLE
            @warn "Stochastic program is infeasible"
            return objective_sense(stochasticmodel) == MOI.MAX_SENSE ? -Inf : Inf
        elseif status == MOI.DUAL_INFEASIBLE
            @warn "Stochastic program is unbounded"
            return objective_sense(stochasticmodel) == MOI.MAX_SENSE ? Inf : -Inf
        else
            @warn("Stochastic program could not be solved, returned status: $status")
            return NaN
        end
    end
end
"""
    stage_parameters(stochasticprogram::StochasticProgram, stage::Integer)

Return the parameters at `stage` in `stochasticprogram`.
"""
function stage_parameters(stochasticprogram::StochasticProgram{N}, stage::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    return stochasticprogram.stages[stage].parameters
end
"""
    decision(stochasticprogram::StochasticProgram, index::MOI.VariableIndex)

Return the current value of the first-stage decision at `index` of `stochasticprogram`.
"""
function decision(stochasticprogram::StochasticProgram, index::MOI.VariableIndex)
    return decision(structure(stochasticprogram), 1, index)
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

Returns a stage-wise list of all decisions currently in the `stochasticprogram`. The decisions are
ordered by creation time. Defaults to the first stage.
"""
function all_decision_variables(stochasticprogram::StochasticProgram{N}) where N
    return ntuple(Val{N}()) do s
        return all_decision_variables(stochasticprogram, s)
    end
end
"""
    all_decision_variables(stochasticprogram::StochasticProgram{N}, stage::Integer = 1) where N

Returns a list of all decisions currently in the `stochasticprogram` at `stage`. The decisions are
ordered by creation time.
"""
function all_decision_variables(stochasticprogram::StochasticProgram{N}, stage::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    decisions = if stage == 1
        all_decisions(stochasticprogram.decisions, 1)
    else
        all_decisions(proxy(stochasticprogram, stage).ext[:decisions], stage)
    end
    return map(decisions) do index
        DecisionVariable(stochasticprogram, stage, index)
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
    proxy(stochasticprogram::StochasticProgram, stage::Integer)

Return the proxy model of the `stochasticprogram` at `stage`.
"""
function proxy(stochasticprogram::StochasticProgram{N}, stage::Integer) where N
    return proxy(structure(stochasticprogram), stage)
end
"""
    Base.getindex(stochasticprogram::StochasticProgram, stage::Integer, name::Symbol)

Returns the decision, or group of decisions, or decision constraint, or group of decision constraints, of the given `name` and `stage` of the `stochasticprogram` which were added to the model. This errors if regular variables or constraints are queried. If so, either annotate the relevant variables with [`@decision`](@ref) or first query the relevant JuMP subproblem and use the regular `[]` syntax.
"""
function Base.getindex(stochasticprogram::StochasticProgram, stage::Integer, name::Symbol)
    obj_dict = object_dictionary(proxy(stochasticprogram, stage))
    if !haskey(obj_dict, name)
        throw(KeyError(name))
    else
        obj = obj_dict[name]
        if obj isa DecisionRef
            return DecisionVariable(stochasticprogram, stage, index(obj))
        elseif obj isa AbstractArray{<:DecisionRef}
            return map(obj) do dvar
                return DecisionVariable(stochasticprogram, stage, index(dvar))
            end
        elseif obj isa ConstraintRef{Model, <:CI{<:DecisionLike}}
            return SPConstraintRef(stochasticprogram, stage, obj)
        elseif obj isa AbstractArray{<:ConstraintRef{Model, <:CI{<:DecisionLike}}}
            return map(obj) do cref
                return SPConstraintRef(stochasticprogram, stage, cref)
            end
        else
            error("Only decisions and decision constraints can be queried using this syntax. For regular variables and constraints, either annotate the relevant variable with @decision or first query the relevant JuMP subproblem and use the regular `[]` syntax.")
        end
    end
end
"""
    structure_name(stochasticprogram::StochasticProgram)

Return the name of the underlying structure of the `stochasticprogram`.
"""
function structure_name(stochasticprogram::StochasticProgram)
    return structure_name(structure(stochasticprogram))
end
"""
    num_decisions(stochasticprogram::StochasticProgram, stage::Integer = 1)

Return the number of decisions at `stage` in the `stochasticprogram`. Defaults to the first stage.
"""
function num_decisions(stochasticprogram::StochasticProgram{N}, stage::Integer = 1) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    return num_decisions(proxy(stochasticprogram, stage), stage)
end
"""
    num_variables(stochasticprogram::StochasticProgram, stage::Integer = 1)

Return the total number of variables at `stage` in the `stochasticprogram`. Defaults to the first stage.
"""
function JuMP.num_variables(stochasticprogram::StochasticProgram{N}, stage::Integer = 1) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    return num_variables(proxy(stochasticprogram, stage))
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
    scenario(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)

Return the scenario at `scenario_index` of `stochasticprogram` at stage `stage`.
"""
function scenario(stochasticprogram::StochasticProgram{N}, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage == 1 && error("The first stage does not have scenarios.")
    return scenario(structure(stochasticprogram), stage, scenario_index)
end
"""
    scenario(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer)

Return the scenario at `scenario_index` of the two-stage `stochasticprogram`
"""
function scenario(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer)
    return scenario(structure(stochasticprogram), 2, scenario_index)
end
"""
    scenarios(stochasticprogram::StochasticProgram, stage::Integer = 2)

Return an array of all scenarios of the `stochasticprogram` at `stage`. Defaults to the second stage.
"""
function scenarios(stochasticprogram::StochasticProgram{N}, stage::Integer = 2) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage == 1 && error("The first stage does not have scenarios.")
    return scenarios(structure(stochasticprogram), stage)
end
"""
    expected(stochasticprogram::StochasticProgram, stage::Integer = 2)

Return the exected scenario of all scenarios of the `stochasticprogram` at `stage`. Defaults to the second stage.
"""
function expected(stochasticprogram::StochasticProgram{N}, stage::Integer = 2) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage == 1 && error("The first stage does not have scenarios.")
    p = stage_probability(stochasticprogram, stage)
    abs(p - 1.0) <= 1e-6 || @warn "Scenario probabilities do not add up to one. The probability sum is given by $p"
    return expected(structure(stochasticprogram), stage)
end
"""
    scenario_type(stochasticprogram::StochasticProgram, stage::Integer = 2)

Return the type of the scenario structure associated with `stochasticprogram` at `stage`. Defaults to the second stage.
"""
function scenario_type(stochasticprogram::StochasticProgram{N}, stage::Integer = 2) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage == 1 && error("The first stage does not have scenarios.")
    return scenario_type(structure(stochasticprogram), stage)
end
"""
    scenario_types(stochasticprogram::StochasticProgram)

Return a stage-wise list of the scenario types of `stochasticprogram`.
"""
function scenario_types(stochasticprogram::StochasticProgram)
    return ntuple(Val(num_stages(stochasticprogram) - 1)) do s
        scenario_type(stochasticprogram, s + 1)
    end
end
"""
    probability(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)

Return the probability of the scenario at `scenario_index` in the `stochasticprogram` at `stage` occuring.
"""
function probability(stochasticprogram::StochasticProgram{N}, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    s == 1 && error("The first stage does not have scenarios.")
    return probability(structure(stochasticprogram), stage, scenario_index)
end
"""
    probability(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer)

Return the probability of the scenario at `scenario_index` in the two-stage `stochasticprogram` occuring.
"""
function probability(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer)
    return probability(structure(stochasticprogram), 2, scenario_index)
end
"""
    stage_probability(stochasticprogram::StochasticProgram, stage::Integer = 2)

Return the probability of any scenario in the `stochasticprogram` at `stage` occuring. A well defined model should return 1. Defaults to the second stage.
"""
function stage_probability(stochasticprogram::StochasticProgram{N}, stage::Integer = 2) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage == 1 && error("The first stage does not have scenarios.")
    return stage_probability(structure(stochasticprogram), stage)
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
    subproblem(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)

Return the subproblem at `scenario_index` of the `stochasticprogram` at `stage`.
"""
function subproblem(stochasticprogram::StochasticProgram{N}, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage == 1 && error("The first-stage does not have subproblems.")
    return subproblem(structure(stochasticprogram), stage, scenario_index)
end
"""
    subproblem(stochasticprogram::TwoStasgeStochasticProgram, scenario_index::Integer)

Return the subproblem at `scenario_index` of the two-stage `stochasticprogram`.
"""
function subproblem(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer)
    return subproblem(structure(stochasticprogram), 2, scenario_index)
end
"""
    subproblems(stochasticprogram::StochasticProgram, stage::Integer = 2)

Return an array of all subproblems of the `stochasticprogram` at `stage`. Defaults to the second stage.
"""
function subproblems(stochasticprogram::StochasticProgram{N}, stage::Integer = 2) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage == 1 && error("The first-stage does not have subproblems.")
    return subproblems(structure(stochasticprogram), stage)
end
"""
    num_subproblems(stochasticprogram::StochasticProgram, stage::Integer = 2)

Return the number of subproblems in the `stochasticprogram` at `stage`. Defaults to the second stage.
"""
function num_subproblems(stochasticprogram::StochasticProgram, stage::Integer = 2)
    stage == 1 && return 0
    return num_subproblems(structure(stochasticprogram), stage)
end
"""
    num_scenarios(stochasticprogram::StochasticProgram, stage::Integer = 2)

Return the number of scenarios in the `stochasticprogram` at `stage`. Defaults to the second stage.
"""
function num_scenarios(stochasticprogram::StochasticProgram, stage::Integer = 2)
    stage == 1 && return 0
    return num_scenarios(structure(stochasticprogram), stage)
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
    if JuMP._moi_mode(optimizer) != DIRECT && MOIU.state(optimizer) == MOIU.NO_OPTIMIZER
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

Return the value associated with the solver-specific attribute named `name` in `stochasticprogram`.

See also: [`set_optimizer_attribute`](@ref), [`set_optimizer_attributes`](@ref).
"""
function JuMP.get_optimizer_attribute(stochasticprogram::StochasticProgram, name::String)
    return get_optimizer_attribute(stochasticprogram, MOI.RawOptimizerAttribute(name))
end
"""
    get_optimizer_attribute(stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute)

Return the value of the solver-specific attribute `attr` in `stochasticprogram`.

See also: [`set_optimizer_attribute`](@ref), [`set_optimizer_attributes`](@ref).
"""
function JuMP.get_optimizer_attribute(stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute)
    return MOI.get(stochasticprogram, attr)
end
# ========================== #

# Setters
# ========================== #
"""
    update_known_decisions!(stochasticprogram::Stochasticprogram)

Update all known decision values in the first-stage of `stochasticprogram`.
"""
function update_known_decisions!(stochasticprogram::StochasticProgram)
    update_known_decisions!(structure(stochasticprogram))
end
"""
    update_decisions!(stochasticprogram::Stochasticprogram, stage::Integer, scenario_index::Integer)

Update all known decision values in the node at stage `stage` and scenario `scenario_index` of `stochasticprogram`.
"""
function update_decisions!(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)
    update_known_decisions!(structure(stochasticprogram), stage, scenario_index)
end
"""
    set_optimizer(stochasticmodel::StochasticModel, optimizer)

Set the optimizer of the `stochasticmodel`.
"""
function JuMP.set_optimizer(stochasticmodel::StochasticModel, optimizer)
    set_optimizer!(stochasticmodel.optimizer, optimizer)
    if stochasticmodel.optimizer.optimizer isa AbstractSampledOptimizer
        return nothing
    end
    # Default to SAA
    set_optimizer(stochasticmodel, SAA.Optimizer)
    set_optimizer_attribute(stochasticmodel, InstanceOptimizer(), optimizer)
    return nothing
end
"""
    set_optimizer(stochasticprogram::StochasticProgram, optimizer)

Set the optimizer of the `stochasticprogram`.
"""
function JuMP.set_optimizer(stochasticprogram::StochasticProgram, optimizer)
    if !supports_structure(optimizer(), structure(stochasticprogram))
        @warn "The provided optimizer does not support the underlying structure of the stochastic program. Consider reinstantiating (see `instantiate`) the stochastic program with the optimizer instead."
        return nothing
    end
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
"""
    set_optimizer_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)

Sets solver-specific attribute identified by `name` to `value` in the `stochasticprogram`.

See also: [`get_optimizer_attribute`](@ref)
"""
function JuMP.set_optimizer_attribute(stochasticprogram::StochasticProgram, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticprogram, MOI.RawOptimizerAttribute(String(name)), value)
end
"""
    set_optimizer_attribute(stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute, value)

Set the solver-specific attribute `attr` in `stochasticprogram` to `value`.

See also: [`get_optimizer_attribute`](@ref)
"""
function JuMP.set_optimizer_attribute(stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute, value)
    return MOI.set(stochasticprogram, attr, value)
end
"""
    set_optimizer_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)

Given a list of `attribute => value` pairs or a collection of keyword arguments, calls
`set_optimizer_attribute(stochasticprogram, attribute, value)` for each pair.

See also: [`get_optimizer_attribute`](@ref)
"""
function JuMP.set_optimizer_attributes(stochasticprogram::StochasticProgram, pairs::Pair...)
    for (name, value) in pairs
        set_optimizer_attribute(stochasticprogram, name, value)
    end
end
function JuMP.set_optimizer_attributes(stochasticprogram::StochasticProgram; kw...)
    for (name, value) in kw
        set_optimizer_attribute(stochasticprogram, name, value)
    end
end
function JuMP.set_silent(stochasticprogram::StochasticProgram)
    return MOI.set(stochasticprogram, MOI.Silent(), true)
end
function JuMP.unset_silent(stochasticprogram::StochasticProgram)
    return MOI.set(stochasticprogram, MOI.Silent(), false)
end
function JuMP.set_time_limit_sec(stochasticprogram::StochasticProgram, limit)
    return MOI.set(stochasticprogram, MOI.TimeLimitSec(), limit)
end
function JuMP.unset_time_limit_sec(stochasticprogram::StochasticProgram)
    return MOI.set(stochasticprogram, MOI.TimeLimitSec(), nothing)
end
function JuMP.time_limit_sec(stochasticprogram::StochasticProgram)
    return MOI.get(stochasticprogram, MOI.TimeLimitSec())
end
function JuMP.simplex_iterations(stochasticprogram::StochasticProgram)
    return MOI.get(stochasticprogram, MOI.SimplexIterations())
end
function JuMP.barrier_iterations(stochasticprogram::StochasticProgram)
    return MOI.get(stochasticprogram, MOI.BarrierIterations())
end
function JuMP.node_count(stochasticprogram::StochasticProgram)
    return MOI.get(stochasticprogram, MOI.NodeCount())
end
function JuMP.set_optimizer_attribute(stochasticmodel::StochasticModel, name::Union{Symbol, String}, value)
    return set_optimizer_attribute(stochasticmodel, MOI.RawOptimizerAttribute(String(name)), value)
end
function JuMP.set_optimizer_attribute(stochasticmodel::StochasticModel, attr::MOI.AbstractOptimizerAttribute, value)
    return MOI.set(stochasticmodel, attr, value)
end
function JuMP.set_optimizer_attributes(stochasticmodel::StochasticModel, pairs::Pair...)
    for (name, value) in pairs
        set_optimizer_attribute(stochasticmodel, name, value)
    end
end
function JuMP.set_optimizer_attributes(stochasticmodel::StochasticModel; kw...)
    for (name, value) in kw
        set_optimizer_attribute(stochasticmodel, name, value)
    end
end
function JuMP.set_silent(stochasticmodel::StochasticModel)
    return MOI.set(stochasticmodel, MOI.Silent(), true)
end
function JuMP.unset_silent(stochasticmodel::StochasticModel)
    return MOI.set(stochasticmodel, MOI.Silent(), false)
end
"""
    add_scenario!(stochasticprogram::StochasticProgram, stage::Integer, scenario::AbstractScenario)

Store the second stage `scenario` in the `stochasticprogram` at `stage`.

If the `stochasticprogram` is distributed, the scenario will be defined on the node that currently has the fewest scenarios.
"""
function add_scenario!(stochasticprogram::StochasticProgram, stage::Integer, scenario::AbstractScenario)
    add_scenario!(structure(stochasticprogram), stage, scenario)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_scenario!(stochasticprogram::TwoStageStochasticProgram, scenario::AbstractScenario)

Store the second stage `scenario` in the two-stage `stochasticprogram`.
"""
function add_scenario!(stochasticprogram::TwoStageStochasticProgram, scenario::AbstractScenario)
    add_scenario!(structure(stochasticprogram), 2,scenario)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_worker_scenario!(stochasticprogram::StochasticProgram, stage::Integer, scenario::AbstractScenario, w::Integer)

Store the second stage `scenario` in worker node `w` of the `stochasticprogram` at `stage`.
"""
function add_worker_scenario!(stochasticprogram::StochasticProgram, stage::Integer, scenario::AbstractScenario, w::Integer)
    add_scenario!(structure(stochasticprogram), stage, scenario, w)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_worker_scenario!(stochasticprogram::StochasticProgram, stage::Integer, scenario::AbstractScenario, w::Integer)

Store the second stage `scenario` in worker node `w` of the two-stage `stochasticprogram`.
"""
function add_worker_scenario!(stochasticprogram::TwoStageStochasticProgram, scenario::AbstractScenario, w::Integer)
    add_scenario!(structure(stochasticprogram), 2, scenario, w)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, stage::Integer)

Store the scenario returned by `scenariogenerator` in the `stage` of the `stochasticprogram`. If the `stochasticprogram` is distributed, the scenario will be defined on the node that currently has the fewest scenarios.
"""
function add_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, stage::Integer)
    add_scenario!(scenariogenerator, structure(stochasticprogram), stage)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram)

Store the scenario returned by `scenariogenerator` in the two-stage `stochasticprogram`. If the `stochasticprogram` is distributed, the scenario will be defined on the node that currently has the fewest scenarios.
"""
function add_scenario!(scenariogenerator::Function, stochasticprogram::TwoStageStochasticProgram)
    add_scenario!(scenariogenerator, structure(stochasticprogram), 2)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_worker_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, stage::Integer, w::Integer)

Store the scenario returned by `scenariogenerator` in worker node `w` of the `stochasticprogram` at `stage`.
"""
function add_worker_scenario!(scenariogenerator::Function, stochasticprogram::StochasticProgram, stage::Integer, w::Integer)
    add_scenario!(scenariogenerator, structure(stochasticprogram), stage, w)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_worker_scenario!(scenariogenerator::Function, stochasticprogram::TwoStageStochasticProgram, w::Integer)

Store the scenario returned by `scenariogenerator` in worker node `w` of the two-stage `stochasticprogram`.
"""
function add_worker_scenario!(scenariogenerator::Function, stochasticprogram::TwoStageStochasticProgram, w::Integer)
    add_scenario!(scenariogenerator, structure(stochasticprogram), 2, w)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_scenarios!(stochasticprogram::StochasticProgram, stage::Integer, scenarios::Vector{<:AbstractScenario})

Store the collection of `scenarios` in the `stochasticprogram` at `stage`. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function add_scenarios!(stochasticprogram::StochasticProgram, stage::Integer, scenarios::Vector{<:AbstractScenario})
    add_scenarios!(structure(stochasticprogram), stage, scenarios)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_scenarios!(stochasticprogram::TwoStageStochasticProgram, scenarios::Vector{<:AbstractScenario})

Store the collection of `scenarios` in the two-stage `stochasticprogram`. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function add_scenarios!(stochasticprogram::TwoStageStochasticProgram, scenarios::Vector{<:AbstractScenario})
    add_scenarios!(structure(stochasticprogram), 2, scenarios)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_worker_scenarios!(stochasticprogram::StochasticProgram, stage::Integer, scenarios::Vector{<:AbstractScenario}, w::Integer)

Store the collection of `scenarios` in in worker node `w` of the `stochasticprogram` at `stage`.
"""
function add_worker_scenarios!(stochasticprogram::StochasticProgram, stage::Integer, scenarios::Vector{<:AbstractScenario}, w::Integer)
    add_scenarios!(structure(stochasticprogram), stage, scenarios, w)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_worker_scenarios!(stochasticprogram::StochasticProgram, stage::Integer, scenarios::Vector{<:AbstractScenario}, w::Integer)

Store the collection of `scenarios` in in worker node `w` of the two-stage `stochasticprogram`.
"""
function add_worker_scenarios!(stochasticprogram::TwoStageStochasticProgram, scenarios::Vector{<:AbstractScenario}, w::Integer)
    add_scenarios!(structure(stochasticprogram), 2, scenarios, w)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, stage::Integer, n::Integer)

Generate `n` scenarios using `scenariogenerator` and store in the `stochasticprogram` at `stage`. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function add_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, stage::Integer, n::Integer)
    add_scenarios!(scenariogenerator, structure(stochasticprogram), stage, n)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_scenarios!(scenariogenerator::Function, stochasticprogram::TwoStageStochasticProgram, n::Integer)

Generate `n` scenarios using `scenariogenerator` and store in the two-stage `stochasticprogram`. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function add_scenarios!(scenariogenerator::Function, stochasticprogram::TwoStageStochasticProgram, n::Integer)
    add_scenarios!(scenariogenerator, structure(stochasticprogram), 2, n)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_worker_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, stage::Integer, n::Integer, w::Integer)

Generate `n` scenarios using `scenariogenerator` and store them in worker node `w` of the `stochasticprogram` at `stage`.
"""
function add_worker_scenarios!(scenariogenerator::Function, stochasticprogram::StochasticProgram, stage::Integer, n::Integer, w::Integer)
    add_scenarios!(scenariogenerator, structure(stochasticprogram), stage, n, w)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    add_worker_scenarios!(scenariogenerator::Function, stochasticprogram::TwoStageStochasticProgram, n::Integer, w::Integer)

Generate `n` scenarios using `scenariogenerator` and store them in worker node `w` of the two-stage `stochasticprogram`.
"""
function add_worker_scenarios!(scenariogenerator::Function, stochasticprogram::TwoStageStochasticProgram, n::Integer, w::Integer)
    add_scenarios!(scenariogenerator, structure(stochasticprogram), 2, n, w)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
"""
    sample!(stochasticprogram::StochasticProgram, stage::Integer, sampler::AbstractSampler, n::Integer)

Sample `n` scenarios using `sampler` and add to the `stochasticprogram` at `stage`. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function sample!(stochasticprogram::StochasticProgram, stage::Integer, sampler::AbstractSampler, n::Integer)
    sample!(structure(stochasticprogram), stage, sampler, n)
    return stochasticprogram
end
"""
    sample!(stochasticprogram::TwoStageStochasticProgram, sampler::AbstractSampler, n::Integer)

Sample `n` scenarios using `sampler` and add to the two-stage `stochasticprogram`. If the `stochasticprogram` is distributed, scenarios will be distributed evenly across workers.
"""
function sample!(stochasticprogram::TwoStageStochasticProgram, sampler::AbstractSampler, n::Integer)
    sample!(structure(stochasticprogram), 2, sampler, n)
    return stochasticprogram
end
# ========================== #
