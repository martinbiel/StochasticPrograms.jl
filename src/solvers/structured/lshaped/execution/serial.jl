"""
    SerialExecution

Functor object for using serial execution in a lshaped algorithm. Create by supplying a [`Serial`](@ref) object through `execution` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

"""
struct SerialExecution{H <: AbstractFeasibilityHandler,
                       T <: AbstractFloat,
                       A <: AbstractVector} <: AbstractLShapedExecution
    subproblems::Vector{SubProblem{H,T}}
    decisions::Decisions
    subobjectives::A
    model_objectives::A

    function SerialExecution(structure::VerticalStructure{2, 1, <:Tuple{ScenarioProblems}},
                             ::Type{F}, ::Type{T}, ::Type{A}) where {F <: AbstractFeasibility,
                                                                     T <: AbstractFloat,
                                                                     A <: AbstractVector}
        H = HandlerType(F)
        return new{H,T,A}(Vector{SubProblem{H,T}}(), structure.decisions[2], A(), A())
    end
end

function num_thetas(lshaped::AbstractLShaped, ::SerialExecution)
    return num_thetas(num_subproblems(lshaped), lshaped.aggregation)
end

function initialize_subproblems!(execution::SerialExecution{H,T},
                                 scenarioproblems::ScenarioProblems) where {H <: AbstractFeasibilityHandler,
                                                                            T <: AbstractFloat}
    for i in 1:num_subproblems(scenarioproblems)
        push!(execution.subproblems, SubProblem(
            subproblem(scenarioproblems, i),
            i,
            T(probability(scenario(scenarioproblems, i))),
            all_known_decisions(execution.decisions),
            H))
    end
    return nothing
end

function finish_initilization!(lshaped::AbstractLShaped, execution::SerialExecution)
    append!(execution.subobjectives, fill(1e10, num_thetas(lshaped)))
    append!(execution.model_objectives, fill(-1e10, num_thetas(lshaped)))
    return nothing
end

function restore_subproblems!(lshaped::AbstractLShaped, execution::SerialExecution)
    for subproblem in execution.subproblems
        restore_subproblem!(subproblem)
    end
    return nothing
end

function resolve_subproblems!(lshaped::AbstractLShaped, execution::SerialExecution{H,T}) where {H <: AbstractFeasibilityHandler, T <: AbstractFloat}
    # Update subproblems
    update_known_decisions!(execution.decisions, lshaped.x)
    # Assume no cuts are added
    added = false
    # Update and solve subproblems
    for subproblem in execution.subproblems
        update_subproblem!(subproblem)
        cut::SparseHyperPlane{T} = subproblem(lshaped.x)
        added |= aggregate_cut!(lshaped, lshaped.aggregation, cut)
    end
    added |= flush!(lshaped, lshaped.aggregation)
    # Return current objective value and cut_added flag
    return current_objective_value(lshaped), added
end

# API
# ------------------------------------------------------------
function (execution::Serial)(structure::VerticalStructure{2, 1, <:Tuple{ScenarioProblems}},
                             ::Type{F}, ::Type{T}, ::Type{A}) where {F <: AbstractFeasibility,
                                                                     T <: AbstractFloat,
                                                                     A <: AbstractVector}
    return SerialExecution(structure, F, T, A)
end

function str(::Serial)
    return ""
end
