# Structured solver interface
# ========================== #
abstract type AbstractStructuredSolver end
abstract type AbstractStructuredModel end

function StructuredModel(solver::AbstractStructuredSolver,stochasticprogram::JuMP.Model)
    throw(MethodError(StructuredModel,(solver,stochasticprogram)))
end

function optimize_structured!(structuredmodel::AbstractStructuredModel)
    throw(MethodError(optimize!,structuredmodel))
end

function fill_solution!(structuredmodel::AbstractStructuredModel,stochasticprogram::JuMP.Model)
    throw(MethodError(optimize!,structuredmodel))
end
# ========================== #
