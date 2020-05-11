@info "Running functionality tests..."
@testset "Stochastic Programs: Functionality" begin
    @testset "SP Constructs: $name" for (model,scenarios,res,name) in problems
        tol = 1e-2
        sp = instantiate(model,
                         scenarios,
                         optimizer = () -> GLPK.Optimizer(presolve = true))
        optimize!(sp)
        @test termination_status(sp) == MOI.OPTIMAL
        @test isapprox(optimal_decision(sp), res.x̄, rtol = tol)
        @test isapprox(objective_value(sp), res.VRP, rtol = tol)
        @test isapprox(EWS(sp), res.EWS, rtol = tol)
        @test isapprox(EVPI(sp), res.EVPI, rtol = tol)
        @test isapprox(VSS(sp), res.VSS, rtol = tol)
        @test isapprox(EV(sp), res.EV, rtol = tol)
        @test isapprox(EEV(sp), res.EEV, rtol = tol)
    end
    @testset "Inequalities: $name" for (model,scenarios,res,name) in problems
        sp = instantiate(model,
                         scenarios,
                         optimizer = () -> GLPK.Optimizer(presolve = true))
        @test EWS(sp) <= VRP(sp)
        @test VRP(sp) <= EEV(sp)
        @test VSS(sp) >= 0
        @test EVPI(sp) >= 0
        @test VSS(sp) <= EEV(sp)-EV(sp)
        @test EVPI(sp) <= EEV(sp)-EV(sp)
    end
    @testset "Copying: $name" for (model,_scenarios,res,name) in problems
        tol = 1e-2
        sp = instantiate(model,
                         _scenarios,
                         optimizer = () -> GLPK.Optimizer(presolve = true))
        sp_copy = copy(sp, optimizer = () -> GLPK.Optimizer(presolve = true))
        add_scenarios!(sp_copy, scenarios(sp))
        @test num_scenarios(sp_copy) == num_scenarios(sp)
        generate!(sp_copy)
        @test num_subproblems(sp_copy) == num_subproblems(sp)
        optimize!(sp_copy)
        @test termination_status(sp_copy) == MOI.OPTIMAL
        optimize!(sp)
        @test isapprox(optimal_decision(sp_copy), optimal_decision(sp), rtol = tol)
        @test isapprox(objective_value(sp_copy), objective_value(sp), rtol = tol)
        @test isapprox(EWS(sp_copy), EWS(sp), rtol = tol)
        @test isapprox(EVPI(sp_copy), EVPI(sp), rtol = tol)
        @test isapprox(VSS(sp_copy), VSS(sp), rtol = tol)
        @test isapprox(EV(sp_copy), EV(sp), rtol = tol)
        @test isapprox(EEV(sp_copy), EEV(sp), rtol = tol)
    end
    @testset "Sampling" begin
        sampled_sp = StochasticPrograms.sample(simple, sampler, 100, optimizer = GLPK.Optimizer)
        generate!(sampled_sp)
        @test num_scenarios(sampled_sp) == 100
        @test isapprox(stage_probability(sampled_sp), 1.0)
        StochasticPrograms.sample!(sampled_sp, sampler, 100)
        generate!(sampled_sp)
        @test num_scenarios(sampled_sp) == 200
        @test isapprox(stage_probability(sampled_sp), 1.0)
    end
    # @testset "Confidence intervals" begin
    #     try
    #         CI = confidence_interval(simple_model, sampler, optimizer = GLPK.Optimizer, N = 200, log = false)
    #         @test lower(CI) <= upper(CI)
    #     catch end
    #     set_optimizer!(simple_model, GLPK.Optimizer)
    #     sol = optimize!(simple_model, sampler, confidence = 0.95, tol = 1e-1, log = false)
    #     @test lower(objective_value(simple_model)) <= upper(objective_value(simple_model))
    # end
end
