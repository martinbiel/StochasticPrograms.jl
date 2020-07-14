# Progressive-hedging solvers

Documentation for `StochasticPrograms.jl`'s progressive-hedging solvers.

## Index

```@index
Pages = ["progressivehedging.md"]
```

## API

```@docs
ProgressiveHedgingAlgorithm
```
```@autodocs
Modules = [ProgressiveHedging]
Pages   = ["attributes.jl", "MOI_wrapper.jl"]
```

## Execution

```@docs
ProgressiveHedging.SerialExecution
ProgressiveHedging.SynchronousExecution
ProgressiveHedging.AsynchronousExecution
```

## Penalties


```@docs
ProgressiveHedging.set_penalization_attribute
ProgressiveHedging.set_penalization_attributes
ProgressiveHedging.RawPenalizationParameter
ProgressiveHedging.FixedPenalization
ProgressiveHedging.Fixed
ProgressiveHedging.AdaptivePenalization
ProgressiveHedging.Adaptive
```
