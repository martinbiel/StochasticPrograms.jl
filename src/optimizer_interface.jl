# Structured optimizer interface
# ========================== #
"""
    load_structure!(optimizer::AbstractStructuredOptimizer, structure::AbstractStochasticStructure)

Instantiate the `optimizer` with the stochastic program represented in memory by the given `structure`.

See also: [`optimize!`](@ref)
"""
function load_structure!(optimizer::AbstractStructuredOptimizer, structure::AbstractStochasticStructure)
    throw(MethodError(load_structure!, optimizer, structure))
end



# API
# load_structure!
# [x] optimizer_name
# [x] optimize!
# optimal_decision
# optimal_value
# [x] termination_status
# optimal_recourse_decision
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
    optimal_value(optimizer::AbstractStructuredOptimizer)

Optionally, return a string identifier of `AbstractStructuredOptimizer`.
"""
function optimal_value(::AbstractStructuredOptimizer)
    return "SolverName() attribute not implemented by the optimizer."
end
"""
    optimizer_name(optimizer::AbstractStructuredOptimizer)

Optionally, return a string identifier of `AbstractStructuredOptimizer`.
"""
function optimizer_name(::AbstractStructuredOptimizer)
    return "SolverName() attribute not implemented by the optimizer."
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
