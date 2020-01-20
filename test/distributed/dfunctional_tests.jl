@info "Running functionality tests..."
@testset "Distributed Stochastic Programs" begin
    @testset "Distributed Sanity Check: $name" for (sp,res,name) in problems
        optimize!(sp)
        sp_nondist = copy(sp, procs = [1])
        add_scenarios!(sp_nondist, scenarios(sp))
        optimize!(sp_nondist,solver=GLPKSolverLP())
        @test scenariotype(sp) == scenariotype(sp_nondist)
        @test isapprox(stage_probability(sp), stage_probability(sp_nondist))
        @test nscenarios(sp) == nscenarios(sp_nondist)
        @test nscenarios(sp) == length(scenarios(sp))
        @test nsubproblems(sp) == nsubproblems(sp_nondist)
        @test isapprox(optimal_decision(sp), optimal_decision(sp_nondist))
        @test isapprox(optimal_value(sp), optimal_value(sp_nondist))
    end
    @testset "Distributed SP Constructs: $name" for (sp,res,name) in problems
        tol = 1e-2
        @test optimize!(sp) == :Optimal
        @test isapprox(optimal_decision(sp), res.x̄, rtol = tol)
        @test isapprox(optimal_value(sp), res.VRP, rtol = tol)
        @test isapprox(EWS(sp), res.EWS, rtol = tol)
        @test isapprox(EVPI(sp), res.EVPI, rtol = tol)
        @test isapprox(VSS(sp), res.VSS, rtol = tol)
        @test isapprox(EV(sp), res.EV, rtol = tol)
        @test isapprox(EEV(sp), res.EEV, rtol = tol)
    end
    @testset "Distributed Inequalities: $name" for (sp,res,name) in problems
        @test EWS(sp) <= VRP(sp)
        @test VRP(sp) <= EEV(sp)
        @test VSS(sp) >= 0
        @test EVPI(sp) >= 0
        @test VSS(sp) <= EEV(sp)-EV(sp)
        @test EVPI(sp) <= EEV(sp)-EV(sp)
    end
    @testset "Distributed Copying: $name" for (sp,res,name) in problems
        tol = 1e-2
        sp_copy = copy(sp)
        add_scenarios!(sp_copy, scenarios(sp))
        @test nscenarios(sp_copy) == nscenarios(sp)
        generate!(sp_copy)
        @test nsubproblems(sp_copy) == nsubproblems(sp)
        @test optimize!(sp_copy) == :Optimal
        optimize!(sp)
        @test isapprox(optimal_decision(sp_copy), optimal_decision(sp), rtol = tol)
        @test isapprox(optimal_value(sp_copy), optimal_value(sp), rtol = tol)
        @test isapprox(EWS(sp_copy), EWS(sp), rtol = tol)
        @test isapprox(EVPI(sp_copy), EVPI(sp), rtol = tol)
        @test isapprox(VSS(sp_copy), VSS(sp), rtol = tol)
        @test isapprox(EV(sp_copy), EV(sp), rtol = tol)
        @test isapprox(EEV(sp_copy), EEV(sp), rtol = tol)
    end
    @testset "Distributed Sampling" begin
        sampled_sp = sample(simple_model, sampler, 100, solver=GLPKSolverLP())
        @test nscenarios(sampled_sp) == 100
        @test nsubproblems(sampled_sp) == 100
        @test isapprox(stage_probability(sampled_sp), 1.0)
        sample!(sampled_sp, sampler, 100)
        @test nscenarios(sampled_sp) == 200
        @test nsubproblems(sampled_sp) == 200
        @test isapprox(stage_probability(sampled_sp), 1.0)
    end
    @testset "Distributed confidence intervals" begin
        glpk = GLPKSolverLP()
        CI = confidence_interval(simple_model, sampler, N = 200, solver = glpk, log = false)
        @test lower(CI) <= upper(CI)
        sol = optimize!(simple_model, sampler, solver = glpk, confidence = 0.95, tol = 1e-1, log = false)
        @test lower(confidence_interval(sol)) <= upper(confidence_interval(sol))
    end
end
