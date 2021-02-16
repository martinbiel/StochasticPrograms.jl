"""
    SynchronousExecution

Functor object for using synchronous execution in an quasi-gradient algorithm (assuming multiple Julia cores are available). Create by supplying a [`Synchronous`](@ref) object through `execution` in `QuasiGradient.Optimizer` or by setting the [`Execution`](@ref) attribute.

"""
struct SynchronousExecution{T <: AbstractFloat} <: AbstractQuasiGradientExecution
    subworkers::Vector{SubWorker{T}}
    decisions::Vector{DecisionChannel}

    function SynchronousExecution(structure::VerticalStructure{2, 1, <:Tuple{DistributedScenarioProblems}}, ::Type{T}) where T <: AbstractFloat
        return new{T}(Vector{SubWorker{T}}(undef, nworkers()),
                      scenarioproblems(structure).decisions)
    end
end

function initialize_subproblems!(execution::SynchronousExecution,
                                 scenarioproblems::DistributedScenarioProblems)
    load_subproblems!(execution.subworkers, scenarioproblems, execution.decisions)
    return nothing
end

function restore_subproblems!(::AbstractQuasiGradient, execution::SynchronousExecution)
    restore_subproblems!(execution.subworkers)
    return nothing
end

function resolve_subproblems!(quasigradient::AbstractQuasiGradient, execution::SynchronousExecution{T}) where T <: AbstractFloat
    # Prepare
    partial_gradients = Vector{typeof(quasigradient.subgradient)}(undef, nworkers())
    partial_objectives = Vector{T}(undef, nworkers())
    # Initialize subgradient
    quasigradient.subgradient .= quasigradient.c
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_objectives[i], partial_gradients[i] =
                remotecall_fetch(w,
                                 execution.subworkers[w-1],
                                 execution.decisions[w-1],
                                 quasigradient.x) do sw, decisions, x
                                     # Fetch all subproblems stored in worker
                                     subproblems::Vector{SubProblem{T}} = fetch(sw)
                                     # Prepare
                                     partial_subgradient = zero(x)
                                     Q = zero(T)
                                     if length(subproblems) == 0
                                         return Q, partial_subgradient
                                     end
                                     # Update subproblems
                                     update_known_decisions!(fetch(decisions), x)
                                     # Update and solve subproblems
                                     for subproblem in subproblems
                                         update_subproblem!(subproblem)
                                         subgradient::SparseSubgradient{T} = subproblem(x)
                                         partial_subgradient .-= subgradient.δQ
                                         Q += subgradient.Q
                                     end
                                     return Q, partial_subgradient
                                 end
        end
    end
    # Collect results
    quasigradient.subgradient .+= sum(partial_gradients)
    # Return current objective value and cut_added flag
    return current_objective_value(quasigradient, sum(partial_objectives))
end

# API
# ------------------------------------------------------------
function (execution::Synchronous)(structure::VerticalStructure{2, 1, <:Tuple{DistributedScenarioProblems}},
                                  ::Type{T}) where {T <: AbstractFloat}
    return SynchronousExecution(structure, T)
end

function str(::Synchronous)
    return "Synchronous "
end
