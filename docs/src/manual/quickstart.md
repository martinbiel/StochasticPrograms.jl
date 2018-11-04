# Quick start

## Installation

StochasticPrograms is not yet registered and is therefore installed as follows:
```julia
pkg> add https://github.com/martinbiel/StochasticPrograms.jl
```
Afterwards, the functionality can be made available in a module or REPL through:
```@example simple
using StochasticPrograms
```

## A simple stochastic program

To showcase the use of StochasticPrograms we will walk through a simple example. Consider the following stochastic program: (taken from [Introduction to Stochastic Programming](https://link.springer.com/book/10.1007%2F978-1-4614-0237-4)).

```math
\DeclareMathOperator*{\minimize}{minimize}
\begin{aligned}
 \minimize_{x_1, x_2 \in \mathbb{R}} & \quad 100x_1 + 150x_2 + \operatorname{\mathbb{E}}_{\omega} \left[Q(x_1,x_2,\xi)\right] \\
 \text{s.t.} & \quad x_1+x_2 \leq 120 \\
 & \quad x_1 \geq 40 \\
 & \quad x_2 \geq 20
\end{aligned}
```
where
```math
\begin{aligned}
 Q(x_1,x_2,\xi) = \min_{y_1,y_2 \in \mathbb{R}} & \quad q_1(\xi)y_1 + q_2(\xi)y_2 \\
 \text{s.t.} & \quad 6y_1+10y_2 \leq 60x_1 \\
 & \quad 8y_1 + 5y_2 \leq 80x_2 \\
 & \quad 0 \leq y_1 \leq d_1(\xi) \\
 & \quad 0 \leq y_2 \leq d_2(\xi)
\end{aligned}
```
and the stochastic variable
```math
  \xi = \begin{pmatrix}
    d_1 & d_2 & q_1 & q_2
  \end{pmatrix}^T
```
takes on the value
```math
  \xi_1 = \begin{pmatrix}
    500 & 100 & -24 & -28
  \end{pmatrix}^T
```
with probability ``0.4`` and
```math
  \xi_1 = \begin{pmatrix}
    300 & 300 & -28 & -32
  \end{pmatrix}^T
```
with probability ``0.6``. In the following, we consider how to model, analyze, and solve this stochastic program using StochasticPrograms.

## Scenario definition

First, we introduce a scenario type that can encompass the scenarios ``\xi_1`` and ``\xi_2`` above. This can be achieved conviently through the `@scenario` macro:
```@example simple
@scenario Simple = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end
```
Now, ``\xi_1`` and ``\xi_2`` can be created through:
```@example simple
ξ₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)
```
and
```@example simple
ξ₂ = SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)
```
Some useful functionality is automatically made available when introducing scenarios in this way. For example, we can check the discrete probability of a given scenario occuring:
```@example simple
probability(ξ₁)
```
Moreover, we can form the expected scenario out of a given set:
```@example simple
ξ̄ = expected([ξ₁, ξ₂])
```

## Stochastic program definition

We are now ready to create a stochastic program based on the introduced scenario type. Consider:
```@example simple
sp = StochasticProgram([ξ₁, ξ₂])
```
The above command creates a stochastic program and preloads the two defined scenarios. Now, we provide model recipes for the first and second stage of the example problem. The first stage is straightforward, and is defined using JuMP syntax inside a `@first_stage` block:
```@example simple
@first_stage sp = begin
    @variable(model, x₁ >= 40)
    @variable(model, x₂ >= 20)
    @objective(model, Min, 100*x₁ + 150*x₂)
    @constraint(model, x₁ + x₂ <= 120)
end
```
The recipe was immediately used to generate an instance of the first stage model. Next, we give a second stage recipe inside a `@second_stage` block:
```@example simple
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
Every first stage variable that occurs in the second stage model is annotated with `@decision` at the beginning of the definition. Moreover, the scenario data is referenced through `scenario`. Instances of the defined scenario `SimpleScenario` will be injected to create instances of the second stage model. The second stage recipe is immediately used to generate second stage models for each preloaded scenario. Hence, the stochastic program definition is complete. We can now print the program and confirm that it indeed models the example recourse problem given above:
```@example simple
print(sp)
```

## Deterministically equivalent problem

Since the example problem is small it is straightforward to work out the extended form:
```math
\begin{aligned}
 \minimize_{x_1, x_2, y_{11}, y_{21}, y_{12}, y_{22} \in \mathbb{R}} & \quad 100x_1 + 150x_2 - 9.6y_{11} - 11.2y_{21} - 16.8y_{12} - 19.2y_{22}  \\
 \text{s.t.} & \quad x_1 + x_2 \leq 120 \\
 & \quad 6 y_{11} + 10 y_{21} \leq 60 x_1 \\
 & \quad 8 y_{11} + 5 y_{21} \leq 80 x_2 \\
 & \quad 6 y_{12} + 10 y_{22} \leq 60 x_1 \\
 & \quad 8 y_{12} + 5 y_{22} \leq 80 x_2 \\
 & \quad x_1 \geq 40 \\
 & \quad x_2 \geq 20 \\
 & \quad 0 \leq y_{11} \leq 500 \\
 & \quad 0 \leq y_{21} \leq 100 \\
 & \quad 0 \leq y_{12} \leq 300 \\
 & \quad 0 \leq y_{22} \leq 300
\end{aligned}
```
which is also commonly referred to as the deterministically equivalent problem. This construct is available in StochasticPrograms through:
```@example simple
dep = DEP(sp)
print(dep)
```

## Optimal first stage decision

The defined stochastic program can be optimized by supplying a capable solver. Structure exploiting solvers are outlined in [Structured solvers](@ref). In addition, it is possible to give a MathProgBase solver capable of solving linear programs. For example, we can solve `sp` with the GLPK solver as follows:
```@example simple
using GLPKMathProgInterface

optimize!(sp, solver = GLPKSolverLP())
```
Internally, this solve the extended form of `sp` above. We can now inspect the optimal first stage decision through:
```@example simple
optimal_decision(sp)
```
Moreover, the optimal value, i.e. the expected outcome of using the optimal decision, is acquired through:
```@example simple
optimal_value(sp)
```

## Wait-and-see models

If we assume that we know what the actual outcome will be, we would be interested in the optimal course of action in that scenario. This is the concept of wait-and-see models. For example if ``ξ₁`` is believed to be the actual outcome, we can define a wait-and-see model as follows:
```@example simple
ws = WS(sp, ξ₁)
print(ws)
```
The optimal first stage decision in this scenario can be determined through:
```@example simple
WS_decision(sp, ξ₁, solver = GLPKSolverLP())
```
Another important concept is the wait-and-see model corresponding to the expected future scenario. This is referred to as the *expected value problem* and can be generated through:
```@example simple
evp = EVP(sp)
print(evp)
```
Internally, this generates the expected scenario out of the available scenarios and forms the respective wait-and-see model. The optimal first stage decision associated with the expected value problem is conviently determined using
```@example simple
EVP_decision(sp, solver = GLPKSolverLP())
```

## Stochastic performance

Finally, we consider some performance measures of the defined model. The *expected value of perfect information* is the difference between the value of the recourse problem and the expected result of having perfect knowledge. In other words, it involes solving the recourse problem as well as every wait-and-see model that can be formed from the available scenarios. We calculate it as follows:
```@example simple
EVPI(sp, solver = GLPKSolverLP())
```
Another
```@example simple
VSS(sp, solver = GLPKSolverLP())
```

```@example simple
ξ₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.3)
ξ₂ = SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.5)
ξ₃ = SimpleScenario(-38.0, -42.0, 100.0, 400.0, probability = 0.2)
sp2 = StochasticProgram([ξ₁, ξ₂, ξ₃])
transfer_model!(sp2, sp)
generate!(sp2)
VSS(sp2, solver = GLPKSolverLP())
```
