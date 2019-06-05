# Public interface

Documentation for `StochasticPrograms.jl`'s public interface.

## Contents

```@contents
Pages = ["public.md"]
```

## Index

```@index
Pages = ["public.md"]
Order   = [:type, :macro, :function]
```

## Constructors

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["stochasticprogram.jl"]
```

## Scenarios

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["scenario.jl"]
```

```@docs
AbstractSampler
Sampler
sample
```

```@meta
DocTestSetup = quote
    using StochasticPrograms
end
```

```@docs
@scenario
@zero
@expectation
@sampler
@sample
```

## Model definition

```@docs
@stage
@first_stage
@second_stage
@decision
@parameters
@uncertain
@stochastic_model
```

## API

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["api.jl", "stochasticsolution.jl", "SAASolver.jl", "generation.jl", "evaluation.jl"]
```

## Stochastic programming constructs

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["spconstructs.jl"]
```
