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

# Scenario-decomposition spconstructs #
# =================================== #
function EWS(stochasticprogram::StochasticProgram, structure::ScenarioDecompositionStructure)
    # Restore structure if optimization has been run before
    restore_structure!(optimizer(stochasticprogram))
    # Dispatch on scenarioproblems
    return EWS_horizontal(scenarioproblems(structure))
end
function EWS_horizontal(scenarioproblems::ScenarioProblems)
    return outcome_mean(subproblems(scenarioproblems), probability.(scenarios(scenarioproblems)))
end
function EWS_horizontal(scenarioproblems::DistributedScenarioProblems)
    partial_ews = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_ews[i] = remotecall_fetch(
                w,
                scenarioproblems[w-1]) do sp
                    scenarioproblems = fetch(sp)
                    num_scenarios(scenarioproblems) == 0 && return 0.0
                    return outcome_mean(subproblems(scenarioproblems),
                                        probability.(scenarios(scenarioproblems)))
                end
        end
    end
    return sum(partial_ews)
end

function statistical_EWS(::StochasticProgram, structure::ScenarioDecompositionStructure)
    return statistical_EWS_horizontal(scenarioproblems(structure))
end
function statistical_EWS_horizontal(scenarioproblems::ScenarioProblems)
    # Welford algorithm on WS subproblems
    return welford(subproblems(scenarioproblems),
                   probability.(scenarios(scenarioproblems)))
end
function statistical_EWS_horizontal(scenarioproblems::DistributedScenarioProblems)
    partial_welfords = Vector{Tuple{Float64,Float64,Float64,Int}}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_welfords[i] = remotecall_fetch(
                w,
                scenarioproblems[w-1]) do sp
                    scenarioproblems = fetch(sp)
                    num_scenarios(scenarioproblems) == 0 && return 0.0, 0.0, 0.0, 0
                    return welford(subproblems(scenarioproblems),
                                   probability.(scenarios(scenarioproblems)))
                end
        end
    end
    𝔼WS, σ², _ = reduce(aggregate_welford, partial_welfords)
    return 𝔼WS, sqrt(σ²)
end
