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

## Execution

```@docs
ProgressiveHedgingSolvers.SerialExecution
ProgressiveHedgingSolvers.SynchronousExecution
ProgressiveHedgingSolvers.AsynchronousExecution
```

## Penalties

```@docs
ProgressiveHedgingSolvers.FixedPenalization
ProgressiveHedgingSolvers.Fixed
ProgressiveHedgingSolvers.AdaptivePenalization
ProgressiveHedgingSolvers.Adaptive
```
