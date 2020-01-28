# StochasticPrograms.jl

*A modeling framework for stochastic programming problems*

## Summary

StochasticPrograms models recourse problems where an initial decision is taken, unknown parameters are observed, followed by recourse decisions to correct any inaccuracy in the initial decision. The underlying optimization problems are formulated in [JuMP.jl](https://github.com/JuliaOpt/JuMP.jl). In StochasticPrograms, model instantiation can be deferred until required. As a result, scenario data can be loaded/reloaded to create/rebuild the recourse model at a later stage, possibly on separate machines in a cluster. Another consequence of deferred model instantiation is that StochasticPrograms.jl can provide stochastic programming constructs, such as *expected value of perfect information* ([`EVPI`](@ref)) and *value of the stochastic solution* ([`VSS`](@ref)), to gain deeper insights about formulated recourse problems. A good introduction to recourse models, and to the stochastic programming constructs provided in this package, is given in [Introduction to Stochastic Programming](https://link.springer.com/book/10.1007%2F978-1-4614-0237-4). A stochastic program has a structure that can be exploited in solver algorithms. Therefore, StochasticPrograms provides a structured solver interface. Furthermore, a suite of solvers based on L-shaped and progressive-hedging algorithms that implements this interface are included. StochasticPrograms has parallel capabilities, implemented using the standard Julia library for distributed computing.

## Features

- Flexible problem definition
- Deferred model instantiation
- Scenario data injection
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
Pages = ["manual/quickstart.md", "manual/data.md", "manual/model.md", "manual/distributed.md", "manual/structuredsolvers.md", "manual/examples.md"]
```

## Library Outline

```@contents
Pages = ["library/public.md", "library/solverinterface.md", "library/crash.md", "library/lshaped.md", "library/progressivehedging.md"]
```

### [Index](@id main-index)

```@index
Pages = ["library/public.md"]
Order   = [:type, :macro, :function]
```
