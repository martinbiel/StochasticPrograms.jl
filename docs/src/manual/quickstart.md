# Quick start

## Installation

StochasticPrograms is installed as follows:
```julia
pkg> add StochasticPrograms
```
Afterwards, the functionality can be made available in a module or REPL through:
```@example simple
using StochasticPrograms
```

## Stochastic programs

Consider some probability space ``(\Omega,\mathcal{F},\pi)`` where ``\Omega`` is a sample space, ``\mathcal{F}`` is a ``\sigma``-algebra over ``\Omega`` and ``\pi: \mathcal{F} \to [0,1]`` is a probability measure. Let ``\xi(\omega): \Omega \to \mathbb{R}^{N}`` be some random variable on ``\Omega`` with finite second moments. A two-stage linear stochastic program has the following mathematical representation:
```math
\DeclareMathOperator*{\minimize}{minimize}
\begin{aligned}
 \minimize_{x \in \mathbb{R}^n} & \quad c^T x + \operatorname{\mathbb{E}}_{\omega} \left[Q(x,\xi(\omega))\right] \\
 \text{s.t.} & \quad Ax = b \\
 & \quad x \geq 0
\end{aligned}
```
where
```math
\begin{aligned}
    Q(x,\xi(\omega)) = \min_{y \in \mathbb{R}^m} & \quad q_{\omega}^T y \\
    \text{s.t.} & \quad T_{\omega}x + Wy = h_{\omega} \\
    & \quad y \geq 0
  \end{aligned}
```
If the sample space ``\Omega`` is finite, stochastic program has a closed form that can be represented on a computer. Such functionality is provided by StochasticPrograms. If the sample space ``\Omega`` is infinite, sampling techniques can be used to represent the stochastic program using finite [`SAA`](@ref) instances.

## A simple stochastic program

To showcase the use of StochasticPrograms we will walk through a simple example. Consider the following stochastic program: (taken from [Introduction to Stochastic Programming](https://link.springer.com/book/10.1007%2F978-1-4614-0237-4)).

```math
\DeclareMathOperator*{\minimize}{minimize}
\begin{aligned}
 \minimize_{x_1, x_2 \in \mathbb{R}} & \quad 100x_1 + 150x_2 + \operatorname{\mathbb{E}}_{\omega} \left[Q(x_1,x_2,\xi(\omega))\right] \\
 \text{s.t.} & \quad x_1+x_2 \leq 120 \\
 & \quad x_1 \geq 40 \\
 & \quad x_2 \geq 20
\end{aligned}
```
where
```math
\begin{aligned}
 Q(x_1,x_2,\xi(\omega)) = \min_{y_1,y_2 \in \mathbb{R}} & \quad q_1(\omega)y_1 + q_2(\omega)y_2 \\
 \text{s.t.} & \quad 6y_1+10y_2 \leq 60x_1 \\
 & \quad 8y_1 + 5y_2 \leq 80x_2 \\
 & \quad 0 \leq y_1 \leq d_1(\omega) \\
 & \quad 0 \leq y_2 \leq d_2(\omega)
\end{aligned}
```
and the stochastic variable
```math
  \xi(\omega) = \begin{pmatrix}
     q_1(\omega) & q_2(\omega) & d_1(\omega) & d_2(\omega)
  \end{pmatrix}^T
```
takes on the value
```math
  \xi_1 = \begin{pmatrix}
    -24 & -28 & 500 & 100
  \end{pmatrix}^T
```
with probability ``0.4`` and
```math
  \xi_1 = \begin{pmatrix}
    -28 & -32 & 300 & 300
  \end{pmatrix}^T
```
with probability ``0.6``. In the following, we consider how to model, analyze, and solve this stochastic program using StochasticPrograms. In many examples, a MathProgBase solver is required. Hence, we load the GLPK solver.
```@example simple
using GLPKMathProgInterface
```

## Stochastic model definition

First, we define a stochastic model that describes the introduced stochastic program above.

```@example simple
simple_model = @stochastic_model begin
    @stage 1 begin
        @variable(model, x₁ >= 40)
        @variable(model, x₂ >= 20)
        @objective(model, Min, 100*x₁ + 150*x₂)
        @constraint(model, x₁ + x₂ <= 120)
    end
    @stage 2 begin
        @decision x₁ x₂
        @uncertain q₁ q₂ d₁ d₂
        @variable(model, 0 <= y₁ <= d₁)
        @variable(model, 0 <= y₂ <= d₂)
        @objective(model, Min, q₁*y₁ + q₂*y₂)
        @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
        @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
    end
end
```
The optimization models in the first and second stage are defined using JuMP syntax inside `@stage` blocks. Every first-stage variable that occurs in the second stage model is annotated with `@decision` at the beginning of the definition. Moreover, the `@uncertain` annotation specifies that the variables `q₁`, `q₂`, `d₁` and `d₂` are uncertain. Instances of the uncertain variables will later be injected to create instances of the second stage model.

## Instantiating the stochastic program

Next, we create the two instances ``\xi_1`` and ``\xi_2`` of the random variable. For simple models this is conveniently achieved through the [`Scenario`](@ref) type. ``\xi_1`` and ``\xi_2`` can be created as follows:
```@example simple
ξ₁ = Scenario(q₁ = -24.0, q₂ = -28.0, d₁ = 500.0, d₂ = 100.0, probability = 0.4)
```
and
```@example simple
ξ₂ = Scenario(q₁ = -28.0, q₂ = -32.0, d₁ = 300.0, d₂ = 300.0, probability = 0.6)
```
where the variable names should match those given in the `@uncertain` annotation. We are now ready to instantiate the stochastic program introduced above.
```@example simple
sp = instantiate(simple_model, [ξ₁, ξ₂], solver = GLPKSolverLP())
```
The above command creates an instance of the first stage model and second stage model instances for each of the supplied scenarios. The provided solver will be used internally when necessary. For clarity, we will still explicitly supply a solver when it is required. We can print the stochastic program and confirm that it indeed models the example recourse problem given above:
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

## Sampled average approximation

In the above, the probability space consists of only two scenarios and the stochastic program can hence be represented in a closed form. If it instead holds that ``\xi`` follows say a normal distribution, then it is no longer possible to represent the full stochastic program since this would require infinite scenarios. We then revert to sampling-based techniques. For example, let ``\xi \sim \mathcal{N}(\mu, \Sigma)`` with
```math
\mu = \begin{pmatrix}
 -28 \\
 -32 \\
 300 \\
 300
\end{pmatrix}, \quad \Sigma = \begin{pmatrix}
 2 & 0.5 & 0 & 0 \\
 0.5 & 1 & 0 & 0 \\
 0 & 0 & 50 & 20 \\
 0 & 0 & 20 & 30
\end{pmatrix}
```
To approximate the resulting stochastic program in StochasticPrograms, we first create a sampler object capable of generating scenarios from this distribution. This is most conveniently achieved using the [`@sampler`](@ref) macro:
```@example simple
using Distributions

@sampler SimpleSampler = begin
    N::MvNormal

    SimpleSampler(μ, Σ) = new(MvNormal(μ, Σ))

    @sample Scenario begin
        x = rand(sampler.N)
        return Scenario(q₁ = x[1], q₂ = x[2], d₁ = x[3], d₂ = x[4], probability = pdf(sampler.N, x))
    end
end

μ = [-28, -32, 300, 300]
Σ = [2 0.5 0 0
     0.5 1 0 0
     0 0 50 20
     0 0 20 30]

sampler = SimpleSampler(μ, Σ)
```
Now, we can use the same stochastic model created before and the created sampler object to generate a stochastic average approximation (SAA) of the stochastic program. For now, we create a small SAA model of just 5 scenarios:
```@example simple
saa = SAA(simple_model, sampler, 5)
```
Typically, a large number of scenarios are required to accurately represent the stochastic program. We will consider this in more depth below. Let us first also print the SAA model:
```@example simple
print(saa)
```
In the subsequent discussions, note that `sp` represents the finite simple stochastic program with known closed form, `simple_model` contains the mathematical representation of the general stochastic model, and `saa` are approximated instances of the general model.

## Evaluate decisions

Decision evaluation is an important concept in stochastic programming. The expected result of taking a given first-stage decision ``x`` is given by
```math
V(x) = c^T x + \operatorname{\mathbb{E}}_{\omega} \left[Q(x,\xi(\omega))\right]
```
If the sample space is finite, the above expressions has a closed form that is readily calculated. Consider the following first-stage decision:
```@example simple
x = [40., 20.]
```
The expected result of taking this decision in the simple finite model can be determined through:
```@example simple
evaluate_decision(sp, x, solver = GLPKSolverLP())
```
The supplied solver is used to solve all available second stage models, with fixed first-stage values. These outcome models can be built manually by supplying a scenario and the first-stage decision.
```@example simple
print(outcome_model(sp, x, ξ₁))
```
Moreover, we can evaluate the result of the decision in a given scenario, i.e. solving a single outcome model, through:
```@example simple
evaluate_decision(sp, x, ξ₁, solver = GLPKSolverLP())
```
If the sample space is infinite, or if the underlying random variable ``\xi`` is continuous, a first-stage decision can only be evaluated in a stochastic sense. For example, note the result of evaluating the decision on the SAA model created above:
```@example simple
evaluate_decision(saa, x, solver = GLPKSolverLP())
```
and compare it to the result of evaluating it on another SAA model of similar size:
```@example simple
another_saa = SAA(simple_model, sampler, 5)
evaluate_decision(another_saa, x, solver = GLPKSolverLP())
```
which, if any, of these values should be a candidate for the true value of ``V(x)``? A more precise result is obtained by evaluating the decision using a sampled-based approach. Such querys are instead made to the `simple_model` object by supplying an appropriate [`AbstractSampler`](@ref) and a desired confidence level. Consider:
```@example simple
evaluate_decision(simple_model, x, sampler, solver = GLPKSolverLP(), confidence = 0.9)
```
The result is a 90% confidence interval around ``V(x)``. Consult [`evaluate_decision`](@ref) for the tweakable parameters that govern the resulting confidence interval.

## Optimal first-stage decision

The optimal first-stage decision is the decision that gives the best expected result over all available scenarios. This decision can be determined by solving the deterministically equivalent problem, by supplying a capable solver. Structure exploiting solvers are outlined in [Structured solvers](@ref). In addition, it is possible to give a MathProgBase solver capable of solving linear programs. For example, we can solve `sp` with the GLPK solver as follows:
```@example simple
optimize!(sp, solver = GLPKSolverLP())
```
Internally, this generates and solves the extended form of `sp`. We can now inspect the optimal first-stage decision through:
```@example simple
x_opt = optimal_decision(sp)
```
Moreover, the optimal value, i.e. the expected outcome of using the optimal decision, is acquired through:
```@example simple
optimal_value(sp)
```
which of course coincides with the result of evaluating the optimal decision:
```@example simple
evaluate_decision(sp, x_opt, solver = GLPKSolverLP())
```
This value is commonly referred to as the *value of the recourse problem* (VRP). We can also calculate it directly through:
```@example simple
VRP(sp, solver = GLPKSolverLP())
```

If the sample space is infinite, or if the underlying random variable ``\xi`` is continuous, the value of the recourse problem can not be computed exactly. However, by supplying an [`AbstractSampler`](@ref) we can use sample-based techniques to compute a confidence interval around the true optimum:
```@example simple
confidence_interval(simple_model, sampler, solver = GLPKSolverLP(), confidence = 0.95)
```
Similarly, a first-stage decision is only optimal in a stochastic sense. Such solutions can be obtained from running [`optimize`](@ref) on the stochastic model object, supplying a sample-based solver. Sample-based solvers are also outlined in [Structured solvers](@ref). StochasticPrograms includes the [`SAASolver`](@ref), which runs a simple sequential SAA algorithm. Emerging SAA problems are solved by a supplied [`AbstractStructuredSolver`](@ref) or by a `MathProgBase` solver through the extensive form. Consider the following:
```@example simple
solution = optimize(simple_model, sampler, solver = SAASolver(GLPKSolverLP()), confidence = 0.95)
```
The result is a [`StochasticSolution`](@ref), which includes an optimal solution estimate as well as a confidence interval around the solution. The approximately optimal first-stage decision is obtained by
```@example simple
decision(solution)
```

## Wait-and-see models

If we assume that we know what the actual outcome will be, we would be interested in the optimal course of action in that scenario. This is the concept of wait-and-see models. For example if ``ξ₁`` is believed to be the actual outcome, we can define a wait-and-see model as follows:
```@example simple
ws = WS(sp, ξ₁)
print(ws)
```
The optimal first-stage decision in this scenario can be determined through:
```@example simple
x₁ = WS_decision(sp, ξ₁, solver = GLPKSolverLP())
```
We can evaluate this decision:
```@example simple
evaluate_decision(sp, x₁, solver = GLPKSolverLP())
```
The outcome is of course worse than taking the optimal decision. However, it would perform better if ``ξ₁`` is the actual outcome:
```@example simple
evaluate_decision(sp, x₁, ξ₁, solver = GLPKSolverLP())
```
as compared to:
```@example simple
evaluate_decision(sp, x_opt, ξ₁, solver = GLPKSolverLP())
```
Another important concept is the wait-and-see model corresponding to the expected future scenario. This is referred to as the *expected value problem* and can be generated through:
```@example simple
evp = EVP(sp)
print(evp)
```
Internally, this generates the expected scenario out of the available scenarios and forms the respective wait-and-see model. The optimal first-stage decision associated with the expected value problem is conviently determined using
```@example simple
x̄ = EVP_decision(sp, solver = GLPKSolverLP())
```
Again, we can evaluate this decision:
```@example simple
evaluate_decision(sp, x̄, solver = GLPKSolverLP())
```
This value is often referred to as *the expected result of using the expected value solution* (EEV), and is also available through:
```@example simple
EEV(sp, solver = GLPKSolverLP())
```

## Stochastic performance

Finally, we consider some performance measures of the defined model. The *expected value of perfect information* is the difference between the value of the recourse problem and the expected result of having perfect knowledge. In other words, it involes solving the recourse problem as well as every wait-and-see model that can be formed from the available scenarios. We calculate it as follows:
```@example simple
EVPI(sp, solver = GLPKSolverLP())
```
The resulting value indicates the expected gain of having perfect information about future scenarios. Another concept is the *value of the stochastic solution*, which is the difference between the value of the recourse problem and the EEV. We calculate it as follows:
```@example simple
VSS(sp, solver = GLPKSolverLP())
```
The resulting value indicates the gain of including uncertainty in the model formulation.
