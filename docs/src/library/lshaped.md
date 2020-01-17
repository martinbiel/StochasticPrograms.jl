# L-shaped solvers

Documentation for `StochasticPrograms.jl`'s L-shaped solvers.

## Index

```@index
Pages = ["lshaped.md"]
```

## L-shaped solver factory

```@docs
LShapedSolver
```

## Execution

```@docs
LShapedSolvers.SerialExecution
LShapedSolvers.SynchronousExecution
LShapedSolvers.AsynchronousExecution
```

## Regularization

```@docs
LShapedSolvers.NoRegularization
LShapedSolvers.DontRegularize
LShapedSolvers.RegularizedDecomposition
LShapedSolvers.RD
LShapedSolvers.TrustRegion
LShapedSolvers.TR
LShapedSolvers.LevelSet
LShapedSolvers.LV
```

## Aggregation

```@autodocs
Modules = [LShapedSolvers]
Pages   = ["no_aggregation.jl", "partial_aggregation.jl", "dynamic_aggregation.jl", "cluster_aggregation.jl", "hybrid_aggregation.jl"]
```

### Selection rules

```@autodocs
Modules = [LShapedSolvers]
Pages   = ["selection_rules.jl"]
```

### Cluster rules

```@autodocs
Modules = [LShapedSolvers]
Pages   = ["cluster_rules.jl"]
```

### Distance measures

```@autodocs
Modules = [LShapedSolvers]
Pages   = ["distance_measures.jl"]
```

## Consolidation

```@autodocs
Modules = [LShapedSolvers]
Pages   = ["consolidation.jl"]
```
