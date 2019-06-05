StochasticPrograms release notes
==================

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
