using Base.Test
include("/opt/julia-0.6/share/julia/test/testenv.jl")
addprocs_with_testenv(3)
@test nworkers() == 3

using StochasticPrograms
using JuMP
using Clp

struct SPResult
    x̄::Vector{Float64}
    VRP::Float64
    EVPI::Float64
    VSS::Float64
    EV::Float64
    EEV::Float64
end

problems = Vector{Tuple{JuMP.Model,SPResult,String}}()
info("Loading test problems...")
info("Loading simple...")
include("simple.jl")
info("Loading farmer...")
include("farmer.jl")

info("Test problems loaded. Starting test sequence.")
@testset "Distributed SP Constructs: $name" for (sp,res,name) in problems
    solve(sp)
    @test norm(optimal_decision(sp)-res.x̄) <= 1e-2
    @test abs(optimal_value(sp)-res.VRP) <= 1e-2
    @test abs(EVPI(sp)-res.EVPI) <= 1e-2
    @test abs(VSS(sp)-res.VSS) <= 1e-2
    @test abs(EV(sp)-res.EV) <= 1e-2
    @test abs(EEV(sp)-res.EEV) <= 1e-2
end

@testset "Distributed Inequalities: $name" for (sp,res,name) in problems
    @test EWS(sp) <= VRP(sp)
    @test VRP(sp) <= EEV(sp)
    @test VSS(sp) >= 0
    @test EVPI(sp) >= 0
    @test VSS(sp) <= EEV(sp)-EV(sp)
    @test EVPI(sp) <= EEV(sp)-EV(sp)
end
