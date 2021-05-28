"""
    SerialExecution

Functor object for using serial execution in a lshaped algorithm. Create by supplying a [`Serial`](@ref) object through `execution` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

"""
struct SerialExecution{T <: AbstractFloat,
                       A <: AbstractVector,
                       F <: AbstractFeasibilityAlgorithm,
                       I <: AbstractIntegerAlgorithm} <: AbstractLShapedExecution
    subproblems::Vector{SubProblem{T,F,I}}
    decisions::DecisionMap
    subobjectives::A
    model_objectives::A
    metadata::MetaData

    function SerialExecution(structure::StageDecompositionStructure{2, 1, <:Tuple{ScenarioProblems}},
                             feasibility_strategy::AbstractFeasibilityStrategy,
                             integer_strategy::AbstractIntegerStrategy,
                             ::Type{T},
                             ::Type{A}) where {T <: AbstractFloat,
                                               A <: AbstractVector}
        F = worker_type(feasibility_strategy)
        I = worker_type(integer_strategy)
        execution = new{T,A,F,I}(Vector{SubProblem{T,F,I}}(), structure.decisions[2], A(), A(), MetaData())
        # Load subproblems
        for i in 1:num_subproblems(structure, 2)
            push!(execution.subproblems, SubProblem(
                subproblem(structure, 2, i),
                i,
                T(probability(scenario(structure, 2, i))),
                feasibility_strategy,
                integer_strategy))
        end
        return execution
    end
end

function num_thetas(lshaped::AbstractLShaped, ::SerialExecution)
    return num_thetas(num_subproblems(lshaped), lshaped.aggregation)
end

function initialize_subproblems!(execution::SerialExecution{T},
                                 scenarioproblems::ScenarioProblems,
                                 feasibility_strategy::AbstractFeasibilityStrategy,
                                 integer_strategy::AbstractIntegerStrategy) where T <: AbstractFloat
    for i in 1:num_subproblems(scenarioproblems)
        push!(execution.subproblems, SubProblem(
            subproblem(scenarioproblems, i),
            i,
            T(probability(scenario(scenarioproblems, i))),
            feasibility_strategy,
            integer_strategy))
    end
    return nothing
end

function mutate_subproblems!(mutator::Function, execution::SerialExecution)
    for subproblem in execution.subproblems
        mutator(subproblem)
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

function resolve_subproblems!(lshaped::AbstractLShaped, execution::SerialExecution{T}) where T <: AbstractFloat
    # Update subproblems
    update_known_decisions!(execution.decisions, lshaped.x)
    # Assume no cuts are added
    added = false
    # Update and solve subproblems
    for subproblem in execution.subproblems
        update_subproblem!(subproblem)
        cut::SparseHyperPlane{T} = subproblem(lshaped.x, execution.metadata)
        added |= aggregate_cut!(lshaped, lshaped.aggregation, cut)
    end
    added |= flush!(lshaped, lshaped.aggregation)
    # Return current objective value and cut_added flag
    return current_objective_value(lshaped), added
end

# API
# ------------------------------------------------------------
function (execution::Serial)(structure::StageDecompositionStructure{2, 1, <:Tuple{ScenarioProblems}},
                             feasibility_strategy::AbstractFeasibilityStrategy,
                             integer_strategy::AbstractIntegerStrategy,
                             ::Type{T},
                             ::Type{A}) where {T <: AbstractFloat,
                                               A <: AbstractVector}
    return SerialExecution(structure,
                           feasibility_strategy,
                           integer_strategy,
                           T,
                           A)
end

function str(::Serial)
    return ""
end
