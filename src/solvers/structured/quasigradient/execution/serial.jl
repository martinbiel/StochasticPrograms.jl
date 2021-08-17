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

"""
    SerialExecution

Functor object for using serial execution in a quasi-gradient algorithm. Create by supplying a [`Serial`](@ref) object through `execution` in `QuasiGradient.Optimizer` or by setting the [`Execution`](@ref) attribute.

"""
struct SerialExecution{T <: AbstractFloat, S <: AbstractSubProblem{T}} <: AbstractQuasiGradientExecution
    subproblems::Vector{S}
    decisions::DecisionMap

    function SerialExecution(structure::StageDecompositionStructure{2, 1, <:Tuple{ScenarioProblems}}, x::AbstractVector, subproblems::Unaltered, ::Type{T}) where T <: AbstractFloat
        execution = new{T,SubProblem{T}}(Vector{SubProblem{T}}(), structure.decisions[2])
        initialize_subproblems!(execution, scenarioproblems(structure, 2))
        return execution
    end

    function SerialExecution(structure::StageDecompositionStructure{2, 1, <:Tuple{ScenarioProblems}}, x::AbstractVector, subproblems::Smoothed, ::Type{T}) where T <: AbstractFloat
        execution = new{T,SmoothSubProblem{T}}(Vector{SmoothSubProblem{T}}(), structure.decisions[2])
        initialize_subproblems!(execution, scenarioproblems(structure, 2), x; type2dict(subproblems.parameters)...)
        return execution
    end
end

function initialize_subproblems!(execution::SerialExecution{T,SubProblem{T}}, scenarioproblems::ScenarioProblems) where T <: AbstractFloat
    for i in 1:num_subproblems(scenarioproblems)
        push!(execution.subproblems, SubProblem(
            subproblem(scenarioproblems, i),
            i,
            T(probability(scenario(scenarioproblems, i)))))
    end
    return nothing
end

function initialize_subproblems!(execution::SerialExecution{T,SmoothSubProblem{T}},
                                 scenarioproblems::ScenarioProblems,
                                 x::AbstractVector;
                                 kw...) where T <: AbstractFloat
    for vi in all_known_decisions(execution.decisions)
        # Unfix first-stage decisions
        execution.decisions[vi].state = NotTaken
    end
    # Load smooth subproblems (through Moreau envelope)
    for i in 1:num_subproblems(scenarioproblems)
        push!(execution.subproblems, SmoothSubProblem(
            subproblem(scenarioproblems, i),
            i,
            T(probability(scenario(scenarioproblems, i))),
            x; kw...))
    end
    return nothing
end

function resolve_subproblems!(quasigradient::AbstractQuasiGradient, execution::SerialExecution{T,SubProblem{T}}) where T <: AbstractFloat
    # Update subproblems
    update_known_decisions!(execution.decisions, quasigradient.x)
    # Initialize subgradient
    quasigradient.gradient .= quasigradient.c
    Q = zero(T)
    # Update and solve subproblems
    for subproblem in execution.subproblems
        update_subproblem!(subproblem)
        subgradient = subproblem(quasigradient.x)
        if isinf(subgradient.Q)
            return subgradient.Q
        end
        quasigradient.gradient .-= subgradient.δQ
        Q += subgradient.Q
    end
    # Return current objective value and subgradient
    return current_objective_value(quasigradient, Q)
end

function resolve_subproblems!(quasigradient::AbstractQuasiGradient, execution::SerialExecution{T,SmoothSubProblem{T}}) where T <: AbstractFloat
    # Update subproblems
    update_known_decisions!(execution.decisions, quasigradient.x)
    # Initialize subgradient
    quasigradient.gradient .= quasigradient.c
    Q = zero(T)
    # Update and solve subproblems
    for subproblem in execution.subproblems
        update_subproblem!(subproblem)
        gradient = subproblem(quasigradient.x)
        if isinf(gradient.Q)
            return gradient.Q
        end
        quasigradient.gradient .+= gradient.δQ
        Q += gradient.Q
    end
    # Return current objective value and subgradient
    return current_objective_value(quasigradient, Q)
end

function restore_subproblems!(::AbstractQuasiGradient, execution::SerialExecution{T,SubProblem{T}}) where T <: AbstractFloat
    return nothing
end

function restore_subproblems!(::AbstractQuasiGradient, execution::SerialExecution{T,SmoothSubProblem{T}}) where T <: AbstractFloat
    for subproblem in execution.subproblems
        restore_subproblem!(subproblem)
    end
    for vi in all_known_decisions(execution.decisions)
        # Remove common projection targets
        remove_decision!(execution.decisions, vi)
    end
    for vi in all_decisions(execution.decisions)
        # Re-fix first-stage decisions
        execution.decisions[vi].state = Known
    end
    return nothing
end

# API
# ------------------------------------------------------------
function (execution::Serial)(structure::StageDecompositionStructure{2, 1, <:Tuple{ScenarioProblems}},
                             x::AbstractVector,
                             subproblems::AbstractSubProblemState,
                             ::Type{T}) where T <: AbstractFloat
    return SerialExecution(structure, x, subproblems, T)
end

function str(::Serial)
    return ""
end
