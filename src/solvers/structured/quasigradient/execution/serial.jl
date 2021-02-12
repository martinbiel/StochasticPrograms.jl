"""
    SerialExecution

Functor object for using serial execution in a quasi-gradient algorithm. Create by supplying a [`Serial`](@ref) object through `execution` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

"""
struct SerialExecution{T <: AbstractFloat, A <: AbstractVector} <: AbstractQuasiGradientExecution
    subproblems::Vector{SubProblem{T}}
    decisions::Decisions
    subobjectives::A

    function SerialExecution(structure::VerticalStructure{2, 1, <:Tuple{ScenarioProblems}},
                             ::Type{T}, ::Type{A}) where {T <: AbstractFloat,
                                                                     A <: AbstractVector}
        return new{T,A}(Vector{SubProblem{T}}(), structure.decisions[2], A())
    end
end

function initialize_subproblems!(execution::SerialExecution{T}, scenarioproblems::ScenarioProblems) where T <: AbstractFloat
    for i in 1:num_subproblems(scenarioproblems)
        push!(execution.subproblems, SubProblem(
            subproblem(scenarioproblems, i),
            i,
            T(probability(scenario(scenarioproblems, i)))))
    end
    return nothing
end

function finish_initilization!(quasigradient::AbstractQuasiGradient, execution::SerialExecution)
    append!(execution.subobjectives, fill(1e10, num_subproblems(quasigradient)))
    return nothing
end

function resolve_subproblems!(quasigradient::AbstractQuasiGradient, execution::SerialExecution{T}) where T <: AbstractFloat
    # Update subproblems
    update_known_decisions!(execution.decisions, quasigradient.x)
    # Initialize subgradient
    quasigradient.subgradient .= quasigradient.c
    # Update and solve subproblems
    for subproblem in execution.subproblems
        update_subproblem!(subproblem)
        subgradient::SparseSubgradient{T} = subproblem(quasigradient.x)
        quasigradient.subgradient .-= subgradient.δQ
        execution.subobjectives[subgradient.id] = subgradient.Q
    end
    # Return current objective value and subgradient
    return current_objective_value(quasigradient)
end

# API
# ------------------------------------------------------------
function (execution::Serial)(structure::VerticalStructure{2, 1, <:Tuple{ScenarioProblems}},
                             ::Type{T}, ::Type{A}) where {T <: AbstractFloat,
                                                                     A <: AbstractVector}
    return SerialExecution(structure, T, A)
end

function str(::Serial)
    return ""
end
