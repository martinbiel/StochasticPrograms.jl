# Stochastic models

Now, tools related to model definitions in StochasticPrograms are introduced in more detail.

## Model objects

To further seperate model design from data design, StochasticPrograms provides a stochastic model object. This object can be used to store the optimization models before introducing scenario data. Consider the following alternative approach to the simple problem introduced in the [Quick start](@ref):
```@example stochasticmodel
using StochasticPrograms

simple_model = StochasticModel((sp) -> begin
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
end)
```
The resulting model object can be used to [`instantiate`](@ref) different stochastic programs as long as the corresponding scenario data conforms to the second stage model. For example, lets introduce a similar scenario type and use it to construct the same stochastic program as in the [Quick start](@ref):
```@example stochasticmodel
@scenario AnotherSimple = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end

ξ₁ = AnotherSimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)
ξ₂ = AnotherSimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)

sp = instantiate(simple_model, [ξ₁, ξ₂])
```
Moreoever, [`SAA`](@ref) models are constructed in a straightforward way. Consider the following:
```@example stochasticmodel
@sampler AnotherSimple = begin
    @sample begin
        return AnotherSimpleScenario(-24.0 + 2*(2*rand()-1),
                                     -28.0 + (2*rand()-1),
                                     300.0 + 100*(2*rand()-1),
                                     300.0 + 100*(2*rand()-1),
                                     probability = rand())
    end
end

saa = SAA(simple_model, AnotherSimpleSampler(), 10)
```
This allows the user to clearly distinguish between the often abstract *base-model*:
```math
\DeclareMathOperator*{\minimize}{minimize}
\begin{aligned}
 \minimize_{x \in \mathbb{R}^n} & \quad c^T x + \operatorname{\mathbb{E}}_{\omega} \left[Q(x,\xi(\omega))\right] \\
 \text{s.t.} & \quad Ax = b \\
 & \quad x \geq 0
\end{aligned}
```
and *look-ahead* models that approximate the base-model:
```math
\DeclareMathOperator*{\minimize}{minimize}
\begin{aligned}
 \minimize_{x \in \mathbb{R}^n, y_s \in \mathbb{R}^m} & \quad c^T x + \sum_{s = 1}^n \pi_s q_s^Ty_s \\
 \text{s.t.} & \quad Ax = b \\
 & \quad T_s x + W y_s = h_s, \quad &s = 1, \dots, n \\
 & \quad x \geq 0, y_s \geq 0, \quad &s = 1, \dots, n
\end{aligned}
```

## Deferred models

Another tool StochasticPrograms is deferred model instantiation. Consider again the simple problem introduced in the [Quick start](@ref), but with some slight differences:
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
