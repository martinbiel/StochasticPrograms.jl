# StochasticPrograms

[![Build Status](https://travis-ci.org/martinbiel/StochasticPrograms.jl.svg?branch=master)](https://travis-ci.org/martinbiel/StochasticPrograms.jl)

[![Coverage Status](https://coveralls.io/repos/martinbiel/StochasticPrograms.jl/badge.svg?branch=master&service=github)](https://coveralls.io/github/martinbiel/StochasticPrograms.jl?branch=master)

[![codecov.io](http://codecov.io/github/martinbiel/StochasticPrograms.jl/coverage.svg?branch=master)](http://codecov.io/github/martinbiel/StochasticPrograms.jl?branch=master)

## Description

`StochasticPrograms` is a modeling framework for two-stage stochastic programming problems. In other words, it can be used to model recourse problems where an initial decision is taken, unknown parameters are observed, followed by recourse decisions to hedge the original decisions. The underlying optimization problems are formulated in [JuMP.jl][JuMP]. In `StochasticPrograms`, the construction of second stage models is deferred through anonymous creation functions. As a result, scenario data can be loaded/reloaded to create/rebuild the recourse model at a later stage, possibly on separate machines in a cluster. Another consequence of deferred model creation is that `StochasticPrograms` can provide stochastic programming constructs, such as EVPI and VSS, to gain deeper insights about formulated recourse problems. A good introduction to recourse models, and to the stochastic programming constructs provided in this package, is given in [Introduction to Stochastic Programming][Birge]. Like [StructJuMP.jl][Struct], recourse models can be instantiated in parallel on distributed memory. However, instead of relying on MPI, the parallel capabilities of `StochasticPrograms` are implemented using the standard Julia library for distributed computing.

Recourse models created in `StochasticPrograms` can be solved in two ways. Either, by providing an `AbstractMathProgSolver` which will solve an extensive deterministically equivalent [JuMP.jl][JuMP] formulation of the recourse model. Or, provide an `AbstractStructuredSolver`, such as those provided in [LShapedSolvers.jl][LShaped], to solve the recourse model using specialized decomposition strategies for stochastic programs.

[JuMP]: https://github.com/JuliaOpt/JuMP.jl
[Struct]: https://github.com/StructJuMP/StructJuMP.jl
[Birge]: https://link.springer.com/book/10.1007%2F978-1-4614-0237-4
[LShaped]: https://github.com/martinbiel/LShapedSolvers.jl

## Basic Usage

Consider the following simple recourse problem, which will be used to exemplify the use of `StochasticPrograms`, given below:

```
minimize    100x₁ + 150x₂ + E_ξ(q₁(ξ)y₁ + q₂(ξ)y₂)
subject to     x₁ + x₂ ≤ 120
            6y₁ + 10y₂ ≤ 60x₁
             8y₁ + 5y₂ ≤ 80x₂
                0 ≤ y₁ ≤ d₁(ξ)
                0 ≤ y₂ ≤ d₂(ξ)
                    x₁ ≥ 40,
                    x₂ ≥ 20,
```

where the stochastic variable `ξ = (d₁,d₂,q₁,q₂)` takes on the values `(500,100,-24,-28)` with probability `0.4` and `(300,300,-28,-32)` with probability `0.6`.

### Defining Scenarios

The first step to creating the recourse problem above in `StochasticPrograms` is to create a scenario struct as a child of the abstract type `AbstractScenarioData`. The struct should contain all stochastic parameters, as well as the probability, of the modeled scenarios. A possible implementation of the scenarios in the recourse problem above could be as follows:

```julia
julia> struct SimpleScenario <: AbstractScenarioData
           π::Float64
           d::Vector{Float64}
           q::Vector{Float64}
       end

julia> StochasticPrograms.probability(s::SimpleScenario) = s.π

```

where `π` specifys the probability of the scenario occuring. If the probability function is not specified, `StochasticPrograms` assumes that probability of a scenario is stored in a field named `π`. Now, the two scenarios above can be constructed:

```julia
julia> s1 = SimpleScenario(0.4,[500.0,100],[-24.0,-28])
SimpleScenario(0.4, [500.0, 100.0], [-24.0, -28.0])

julia> s2 = SimpleScenario(0.6,[300.0,300],[-28.0,-32])
SimpleScenario(0.6, [300.0, 300.0], [-28.0, -32.0])
```

Some stochastic programming constructs require the expected value of a given set of scenarios, defined here as:

```julia
julia> function StochasticPrograms.expected(sds::Vector{SimpleScenario})
           sd = SimpleScenario(1,sum([s.π*s.d for s in sds]),sum([s.π*s.q for s in sds]))
       end

```

### Creating a Stochastic Program

```julia
julia> using StochasticPrograms

julia> using Clp

julia> sp = StochasticProgram([s1,s2],solver=ClpSolver())

julia> @first_stage sp = begin
           @variable(model, x₁ >= 40)
           @variable(model, x₂ >= 20)
           @objective(model, Min, 100*x₁ + 150*x₂)
           @constraint(model, x₁+x₂ <= 120)
       end

julia> @second_stage sp = begin
           @decision x₁ x₂
           s = scenario
           @variable(model, 0 <= y₁ <= s.d[1])
           @variable(model, 0 <= y₂ <= s.d[2])
           @objective(model, Min, s.q[1]*y₁ + s.q[2]*y₂)
           @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
           @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
       end
```

Two things are important to note in the formulation of the second stage problem. First, the decision variables from the first stage that influence the second stage must be annotated with `@decision`. Second, the scenario specific data is accessed through the keyword `scenario`. Above, `scenario` will be structure of type `SimpleScenario`, containing the necessary fields `q` and `d`. As two scenarios were preloaded when the `StochasticProgram` was created, a recourse problem is created instantly:

```julia
julia> print(sp)
First-stage
==============
Min 100 x₁ + 150 x₂
Subject to
 x₁ + x₂ ≤ 120
 x₁ ≥ 40
 x₂ ≥ 20

Second-stage
==============
Subproblem 1:
Min -24 y₁ - 28 y₂
Subject to
 6 y₁ + 10 y₂ - 60 x₁ ≤ 0
 8 y₁ + 5 y₂ - 80 x₂ ≤ 0
 0 ≤ y₁ ≤ 500
 0 ≤ y₂ ≤ 100

Subproblem 2:
Min -28 y₁ - 32 y₂
Subject to
 6 y₁ + 10 y₂ - 60 x₁ ≤ 0
 8 y₁ + 5 y₂ - 80 x₂ ≤ 0
 0 ≤ y₁ ≤ 300
 0 ≤ y₂ ≤ 300

```

Alternatively, it is possible construct an empty stochastic program, define the first and second stage models, and then add scenarios to create the model.

```julia
julia> sp = StochasticProgram(SimpleScenario,solver=ClpSolver())

julia> @first_stage sp = begin
           @variable(model, x₁ >= 40)
           @variable(model, x₂ >= 20)
           @objective(model, Min, 100*x₁ + 150*x₂)
           @constraint(model, x₁+x₂ <= 120)
       end

julia> @second_stage sp = begin
           @decision x₁ x₂
           s = scenario
           @variable(model, 0 <= y₁ <= s.d[1])
           @variable(model, 0 <= y₂ <= s.d[2])
           @objective(model, Min, s.q[1]*y₁ + s.q[2]*y₂)
           @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
           @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
       end

julia> push!(sp,s1)

julia> push!(sp,s2)

julia> generate!(sp)

julia> print(sp)
First-stage
==============
Min 100 x₁ + 150 x₂
Subject to
 x₁ + x₂ ≤ 120
 x₁ ≥ 40
 x₂ ≥ 20

Second-stage
==============
Subproblem 1:
Min -24 y₁ - 28 y₂
Subject to
 -60 x₁ + 6 y₁ + 10 y₂ ≤ 0
 -80 x₂ + 8 y₁ + 5 y₂ ≤ 0
 0 ≤ y₁ ≤ 500
 0 ≤ y₂ ≤ 100

Subproblem 2:
Min -28 y₁ - 32 y₂
Subject to
 -60 x₁ + 6 y₁ + 10 y₂ ≤ 0
 -80 x₂ + 8 y₁ + 5 y₂ ≤ 0
 0 ≤ y₁ ≤ 300
 0 ≤ y₂ ≤ 300

```

### Solving

The recourse model is solved by calling `solve`. If no solver was specified during creation, it needs to be provided to `solve` as a keyword argument.

```julia
julia> solve(sp,solver=ClpSolver())
:Optimal

julia> sp.colVal
2-element Array{Float64,1}:
 46.6667
 36.25

```

Alternatively, the recourse model is solved by using some structured solver.

```julia
julia> using LShapedSolvers

julia> solve(sp,solver=LShapedSolver(:ls,ClpSolver()))
L-Shaped Gap  Time: 0:00:01 (4 iterations)
  Objective:       -855.8333333333358
  Gap:             2.1229209144670507e-15
  Number of cuts:  5
:Optimal

julia> sp.colVal
2-element Array{Float64,1}:
 46.6667
 36.25

```

### Evaluating Solutions

The result of some first stage candidate decision, for example `x = [50,50]`, can be evaluated by calling

```julia
julia> eval_decision(sp,x,solver=ClpSolver())
356.0

```

The decision is evaluated internally by constructing corresponding outcome models for each scenario

```julia
julia> outcome = outcome_model(sp,s1,x,ClpSolver())
Minimization problem with:
 * 2 linear constraints
 * 4 variables
Solver is ClpMathProg

julia> print(outcome)
Min -24 y₁ - 28 y₂
Subject to
 6 y₁ + 10 y₂ - 60 x₁ ≤ 0
 8 y₁ + 5 y₂ - 80 x₂ ≤ 0
 x₁ = 50
 x₂ = 50
 0 ≤ y₁ ≤ 500
 0 ≤ y₂ ≤ 100

```

and calculating the expected value.

## Stochastic Programming Constructs

### Deterministic Equivalent Problem

A deterministically equivalent formulation of the recourse model can be obtained through the `DEP` command. It forms an extensive block-structured problem, using all provided scenarios.

```julia
julia> dep = DEP(sp)
Minimization problem with:
 * 5 linear constraints
 * 6 variables
Solver is ClpMathProg

julia> print(dep)
Min 100 x₁ + 150 x₂ - 9.600000000000001 y₁_1 - 11.200000000000001 y₂_1 - 16.8 y₁_2 - 19.2 y₂_2
Subject to
 x₁ + x₂ ≤ 120
 6 y₁_1 + 10 y₂_1 - 60 x₁ ≤ 0
 8 y₁_1 + 5 y₂_1 - 80 x₂ ≤ 0
 6 y₁_2 + 10 y₂_2 - 60 x₁ ≤ 0
 8 y₁_2 + 5 y₂_2 - 80 x₂ ≤ 0
 x₁ ≥ 40
 x₂ ≥ 20
 0 ≤ y₁_1 ≤ 500
 0 ≤ y₂_1 ≤ 100
 0 ≤ y₁_2 ≤ 300
 0 ≤ y₂_2 ≤ 300

```

Note, that a solver must be provided as an argument to `DEP` if none was provided during construction of `sp`. The above formulation is used to solve the recourse model if a `AbstractMathProgSolver` solver is provided. Also, the `VRP` command can be used to directly obtain the optimal value of the recourse problem.

```julia
julia> VRP(sp)
-855.8333333333335
```

### Expected Value Problem

The expected value problem, obtained by forming the expected scenario using `expected` is obtained through the `EVP` command. Again, note that a solver must be provided as an argument to `EVP` if none was provided during recourse model construction.

```julia
julia> evp = EVP(sp)
Minimization problem with:
 * 3 linear constraints
 * 4 variables
Solver is ClpMathProg

julia> print(evp)
Min 100 x₁ + 150 x₂ - 26.400000000000002 y₁ - 30.4 y₂
Subject to
 x₁ + x₂ ≤ 120
 6 y₁ + 10 y₂ - 60 x₁ ≤ 0
 8 y₁ + 5 y₂ - 80 x₂ ≤ 0
 x₁ ≥ 40
 x₂ ≥ 20
 0 ≤ y₁ ≤ 380
 0 ≤ y₂ ≤ 220

```

The expected value problem can now be solved and used to obtain the expected value solution. It can then be evaluated to obtain the expected result (EEV) of using the expected value solution.

```julia
julia> solve(evp)
:Optimal

julia> x = evp.colVal[1:2]
2-element Array{Float64,1}:
 71.4583
 48.5417

julia> evp.objVal
-1445.916666666666

julia> eval_decision(sp,x)
-568.9166666666661

```

Alternatively, the expected results of using the EV solution (EEV) can be obtained directly through the `EEV` command:

```julia
julia> EEV(sp)
-568.9166666666661

```

In addition, the `EV` command can be used to obtain directly the optimal value of the expected value problem:

```julia
julia> EV(sp)
-1445.916666666666

```

### Wait-And-See Solution

The wait-and-see solution corresponding to a given scenario can be obtained through the `WS` command. Again, a solver must be provided if not provided before.

```julia
julia> ws = WS(sp,s1)
Minimization problem with:
 * 3 linear constraints
 * 4 variables
Solver is ClpMathProg

julia> print(ws)
Min 100 x₁ + 150 x₂ - 24 y₁ - 28 y₂
Subject to
 x₁ + x₂ ≤ 120
 6 y₁ + 10 y₂ - 60 x₁ ≤ 0
 8 y₁ + 5 y₂ - 80 x₂ ≤ 0
 x₁ ≥ 40
 x₂ ≥ 20
 0 ≤ y₁ ≤ 500
 0 ≤ y₂ ≤ 100

```

The `EWS` command can be used to evaluate the expected value of all possible wait-and-see solutions.

```julia
julia> EWS(sp)
-1518.7500000000002
```

### Expected Value of Perfect Information (EVPI)

The expected value of perfect information, defined as `EVPI = VRP - WS`, is obtained through

```julia
julia> EVPI(sp)
662.9166666666667

```

where a solver must be provided as a keyword argument if not specified before.

### Value of the Stochastic Solution (VSS)

The value of the stochastic solution, defined as `VSS = EEV - VRP`, is obtained through

```julia
julia> VSS(sp)
286.9166666666674

```

where a solver must be provided as a keyword argument if not specified before.

## Distributed model creation

If multiple Julia processes have been added with `addprocs`, `StochasticPrograms` will automatically distribute the scenario problems on the worker processes. This can be explicitly requested or avoided by specifying the keyword argument `procs` during creation of the recourse model. If `procs = [1]` is specified, the scenarios will not be distributed, even though workers have been added.

```julia

julia> addprocs(3)
3-element Array{Int64,1}:
 2
 3
 4

julia> using StochasticPrograms

julia> using Clp

julia> @everywhere begin
           struct SimpleScenario <: StochasticPrograms.AbstractScenarioData
               π::Float64
               d::Vector{Float64}
               q::Vector{Float64}
           end

           function StochasticPrograms.expected(sds::Vector{SimpleScenario})
               sd = SimpleScenario(1,sum([s.π*s.d for s in sds]),sum([s.π*s.q for s in sds]))
           end
       end

julia> sp = StochasticProgram(SimpleScenario,procs=workers())

julia> @first_stage sp = begin
           @variable(model, x₁ >= 40)
           @variable(model, x₂ >= 20)
           @objective(model, Min, 100*x₁ + 150*x₂)
           @constraint(model, x₁+x₂ <= 120)
       end

julia> @second_stage sp = begin
           @decision x₁ x₂
           s = scenario
           @variable(model, 0 <= y₁ <= s.d[1])
           @variable(model, 0 <= y₂ <= s.d[2])
           @objective(model, Min, s.q[1]*y₁ + s.q[2]*y₂)
           @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
           @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
       end

```

Now, scenario data can be loaded on a worker through for example

```julia
julia> remotecall_fetch((sp) -> begin
           scenarioproblems = fetch(sp)
           s1 = SimpleScenario(0.4,[500.0,100],[-24.0,-28])
           push!(scenarioproblems,s1)
       end,
       2,
       scenarioproblems(sp))
```

One can still load scenarios by `push!` or `append!`, but they will be sent to worker processes internally.

```julia
julia> push!(sp,s2)

julia> generate!(sp)

julia> print(sp)
First-stage
==============
Min 100 x₁ + 150 x₂
Subject to
 x₁ + x₂ ≤ 120
 x₁ ≥ 40
 x₂ ≥ 20

Second-stage
==============
Subproblem 1:
Min -24 y₁ - 28 y₂
Subject to
 -60 x₁ + 6 y₁ + 10 y₂ ≤ 0
 -80 x₂ + 8 y₁ + 5 y₂ ≤ 0
 0 ≤ y₁ ≤ 500
 0 ≤ y₂ ≤ 100

```

The subproblems above were fetched internally from worker 2 before printing. The distributed features allow for parallel data loading as well as some performance improvements in the `EWS` and `EEV` functions. In addition, distributed structured solvers, such as those provided in [LShapedSolvers.jl][LShaped], benefit from distributed scenarios.

## Structured Solver Interface

An interface for specialized solvers for stochastic programs is provided. The interface mimics that of [MathProgBase.jl][MathProgBase]. To implement a structured solver, provide an `AbstractStructuredSolver` and an `AbstractStructuredModel`, as well as implement

```julia
function StructuredModel(solver::AbstractStructuredSolver,stochasticprogram::JuMP.Model)
    ...
end
```

To construct the `AbstractStructuredModel` object from the `AbstractStructuredSolver` and the `StochasticProgram`. In addition, one should implement

```julia
function optimize_structured!(structuredmodel::AbstractStructuredModel)
    ...
end
```

which should solve the recourse problem using the structured optimization algorithm, and

```julia
function fill_solution!(structuredmodel::AbstractStructuredModel,stochasticprogram::JuMP.Model)
    ...
end
```

which should fill the first stage and second stage `JuMP` models with the optimal solutions. For an example implementation, see [LShapedSolvers.jl][LShapedImpl].

[MathProgBase]: https://github.com/JuliaOpt/MathProgBase.jl
[LShapedImpl]: https://github.com/martinbiel/LShapedSolvers.jl/blob/master/src/spinterface.jl
