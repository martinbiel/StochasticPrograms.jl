# Structured solvers

A stochastic program has a structure that can be exploited in solver algorithms through decomposition. This can heavily reduce the computation time required to optimize the stochastic program, compared to solving the extensive form directly. Moreover, a distributed stochastic program is by definition decomposed and a structured solver that can operate in parallel will be much more efficient.

## Stochastic structure

StochasticPrograms provides multiple alternatives for how finite stochastic program instances are represented and stored in memory. We refer to these alternatives as the structure of the stochastic program. Certain operations are more efficient in certain structures. We summarize the available structures in the following. For code examples, see the [Quick start](@ref).

### Deterministic Equivalent

The [`DeterministicEquivalent`](@ref), instantiated using [`Deterministic`](@ref), is the default structure in StochasticPrograms. A stochastic program instance is represented by one large optimization problem that considers all scenarios at once. This structure is supported by any standard third-party `MathOptInterface` solver. Moreover, it is the most efficient choice for smaller problem sizes.

### Vertical block-decomposition

The [`VerticalStructure`](@ref), instantiated using [`Vertical`](@ref), decomposes the stochastic program into stages. It is the structure induced by the L-shaped algorithm and is efficient for larger instances. It is especially efficient for decision evaluation problem, such as when calculating [`VSS`](@ref). In a distributed environment, the subproblems in later stages can be distributed on worker nodes. This distributed vertical structure is instantiated using [`DistributedVertical`](@ref).

### Horizontal block-decomposition

The [`HorizontalStructure`](@ref), instantiated using [`Horizontal`](@ref), decomposes the stochastic program by scenarios. It is the structure induced by the progressive-hedging algorithm and is efficient for larger instances. It is especially efficient for solving wait-and-see type problems, such as when calculating [`EVPI`](@ref). In a distributed environment, the subproblems in later stages can be distributed on worker nodes. This distributed vertical structure is instantiated using [`DistributedVertical`](@ref).

## Solver interface

The structured solver interface mimics that of `MathOptInterface`, and it needs to be implemented by any structured solver to be compatible with StochasticPrograms. We distinguish between structure-exploiting solvers for solving finite stochastic programs and sampled-bases solvers for approximately solving stochastic models, even though they can be based on the same algorithm.

### Stochastic programs

To interface a new structure-exploiting solver, define a [`AbstractStructuredOptimizer`](@ref) object. To follow the style of `MathOptInterface`, name the object `Optimizer` so that users can `set_optimizer(sp, SOLVER_MODULE.Optimizer)` to use the optimizer. Next, implement [`load_structure!`](@ref), which loads any stochastic structure supported by the solver. Define [`supports_structure`](@ref) to inform StochasticPrograms what structures are supported by the solver and define [`default_structure`](@ref) to ensure that an appropriate structure is used when instantiating a stochastic program with your solver. After a call to [`load_structure!`](@ref), [`optimize!`](@ref) should solve the stochastic program or otherwise throw [`UnloadedStructure`](@ref). After a call to [`optimize!`](@ref), calling [`restore_structure!`](@ref) should remove any changes made to the model by the solver. For example, calling this method after running an L-shaped procedure removes all cutting planes from the first stage. The solver should at least be able to return a solver for solving subproblems through [`subproblem_optimizer`](@ref) and can also optionally support a [`master_optimizer`](@ref). Finally, the solver can optionally support a custom solver name through [`optimizer_name`](@ref).

In summary, the solver interface that a new [`AbstractStructuredOptimizer`](@ref) should adhere to is given by
 - [`supports_structure`](@ref)
 - [`default_structure`](@ref)
 - [`check_loadable`](@ref)
 - [`load_structure!`](@ref)
 - [`restore_structure!`](@ref)
 - [`optimize!`](@ref)
 - [`optimizer_name`](@ref)
 - [`num_iterations`](@ref)
 - [`master_optimizer`](@ref)
 - [`subproblem_optimizer`](@ref)

In addition, the solver can include support getting/setting/modiyfing any `MathOptInterface` attributes. See also the subtypes of [`AbstractStructuredOptimizerAttribute`](@ref) for special attributes defined by the framework. For more thorough examples of implementing the structured solver interface, see the [L-shaped](https://github.com/martinbiel/StochasticPrograms.jl/tree/master/src/solvers/structured/lshaped/MOI_wrapper) or [Progressive-hedging](https://github.com/martinbiel/StochasticPrograms.jl/tree/master/src/solvers/structured/progressivehedging/MOI_wrapper) implementations.

### Stochastic models

To interface a new structure-exploiting solver, define a [`AbstractSampledOptimizer`](@ref) object. Next, implement [`load_model!`](@ref), which should load a provided `StochasticModel` object into the solver. A call to [`optimize!`](@ref) should then approximately solve the model. Afterwards, a call to [`optimal_instance`](@ref) can optionally return a sampled instance with an optimal value within the confidence interval of the solution. Again, a custom solver name can be provided in [`optimizer_name`](@ref).

In summary, the solver interface that a new [`AbstractSampledOptimizer`](@ref) should adhere to is given by

 - [`load_model!`](@ref)
 - [`optimize!`](@ref)
 - [`optimizer_name`](@ref)
 - [`optimal_instance`](@ref)

See also the subtypes of [`AbstractSampledOptimizerAttribute`](@ref) for special attributes defined by the framework. For a thorough example, consider the [SAA](https://github.com/martinbiel/StochasticPrograms.jl/tree/master/src/solvers/sampled/SAA/MOI_wrapper) implementation.

## Crash methods

Some structure-exploiting algorithms benefit from crash starting in various ways. For example, a good initial guess in combination with a regularization procedure can improve convergence.

The following [`Crash`](@ref) methods are available in StochasticPrograms:
- [`Crash.None`](@ref) (default)
- [`Crash.EVP`](@ref)
- [`Crash.Scenario`](@ref)
- [`Crash.PreSolve`](@ref)
- [`Crash.Custom`](@ref)

To use a Crash procedure, set the `crash` keyword in the call to [`optimize!`](@ref).

## L-shaped solvers

StochasticPrograms includes a collection of L-shaped algorithms in the submodule `LShaped`. All algorithm variants are based on the L-shaped method by Van Slyke and Wets. `LShaped` interfaces with StochasticPrograms through the structured solver interface. Every algorithm variant is an instance of the functor object [`LShapedAlgorithm`](@ref), and are instanced using the API object [`LShaped.Optimizer`](@ref). Consider subtypes of [`AbstractLShapedAttribute`](@ref) for a summary of available configurations.

As an example, we solve the simple problem introduced in the [Quick start](@ref):
```julia
set_optimizer(sp, LShaped.Optimizer)
set_optimizer_attribute(sp, MasterOptimizer(), GLPK.Optimizer)
set_optimizer_attribute(sp, SubProblemOptimizer(), GLPK.Optimizer)
optimize!(sp)
```
```julia
L-Shaped Gap  Time: 0:00:02 (6 iterations)
  Objective:       -855.8333333333358
  Gap:             0.0
  Number of cuts:  8
  Iterations:      6
```
Note, that an LP capable `AbstractOptimizer` is required to solve emerging subproblems.

`LShaped` uses a policy-based design. This allows combinatorially many variants of the original algorithm to be instanced by supplying linearly many policies to the factory function [`LShaped.Optimizer`](@ref). We briefly describe the various policies in the following.

### Feasibility cuts

If the stochastic program does not have complete, or relatively complete, recourse then subproblems may be infeasible for some master iterates. Convergence can be maintained through the use of feasibility cuts. To reduce overhead and memory usage, feasibility issues are ignored by default. If you know that your problem does not have complete recourse, or if the algorithm terminates due to infeasibility, set the [`FeasibilityStrategy`](@ref) attribute to `FeasibilityCuts`:
```julia
set_optimizer_attribute(sp, FeasibilityStrategy(), FeasibilityCuts())
optimize!(sp)
```

### Integer strategies

If the stochastic program includes binary or integer decisions, especially in the second-stage, special strategies are required for the L-shaped algorihm to stay effective. Integer restrictions are ignored by default and the procedure will generally not converge if they are present.
```julia
set_optimizer_attribute(sp, IntegerStrategy(), CombinatorialCuts())
optimize!(sp)
```

The following L-shaped integer strategies are available:
- [`IgnoreIntegers`](@ref) (default)
- [`CombinatorialCuts`](@ref)
- [`Convexification`](@ref)

Note, that [`CombinatorialCuts`](@ref) requires a third-party subproblem optimizer with integer capabilities. [`Convexification`](@ref) solves linear subproblems through cutting-plane approximations, determined by a convexification strategy. The currently availiable strategies are:
- `Gomory`
- `LiftAndProject`
- `CuttingPlaneTree`
The `Gomory` strategy is cheapest and often the most effective. The latter strategies involves solving extra linear programs using a supplied `optimizer`.

### Regularization

A Regularization procedure can improve algorithm performance. The idea is to limit the candidate search to a neighborhood of the current best iterate in the master problem. This can result in more effective cutting planes. Moreover, regularization enables warm-starting the L-shaped procedure with [`Crash`](@ref) decisions. Regularization is enabled by setting the [`Regularizer`](@ref) attribute.

The following L-shaped regularizations are available:
- [`NoRegularization`](@ref) (default)
- [`RegularizedDecomposition`](@ref)
- [`TrustRegion`](@ref)
- [`LevelSet`](@ref)

Note, that [`RegularizedDecomposition`](@ref) and [`LevelSet`](@ref) require an `AbstractOptimizer` capable of solving QP problems. Alternatively, the quadratic proximal term in the objective can be approximated through various linear terms. This is achieved by supplying a `AbstractPenaltyTerm` object through `penaltyterm` in either [`RD`](@ref) or [`LV`](@ref). The alternatives are given below:

- [`Quadratic`](@ref) (default)
- [`InfNorm`](@ref)
- [`ManhattanNorm`](@ref)

### Aggregation

Cut aggregation can be applied to reduce communication latency and load imbalance. This can yield major performance improvements in distributed settings. Aggregation is enabled by setting the [`Aggregator`](@ref) attribute.

The following aggregation schemes are available:
- [`NoAggregation`](@ref) (default)
- [`PartialAggregation`](@ref)
- [`DynamicAggregation`](@ref)
- [`ClusterAggregation`](@ref)
- [`HybridAggregation`](@ref)

### Consolidation

If cut consolidation is enabled, cuts from previous iterations that are no longer active are aggregated to reduce the size of the master. Consolidation is enabled by setting the [`Consolidator`](@ref) attribute to [`Consolidate`](@ref). See [`Consolidation`](@ref) for further details.

### Execution

There are three currently available modes of execution:

- [`Serial`](@ref) (default)
- [`Synchronous`](@ref)
- [`Asynchronous`](@ref)

Running a distributed L-shaped algorithm, either synchronously or asynchronously, required adding Julia worker cores with [`addprocs`]. The execution policy can be changed by setting the [`Execution`](@ref) attribute.

### Solver examples

Below are a few examples of L-shaped algorithm with advanced policy configurations:

```julia
function tr_with_partial_aggregation()
    opt = LShaped.Optimizer()
    MOI.set(opt, MasterOptimizer(), GLPK.Optimizer)
    MOI.set(opt, SubProblemOptimizer(), GLPK.Optimizer)
    MOI.set(opt, Regularizer(), TR()) # Set regularization to trust-region
    MOI.set(opt, Aggregator(), PartialAggregate(36)) # Use partial aggregation in groups of 36 cuts
    return opt
end

function lv_with_kmedoids_aggregation_and_consolidation()
    opt = LShaped.Optimizer()
    MOI.set(opt, MasterOptimizer(), Gurobi.Optimizer)
    MOI.set(opt, SubProblemOptimizer(), Gurobi.Optimizer)
    MOI.set(opt, Regularizer(), LV()) # Use level-set regularization
    MOI.set(opt, Aggregator(), ClusterAggregate(Kmedoids(20, distance = angular_distance) # Use K-medoids cluster aggregation
    MOI.set(opt, Consolidator(), Consolidate()) # Enable consolidation
    return opt
end

# Employ advanced solvers
set_optimizer(sp, tr_with_partial_aggregation)
optimize!(sp)

set_optimizer(sp, lv_with_kmedoids_aggregation_and_consolidation)
optimize!(sp)
```

### References

1. Van Slyke, R. and Wets, R. (1969), [L-Shaped Linear Programs with Applications to Optimal Control and Stochastic Programming](https://epubs.siam.org/doi/abs/10.1137/0117061), SIAM Journal on Applied Mathematics, vol. 17, no. 4, pp. 638-663.

2. Ruszczyński, A (1986), [A regularized decomposition method for minimizing a sum of polyhedral functions](https://link.springer.com/article/10.1007/BF01580883), Mathematical Programming, vol. 35, no. 3, pp. 309-333.

3. Linderoth, J. and Wright, S. (2003), [Decomposition Algorithms for Stochastic Programming on a Computational Grid](https://link.springer.com/article/10.1023/A:1021858008222), Computational Optimization and Applications, vol. 24, no. 2-3, pp. 207-250.

4. Fábián, C. and Szőke, Z. (2006), [Solving two-stage stochastic programming problems with level decomposition](https://link.springer.com/article/10.1007%2Fs10287-006-0026-8), Computational Management Science, vol. 4, no. 4, pp. 313-353.

5. Wolf, C. and Koberstein, A. (2013), [Dynamic sequencing and cut con-solidation for the parallel hybrid-cut nested l-shaped method](https://www.sciencedirect.com/science/article/pii/S0377221713003159), European Journal of Operational Research, vol. 230, no. 1, pp. 143-156.

6. Biel, M. and Johansson, M. (2018), [Distributed L-shaped Algorithms in Julia](https://ieeexplore.ieee.org/document/8639173), 2018 IEEE/ACM Parallel Applications Workshop, Alternatives To MPI (PAW-ATM).

7. Biel, M. and Johansson, M. (2019), [Dynamic cut aggregation in L-shaped algorithms](https://arxiv.org/abs/1910.13752), arXiv preprint arXiv:1910.13752.

## Progressive-hedging solvers

StochasticPrograms also includes a collection of progressive-hedging algorithms in the submodule `ProgressiveHedging`. All algorithm variants are based on the original progressive-hedging algorithm by Rockafellar and Wets. `ProgressiveHedging` interfaces with StochasticPrograms through the structured solver interface. Every algorithm variant is an instance of the functor object [`ProgressiveHedgingAlgorithm`](@ref), and are instanced using the API object [`ProgressiveHedging.Optimizer`](@ref). Consider subtypes of [`AbstractProgressiveHedgingAttribute`](@ref) for a summary of available configurations.

As an example, we solve the simple problem introduced in the [Quick start](@ref):
```julia
set_optimizer(sp, ProgressiveHedging.Optimizer)
set_optimizer_attribute(sp, SubProblemOptimizer(), Ipopt.Optimizer)
optimize!(sp)
```
```julia
Progressive Hedging Time: 0:00:05 (303 iterations)
  Objective:   -855.5842547490254
  Primal gap:  7.2622997706326046e-6
  Dual gap:    8.749063651111478e-6
  Iterations:  302
```
Note, that an QP/LP capable `AbstractOptimizer` is required to solve emerging subproblems.

`ProgressiveHedging` also uses a policy-based design. See [`ProgressiveHedging.Optimizer`](@ref) for options. We briefly describe the various policies in the following.

### Penalty

There are two options for the penalty parameter used in the progressive-hedging algorithm. The alternatives are

- [`Fixed`](@ref) (default)
- [`Adaptive`](@ref)

### Execution

The same execution policies as for `LShaped` are available in `ProgressiveHedging`, i.e.

- [`Serial`](@ref) (default)
- [`Synchronous`](@ref)
- [`Asynchronous`](@ref)

### Penalty term

As with the L-shaped variants with quadratic 2-norm terms, the 2-norm term in progressive-hedging subproblems can be approximated. This enables the use of an `AbstractOptimizer` that only support linear problems. The alternatives are as before:

- [`Quadratic`](@ref) (default)
- [`InfNorm`](@ref)
- [`ManhattanNorm`](@ref)

### References

1. R. T. Rockafellar and Roger J.-B. Wets (1991), [Scenarios and Policy Aggregation in Optimization Under Uncertainty](https://pubsonline.informs.org/doi/10.1287/moor.16.1.119), Mathematics of Operations Research, vol. 16, no. 1, pp. 119-147.

2. Zehtabian. S and Bastin. F (2016), [Penalty parameter update strategies in progressive hedging algorithm](http://www.cirrelt.ca/DocumentsTravail/CIRRELT-2016-12.pdf)

## Quasi-gradient solvers

StochasticPrograms also includes a collection of quasi-gradient algorithms in the submodule `QuasiGradient`. All algorithm variants are based on projected subgradient methods. `QuasiGradient` interfaces with StochasticPrograms through the structured solver interface. Every algorithm variant is an instance of the functor object [`QuasiGradientAlgorithm`](@ref), and are instanced using the API object [`QuasiGradient.Optimizer`](@ref). Consider subtypes of [`AbstractQuasiGradientAttribute`](@ref) for a summary of available configurations.

As an example, we solve the simple problem introduced in the [Quick start](@ref):
```julia
set_optimizer(sp, QuasiGradient.Optimizer)
set_optimizer_attribute(sp, MasterOptimizer(), Ipopt.Optimizer)
set_optimizer_attribute(sp, SubProblemOptimizer(), GLPK.Optimizer)
optimize!(sp)
```
```julia
Quasi-gradient Progress 100%|██████████████████████████████████████████████████████████████████| Time: 0:00:08
  Objective:   -854.9691513511461
  ||∇Q||::     34.64997546896679
  Iterations:  1000
```
Note, that an QP/LP capable `AbstractOptimizer` is required to solve emerging subproblems.

`QuasiGradient` also uses a policy-based design. See [`QuasiGradient.Optimizer`](@ref) for options. We briefly describe the various policies in the following.

### Step-size

The following step-size policies are available:

- [`Constant`](@ref) (default)
- [`Diminishing`](@ref)
- [`Polyak`](@ref)
- [`BB`](@ref)

### Prox

A proximal step is taken each iteration in a projected (sub)gradient method. The following prox steps are currently available:

- [`NoProx`](@ref)
- [`Polyhedron`](@ref) (default)
- [`AndersonAcceleration`](@ref)
- [`Nesterov`](@ref)
- [`DryFriction`](@ref)

At the very least, a polyhedral projection on the first-stage constraints are required when solving stochastic programs.

### Termination

The following termination criteria are available:

- [`AfterMaximumIterations`](@ref) (default)
- [`AtObjectiveThreshold`](@ref)
- [`AtGradientThreshold`](@ref)

### Execution

The following execution policies are available in `QuasiGradient`, i.e.

- [`Serial`](@ref) (default)
- [`Synchronous`](@ref)

### Smoothing

A smooth approximation can be applied to the subproblems to enable gradient-based method that require smooth properties. The smoothing procedure is based on Moreau envelopes.

- [`Unaltered`](@ref) (default)
- [`Smoothed`](@ref)
