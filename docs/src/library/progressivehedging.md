# Progressive-hedging solvers

Documentation for `StochasticPrograms.jl`'s progressive-hedging solvers.

## Index

```@index
Pages = ["progressivehedging.md"]
```

## Progressive-hedging solver factory

```@docs
ProgressiveHedgingSolver
```

### Execution

```@docs
ProgressiveHedgingSolvers.SerialExecution
ProgressiveHedgingSolvers.Serial
ProgressiveHedgingSolvers.SynchronousExecution
ProgressiveHedgingSolvers.Synchronous
ProgressiveHedgingSolvers.AsynchronousExecution
ProgressiveHedgingSolvers.Asynchronous
```

### Penalties

```@docs
ProgressiveHedgingSolvers.FixedPenalization
ProgressiveHedgingSolvers.Fixed
ProgressiveHedgingSolvers.AdaptivePenalization
ProgressiveHedgingSolvers.Adaptive
```
