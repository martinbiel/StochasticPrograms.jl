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
using JuMP
using LinearAlgebra
using GLPKMathProgInterface
using OSQP

@everywhere import StochasticPrograms: probability, expected

include("../problems/problem_load.jl")
include("dfunctional_tests.jl")
include("dsolver_tests.jl")
