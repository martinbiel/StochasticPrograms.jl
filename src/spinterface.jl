# Structured solver interface
# ========================== #
function StructuredModel(stochasticprogram::StochasticProgram, solver::AbstractStructuredSolver)
    throw(MethodError(StructuredModel, (stochasticprogram, solver)))
end

function optimsolver(solver::AbstractStructuredSolver)
    throw(MethodError(optimsolver, solver))
end

function optimize_structured!(structuredmodel::AbstractStructuredModel)
    throw(MethodError(optimize_structured!, structuredmodel))
end

function fill_solution!(stochasticprogram::StochasticProgram, structuredmodel::AbstractStructuredModel)
    throw(MethodError(fill_solution!, stochasticprogram, structuredmodel))
end

function solverstr(solver::AbstractStructuredModel)
    throw(MethodError(solverstr, solver))
end
# ========================== #
