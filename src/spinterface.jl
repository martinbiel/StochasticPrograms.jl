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
    fill_solution!(stochasticprogram::StochasticProgram, structuredmodel::AbstractStructuredModel)

Fill in the optimal solution in `stochasticprogram` after a call to `optimize_structured!`. Should fill in the first stage result and second stage results for each available scenario.

See also: [`optimize_structured!`](@ref)
"""
function fill_solution!(stochasticprogram::StochasticProgram, structuredmodel::AbstractStructuredModel)
    throw(MethodError(fill_solution!, stochasticprogram, structuredmodel))
end
"""
    solverstr(solver::AbstractStructuredSolver)

Optionally, return a string identifier of `AbstractStructuredSolver`.
"""
function solverstr(::AbstractStructuredSolver)
    return "Unnamed structured solver"
end
# Sample-based solver interface
# ========================== #
"""
    SampledModel(stochasticmodel::StochasticModel, sampler::AbstractSampler, solver::AbstractSampledSolver)

Return an instance of `AbstractSampledModel` based on `stochasticmodel`, `sampler` and the given `solver`.

See also: [`optimize_sampled!`](@ref), [`stochastic_solution`](@ref)
"""
function SampledModel(stochasticmodel::StochasticModel, solver::AbstractSampledSolver)
    throw(MethodError(StructuredModel, (stochasticprogram, solver)))
end
"""
    optimize_sampled!(sampledmodel::AbstractSampledmodel, sampler::AbstractSampler, confidence::AbstractFloat)

Optimize the `AbstractSampledModel` to the given `confidence` level, using `sampler` to generate scenarios. This should approximately optimize the `stochasticmodel` the sampled model was instantiated from.

See also: [`stochastic_solution`](@ref)
"""
function optimize_sampled!(sampledmodel::AbstractSampledModel, sampler::AbstractSampler, confidence::AbstractFloat)
    throw(MethodError(optimize_sampled!, sampledmodel, sampler))
end
"""
    stochastic_solution(sampledmodel::AbstractSampledmodel)

Generate a `StochasticSolution` from `sampledmodel` after a call to `optimize_sampled!`. The solution should include an approximately optimal first-stage decision, an an approximate optimal value and a confidence interval around the true optimum of the original stochastic model.

See also: [`optimize_sampled!`](@ref), [`StochasticSolution`](@ref)
"""
function stochastic_solution(sampledmodel::AbstractSampledModel)
    throw(MethodError(stochastic_solution, sampledmodel))
end
"""
    internal_solver(solver::AbstractSampledSolver)

Return an `AbstractMathProgSolver`, if available, from `solver`.
"""
function internal_solver(solver::AbstractSampledSolver)
    throw(MethodError(optimsolver, solver))
end
"""
    solverstr(solver::AbstractStructuredSolver)

Optionally, return a string identifier of `AbstractStructuredSolver`.
"""
function solverstr(::AbstractSampledSolver)
    return "Unnamed sample-based solver"
end
# ========================== #
