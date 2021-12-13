# StochasticPrograms.jl

*A modeling framework for stochastic programming problems*

## Summary

Stochastic programming models recourse problems where an initial decision is taken, uncertain parameters are observed, followed by recourse decisions to correct any inaccuracy in the initial decision. StochasticPrograms.jl is a general purpose modeling framework for stochastic programming. The framework includes both modeling tools and structure-exploiting optimization algorithms. The underlying optimization problems are formulated using [JuMP.jl](https://github.com/JuliaOpt/JuMP.jl). Stochastic programming models can be efficiently formulated using an expressive syntax and models can be instantiated, inspected, and analyzed interactively. The framework scales seamlessly to distributed environments. Small instances of a model can be run locally to ensure correctness, while larger instances are automatically distributed in a memory-efficient way onto supercomputers or clouds and solved using parallel optimization algorithms. These structure-exploiting solvers are based on variations of the classical L-shaped, progressive-hedging, and quasi-gradient algorithms.

The framework will prove useful to researchers, educators and industrial users alike. Researchers will benefit from the readily extensible open-source framework, where they can formulate complex stochastic models or quickly typeset and test novel optimization algorithms. Educators of stochastic programming will benefit from the clean and expressive syntax. Moreover, the framework supports analysis tools and stochastic programming constructs, such as *expected value of perfect information* ([`EVPI`](@ref)) and *value of the stochastic solution* ([`VSS`](@ref)), from classical theory and leading textbooks. Industrial practitioners can make use of StochasticPrograms.jl to rapidly formulate complex models, analyze small instances locally, and then run large-scale instances in production. In doing so, they get distributed capabilities for free, without changing the code, and access to well-tested state-of-the-art implementations of parallel structure-exploiting solvers. A good introduction to recourse models, and to the stochastic programming constructs provided in this package, is given in [Introduction to Stochastic Programming](https://link.springer.com/book/10.1007%2F978-1-4614-0237-4).

## Features

- Flexible problem definition
- Deferred model instantiation
- Scenario data injection
- Comprehensive collection of stochastic programming methods
- Natively distributed
- Interface to structure-exploiting solver algorithms
- Efficient parallel implementations of classical algorithms

Consider [Quick start](@ref) for a tutorial explaining how to get started using StochasticPrograms.

Some examples of models written in StochasticPrograms can be found on the [Examples](@ref) page.

See the [Index](@ref main-index) for the complete list of documented functions and types.

## Citing

If you use StochasticPrograms, please cite the following [preprint](https://arxiv.org/abs/1909.10451):

```
@article{spjl,
  title     = {Efficient Stochastic Programming in {J}ulia},
  author    = {Martin Biel and Mikael Johansson},
  journal   = {arXiv preprint arXiv:1909.10451},
  year      = {2019}
}
```

If you use the cut aggregation funcionality for L-shaped, please cite the following [preprint](https://arxiv.org/abs/1910.13752)

```
@article{cutaggregation,
  title     = {Dynamic cut aggregation in {L}-shaped algorithms},
  author    = {Martin Biel and Mikael Johansson},
  journal   = {arXiv preprint arXiv:1910.13752},
  year      = {2019}
}
```

## Manual Outline

```@contents
Pages = ["manual/quickstart.md", "manual/data.md", "manual/model.md", "manual/decisions.md", "manual/distributed.md", "manual/structuredsolvers.md", "manual/examples.md"]
```

## Library Outline

```@contents
Pages = ["library/public.md", "library/solverinterface.md", "library/crash.md", "library/lshaped.md", "library/progressivehedging.md", "library/SAA.md"]
```

### [Index](@id main-index)

```@index
Pages = ["library/public.md"]
Order   = [:type, :macro, :function]
```
