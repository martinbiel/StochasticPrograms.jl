# Solver interface

Documentation for `StochasticPrograms.jl`'s interface for structured solvers and sample-based solvers.

## Index

```@index
Pages = ["solverinterface.md"]
```

## Interface

```@docs
AbstractStructuredOptimizer
AbstractSampledOptimizer
```

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["optimizer_interface.jl"]
```

## Attributes

```@docs
AbstractStructuredOptimizerAttribute
AbstractSampledOptimizerAttribute
```

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["attributes.jl"]
```


## Execution

```@docs
Serial
Synchronous
Asynchronous
```

## Penalty terms

```@docs
Quadratic
Linearized
InfNorm
ManhattanNorm
```
