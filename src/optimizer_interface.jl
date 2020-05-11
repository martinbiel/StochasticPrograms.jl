# Structured optimizer interface
# ========================== #
"""
    load_structure!(optimizer::AbstractStructuredOptimizer, structure::AbstractStochasticStructure, x₀::AbstractVector)

Instantiate the `optimizer` with the stochastic program represented in memory by the given `structure` and inital decision `x₀`.

See also: [`optimize!`](@ref)
"""
function load_structure!(optimizer::AbstractStructuredOptimizer, structure::AbstractStochasticStructure, x₀::AbstractVector)
    throw(MethodError(load_structure!, optimizer, structure, x₀))
end
"""
    restore_structure!(optimizer::AbstractStructuredOptimizer)

Restore the stochastic program to the state it was in before a call to `optimize!`

See also: [`load_structure!`](@ref)
"""
function restore_structure!(optimizer::AbstractStructuredOptimizer)
    throw(MethodError(restore_structure!, optimizer))
end
"""
    optimize!(optimizer::AbstractStructuredOptimizer)

Start the solution procedure for `optimizer` after a call to [`load_structure!`](@ref).

See also: [`load_structure!`](@ref)
"""
function optimize!(optimizer::AbstractStructuredOptimizer)
    throw(MethodError(optimize_structured!, optimizer))
end
"""
    termination_status(optimizer::AbstractStructuredOptimizer)

Return the reason why the solver stopped (i.e., the MathOptInterface model attribute `TerminationStatus`).
"""
function termination_status(optimizer::AbstractStructuredOptimizer)
    throw(MethodError(termination_status, optimizer))
end
"""
    optimizer_name(optimizer::AbstractStructuredOptimizer)

Optionally, return a string identifier of `AbstractStructuredOptimizer`.
"""
function optimizer_name(::AbstractStructuredOptimizer)
    return "SolverName() attribute not implemented by the optimizer."
end
"""
    master_optimizer(optimizer::AbstractStructuredOptimizer)

Return a MOI optimizer constructor
"""
function master_optimizer(optimizer::AbstractStructuredOptimizer)
    return throw(MethodError(master_optimizer, optimizer))
end
"""
    master_optimizer(optimizer::AbstractStructuredOptimizer)

Return a MOI optimizer constructor for solving subproblems
"""
function sub_optimizer(optimizer::AbstractStructuredOptimizer)
    return throw(MethodError(sub_optimizer, optimizer))
end
# # Sample-based solver interface
# # ========================== #
# """
#     optimize_sampled!(sampledoptimizer::AbstractSampledOptimizer, stochasticmodel::StochasticModel, sampler::AbstractSampler, confidence::AbstractFloat)

# Approximately optimize the `stochasticmodel` to the given `confidence` level, using `sampler` to generate scenarios.
# """
# function optimize_sampled!(sampledoptimizer::AbstractSampledOptimizer, stochasticmodel::StochasticModel, sampler::AbstractSampler, confidence::AbstractFloat)
#     throw(MethodError(optimize_sampled!, sampledoptimizer, stochasticmodel, sampler))
# end
# """
#     optimal_value(sampledoptimizer::AbstractStructuredOptimizer)

# Generate a `StochasticSolution` from `sampledoptimizer` after a call to `optimize_sampled!`. The solution should include an approximately optimal first-stage decision, an an approximate optimal value and a confidence interval around the true optimum of the original stochastic model.

# See also: [`optimize_sampled!`](@ref), [`StochasticSolution`](@ref)
# """
# function optimal_value(sampledoptimizer::AbstractStructuredOptimizer)
#     throw(MethodError(optimal_value, sampledoptimizer))
# end
# """
#     internal_solver(solver::AbstractSampledOptimizer)

# Return an `AbstractMathProgSolver`, if available, from `solver`.
# """
# function internal_solver(solver::AbstractSampledOptimizer)
#     throw(MethodError(optimsolver, solver))
# end
# """
#     optimizer_name(optimizer::AbstractSampledOptimizer)

# Optionally, return a string identifier of `AbstractSampledOptimizer`.
# """
# function optimizer_name(::AbstractSampledOptimizer)
#     return "SolverName() attribute not implemented by the optimizer."
# end
# ========================== #
