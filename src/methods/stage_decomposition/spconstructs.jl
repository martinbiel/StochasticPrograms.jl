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

# Stage-decomposition spconstructs #
# ================================ #
function EWS(stochasticprogram::StochasticProgram,
             structure::StageDecompositionStructure{2,1,Tuple{SP}}) where SP <: DistributedScenarioProblems
    partial_ews = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_ews[i] = remotecall_fetch(
                w,
                scenarioproblems(structure, 2)[w-1],
                stochasticprogram.generator[:stage_1],
                stochasticprogram.generator[:stage_2],
                stage_parameters(stochasticprogram, 1),
                stage_parameters(stochasticprogram, 2),
                subproblem_optimizer(stochasticprogram)) do sp, gen_one, gen_two, one_params, two_params, opt
                    scenarioproblems = fetch(sp)
                    num_scenarios(scenarioproblems) == 0 && return 0.0
                    subproblems = map(scenarios(scenarioproblems)) do scenario
                        ws = _WS(gen_one,
                                 gen_two,
                                 one_params,
                                 two_params,
                                 scenario,
                                 DecisionMap(),
                                 DecisionMap(),
                                 opt)
                        return ws
                    end
                    return outcome_mean(subproblems, probability.(scenarios(scenarioproblems)))
                end
        end
    end
    return sum(partial_ews)
end

function statistical_EWS(stochasticprogram::StochasticProgram,
                         structure::StageDecompositionStructure{2,1,Tuple{SP}}) where SP <: DistributedScenarioProblems
    partial_welfords = Vector{Tuple{Float64,Float64,Float64,Int}}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_ews[i] = remotecall_fetch(
                w,
                scenarioproblems(structure, 2)[w-1],
                stochasticprogram.generator[:stage_1],
                stochasticprogram.generator[:stage_2],
                stage_parameters(stochasticprogram, 1),
                stage_parameters(stochasticprogram, 2),
                subproblem_optimizer(stochasticprogram)) do sp, gen_one, gen_two, one_params, two_params, opt
                    scenarioproblems = fetch(sp)
                    num_scenarios(scenarioproblems) == 0 && return 0.0, 0.0, 0.0, 0
                    ws_models = map(scenarios(scenarioproblems)) do scenario
                        ws = _WS(gen_one,
                                 gen_two,
                                 one_params,
                                 two_params,
                                 scenario,
                                 DecisionMap(),
                                 DecisionMap(),
                                 opt)
                        return ws
                    end
                    return welford(ws_models, probability.(scenarios(scenarioproblems)))
                end
        end
    end
    𝔼WS, σ², _ = reduce(aggregate_welford, partial_welfords)
    return 𝔼WS, sqrt(σ²)
end
