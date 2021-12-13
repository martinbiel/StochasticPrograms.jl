# StochasticPrograms

*A modeling framework for stochastic programming problems*

[![Build Status](https://github.com/martinbiel/StochasticPrograms.jl/workflows/CI/badge.svg?branch=master)](https://github.com/martinbiel/StochasticPrograms.jl/actions?query=workflow%3ACI)
[![codecov.io](http://codecov.io/github/martinbiel/StochasticPrograms.jl/coverage.svg?branch=master)](http://codecov.io/github/martinbiel/StochasticPrograms.jl?branch=master)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://martinbiel.github.io/StochasticPrograms.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://martinbiel.github.io/StochasticPrograms.jl/dev)

## Installation

```julia
pkg> add StochasticPrograms
```

## Summary

Stochastic programming models recourse problems where an initial decision is taken, uncertain parameters are observed, followed by recourse decisions to correct any inaccuracy in the initial decision. StochasticPrograms.jl is a general purpose modeling framework for stochastic programming. The framework includes both modeling tools and structure-exploiting optimization algorithms. The underlying optimization problems are formulated using [JuMP.jl](https://github.com/JuliaOpt/JuMP.jl). Stochastic programming models can be efficiently formulated using an expressive syntax and models can be instantiated, inspected, and analyzed interactively. The framework scales seamlessly to distributed environments. Small instances of a model can be run locally to ensure correctness, while larger instances are automatically distributed in a memory-efficient way onto supercomputers or clouds and solved using parallel optimization algorithms. These structure-exploiting solvers are based on variations of the classical L-shaped, progressive-hedging, and quasi-gradient algorithms.

The framework will prove useful to researchers, educators and industrial users alike. Researchers will benefit from the readily extensible open-source framework, where they can formulate complex stochastic models or quickly typeset and test novel optimization algorithms. Educators of stochastic programming will benefit from the clean and expressive syntax. Moreover, the framework supports analysis tools and stochastic programming constructs, such as *expected value of perfect information* and *value of the stochastic solution*, from classical theory and leading textbooks. Industrial practitioners can make use of StochasticPrograms.jl to rapidly formulate complex models, analyze small instances locally, and then run large-scale instances in production. In doing so, they get distributed capabilities for free, without changing the code, and access to well-tested state-of-the-art implementations of parallel structure-exploiting solvers. A good introduction to recourse models, and to the stochastic programming constructs provided in this package, is given in [Introduction to Stochastic Programming](https://link.springer.com/book/10.1007%2F978-1-4614-0237-4). To learn more about the package, consider the [documentation](https://martinbiel.github.io/StochasticPrograms.jl/stable).

## Project Status

The package is tested against Julia `1.6`, `1.7` and `nightly` branches on Linux, macOS, and Windows. See [NEWS](https://github.com/martinbiel/StochasticPrograms.jl/blob/master/NEWS.md) for release notes.

An older version for Julia `0.6` is available on the `compat-0.6` branch, but backwards compatibility can not be promised.

## Citing

If you use StochasticPrograms, please cite the following [preprint](https://arxiv.org/abs/1909.10451):

```
@Article{spjl,
  title     = {Efficient Stochastic Programming in {J}ulia},
  author    = {Martin Biel and Mikael Johansson},
  journal   = {arXiv preprint arXiv:1909.10451},
  year      = {2019}
}
```
