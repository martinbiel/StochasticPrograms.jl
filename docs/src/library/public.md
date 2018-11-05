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
Pages   = ["twostage.jl"]
```

## Scenarios

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["scenario.jl"]
```

```@docs
AbstractSampler
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

```@meta
DocTestSetup = quote
    using StochasticPrograms
    @scenario Simple = begin
        q₁::Float64
        q₂::Float64
        d₁::Float64
        d₂::Float64
    end
    s₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)
    s₂ = SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)
    sp = StochasticProgram([s₁,s₂])
    @first_stage sp = begin
        @variable(model, x₁ >= 40)
        @variable(model, x₂ >= 20)
        @objective(model, Min, 100*x₁ + 150*x₂)
        @constraint(model, x₁ + x₂ <= 120)
    end
end
```

```@docs
@first_stage
@second_stage
@decision
```

## API

```@meta
DocTestSetup = quote
    using StochasticPrograms
	@scenario Simple = begin
		q₁::Float64
		q₂::Float64
		d₁::Float64
		d₂::Float64
	end
	s₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)
	s₂ = SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)
    sp = StochasticProgram([s₁,s₂])
    @first_stage sp = begin
        @variable(model, x₁ >= 40)
        @variable(model, x₂ >= 20)
        @objective(model, Min, 100*x₁ + 150*x₂)
        @constraint(model, x₁ + x₂ <= 120)
    end
    @second_stage sp = begin
        @decision x₁ x₂
        ξ = scenario
        @variable(model, 0 <= y₁ <= ξ.d₁)
        @variable(model, 0 <= y₂ <= ξ.d₂)
        @objective(model, Min, ξ.q₁*y₁ + ξ.q₂*y₂)
        @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
        @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
    end
end
```
```@autodocs
Modules = [StochasticPrograms]
Pages   = ["api.jl", "generation.jl", "evaluation.jl"]
```

## Stochastic programming constructs

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["spconstructs.jl"]
```
