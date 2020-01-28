# Distributed stochastic programs

Stochastic programs related to industrial applications are often associated with complex models and vast numbers of scenarios, often in the order of `1000-1000000`. Hence, the extensive form can have billions of variables and constraints, and often does not fit in memory on a single machine. This clarifies the need for solution approaches that work in parallel on distributed data when instansiating and optimizing large-scale stochastic programs.

If multiple Julia processes are available, locally or in a cluster, StochasticPrograms natively distributes any defined stochastic programs on the available processing nodes. Consider as before:
```julia
using Distributed

addprocs(3)

@everywhere using StochasticPrograms

@scenario Simple = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end

@sampler SimpleSampler = begin
    @sample begin
        return SimpleScenario(-24.0 + 2*(2*rand()-1),
                              -28.0 + (2*rand()-1),
                              300.0 + 100*(2*rand()-1),
                              300.0 + 100*(2*rand()-1),
                              probability = rand())
    end
end
```
[`@scenario`](@ref) and [`@sampler`](@ref) automatically ensures that the introduced scenario and sampler types are available on all processes. Define the stochastic model in the usual way:
```julia
simple_model = @stochastic_model begin
    @stage 1 begin
        @variable(model, x₁ >= 40)
        @variable(model, x₂ >= 20)
        @objective(model, Min, 100*x₁ + 150*x₂)
        @constraint(model, x₁ + x₂ <= 120)
    end
    @stage 2 begin
        @decision x₁ x₂
        @uncertain q₁ q₂ d₁ d₂ from SimpleScenario
        @variable(model, 0 <= y₁ <= d₁)
        @variable(model, 0 <= y₂ <= d₂)
        @objective(model, Min, q₁*y₁ + q₂*y₂)
        @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
        @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
    end
end
```
and instantiate a sampled model with 10 sceanarios:
```julia
sp = sample(simple_model, SimpleSampler(), 10)
```
the lightweight model recipes are passed to all worker nodes. The worker nodes then use the recipes and lightweight sampler object to instansiate second stage models in parallel. This is one of the intended outcomes of the design choices made in StochasticPrograms. The separation between data design and model design allows us to minimize data passing in a natural way.

Many operations in StochasticPrograms are embarassingly parallel which is exploited throughout when a stochastic program is distributed. Notably:
 - [`evaluate_decision`](@ref)
 - [`EVPI`](@ref)
 - [`VSS`](@ref)
Perform many subproblem independent operations in parallel. The best performance is achieved if the optimization of the recourse problem is performed by an algorithm that can operate in parallel on the distributed stochastic programs. The solver suites `LShapedSolvers` and `ProgressiveHedgingSolvers` are examples of this. For example, we can optimize the distributed version of the simple stochastic program with a parallelized L-shaped algorithm as follows:
```julia
using LShapedSolvers
using GLPKMathProgInterface

optimize!(sp, solver = LShapedSolver(GLPKSolverLP(), execution = Synchronous()))
```
```julia
Distributed L-Shaped Gap  Time: 0:00:03 (6 iterations)
  Objective:       -855.8333333333339
  Gap:             0.0
  Number of cuts:  7
:Optimal
```

A quick note should also be made about the API calls that become less efficient in a distributed setting. This includes all calls that collect data that reside on remote processes. The functions in this category that involve the most data passing is [`scenarios`](@ref), which fetches all scenarios in the stochastic program, and [`subproblems`](@ref), which fetches all second stage models in the stochastic program. If these collections are required frequently it is recommended to not distribute the stochastic program. This can be ensured by supplying `procs = [1]` to the constructor call. Individual queries `scenario(stochasticprogram, i)` and `subproblem(stochasticprogram, i)` are viable depending on the size of the scenarios/models. If a `MathProgBase` solver is supplied to a distributed stochastic program it will fetch all scenarios to the master node and attempt to build the extensive form. Long computation times are expected for large-scale models, assuming they fit in memory. If so, it is again recommended to avoid distributing the stochastic program through `procs = [1]`. The best approach is to use a structured solver that can operate on distributed stochastic programs, such as `LShapedSolvers` or `ProgressiveHedgingSolvers`.
