# Structured optimizer interface
# ========================== #
"""
    optimize_structured!(structuredoptimizer::AbstractStructuredOptimizer)

Optimize the `AbstractStructuredOptimizer`, which also optimizes the `stochasticprogram` it was instantiated from.

See also: [`fill_solution!`](@ref)
"""
function optimize_structured!(structuredoptimizer::AbstractStructuredOptimizer)
    throw(MethodError(optimize_structured!, structuredoptimizer))
end
"""
    termination_status(structuredoptimizer::AbstractStructuredOptimizer)

Return the reason why the solver stopped (i.e., the MathOptInterface model attribute `TerminationStatus`).
"""
function termination_status(structuredoptimizer::AbstractStructuredOptimizer)
    throw(MethodError(termination_status, structuredoptimizer))
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
