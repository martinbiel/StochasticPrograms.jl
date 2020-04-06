  # Structured solver interface
# ========================== #
"""
    StructuredModel(stochasticprogram::StochasticProgram, solver::AbstractStructuredSolver)

Return an instance of `AbstractStructuredModel` based on `stochasticprogram` and the given `solver`.

See also: [`optimize_structured!`](@ref), [`fill_solution!`](@ref)
"""
function StructuredModel(stochasticprogram::StochasticProgram, solver::AbstractStructuredSolver)
    throw(MethodError(StructuredModel, (stochasticprogram, solver)))
end
"""
    internal_solver(solver::AbstractStructuredSolver)

Return an `AbstractMathProgSolver`, if available, from `solver`.
"""
function internal_solver(solver::AbstractStructuredSolver)
    throw(MethodError(optimsolver, solver))
end
"""
    optimize_structured!(structuredmodel::AbstractStructuredModel)

Optimize the `AbstractStructuredModel`, which also optimizes the `stochasticprogram` it was instantiated from.

See also: [`fill_solution!`](@ref)
"""
function optimize_structured!(structuredmodel::AbstractStructuredModel)
    throw(MethodError(optimize_structured!, structuredmodel))
end
"""
    termination_status(structuredoptimizer::AbstractStructuredOptimizer)

Return the reason why the solver stopped (i.e., the MathOptInterface model attribute `TerminationStatus`).
"""
function termination_status(structuredoptimizer::AbstractStructuredOptimizer)
    throw(MethodError(termination_status, structuredoptimizer))
end
"""
    fill_solution!(stochasticprogram::StochasticProgram, structuredmodel::AbstractStructuredModel)

Fill in the optimal solution in `stochasticprogram` after a call to `optimize_structured!`. Should fill in the first stage result and second stage results for each available scenario.

See also: [`optimize_structured!`](@ref)
"""
function fill_solution!(stochasticprogram::StochasticProgram, structuredmodel::AbstractStructuredModel)
    throw(MethodError(fill_solution!, stochasticprogram, structuredmodel))
end
"""
    optimizer_name(optimizer::AbstractStructuredOptimizer)

Optionally, return a string identifier of `AbstractStructuredOptimizer`.
"""
function optimizer_name(::AbstractStructuredOptimizer)
    return "SolverName() attribute not implemented by the optimizer."
end
# Sample-based solver interface
# ========================== #
"""
    optimize_sampled!(sampledoptimizer::AbstractSampledOptimizer, stochasticmodel::StochasticModel, sampler::AbstractSampler, confidence::AbstractFloat)

Approximately optimize the `stochasticmodel` to the given `confidence` level, using `sampler` to generate scenarios.
"""
function optimize_sampled!(sampledoptimizer::AbstractSampledOptimizer, stochasticmodel::StochasticModel, sampler::AbstractSampler, confidence::AbstractFloat)
    throw(MethodError(optimize_sampled!, sampledoptimizer, stochasticmodel, sampler))
end
"""
    optimal_value(sampledoptimizer::AbstractStructuredOptimizer)

Generate a `StochasticSolution` from `sampledoptimizer` after a call to `optimize_sampled!`. The solution should include an approximately optimal first-stage decision, an an approximate optimal value and a confidence interval around the true optimum of the original stochastic model.

See also: [`optimize_sampled!`](@ref), [`StochasticSolution`](@ref)
"""
function optimal_value(sampledoptimizer::AbstractStructuredOptimizer)
    throw(MethodError(optimal_value, sampledoptimizer))
end
"""
    internal_solver(solver::AbstractSampledOptimizer)

Return an `AbstractMathProgSolver`, if available, from `solver`.
"""
function internal_solver(solver::AbstractSampledOptimizer)
    throw(MethodError(optimsolver, solver))
end
"""
    optimizer_name(optimizer::AbstractSampledOptimizer)

Optionally, return a string identifier of `AbstractSampledOptimizer`.
"""
function optimizer_name(::AbstractSampledOptimizer)
    return "SolverName() attribute not implemented by the optimizer."
end
# ========================== #
