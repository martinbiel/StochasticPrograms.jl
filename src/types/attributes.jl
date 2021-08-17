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

# Scenario-dependent attributes #
# ========================== #
struct ScenarioDependentOptimizerAttribute <: MOI.AbstractOptimizerAttribute
    stage::Int
    scenario_index::Int
    attr::MOI.AbstractOptimizerAttribute
end

struct ScenarioDependentModelAttribute <: MOI.AbstractModelAttribute
    stage::Int
    scenario_index::Int
    attr::MOI.AbstractModelAttribute
end

struct ScenarioDependentVariableAttribute <: MOI.AbstractVariableAttribute
    stage::Int
    scenario_index::Int
    attr::MOI.AbstractVariableAttribute
end

struct ScenarioDependentConstraintAttribute <: MOI.AbstractConstraintAttribute
    stage::Int
    scenario_index::Int
    attr::MOI.AbstractConstraintAttribute
end

const AnyScenarioDependentAttribute = Union{ScenarioDependentOptimizerAttribute,
                                            ScenarioDependentModelAttribute,
                                            ScenarioDependentVariableAttribute,
                                            ScenarioDependentConstraintAttribute}

MOI.is_set_by_optimize(attr::AnyScenarioDependentAttribute) = MOI.is_set_by_optimize(attr.attr)


is_structure_independent(attr::MOI.AnyAttribute) = true
is_structure_independent(::Union{MOI.ObjectiveFunction,
                                 MOI.ObjectiveFunctionType,
                                 MOI.ObjectiveSense}) = false
is_structure_independent(attr::AnyScenarioDependentAttribute) = is_structure_independent(attr.attr)
