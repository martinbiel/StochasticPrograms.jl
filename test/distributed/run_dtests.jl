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

using Test
using Distributed
include(joinpath(Sys.BINDIR, "..", "share", "julia", "test", "testenv.jl"))
addprocs_with_testenv(3)
@test nworkers() == 3
@everywhere using Logging
for w in workers()
    # Do not log on worker nodes
    remotecall(()->global_logger(NullLogger()),w)
end

@everywhere using StochasticPrograms
@everywhere using JuMP
@everywhere using LinearAlgebra
@everywhere using GLPK
@everywhere using Ipopt

@everywhere using Distributions

@everywhere import StochasticPrograms: probability, expected

include("../decisions/decisions.jl")
TestDecisionVariable.run_dtests()
TestDecisionConstraint.run_dtests()
TestDecisionObjective.run_dtests()
include("../problems/problem_load.jl")
include("dfunctional_tests.jl")
include("dsolver_tests.jl")
