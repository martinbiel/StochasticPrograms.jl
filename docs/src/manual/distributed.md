# Distributed stochastic programs

Stochastic programs related to industrial applications are often associated with complex models and vast numbers of scenarios, often in the order of `1000-1000000`. Hence, the extensive form can have billions of variables and constraints, and often does not fit in memory on a single machine. This clarifies the need for solution approaches that work in parallel on distributed data when instansiating and optimizing large-scale stochastic programs.

If multiple Julia processes are available, locally or in a cluster, StochasticPrograms natively distributes any defined stochastic programs on the available processing nodes. As an example, we revisit the simple problem introduced in the [Quick start](@ref):
```julia distributed
using Distributed

addprocs(3)

using StochasticPrograms

@scenario Simple = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end
```
[`@scenario`](@ref) automatically ensures that the introduced scenario type is available on all processes. Define the stochastic program in the usual way:
```julia
sp = StochasticProgram(SimpleScenario)
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
```
```julia
Distributed stochastic program with:
 * 0 scenarios of type SimpleScenario
 * 2 decision variables
 * 0 recourse variables
Solver is default solver
```
The printout indicates that the created stochastic program is distributed. Technically, nothing has been distributed yet since there are no scenarios. The first stage problem always reside on the master node. Let us now add the two scenarios. We could add the in the usual way with [`add_scenario!`](@ref). However, this would create the scenario data on the master node and then send the data. This is fine for this small scenario, but for a large-scale program this would involve a lot of data passing. As stated [`@scenario`](@ref) made the scenario type available on all nodes, so a better approach is to:
```julia
add_scenario!(sp; defer = true, w = 2) do
    return SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)
end
add_scenario!(sp; defer = true, w = 3) do
    return SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)
end
```
```julia
Distributed stochastic program with:
 * 2 scenarios of type SimpleScenario
 * 2 decision variables
 * deferred second stage
Solver is default solver
```
This instansiates the scenarios locally on each node and loads them into local storage. An even more effective paradigm is to only send a lightweight [`AbstractSampler`](@ref) object to each node, and have them sample any required scenario. This is the recommended approach for large-scale stochastic programs. The model generation was purposefully deferred to make a final point. If we now call:
```julia
generate!(sp)
```
```julia
Distributed stochastic program with:
 * 2 scenarios of type SimpleScenario
 * 2 decision variables
 * 2 recourse variables
Solver is default solver
```
the lightweight model recipes are passed to all worker nodes. The worker nodes then use the recipes to instansiate second stage models in parallel. This is one of the intended outcomes of the design choices made in StochasticPrograms. The separation between data design and model design allows us to minimize data passing in a natural way.

Many operations in StochasticPrograms are embarassingly parallel which is exploited throughout when a stochastic program is distributed. Notably:
 - [`evaluate_decision`](@ref)
 - [`EVPI`](@ref)
 - [`VSS`](@ref)
Perform many subproblem independent operations in parallel. The best performance is achieved if the optimization of the recourse problem is performed by an algorithm that can operate in parallel on the distributed stochastic programs. The solver suites [LShapedSolvers.jl](@ref) and [ProgressiveHedgingSolvers.jl](@ref) are examples of this. For example, we can optimize the distributed version of the simple stochastic program with a parallelized L-shaped algorithm as follows:
```julia
using LShapedSolvers
using GLPKMathProgInterface

optimize!(sp, solver = LShapedSolver(:dls, GLPKSolverLP()))
```
```julia
Distributed L-Shaped Gap  Time: 0:00:03 (6 iterations)
  Objective:       -855.8333333333339
  Gap:             0.0
  Number of cuts:  7
:Optimal
```

A quick note should also be made about the API calls that become less efficient in a distributed setting. This includes all calls that collect data that reside on remote processes. The functions in this category that involve the most data passing is [`scenarios`](@ref), which fetches all scenarios in the stochastic program, and [`subproblems`](@ref), which fetches all second stage models in the stochastic program. If these collections are required frequently it is recommended to not distribute the stochastic program. This can be ensured by supplying `procs = [1]` to the constructor call. Individual queries `scenario(stochasticprogram, i)` and `subproblem(stochasticprogram, i)` are viable depending on the size of the scenarios/models. If a `MathProgBase` solver is supplied to a distributed stochastic program it will fetch all scenarios to the master node and attempt to build the extensive form. Long computation times are expected for large-scale models, assuming they fit in memory. If so, it is again recommended to avoid distributing the stochastic program through `procs = [1]`. The best approach is to use a structured solver that can operate on distributed stochastic programs, such as [LShapedSolvers.jl](@ref) or [ProgressiveHedgingSolvers.jl](@ref).
