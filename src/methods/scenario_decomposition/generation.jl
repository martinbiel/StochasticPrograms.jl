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

# Scenario-decomposition generation #
# ================================= #
function generate!(stochasticprogram::StochasticProgram{N}, structure::ScenarioDecompositionStructure{N}) where N
    # Generate all stages
    for stage in 2:N
        generate!(stochasticprogram, structure, stage)
    end
    return nothing
end

function generate!(stochasticprogram::TwoStageStochasticProgram, structure::ScenarioDecompositionStructure{2}, stage::Integer)
    stage == 2 || error("Stage $stage not available in two-stage model.")
    # Check generators
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Consider @stage 2.")
    # Sanity check on scenario probabilities
    if num_scenarios(structure, stage) > 0
        p = stage_probability(structure, stage)
        abs(p - 1.0) <= 1e-6 || @warn "Scenario probabilities do not add up to one. The probability sum is given by $p"
    end
    # Generate
    generate_horizontal!(scenarioproblems(structure, stage),
                         generator(stochasticprogram, :stage_1),
                         generator(stochasticprogram, :stage_2),
                         stage_parameters(stochasticprogram, 1),
                         stage_parameters(stochasticprogram, 2),
                         structure.decisions[stage-1],
                         subproblem_optimizer(stochasticprogram))
    return nothing
end

function generate_horizontal!(scenarioproblems::ScenarioProblems,
                              stage_one_generator::Function,
                              stage_two_generator::Function,
                              stage_one_params::Any,
                              stage_two_params::Any,
                              decision_map::DecisionMap,
                              optimizer)
    for i in num_subproblems(scenarioproblems)+1:num_scenarios(scenarioproblems)
        push!(scenarioproblems.problems, _WS(stage_one_generator,
                                             stage_two_generator,
                                             stage_one_params,
                                             stage_two_params,
                                             scenario(scenarioproblems,i),
                                             decision_map,
                                             DecisionMap(),
                                             optimizer))
    end
    return nothing
end
function generate_horizontal!(scenarioproblems::DistributedScenarioProblems,
                              stage_one_generator::Function,
                              stage_two_generator::Function,
                              stage_one_params::Any,
                              stage_two_params::Any,
                              ::DecisionMap,
                              optimizer)
    @sync begin
        for w in workers()
            @async remotecall_fetch(
                w,
                scenarioproblems[w-1],
                stage_one_generator,
                stage_two_generator,
                stage_one_params,
                stage_two_params,
                scenarioproblems.decisions[w-1],
                optimizer) do sp, gen_one, gen_two, one_params, two_params, decisions, opt
                    generate_horizontal!(fetch(sp),
                                         gen_one,
                                         gen_two,
                                         one_params,
                                         two_params,
                                         fetch(decisions),
                                         opt)
                end
        end
    end
    return nothing
end

function clear!(structure::ScenarioDecompositionStructure{N}) where N
    # Clear decisions
    clear!(structure.decisions)
    # Clear all stages
    for stage in 2:N
        clear_stage!(structure, stage)
    end
    return nothing
end

function clear_stage!(structure::ScenarioDecompositionStructure{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    clear!(scenarioproblems(structure, s))
    return nothing
end
