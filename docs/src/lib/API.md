# Library

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

## Constructors

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["twostage.jl"]
```

## API

```@autodocs
Modules = [StochasticPrograms]
Pages   = ["api.jl"]
```
