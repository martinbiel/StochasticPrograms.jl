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
    NoIntegerAlgorithm

Empty functor object for running an L-shaped algorithm without dealing with integer variables.

"""
struct NoIntegerAlgorithm <: AbstractIntegerAlgorithm
    check::Bool
end

function initialize_integer_algorithm!(integer::NoIntegerAlgorithm, first_stage::JuMP.Model)
    # Sanity check
    if integer.check &&
       (any(is_binary, all_decision_variables(first_stage, 1)) ||
       any(is_integer, all_decision_variables(first_stage, 1)))
        @warn "First-stage has binary/integer decisions and no `IntegerStrategy` has been set. Procedure will fail if second-stage has binary/integer variables. Otherwise, the master_optimizer must be integer-capable."
    end
    return nothing
end

function initialize_integer_algorithm!(integer::NoIntegerAlgorithm, subproblem::SubProblem)
    if integer.check &&
       (any(is_binary, all_decision_variables(subproblem.model, StochasticPrograms.stage(subproblem.model))) ||
       any(is_integer, all_decision_variables(subproblem.model, StochasticPrograms.stage(subproblem.model))) ||
       any(is_binary, all_auxiliary_variables(subproblem.model)) ||
       any(is_integer, all_auxiliary_variables(subproblem.model)))
        error("Second-stage has binary/integer decisions. Rerun procedure with an `IntegerStrategy`.")
    end
    return nothing
end

function handle_integrality!(lshaped::AbstractLShaped, ::NoIntegerAlgorithm)
    # Ensure any binary/integer decisions are rounded
    for (i,dvar) in enumerate(all_decision_variables(lshaped.structure.first_stage, 1))
        if is_binary(dvar) || is_integer(dvar)
            lshaped.x[i] = round(lshaped.x[i])
        end
    end
    return nothing
end

function integer_variables(::NoIntegerAlgorithm)
    return MOI.VariableIndex[]
end

function check_optimality(::AbstractLShaped, ::NoIntegerAlgorithm)
    return true
end

function solve_subproblem(subproblem::SubProblem,
                          metadata,
                          ::NoFeasibilityAlgorithm,
                          ::NoIntegerAlgorithm,
                          x::AbstractVector)
    return solve_subproblem(subproblem, x)
end

function solve_subproblem(subproblem::SubProblem,
                          metadata,
                          feasibility_algorithm::FeasibilityCutsWorker,
                          ::NoIntegerAlgorithm,
                          x::AbstractVector)
    model = subproblem.optimizer
    if !prepared(feasibility_algorithm)
        prepare!(model, feasibility_algorithm)
    else
        activate!(model, feasibility_algorithm)
    end
    # Optimize auxiliary problem
    MOI.optimize!(model)
    # Sanity check that aux problem could be solved
    status = MOI.get(subproblem.optimizer, MOI.TerminationStatus())
    if !(status ∈ AcceptableTermination)
        error("Subproblem $(subproblem.id) was not solved properly during feasibility check, returned status code: $status")
    end
    sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    w = correction * MOI.get(model, MOI.ObjectiveValue())
    # Ensure correction is available in master
    set_metadata!(metadata, subproblem.id, :correction, correction)
    # Check feasibility
    if w > sqrt(eps())
        # Subproblem is infeasible, create feasibility cut
        return FeasibilityCut(subproblem, x)
    end
    # Restore subproblem and solve as usual
    deactivate!(model, feasibility_algorithm)
    return solve_subproblem(subproblem, x)
end

"""
    IgnoreIntegers

Factory object for [`NoIntegerAlgorithm`](@ref). Passed by default to `integer_strategy` in `LShaped.Optimizer`.

"""
struct IgnoreIntegers <: AbstractIntegerStrategy
    check::Bool

    IgnoreIntegers(check::Bool) = new(check)
end

IgnoreIntegers(; check = false) = IgnoreIntegers(check)

function master(ignore::IgnoreIntegers, ::Type{T}) where T <: AbstractFloat
    return NoIntegerAlgorithm(ignore.check)
end

function worker(ignore::IgnoreIntegers, ::Type{T}) where T <: AbstractFloat
    return NoIntegerAlgorithm(ignore.check)
end
function worker_type(::IgnoreIntegers)
    return NoIntegerAlgorithm
end
