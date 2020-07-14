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

## Structures

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["stochasticstructure.jl"]
```
```@docs
DeterministicEquivalent
VerticalStructure
HorizontalStructure
```

## Decisions

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["decision_variable.jl", "variable_interface.jl"]
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
@container_scenario
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
@known
@parameters
@uncertain
@stochastic_model
```

## API

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["api.jl", "generation.jl", "evaluation.jl"]
```

## Stochastic programming constructs

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["spconstructs.jl"]
```
