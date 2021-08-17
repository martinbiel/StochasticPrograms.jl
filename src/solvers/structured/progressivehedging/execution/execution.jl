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

abstract type AbstractProgressiveHedgingExecution end
# Execution API #
# ------------------------------------------------------------
initialize_subproblems!(ph::AbstractProgressiveHedging, scenarioproblems::AbstractScenarioProblems, penaltyterm::AbstractPenaltyTerm) = initialize_subproblems!(ph, ph.execution, scenarioproblems, penaltyterm)
finish_initilization!(ph::AbstractProgressiveHedging, penalty::AbstractFloat) = finish_initilization!(ph.execution, penalty)
restore_subproblems!(ph::AbstractProgressiveHedging) = restore_subproblems!(ph, ph.execution)
iterate!(ph::AbstractProgressiveHedging) = iterate!(ph, ph.execution)
start_workers!(ph::AbstractProgressiveHedging) = start_workers!(ph, ph.execution)
close_workers!(ph::AbstractProgressiveHedging) = close_workers!(ph, ph.execution)
resolve_subproblems!(ph::AbstractProgressiveHedging) = resolve_subproblems!(ph, ph.execution)
update_iterate!(ph::AbstractProgressiveHedging) = update_iterate!(ph, ph.execution)
update_subproblems!(ph::AbstractProgressiveHedging) = update_subproblems!(ph, ph.execution)
update_dual_gap!(ph::AbstractProgressiveHedging) = update_dual_gap!(ph, ph.execution)
calculate_objective_value(ph::AbstractProgressiveHedging) = calculate_objective_value(ph, ph.execution)
scalar_subproblem_reduction(value::Function, ph::AbstractProgressiveHedging) = scalar_subproblem_reduction(value, ph.execution)
vector_subproblem_reduction(value::Function, ph::AbstractProgressiveHedging, n::Integer) = scalar_subproblem_reduction(value, ph.execution, n)
# ------------------------------------------------------------
include("common.jl")
include("serial.jl")
include("channels.jl")
include("distributed.jl")
include("synchronous.jl")
include("asynchronous.jl")
