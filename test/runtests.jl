using StochasticPrograms
using LShapedSolvers
using JuMP
using Clp
using Base.Test

import StochasticPrograms: probability, expected

struct SPResult
    x̄::Vector{Float64}
    VRP::Float64
    EWS::Float64
    EVPI::Float64
    VSS::Float64
    EV::Float64
    EEV::Float64
end

lssolver = LShapedSolver(:ls,ClpSolver(),log=false)
problems = Vector{Tuple{JuMP.Model,SPResult,String}}()
info("Loading test problems...")
info("Loading simple...")
include("simple.jl")
info("Loading farmer...")
include("farmer.jl")

info("Test problems loaded. Starting test sequence.")
@testset "SP Constructs: $name" for (sp,res,name) in problems
    solve(sp)
    @test norm(optimal_decision(sp)-res.x̄) <= 1e-2
    @test abs(optimal_value(sp)-res.VRP) <= 1e-2
    @test abs(EWS(sp)-res.EWS) <= 1e-2
    @test abs(EVPI(sp)-res.EVPI) <= 1e-2
    @test abs(VSS(sp)-res.VSS) <= 1e-2
    @test abs(EV(sp)-res.EV) <= 1e-2
    @test abs(EEV(sp)-res.EEV) <= 1e-2
end

@testset "SP Constructs (L-shaped Solver): $name" for (sp,res,name) in problems
    set_spsolver(sp,lssolver)
    solve(sp)
    @test norm(optimal_decision(sp)-res.x̄) <= 1e-2
    @test abs(optimal_value(sp)-res.VRP) <= 1e-2
    @test abs(EWS(sp)-res.EWS) <= 1e-2
    @test abs(EVPI(sp)-res.EVPI) <= 1e-2
    @test abs(VSS(sp)-res.VSS) <= 1e-2
    @test abs(EV(sp)-res.EV) <= 1e-2
    @test abs(EEV(sp)-res.EEV) <= 1e-2
end

@testset "Inequalities: $name" for (sp,res,name) in problems
    @test EWS(sp) <= VRP(sp)
    @test VRP(sp) <= EEV(sp)
    @test VSS(sp) >= 0
    @test EVPI(sp) >= 0
    @test VSS(sp) <= EEV(sp)-EV(sp)
    @test EVPI(sp) <= EEV(sp)-EV(sp)
end

info("Preparing simple sampler...")
include("sampling.jl")
@testset "Sampling" begin
    @test nscenarios(sampled_sp) == 0
    @test nsubproblems(sampled_sp) == 0
    sample!(sampled_sp,100)
    @test nscenarios(sampled_sp) == 100
    @test nsubproblems(sampled_sp) == 100
    @test abs(probability(sampled_sp)-1.0) <= 1e-6
    sample!(sampled_sp,100)
    @test nscenarios(sampled_sp) == 200
    @test nsubproblems(sampled_sp) == 200
    @test abs(probability(sampled_sp)-1.0) <= 1e-6
end

info("Starting distributed tests...")

include("/usr/share/julia/test/testenv.jl")
push!(test_exeflags.exec,"--color=yes")
cmd = `$test_exename $test_exeflags run_dtests.jl`

if !success(pipeline(cmd; stdout=STDOUT, stderr=STDERR)) && ccall(:jl_running_on_valgrind,Cint,()) == 0
    error("Distributed test failed, cmd : $cmd")
end
