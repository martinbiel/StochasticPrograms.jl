# Solver interface

Documentation for `StochasticPrograms.jl`'s interface for structured solvers and sample-based solvers.

## Index

```@index
Pages = ["solverinterface.md"]
```

## Interface

```@docs
AbstractStructuredSolver
AbstractStructuredModel
AbstractSampledSolver
AbstractSampledModel
```

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["spinterface.jl"]
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
