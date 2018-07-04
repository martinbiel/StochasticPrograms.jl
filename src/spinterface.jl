# Structured solver interface
# ========================== #
abstract type AbstractStructuredSolver end
abstract type AbstractStructuredModel end

function StructuredModel(solver::AbstractStructuredSolver,stochasticprogram::JuMP.Model)
    throw(MethodError(StructuredModel,(solver,stochasticprogram)))
end

function optimsolver(solver::AbstractStructuredSolver)
    throw(MethodError(optimsolver,solver))
end

function optimize_structured!(structuredmodel::AbstractStructuredModel)
    throw(MethodError(optimize_structured!,structuredmodel))
end

function fill_solution!(structuredmodel::AbstractStructuredModel,stochasticprogram::JuMP.Model)
    throw(MethodError(fill_solution!,structuredmodel))
end
# ========================== #
