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

Optimize the `AbstractStructuredModel`, which also optimizes the `stochasticprogram` it was instansiated from.

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
# ========================== #
