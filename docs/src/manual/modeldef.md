# Model definition

Another central idea in StochasticPrograms is deferred model instantiation. Consider again the simple problem introduced in the [Quick start](@ref), but with some slight differences:
```@example deferred
using StochasticPrograms

@scenario Simple = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end

sp = StochasticProgram(SimpleScenario)

@first_stage sp = begin
    @variable(model, x₁ >= 40)
    @variable(model, x₂ >= 20)
    @objective(model, Min, 100*x₁ + 150*x₂)
    @constraint(model, x₁ + x₂ <= 120)
end defer

@second_stage sp = begin
    @decision x₁ x₂
    ξ = scenario
    @variable(model, 0 <= y₁ <= ξ.d₁)
    @variable(model, 0 <= y₂ <= ξ.d₂)
    @objective(model, Min, ξ.q₁*y₁ + ξ.q₂*y₂)
    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
end
```
There are two things to note here. First, no scenarios have been loaded yet, so no second stage models were instansiated. Moreover, the first stage was defined with the `defer` keyword, and the printout states that the first stage is deferred. This means that the first stage model has not yet been instansiated, but the stochastic program instance has a model recipe that can be used to generate it when required:
```@example deferred
println(has_generator(sp, :stage_1))
println(has_generator(sp, :stage_2))
```
Now, we add the simple scenarios to the stochastic program instance, also with a defer keyword:
```@example deferred
ξ₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)
ξ₂ = SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)
add_scenarios!(sp, [ξ₁, ξ₂], defer = true)
```
The two scenarios are loaded, but no second stage models were instansiated. Deferred stochastic programs will always be generated in full when required. For instance, this occurs when calling [`optimize!`](@ref). Furthermore, we can explicitly instansiate the stochastic program using [`generate!`](@ref):
```@example deferred
generate!(sp)
```
This gives a clear separation between data design and model design, and gives flexibility when defining stochastic programs. The model recipes are also used internally to create different stochastic programming constructs, such as outcome models and wait-and-see models. Moreover, deferred model instantiation is the foundation for the distributed functionality in Stochastic Programs, to be described next.
