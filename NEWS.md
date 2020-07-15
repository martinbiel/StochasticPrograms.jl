StochasticPrograms release notes
==================

Version 0.4.0 (July 14, 2020)
-----------------------------

StochasticPrograms is now compatible with JuMP 0.19+ and the new MathOptInterface backend. This required a major overhaul of the design, which has resulted in breaking changes and many new features. See the documentation for further details.

- The role of the `@decision` macro has changed. It was previously used to annotate variables that originate from previous stages. Now, it is used to define the variable in its origin stage. Specifically, a model that was previosly defined through:
```julia
@stochastic_model begin
    @stage 1 begin
        @variable(model, x₁ >= 40)
        @variable(model, x₂ >= 20)
        @objective(model, Min, 100*x₁ + 150*x₂)
        @constraint(model, x₁ + x₂ <= 120)
    end
    @stage 2 begin
        @decision x₁ x₂
        @uncertain q₁ q₂ d₁ d₂
        @variable(model, 0 <= y₁ <= d₁)
        @variable(model, 0 <= y₂ <= d₂)
        @objective(model, Min, q₁*y₁ + q₂*y₂)
        @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
        @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
    end
end
```
is now defined through
```julia
@stochastic_model begin
    @stage 1 begin
        @decision(model, x₁ >= 40)
        @decision(model, x₂ >= 20)
        @objective(model, Min, 100*x₁ + 150*x₂)
        @constraint(model, x₁ + x₂ <= 120)
    end
    @stage 2 begin
        @uncertain q₁ q₂ d₁ d₂
        @variable(model, 0 <= y₁ <= d₁)
        @variable(model, 0 <= y₂ <= d₂)
        @objective(model, Max, q₁*y₁ + q₂*y₂)
        @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
        @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
    end
end
```
Inside a `@stochastic_model` definition, any variable defined using `@decision` is available for usage in the next stage. The syntax is the same as JuMP's `@variable` macro.
- The `@decision` macro creates specialized `AbstractVariableRef` objects called `DecisionVariable`. Internally, the behaviour of the decision variables vary with context. In a deterministic equivalent problem, or the first stage, the decision variables behave as standard JuMP variables. In second-stage subproblems, they act as parameters with known values.
- The `DecisionVariable`, as well as its internal representations `DecisionRef` and `KnownRef`, all implement JuMP's variable interface. For example, the following now works:
```julia
x₁ = decision_by_name(sp, "x₁")
fix(x₁, 40)
```
and fixes `x₁` in all stages.
- The workflow has been overhauled to match the new JuMP workflow. In short, most actions (optimization, evaluation, VSS, EVPI) require an optimizer to first be set (either through the `optimizer` keyword during `instantiate` or through `set_optimizer`). Optimizers are like JuMP/MOI added as constructors:
```julia
set_optimizer(sp, LShaped.Optimizer)
```
- The L-shaped and progressive-hedging solver suites now each implement a MOI wrapper similar to third-party solvers. In other words, they are now configured in the same way as MOI solvers:
```julia
set_optimizer(sp, LShaped.Optimizer)
set_optimizer_attribute(sp, Regularizer(), TrustRegion())
set_optimizer_attribute(sp, Aggregator(), PartialAggregate(2))
```
This replaces the previous `LShapedSolver`/`ProgressiveHedgingSolver` API.
- The underlying storage structure of an instantiated stochastic program is now induced by the solver. If instantiated with a third-party solver (GLPK, Gurobi, etc) the finite extensive form (DEP) is generated and stored to represent the stochastic program. If instantiated with an L-shaped solver, the program is stored in a vertical structure with a first stage and a collection of second-stage subproblems. If instantiated with a progressive-hedging solver, the program is stored in a horizontal structure with a collection of subproblems with non-anticipativity constraints. Further, these block-decomposition structures can be distributed in memory. The storage type can be set explicitly by setting the `instantiation` keyword during model creation to one of `Deterministic`, `Vertical`, `Horizontal`, `DistributedVertical`, or `DistributedHorizontal`.
- `@uncertain` can now be used with JuMP's container syntax. The new `@container_scenario` macro can be used to create scenarios that match the `@uncertain` declaration.
- Calling `instantiate` with an `AbstractSampler` and a desired number of scenarios replaces `SAA` for sampled model instantiation.

Version 0.3.0 (January 28, 2020)
-----------------------------

- [LShapedSolvers.jl](https://github.com/martinbiel/LShapedSolvers.jl) and [ProgressiveHedgingSolvers](https://github.com/martinbiel/ProgressiveHedgingSolvers.jl) have been integrated into `StochasticPrograms`. The solver repositories will stay up for future development, but the aim is to keep stable versions in `StochasticPrograms`
- Both `LShapedSolvers` and `ProgressiveHedgingSolvers` have seen major rework. This includes both changes to the software design (A policy-base design has succeeded the use of `TraitDispatch`) as well as feature additions (Executors, Cut aggregation, Penalty approximations, ...). See the documentation for further details.
- Added functionality for calculating confidence intervals around EVPI and VSS for continuous models.
- Documentation has been extended to cover all new features. In addition, terminology clarifications have been made for sampled models and SAA.
- Bugfixes

Version 0.2.0 (June 5, 2019)
-----------------------------

0.2 includes a major refactor of model creation.

- Introduces `@stochastic_model` as the main method of model definition. The macro returns a `StochasticModel` object that can be used to either `instantiate` a stochastic program from a given list of scenarios, or to generate an `SAA` model by supplying a sampler object.
- StochasticPrograms now supports an arbitrary number of stage blocks in a type-safe manner. However, most tools and specialized solvers are still only implemented for two-stage models.
- Stages are defined using the new `@stage` block. `@first_stage` and `@second_stage` still exist and are equivalent to `@stage 1` and `@stage 2`.
- The new `@parameters` block is used to specify deterministic parameters in a stage block. The parameters must be provided when instantiating models, but default values can be specified directly in the `@parameters` block.
- The new `@uncertain` block is used to specify stochastic parameters in a stage block. This can be done in multiple ways for flexibility. For example, it is possible to define and utilize a new scenario type using `@scenario` syntax directly in the `@uncertain` block.
- New sample-based tools added for stochastic programs over continuous random variables. These include calculating confidence intervals around the true optimal value or expected results of given first-stage decisions.
- New sample-based solver interface for approximately solving stochastic programs over continuous random variables. A simple solver based on a sequential SAA algorithm is provided by StochasticPrograms.
