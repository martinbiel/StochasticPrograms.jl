# StochasticPrograms

*A modeling framework for stochastic programming problems*

[![Build Status](https://travis-ci.com/martinbiel/StochasticPrograms.jl.svg?branch=master)](https://travis-ci.com/martinbiel/StochasticPrograms.jl)
[![Coverage Status](https://coveralls.io/repos/martinbiel/StochasticPrograms.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/martinbiel/StochasticPrograms.jl?branch=master)
[![codecov.io](http://codecov.io/github/martinbiel/StochasticPrograms.jl/coverage.svg?branch=master)](http://codecov.io/github/martinbiel/StochasticPrograms.jl?branch=master)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://martinbiel.github.io/StochasticPrograms.jl/stable)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://martinbiel.github.io/StochasticPrograms.jl/dev)

## Installation

```julia
pkg> add StochasticPrograms
```

## Summary

StochasticPrograms models recourse problems where an initial decision is taken, unknown parameters are observed, followed by recourse decisions to correct any inaccuracy in the initial decision. The underlying optimization problems are formulated in [JuMP.jl](https://github.com/JuliaOpt/JuMP.jl). In StochasticPrograms, model instantiation can be deferred until required. As a result, scenario data can be loaded/reloaded to create/rebuild the recourse model at a later stage, possibly on separate machines in a cluster. Another consequence of deferred model instantiation is that StochasticPrograms.jl can provide stochastic programming constructs, such as *expected value of perfect information* and *value of the stochastic solution*, to gain deeper insights about formulated recourse problems. A good introduction to recourse models, and to the stochastic programming constructs provided in this package, is given in [Introduction to Stochastic Programming](https://link.springer.com/book/10.1007%2F978-1-4614-0237-4). A stochastic program has a structure that can be exploited in solver algorithms. Therefore, StochasticPrograms provides a structured solver interface. Furthermore, a suite of solvers based on L-shaped and progressive-hedging algorithms that implements this interface are included. StochasticPrograms has parallel capabilities, implemented using the standard Julia library for distributed computing.

## Project Status

The package is tested against Julia the `1.0`, `1.5` and `nightly` branches on Linux, macOS, and Windows. See [NEWS](https://github.com/martinbiel/StochasticPrograms.jl/blob/master/NEWS.md) for release notes.

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
