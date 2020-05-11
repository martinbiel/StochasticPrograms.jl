"""
    SerialExecution

Functor object for using serial execution in a lshaped algorithm. Create by supplying a [`Serial`](@ref) object through `execution` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

"""
struct SerialExecution{H <: AbstractFeasibilityHandler,
                       T <: AbstractFloat,
                       A <: AbstractVector,
                       S <: MOI.AbstractOptimizer} <: AbstractExecution
    subproblems::Vector{SubProblem{H,T,S}}
    decisions::Tuple{Decisions, Decisions}
    subobjectives::A
    model_objectives::A

    function SerialExecution(structure::VerticalBlockStructure{2}, ::Type{F}, ::Type{T}, ::Type{A}, ::Type{S}) where {F <: AbstractFeasibility, T <: AbstractFloat, A <: AbstractVector, S <: MOI.AbstractOptimizer}
        H = HandlerType(F)
        return new{H,T,A,S}(Vector{SubProblem{H,T,S}}(), structure.decisions, A(), A())
    end
end

function num_thetas(lshaped::AbstractLShaped, ::SerialExecution)
    return num_thetas(num_subproblems(lshaped), lshaped.aggregation)
end

function initialize_subproblems!(execution::SerialExecution{H,T},
                                 scenarioproblems::ScenarioProblems,
                                 tolerance::AbstractFloat) where {H <: AbstractFeasibilityHandler,
                                                                  T <: AbstractFloat}
    # Assume sorted order
    master_indices = sort!(collect(keys(execution.decisions[1].decisions)),
                           by = idx -> idx.value)
    for i = 1:num_subproblems(scenarioproblems)
        push!(execution.subproblems, SubProblem(
            subproblem(scenarioproblems, i),
            i,
            T(probability(scenario(scenarioproblems, i))),
            T(tolerance),
            master_indices,
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
    update_known_decisions!(execution.decisions[2], lshaped.x)
    change = KnownValuesChange()
    # Assume no cuts are added
    added = false
    # Update and solve subproblems
    for subproblem in execution.subproblems
        update_subproblem!(subproblem, change)
        cut::SparseHyperPlane{T} = subproblem(lshaped.x)
        added |= aggregate_cut!(lshaped, lshaped.aggregation, cut)
    end
    added |= flush!(lshaped, lshaped.aggregation)
    # Return current objective value and cut_added flag
    return current_objective_value(lshaped), added
end

# function calculate_objective_value(lshaped::AbstractLShaped, execution::SerialExecution)
#     return get_obj(lshaped)⋅decision(lshaped) + sum([subproblem.π*subproblem(decision(lshaped)) for subproblem in execution.subproblems])
# end

# API
# ------------------------------------------------------------
function (execution::Serial)(structure::VerticalBlockStructure, ::Type{F}, ::Type{T}, ::Type{A}, ::Type{S}) where {F <: AbstractFeasibility, T <: AbstractFloat, A <: AbstractVector, S <: MOI.AbstractOptimizer}
    return SerialExecution(structure, F, T, A, S)
end

function str(::Serial)
    return ""
end
