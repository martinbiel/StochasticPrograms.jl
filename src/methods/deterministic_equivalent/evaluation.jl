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

# Deterministic equivalent evaluation #
# =================================== #
function evaluate_decision(structure::DeterministicEquivalent{2}, decision::AbstractVector)
    # Update decisions (checks handled by structure model)
    take_decisions!(structure.model, all_decision_variables(structure.model, 1), decision)
    # Optimize model
    optimize!(structure.model)
    # Switch on return status
    status = termination_status(structure.model)
    result = if status in AcceptableTermination
        result = objective_value(structure.model)
    else
        result = if status == MOI.INFEASIBLE
            result = objective_sense(structure.model) == MOI.MAX_SENSE ? -Inf : Inf
        elseif status == MOI.DUAL_INFEASIBLE
            result = objective_sense(structure.model) == MOI.MAX_SENSE ? Inf : -Inf
        else
            error("Deterministically equivalent model could not be solved, returned status: $status")
        end
    end
    # Revert back to untaken decisions
    untake_decisions!(structure.model, all_decision_variables(structure.model, 1))
    # Return evaluation result
    return result
end

function statistically_evaluate_decision(structure::DeterministicEquivalent{2}, decision::AbstractVector)
    # Update decisions (checks handled by structure model)
    take_decisions!(structure.model, all_decision_variables(structure.model, 1), decision)
    # Optimize model
    optimize!(structure.model)
    # Get sense-correted objective value
    status = termination_status(structure.model)
    Q̂ = if status in AcceptableTermination
        Q̂ = objective_value(structure.model)
    else
        Q̂ = if status == MOI.INFEASIBLE
            return objective_sense(structure.model) == MOI.MAX_SENSE ? (-Inf, 0) : (Inf, 0)
        elseif status == MOI.DUAL_INFEASIBLE
            return objective_sense(structure.model) == MOI.MAX_SENSE ? (Inf, 0) : (-Inf, 0)
        else
            error("Deterministically equivalent model could not be solved, returned status: $status")
        end
    end
    # Calculate subobjectives
    N = num_scenarios(structure)
    Q = Vector{Float64}(undef, N)
    obj_sense = objective_sense(structure.model)
    for (i, sub_objective) in enumerate(structure.decisions.stage_objectives[2])
        (sub_sense, sub_obj) = sub_objective
        Qᵢ = MOIU.eval_variables(sub_obj) do idx
            return MOI.get(backend(structure.model), MOI.VariablePrimal(), idx)
        end
        if obj_sense == sub_sense
            Q[i] = Qᵢ
        else
            Q[i] = -Qᵢ
        end
    end
    probabilities = map(1:num_scenarios(structure, 2)) do i
        probability(structure, 2, i)
    end
    weights = ProbabilityWeights(probabilities)
    σ = std(Q, weights, corrected = true)
    return Q̂, σ
end
