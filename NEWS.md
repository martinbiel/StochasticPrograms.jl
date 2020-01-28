StochasticPrograms release notes
==================

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
