# MIT License
#
# Copyright (c) 2018 Martin Biel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

SubWorker{S} = RemoteChannel{Channel{Vector{S}}}
NonSmoothSubWorker{T} = SubWorker{SubProblem{T}}
SmoothSubWorker{T} = SubWorker{SmoothSubProblem{T}}
ScenarioProblemChannel{S} = RemoteChannel{Channel{ScenarioProblems{S}}}

"""
    SynchronousExecution

Functor object for using synchronous execution in an quasi-gradient algorithm (assuming multiple Julia cores are available). Create by supplying a [`Synchronous`](@ref) object through `execution` in `QuasiGradient.Optimizer` or by setting the [`Execution`](@ref) attribute.

"""
struct SynchronousExecution{T <: AbstractFloat, S <: AbstractSubProblem{T}} <: AbstractQuasiGradientExecution
    subworkers::Vector{SubWorker{S}}
    decisions::Vector{DecisionChannel}

    function SynchronousExecution(structure::StageDecompositionStructure{2, 1, <:Tuple{DistributedScenarioProblems}}, x::AbstractVector, subproblems::Unaltered, ::Type{T}) where T <: AbstractFloat
        execution = new{T, SubProblem{T}}(Vector{NonSmoothSubWorker{T}}(undef, nworkers()),
                           scenarioproblems(structure).decisions)
        initialize_subproblems!(execution, scenarioproblems(structure, 2))
        return execution
    end

    function SynchronousExecution(structure::StageDecompositionStructure{2, 1, <:Tuple{DistributedScenarioProblems}}, x::AbstractVector, subproblems::Smoothed, ::Type{T}) where T <: AbstractFloat
        execution = new{T, SmoothSubProblem{T}}(Vector{SmoothSubWorker{T}}(undef, nworkers()),
                                                scenarioproblems(structure).decisions)
        initialize_subproblems!(execution, scenarioproblems(structure, 2), x, subproblems.parameters)
        return execution
    end
end

function initialize_subproblems!(execution::SynchronousExecution{T, SubProblem{T}},
                                 scenarioproblems::DistributedScenarioProblems) where T <: AbstractFloat
    # Create subproblems on worker processes
    @sync begin
        for w in workers()
            execution.subworkers[w-1] = RemoteChannel(() -> Channel{Vector{SubProblem{T}}}(1), w)
            prev = map(2:(w-1)) do p
                scenarioproblems.scenario_distribution[p-1]
            end
            start_id = isempty(prev) ? 0 : sum(prev)
            @async remotecall_fetch(
                w,
                execution.subworkers[w-1],
                scenarioproblems[w-1],
                start_id) do sw, sp_, start_id
                    sp = fetch(sp_)
                    subproblems = Vector{SubProblem{T}}(undef, num_subproblems(sp))
                    for i in 1:num_subproblems(sp)
                        subproblems[i] = SubProblem(
                            subproblem(sp, i),
                            start_id + i,
                            T(probability(scenario(sp, i))))
                    end
                    put!(sw, subproblems)
                    return nothing
                end
        end
    end
    return nothing
end

function initialize_subproblems!(execution::SynchronousExecution{T, SmoothSubProblem{T}},
                                 scenarioproblems::DistributedScenarioProblems,
                                 x::AbstractVector,
                                 params::SmoothingParameters) where T <: AbstractFloat
    # Create subproblems on worker processes
    @sync begin
        for w in workers()
            execution.subworkers[w-1] = RemoteChannel(() -> Channel{Vector{SmoothSubProblem{T}}}(1), w)
            prev = map(2:(w-1)) do p
                scenarioproblems.scenario_distribution[p-1]
            end
            start_id = isempty(prev) ? 0 : sum(prev)
            @async remotecall_fetch(
                w,
                execution.subworkers[w-1],
                execution.decisions[w-1],
                scenarioproblems[w-1],
                x,
                start_id,
                params) do sw, decisions, sp_, x, start_id, params
                    for vi in all_known_decisions(fetch(decisions))
                        # Unfix first-stage decisions
                        fetch(decisions)[vi].state = NotTaken
                    end
                    sp = fetch(sp_)
                    subproblems = Vector{SmoothSubProblem{T}}(undef, num_subproblems(sp))
                    for i in 1:num_subproblems(sp)
                        subproblems[i] = SmoothSubProblem(
                            subproblem(sp, i),
                            start_id + i,
                            T(probability(scenario(sp, i))),
                            x;
                            type2dict(params)...)
                    end
                    put!(sw, subproblems)
                    return nothing
                end
        end
    end
    return nothing
end

function restore_subproblems!(::AbstractQuasiGradient, execution::SynchronousExecution{T,SubProblem{T}}) where T <: AbstractFloat
    return nothing
end

function restore_subproblems!(::AbstractQuasiGradient, execution::SynchronousExecution{T,SmoothSubProblem{T}}) where T <: AbstractFloat
    @sync begin
        for w in workers()
            @async remotecall_fetch(w, execution.subworkers[w-1], execution.decisions[w-1]) do sw, decisions
                for subproblem in fetch(sw)
                    restore_subproblem!(subproblem)
                end
                for vi in all_known_decisions(fetch(decisions))
                    # Remove common projection targets
                    remove_decision!(fetch(decisions), vi)
                end
                for vi in all_decisions(fetch(decisions))
                    # Re-fix first-stage decisions
                    fetch(decisions)[vi].state = Known
                end
            end
        end
    end
    return nothing
end

function resolve_subproblems!(quasigradient::AbstractQuasiGradient, execution::SynchronousExecution{T,SubProblem{T}}) where T <: AbstractFloat
    # Prepare
    partial_gradients = Vector{typeof(quasigradient.gradient)}(undef, nworkers())
    partial_objectives = Vector{T}(undef, nworkers())
    # Initialize subgradient
    quasigradient.gradient .= quasigradient.c
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
                                         subgradient::SparseGradient{T} = subproblem(x)
                                         if isinf(subgradient.Q)
                                             return subgradient.Q, partial_subgradient
                                         end
                                         partial_subgradient .-= subgradient.δQ
                                         Q += subgradient.Q
                                     end
                                     return Q, partial_subgradient
                                 end
        end
    end
    # Collect results
    quasigradient.gradient .+= sum(partial_gradients)
    # Return current objective value and cut_added flag
    return current_objective_value(quasigradient, sum(partial_objectives))
end

function resolve_subproblems!(quasigradient::AbstractQuasiGradient, execution::SynchronousExecution{T,SmoothSubProblem{T}}) where T <: AbstractFloat
    # Prepare
    partial_gradients = Vector{typeof(quasigradient.gradient)}(undef, nworkers())
    partial_objectives = Vector{T}(undef, nworkers())
    # Initialize subgradient
    quasigradient.gradient .= quasigradient.c
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_objectives[i], partial_gradients[i] =
                remotecall_fetch(w,
                                 execution.subworkers[w-1],
                                 execution.decisions[w-1],
                                 quasigradient.x) do sw, decisions, x
                                     # Fetch all subproblems stored in worker
                                     subproblems::Vector{SmoothSubProblem{T}} = fetch(sw)
                                     # Prepare
                                     partial_gradient = zero(x)
                                     Q = zero(T)
                                     if length(subproblems) == 0
                                         return Q, partial_gradient
                                     end
                                     # Update subproblems
                                     update_known_decisions!(fetch(decisions), x)
                                     # Update and solve subproblems
                                     for subproblem in subproblems
                                         update_subproblem!(subproblem)
                                         gradient::DenseGradient{T} = subproblem(x)
                                         if isinf(gradient.Q)
                                             return gradient.Q, partial_gradient
                                         end
                                         partial_gradient .+= gradient.δQ
                                         Q += gradient.Q
                                     end
                                     return Q, partial_gradient
                                 end
        end
    end
    # Collect results
    quasigradient.gradient .+= sum(partial_gradients)
    # Return current objective value and cut_added flag
    return current_objective_value(quasigradient, sum(partial_objectives))
end

# API
# ------------------------------------------------------------
function (execution::Synchronous)(structure::StageDecompositionStructure{2, 1, <:Tuple{DistributedScenarioProblems}},
                                  x::AbstractVector,
                                  subproblems::AbstractSubProblemState,
                                  ::Type{T}) where {T <: AbstractFloat}
    return SynchronousExecution(structure, x, subproblems, T)
end

function str(::Synchronous)
    return "Synchronous "
end
