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

abstract type AbstractLShapedExecution end
# Execution API #
# ------------------------------------------------------------
num_thetas(lshaped::AbstractLShaped) = num_thetas(lshaped, lshaped.execution)
initialize_subproblems!(lshaped::AbstractLShaped, scenarioproblems::AbstractScenarioProblems) = initialize_subproblems!(lshaped.execution, scenarioproblems)
mutate_subproblems!(mutator::Function, lshaped::AbstractLShaped) = mutate_subproblems!(mutator, lshaped.execution)
finish_initilization!(lshaped::AbstractLShaped) = finish_initilization!(lshaped, lshaped.execution)
restore_subproblems!(lshaped::AbstractLShaped) = restore_subproblems!(lshaped, lshaped.execution)
solve_master!(lshaped::AbstractLShaped) = solve_master!(lshaped, lshaped.execution)
iterate!(lshaped::AbstractLShaped) = iterate!(lshaped, lshaped.execution)
start_workers!(lshaped::AbstractLShaped) = start_workers!(lshaped, lshaped.execution)
close_workers!(lshaped::AbstractLShaped) = close_workers!(lshaped, lshaped.execution)
resolve_subproblems!(lshaped::AbstractLShaped) = resolve_subproblems!(lshaped, lshaped.execution)
current_decision(lshaped::AbstractLShaped) = current_decision(lshaped, lshaped.execution)
calculate_objective_value(lshaped::AbstractLShaped) = calculate_objective_value(lshaped, lshaped.execution)
timestamp(lshaped::AbstractLShaped) = timestamp(lshaped, lshaped.execution)
incumbent_decision(lshaped::AbstractLShaped, t::Integer, regularizer::AbstractRegularization) = incumbent_decision(lshaped, t, regularizer, lshaped.execution)
incumbent_objective(lshaped::AbstractLShaped, t::Integer, regularizer::AbstractRegularization) = incumbent_objective(lshaped, t, regularizer, lshaped.execution)
incumbent_trustregion(lshaped::AbstractLShaped, t::Integer, regularizer::AbstractRegularization) = incumbent_trustregion(lshaped, t, regularizer, lshaped.execution)
readd_cuts!(lshaped::AbstractLShaped, consolidation::Consolidation) = readd_cuts!(lshaped, consolidation, lshaped.execution)
subobjectives(lshaped::AbstractLShaped) = subobjectives(lshaped, lshaped.execution)
set_subobjectives(lshaped::AbstractLShaped, Qs::AbstractVector) = set_subobjectives(lshaped, Qs, lshaped.execution)
model_objectives(lshaped::AbstractLShaped) = model_objectives(lshaped, lshaped.execution)
set_model_objectives(lshaped::AbstractLShaped, Qs::AbstractVector) = set_model_objectives(lshaped, Qs, lshaped.execution)
fill_submodels!(lshaped::AbstractLShaped, scenarioproblems::AbstractScenarioProblems) = fill_submodels!(lshaped, scenarioproblems, lshaped.execution)

# ------------------------------------------------------------
include("common.jl")
include("serial.jl")
include("distributed.jl")
include("synchronous.jl")
include("asynchronous.jl")
