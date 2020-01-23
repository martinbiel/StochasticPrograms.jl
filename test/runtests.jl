using StochasticPrograms
using JuMP
using GLPKMathProgInterface
using OSQP
using LinearAlgebra
using Logging
using Test

import StochasticPrograms: probability, expected

include("problems/problem_load.jl")
#include("functional_tests.jl")
#include("solver_tests.jl")
include("distributed/distributed_tests.jl")
