using StochasticPrograms
#using LShapedSolvers
using Distributed
using JuMP
using GLPKMathProgInterface
using LinearAlgebra
using Test

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

problems = Vector{Tuple{StochasticProgram,SPResult,String}}()
@info "Loading test problems..."
@info "Loading simple..."
include("simple.jl")
@info "Loading farmer..."
include("farmer.jl")
@info "Preparing simple sampler..."
include("sampling.jl")
@info "Test problems loaded. Starting test sequence."

@testset "Stochastic Programs" begin
    @testset "SP Constructs: $name" for (sp,res,name) in problems
        @test solve!(sp) == :Optimal
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
    @testset "Copying: $name" for (sp,res,name) in problems
        sp_copy = copy(sp)
        @test nscenarios(sp_copy) == nscenarios(sp)
        generate!(sp_copy)
        @test nsubproblems(sp_copy) == nsubproblems(sp)
        @test solve!(sp_copy) == :Optimal
        solve!(sp)
        @test norm(optimal_decision(sp_copy)-optimal_decision(sp)) <= 1e-2
        @test abs(optimal_value(sp_copy)-optimal_value(sp)) <= 1e-2
        @test abs(EWS(sp_copy)-EWS(sp)) <= 1e-2
        @test abs(EVPI(sp_copy)-EVPI(sp)) <= 1e-2
        @test abs(VSS(sp_copy)-VSS(sp)) <= 1e-2
        @test abs(EV(sp_copy)-EV(sp)) <= 1e-2
        @test abs(EEV(sp_copy)-EEV(sp)) <= 1e-2
    end
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
end

@info "Starting distributed tests..."

include(joinpath(Sys.BINDIR, "..", "share", "julia", "test", "testenv.jl"))
disttestfile = joinpath(@__DIR__, "run_dtests.jl")
push!(test_exeflags.exec,"--color=yes")
cmd = `$test_exename $test_exeflags $disttestfile`

if !success(pipeline(cmd; stdout=stdout, stderr=stderr)) && ccall(:jl_running_on_valgrind,Cint,()) == 0
    @error "Distributed test failed, cmd : $cmd"
end
