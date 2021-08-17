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

abstract type AbstractQuasiGradientExecution end
# Execution API #
# ------------------------------------------------------------
restore_subproblems!(quasigradient::AbstractQuasiGradient) = restore_subproblems!(quasigradient, quasigradient.execution)
solve_master!(quasigradient::AbstractQuasiGradient) = solve_master!(quasigradient, quasigradient.execution)
iterate!(quasigradient::AbstractQuasiGradient) = iterate!(quasigradient, quasigradient.execution)
start_workers!(quasigradient::AbstractQuasiGradient) = start_workers!(quasigradient, quasigradient.execution)
close_workers!(quasigradient::AbstractQuasiGradient) = close_workers!(quasigradient, quasigradient.execution)
resolve_subproblems!(quasigradient::AbstractQuasiGradient) = resolve_subproblems!(quasigradient, quasigradient.execution)
current_decision(quasigradient::AbstractQuasiGradient) = current_decision(quasigradient, quasigradient.execution)
calculate_objective_value(quasigradient::AbstractQuasiGradient) = calculate_objective_value(quasigradient, quasigradient.execution)
timestamp(quasigradient::AbstractQuasiGradient) = timestamp(quasigradient, quasigradient.execution)
subobjectives(quasigradient::AbstractQuasiGradient) = subobjectives(quasigradient, quasigradient.execution)
set_subobjectives(quasigradient::AbstractQuasiGradient, Qs::AbstractVector) = set_subobjectives(quasigradient, Qs, quasigradient.execution)
# ------------------------------------------------------------
include("common.jl")
include("serial.jl")
include("synchronous.jl")
#include("asynchronous.jl")
