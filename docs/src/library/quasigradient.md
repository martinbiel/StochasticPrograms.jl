# L-shaped solvers

Documentation for `StochasticPrograms.jl`'s quasi-gradient solvers.

## Index

```@index
Pages = ["quasigradient.md"]
```

## API

```@docs
QuasiGradientAlgorithm
```
```@autodocs
Modules = [QuasiGradient]
Pages   = ["attributes.jl", "MOI_wrapper.jl"]
```

## Execution

```@docs
QuasiGradient.SerialExecution
QuasiGradient.SynchronousExecution
```

## Step

```@docs
QuasiGradient.set_step_attribute
QuasiGradient.set_step_attributes
```
```@autodocs
Modules = [QuasiGradient]
Pages   = ["step.jl", "constant.jl", "diminishing.jl", "polyak.jl", "bb.jl"]
```

## Prox

```@docs
QuasiGradient.set_prox_attribute
QuasiGradient.set_prox_attributes
```
```@autodocs
Modules = [QuasiGradient]
Pages   = ["prox.jl", "no_prox.jl", "polyhedron.jl", "anderson.jl", "nesterov.jl", "dry_friction.jl"]
```

### Termination

```@docs
QuasiGradient.set_termination_attribute
QuasiGradient.set_termination_attributes
```
```@autodocs
Modules = [QuasiGradient]
Pages   = ["termination.jl", "iteration.jl", "objective.jl", "gradient.jl"]
```

### Smoothing

```@docs
QuasiGradient.Unaltered
QuasiGradient.Smoothed
QuasiGradient.SubProblem
QuasiGradient.SmoothSubProblem
```
