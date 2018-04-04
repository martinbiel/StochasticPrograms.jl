using StochasticPrograms
using JuMP
using Clp
using Base.Test
include("/opt/julia-0.6/share/julia/test/testenv.jl")

addprocs_with_testenv(3)
@test nworkers() == 3

@everywhere using Base.Test, StochasticPrograms, Clp

struct SPResult
    x̄::Vector{Float64}
    RP::Float64
    EVPI::Float64
    VSS::Float64
    EV::Float64
    EEV::Float64
end
problems = Vector{Tuple{JuMP.Model,SPResult,String}}()
include("simple.jl")
include("farmer.jl")

@testset "Distributed SP Constructs: $name" for (sp,res,name) in problems
    solve(sp)
    @test norm(sp.colVal-res.x̄) <= 1e-2
    @test abs(sp.objVal-res.RP) <= 1e-2
    @test abs(EVPI(sp)-res.EVPI) <= 1e-2
    @test abs(VSS(sp)-res.VSS) <= 1e-2
    @test abs(EV(sp)-res.EV) <= 1e-2
    @test abs(EEV(sp)-res.EEV) <= 1e-2
end

@testset "Distributed Inequalities: $name" for (sp,res,name) in problems
    @test EWS(sp) <= RP(sp)
    @test RP(sp) <= EEV(sp)
    @test VSS(sp) >= 0
    @test EVPI(sp) >= 0
    @test VSS(sp) <= EEV(sp)-EV(sp)
    @test EVPI(sp) <= EEV(sp)-EV(sp)
end
