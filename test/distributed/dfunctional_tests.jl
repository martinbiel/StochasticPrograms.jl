@info "Running functionality tests..."
@testset "Distributed Stochastic Programs" begin
    @testset "Distributed Sanity Check: $name" for (model,scenarios,res,name) in problems
        sp = instantiate(model,
                         scenarios,
                         optimizer = ()->LShaped.Optimizer(GLPK.Optimizer))
        optimize!(sp)
        sp_nondist = copy(sp, instantiation = BlockVertical())
        add_scenarios!(sp_nondist, scenarios(sp))
        @test scenariotype(sp) == scenariotype(sp_nondist)
        @test isapprox(stage_probability(sp), stage_probability(sp_nondist))
        @test num_scenarios(sp) == num_scenarios(sp_nondist)
        @test num_scenarios(sp) == length(scenarios(sp))
        @test num_subproblems(sp) == num_subproblems(sp_nondist)
        @test num_subproblems(sp) == length(subproblems(sp))
        @test isapprox(optimal_decision(sp), optimal_decision(sp_nondist))
        @test isapprox(objective_value(sp), objective_value(sp_nondist))
    end
    @testset "Distributed SP Constructs: $name" for (model,scenarios,res,name) in problems
        tol = 1e-2
        sp = instantiate(model,
                         scenarios,
                         optimizer = ()->LShaped.Optimizer(GLPK.Optimizer))
        @test optimize!(sp) == MOI.OPTIMAL
        @test isapprox(optimal_decision(sp), res.x̄, rtol = tol)
        @test isapprox(objective_value(sp), res.VRP, rtol = tol)
        @test isapprox(EWS(sp), res.EWS, rtol = tol)
        @test isapprox(EVPI(sp), res.EVPI, rtol = tol)
        @test isapprox(VSS(sp), res.VSS, rtol = tol)
        @test isapprox(EV(sp), res.EV, rtol = tol)
        @test isapprox(EEV(sp), res.EEV, rtol = tol)
    end
    @testset "Distributed Inequalities: $name" for (model,scenarios,res,name) in problems
        sp = instantiate(model,
                         scenarios,
                         optimizer = ()->LShaped.Optimizer(GLPK.Optimizer))
        @test EWS(sp) <= VRP(sp)
        @test VRP(sp) <= EEV(sp)
        @test VSS(sp) >= 0
        @test EVPI(sp) >= 0
        @test VSS(sp) <= EEV(sp)-EV(sp)
        @test EVPI(sp) <= EEV(sp)-EV(sp)
    end
    @testset "Distributed Copying: $name" for (model,_scenarios,res,name) in problems
        tol = 1e-2
        sp = instantiate(model,
                         _scenarios,
                         optimizer = ()->LShaped.Optimizer(GLPK.Optimizer))
        sp_copy = copy(sp)
        add_scenarios!(sp_copy, scenarios(sp))
        @test num_scenarios(sp_copy) == num_scenarios(sp)
        generate!(sp_copy)
        @test num_subproblems(sp_copy) == num_subproblems(sp)
        @test optimize!(sp_copy) == MOI.OPTIMAL
        @test optimize!(sp)  == MOI.OPTIMAL
        @test isapprox(optimal_decision(sp_copy), optimal_decision(sp), rtol = tol)
        @test isapprox(objective_value(sp_copy), objective_value(sp), rtol = tol)
        @test isapprox(EWS(sp_copy), EWS(sp), rtol = tol)
        @test isapprox(EVPI(sp_copy), EVPI(sp), rtol = tol)
        @test isapprox(VSS(sp_copy), VSS(sp), rtol = tol)
        @test isapprox(EV(sp_copy), EV(sp), rtol = tol)
        @test isapprox(EEV(sp_copy), EEV(sp), rtol = tol)
    end
    @testset "Distributed Sampling" begin
        sampled_sp = sample(simple, sampler, 100, optimizer = GLPK.Optimizer)
        generate!(sampled_sp)
        @test num_scenarios(sampled_sp) == 100
        @test num_subproblems(sampled_sp) == 100
        @test isapprox(stage_probability(sampled_sp), 1.0)
        sample!(sampled_sp, sampler, 100)
        generate!(sampled_sp)
        @test num_scenarios(sampled_sp) == 200
        @test num_subproblems(sampled_sp) == 200
        @test isapprox(stage_probability(sampled_sp), 1.0)
    end
end
