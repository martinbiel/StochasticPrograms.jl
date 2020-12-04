# Stochastic models

The [`@stochastic_model`](@ref) command is now introduced in more detail. The discussion will as before revolve around the simple example introduced in the [Quick start](@ref):
```julia
simple_model = @stochastic_model begin
    @stage 1 begin
        @decision(model, x₁ >= 40)
        @decision(model, x₂ >= 20)
        @objective(model, Min, 100*x₁ + 150*x₂)
        @constraint(model, x₁ + x₂ <= 120)
    end
    @stage 2 begin
        @known x₁ x₂
        @uncertain q₁ q₂ d₁ d₂
        @variable(model, 0 <= y₁ <= d₁)
        @variable(model, 0 <= y₂ <= d₂)
        @objective(model, Max, q₁*y₁ + q₂*y₂)
        @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
        @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
    end
end
```

## [`@stage`](@ref) blocks

The body of a [`@stochastic_model`](@ref) definition consists of a number of [`@stage`](@ref) blocks, following the syntax:
```julia
@stage N begin
    ...
end
```
Here, `N` is the stage number and the body is made up of [JuMP](https://github.com/JuliaOpt/JuMP.jl) syntax as well as [`@parameters`](@ref), [`@decision`](@ref), and [`@uncertain`](@ref) blocks. At least two stages must be defined and the stages must be defined in consecutive order starting with the first stage. The number of stage blocks included in the [`@stochastic_model`](@ref) definition determines the number of stages that a stochastic program instantiated from the resulting stochastic model will have.

!!! note

    It is possible to define and instantiate stochastic models with more than two stages. However, most internal tools and solvers only support two-stage models at this point.

## [`@parameters`](@ref) blocks

The [`@parameters`](@ref) blocks are used to introduce deterministic parameters to a [`@stage`](@ref) block. See for example [Stage data](@ref). The following:
```julia
@parameters a b
```
makes the constants `a` and `b` available as model parameters. This incurs a promise that those parameters will be injected when instantiating the model, and if no default values are available they must be supplied by the user. In other words, if `sm` is a stochastic model that includes the above [`@parameters`](@ref) annotation in one of its [`@stage`](@ref) blocks, then those parameters must be supplied as keyword arguments when instantiating stochastic programs using this model:
```julia
instantiate(sm, scenarios, a = 1, b = 2)
```
Alternatively, default values can be specified directly in the [`@parameters`](@ref) block:
```julia
@parameters begin
    a = 1
    b = 2
end
```
Values supplied to [`instantiate`](@ref) are always used, and otherwise the default values are used. The responsibility is on the user to ensure that the supplied parameters support the operations used in the [`@stage`](@ref) blocks. Parameters can be reused in multiple blocks, but each occurance must be annotated by [`@parameters`](@ref) in each of the stages.

## [`@decision`](@ref) blocks

The [`@decision`](@ref) blocks are used to annotate linking variables between stages. Their usage is identical syntax-wise to JuMP's `@variable` macros. Internally, they create specialized JuMP variables with context-dependent behaviour.

## [`@known`](@ref) blocks

A [`@known`](@ref) annotation is used in subsequent stages to bring a decision defined in a previous stage into scope. Any decision defined by [`@decision`](@ref) inside a [`@stochastic_model`](@ref) automatically annotates subsequent stages with appropriate [`@known`](@ref) lines.

The [`@known`](@ref) block in the simple example above is given by
```julia
@known x₁ x₂
```
This states that the second stage of the stochastic model depends on the decisions `x₁` and `x₂` taken in the previous stage. Note again that this lines is implicitly added by [`@stochastic_model`](@ref) and is not required.

## [`@uncertain`](@ref) blocks

The [`@uncertain`](@ref) blocks are used to annotate stochastic data in the stochastic model. For flexibility, there are several different ways of doing this. However, an [`@uncertain`](@ref) annotation is always connected to some [`AbstractScenario`](@ref) type, as introduced in [Scenario data](@ref). Note, that a [`@stage`](@ref) block can only include one [`@uncertain`](@ref) block. All stochastic information in a given stage must therefore be captured in the [`@uncertain`](@ref) block of that stage.

The most simple approach is to use leverage the [`Scenario`](@ref) type. Consider the [`@uncertain`](@ref) annotation given above:
```julia
@uncertain q₁ q₂ d₁ d₂
```
This will ensure that [`Scenario`](@ref)s that are expected to have the fields `q₁`, `q₂`, `d₁` and `d₂` are injected when constructing second-stage models. Each such scenario must be supplied or sampled using a supplied sampler object. It is the responsibility of the user to ensure that each supplied or sampled [`Scenario`](@ref) has the correct fields. For example, the following yields a [`Scenario`](@ref) compatible with the above [`@uncertain`](@ref) line:
```julia
Scenario(q₁ = 24.0,
         q₂ = 28.0,
         d₁ = 500.0,
         d₂ = 100.0,
         probability = 0.4)
```
Alternatively, the same scenario is conveniently created using the [`@scenario`](@ref) macro, matching the syntax of the [`@uncertain`](@ref) declaration:
```julia
@scenario q₁ = 24.0 q₂ = 28.0 d₁ = 500.0 d₂ = 100.0 probability = 0.4
```

We can also use JuMP's container syntax:
```julia
@uncertain ξ[1:5]
@uncertain ξ[i in 1:5]
@uncertain ξ[i in 1:5, i != 3]
@uncertain ξ[i in 1:5, j in 1:5]
@uncertain ξ[i in 1:5, k in [:a,:b,:c]]
```
and then use the a corresponding formulation in the [`@scenario`](@ref) macro to generate scenarios:
```julia
ξ = @scenario ξ[1:5] = rand(5) probability = rand()
ξ = @scenario ξ[i in 1:5] i * rand() probability = rand()
ξ = @scenario ξ[i in 1:5, i != 3] i * rand() probability = rand()
ξ = @scenario ξ[i in 1:5, j in 1:5] = rand(5,5) probability = rand()
ξ = @scenario ξ[i in 1:5, k in [:a,:b,:c]] = rand(5,5) probability = rand()
```
Note, that we above sometimes assign the full random vector directly, and sometimes provide an indexed based formula.

As shown in [Stochastic data](@ref), it is also possible to introduce other scenario types, either using [`@define_scenario`](@ref) or manally as explained in [Custom scenarios](@ref) and demonstrated in the [Continuous scenario distribution](@ref) example. If we instead define the necessary scenario structure as follows:
```julia
@define_scenario SimpleScenario = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end
```
One can then use:
```julia
@uncertain ξ::SimpleScenario
```
and extract the required fields from `ξ` which will be of type `SimpleScenario` after data injection. Again, it is the responsibility of the user to supply scenarios of this type when instantiating the model. For example, the following constructs a `SimpleScenario` compatible with the above [`@uncertain`](@ref) line:
```julia
SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)
```
It is also possible to directly unpack the necessary fields using the following syntactic sugar:
```julia
@uncertain q₁ q₂ d₁ d₂ from SimpleScenario
```
The actual scenario instance can still be annotated and used if necessary:
```julia
@uncertain q₁ q₂ d₁ d₂ from ξ::SimpleScenario
```

Finally, if the [`@uncertain`](@ref) block is used within a [`@stochastic_model`](@ref) environment, it is possible to simultaneosly define the underlying scenario type. In other words,
```julia
@uncertain ξ::SimpleScenario = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end
```
```julia
@uncertain q₁ q₂ d₁ d₂ from SimpleScenario = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end
```
and
```julia
@uncertain q₁ q₂ d₁ d₂ from ξ::SimpleScenario = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end
```
are all possible methods of defining and using the `SimpleScenario` type in a `@stage` block.


## Model instantiation

A model object `sm` defined using [`@stochastic_model`](@ref) can be used to instantiate stochastic programs over both finite/infinite sample spaces and discrete/continuous random variables.

If the scenarios are associated with a discrete random variable over a finite sample space, then the corresponding stochastic program is finite and can be instantiated by providing the full list of scenarios:
```julia
sp = instantiate(sm, scenarios)
```
Here, `scenarios` is a vector of scenarios consistent with the [`@uncertain`](@ref) annotation used in the second stage of `sm`. It is the responsibility of the user to ensure that the individual probabilities of the `scenarios` sum up to one, so that the model is consistent.

If the scenarios are instead associated with a continuous random variable, with finite second moments, over an infinite sample space, then the corresponding stochastic program is not finite and must be approximated. The only supported way of doing so in StochasticPrograms is by using sampled average approximations. A finite stochastic program that approximates the stochastic model is obtained through
```julia
sp = instantiate(sm, sampler, n)
```
where `sampler` is an [`AbstractSampler`](@ref), as outlined in [Sampling](@ref), and `n` is the number of samples to include.

## Instant models

It is possible to create one-off stochastic programs without needing to first define a model object. To do so, any required scenario data structure must be defined first. Consider:
```@example instant
using StochasticPrograms

@define_scenario SimpleScenario = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end
ξ₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)
ξ₂ = SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)
```
Next, an unmodeled stochastic program can be instantiated using the two created scenarios:
```@example instant
sp = StochasticProgram([ξ₁, ξ₂], Deterministic())
```
Note that we must provide the instantiation type explicitly as well. A slightly diferrent modeling syntax is now used to define the stage models of `sp`:
```@example instant
@first_stage sp = begin
    @variable(model, x₁ >= 40)
    @variable(model, x₂ >= 20)
    @objective(model, Min, 100*x₁ + 150*x₂)
    @constraint(model, x₁ + x₂ <= 120)
end
@second_stage sp = begin
    @known x₁ x₂
    @uncertain q₁ q₂ d₁ d₂ from SimpleScenario
    @variable(model, 0 <= y₁ <= d₁)
    @variable(model, 0 <= y₂ <= d₂)
    @objective(model, Min, q₁*y₁ + q₂*y₂)
    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
end
```
Here, `@first_stage` and `@second_stage` are just syntactic sugar for `@stage 1` and `@stage 2`. This is is the definition syntax used internally by `StochasticModel` objects when instantiating stochastic programs. Note, that we must explicitly add the `@known` annotations to the second stage with this approach. We can verify that this approach yields the same stochastic program by printing and comparing to the [Quick start](@ref):
```@example instant
print(sp)
```
As a side note, it is possible to run stage definition macros on programs with existing models. This overwrites the previous model and reinstantiates all internal problems. For example, the following increases the lower bound on the second stage variables to 2:
```@example instant
@second_stage sp = begin
    @known x₁ x₂
    @uncertain q₁ q₂ d₁ d₂ from SimpleScenario
    @variable(model, 2 <= y₁ <= d₁)
    @variable(model, 2 <= y₂ <= d₂)
    @objective(model, Min, q₁*y₁ + q₂*y₂)
    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
end

print(sp)
```
It is of course also possible to do this on programs instantiated from a `StochasticModel`.
