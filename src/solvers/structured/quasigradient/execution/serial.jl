"""
    SerialExecution

Functor object for using serial execution in a quasi-gradient algorithm. Create by supplying a [`Serial`](@ref) object through `execution` in `QuasiGradient.Optimizer` or by setting the [`Execution`](@ref) attribute.

"""
struct SerialExecution{T <: AbstractFloat} <: AbstractQuasiGradientExecution
    subproblems::Vector{SubProblem{T}}
    decisions::Decisions

    function SerialExecution(structure::VerticalStructure{2, 1, <:Tuple{ScenarioProblems}}, ::Type{T}) where T <: AbstractFloat
        return new{T}(Vector{SubProblem{T}}(), structure.decisions[2])
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

function resolve_subproblems!(quasigradient::AbstractQuasiGradient, execution::SerialExecution{T}) where T <: AbstractFloat
    # Update subproblems
    update_known_decisions!(execution.decisions, quasigradient.x)
    # Initialize subgradient
    quasigradient.subgradient .= quasigradient.c
    Q = zero(T)
    # Update and solve subproblems
    for subproblem in execution.subproblems
        update_subproblem!(subproblem)
        subgradient::SparseSubgradient{T} = subproblem(quasigradient.x)
        quasigradient.subgradient .-= subgradient.δQ
        Q += subgradient.Q
    end
    # Return current objective value and subgradient
    return current_objective_value(quasigradient, Q)
end

# API
# ------------------------------------------------------------
function (execution::Serial)(structure::VerticalStructure{2, 1, <:Tuple{ScenarioProblems}},
                             ::Type{T}) where T <: AbstractFloat
    return SerialExecution(structure, T)
end

function str(::Serial)
    return ""
end
