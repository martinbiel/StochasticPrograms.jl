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

# Scenario-decomposition evaluation #
# ================================= #
function evaluate_decision(structure::ScenarioDecompositionStructure, decision::AbstractVector)
    return _eval_subproblems(structure, decision)
end

function statistically_evaluate_decision(structure::ScenarioDecompositionStructure, decision::AbstractVector)
    𝔼Q, σ² = _stat_eval_subproblems(structure, decision)
    return 𝔼Q, sqrt(σ²)
end

function _eval_subproblems(structure::ScenarioDecompositionStructure{2,1,Tuple{SP}},
                           decision::AbstractVector) where SP <: ScenarioProblems
    # Update decisions
    take_decisions!(structure.decisions[1], decision)
    map(subprob -> update_decisions!(subprob), subproblems(structure))
    # Cache result
    result = outcome_mean(subproblems(structure), probability.(scenarios(structure)))
    # Revert back to untaken decisions
    untake_decisions!(structure)
    # Return evaluation result
    return result
end
function _eval_subproblems(structure::ScenarioDecompositionStructure{2,1,Tuple{SP}},
                           decision::AbstractVector) where SP <: DistributedScenarioProblems
    Qs = Vector{Float64}(undef, nworkers())
    sp = scenarioproblems(structure)
    @sync begin
        for (i,w) in enumerate(workers())
            @async Qs[i] = remotecall_fetch(
                w,
                sp[w-1],
                sp.decisions[w-1],
                decision) do sp, d, x
                    scenarioproblems = fetch(sp)
                    num_scenarios(scenarioproblems) == 0 && return 0.0
                    take_decisions!(fetch(d), x)
                    map(subprob -> update_decisions!(subprob), subproblems(scenarioproblems))
                    return outcome_mean(subproblems(scenarioproblems),
                                        probability.(scenarios(scenarioproblems)))
                end
        end
    end
    return sum(Qs)
end

function _stat_eval_subproblems(structure::ScenarioDecompositionStructure{2,1,Tuple{SP}},
                                decision::AbstractVector) where SP <: ScenarioProblems
    # Update decisions
    take_decisions!(structure.decisions[1], decision)
    map(subprob -> update_decisions!(subprob), subproblems(structure))
    return welford(subproblems(structure), probability.(scenarios(structure)))
end
function _stat_eval_subproblems(structure::ScenarioDecompositionStructure{2,1,Tuple{SP}},
                                decision::AbstractVector) where SP <: DistributedScenarioProblems
    partial_welfords = Vector{Tuple{Float64,Float64,Float64,Int}}(undef, nworkers())
    sp = scenarioproblems(structure)
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_welfords[i] = remotecall_fetch(
                w,
                sp[w-1],
                sp.decisions[w-1],
                x) do sp, d, x
                    scenarioproblems = fetch(sp)
                    num_scenarios(scenarioproblems) == 0 && return 0.0, 0.0, 0.0, 0
                    take_decisions!(fetch(d), x)
                    map(subprob -> update_decisions!(subprob), subproblems(scenarioproblems))
                    return welford(subproblems(scenarioproblems),
                                   probability.(scenarios(scenarioproblems)))
                end
        end
    end
    𝔼Q, σ², _ = reduce(aggregate_welford, partial_welfords)
    return 𝔼Q, σ²
end
