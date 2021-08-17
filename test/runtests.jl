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

using StochasticPrograms
using JuMP
using GLPK
using Ipopt
using Distributed
using Distributions
using LinearAlgebra
using Logging
using Test

import StochasticPrograms: probability, expected

include("decisions/decisions.jl")
TestDecisionFunctions.runtests()
TestDecisionExpressions.runtests()
TestDecisionOperators.runtests()
TestDecisionVariable.runtests()
TestDecisionConstraint.runtests()
TestDecisionObjective.runtests()
TestSolve.runtests()
include("problems/problem_load.jl")
include("functional_tests.jl")
include("solver_tests.jl")
include("distributed/distributed_tests.jl")
