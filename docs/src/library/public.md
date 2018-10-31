# Public interface

Documentation for `StochasticPrograms.jl`'s public interface.

## Contents

```@contents
Pages = ["public.md"]
```

## Index

```@index
Pages = ["public.md"]
```

## Constructors

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["twostage.jl"]
```

## Model definition

```@meta
DocTestSetup = quote
    using StochasticPrograms
    struct SimpleScenario <: AbstractScenarioData
        π::Probability
        d::Vector{Float64}
        q::Vector{Float64}
    end
    function StochasticPrograms.expected(scenarios::Vector{SimpleScenario})
        isempty(scenarios) && return SimpleScenario(1.,zeros(2),zeros(2))
        return SimpleScenario(1., sum([s.π*s.d for s in scenarios]), sum([s.π*s.q for s in scenarios]))
    end
    s1 = SimpleScenario(0.4, [500.0,100], [-24.0,-28])
    s2 = SimpleScenario(0.6, [300.0,300], [-28.0,-32])
    sp = StochasticProgram(SimpleScenario)
end
```

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["creation.jl"]
```

## API

```@meta
DocTestSetup = quote
    using StochasticPrograms
    struct SimpleScenario <: AbstractScenarioData
        π::Probability
        d::Vector{Float64}
        q::Vector{Float64}
    end
    function StochasticPrograms.expected(scenarios::Vector{SimpleScenario})
        isempty(scenarios) && return SimpleScenario(1.,zeros(2),zeros(2))
        return SimpleScenario(1., sum([s.π*s.d for s in scenarios]), sum([s.π*s.q for s in scenarios]))
    end
    s1 = SimpleScenario(0.4, [500.0,100], [-24.0,-28])
    s2 = SimpleScenario(0.6, [300.0,300], [-28.0,-32])
    sp = StochasticProgram([s1.s2])
    @first_stage sp = begin
        @variable(model, x₁ >= 40)
        @variable(model, x₂ >= 20)
        @objective(model, Min, 100*x₁ + 150*x₂)
        @constraint(model, x₁+x₂ <= 120)
    end
    @second_stage sp = begin
        @decision x₁ x₂
        ξ = scenario
        q₁, q₂, d₁, d₂ = ξ.q[1], ξ.q[2], ξ.d[1], ξ.d[2]
        @variable(model, 0 <= y₁ <= d₁)
        @variable(model, 0 <= y₂ <= d₂)
        @objective(model, Min, q₁*y₁ + q₂*y₂)
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
