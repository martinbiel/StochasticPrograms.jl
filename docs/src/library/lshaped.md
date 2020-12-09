# L-shaped solvers

Documentation for `StochasticPrograms.jl`'s L-shaped solvers.

## Index

```@index
Pages = ["lshaped.md"]
```

## API

```@docs
LShapedAlgorithm
```
```@autodocs
Modules = [LShaped]
Pages   = ["attributes.jl", "MOI_wrapper.jl"]
```

## Execution

```@docs
LShaped.SerialExecution
LShaped.SynchronousExecution
LShaped.AsynchronousExecution
```

## Regularization

```@docs
LShaped.set_regularization_attribute
LShaped.set_regularization_attributes
LShaped.RawRegularizationParameter
LShaped.NoRegularization
LShaped.DontRegularize
LShaped.RegularizedDecomposition
LShaped.RD
LShaped.TrustRegion
LShaped.TR
LShaped.LevelSet
LShaped.LV
```

## Aggregation

```@docs
LShaped.set_aggregation_attribute
LShaped.set_aggregation_attributes
```
```@autodocs
Modules = [LShaped]
Pages   = ["no_aggregation.jl", "partial_aggregation.jl", "dynamic_aggregation.jl", "cluster_aggregation.jl", "granulated_aggregation.jl", "hybrid_aggregation.jl"]
```

### Selection rules

```@autodocs
Modules = [LShaped]
Pages   = ["selection_rules.jl"]
```

### Cluster rules

```@autodocs
Modules = [LShaped]
Pages   = ["cluster_rules.jl"]
```

### Distance measures

```@autodocs
Modules = [LShaped]
Pages   = ["distance_measures.jl"]
```

## Consolidation

```@docs
LShaped.set_consolidation_attribute
LShaped.set_consolidation_attributes
```
```@autodocs
Modules = [LShaped]
Pages   = ["consolidation.jl"]
```
