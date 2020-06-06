@info "Running functionality tests..."
@testset "Stochastic Programs: Functionality" begin
    for (model, _scenarios, res, name) in problems
        tol = 1e-2
        sp = instantiate(model,
                         _scenarios,
                         optimizer = () -> GLPK.Optimizer(presolve = true))
        @testset "SP Constructs: $name" begin
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
        @testset "Inequalities: $name" begin
            @test EWS(sp) <= VRP(sp)
            @test VRP(sp) <= EEV(sp)
            @test VSS(sp) >= 0
            @test EVPI(sp) >= 0
            @test VSS(sp) <= EEV(sp)-EV(sp)
            @test EVPI(sp) <= EEV(sp)-EV(sp)
        end
        @testset "Copying: $name" begin
            sp_copy = copy(sp, optimizer = () -> GLPK.Optimizer(presolve = true))
            add_scenarios!(sp_copy, scenarios(sp))
            @test num_scenarios(sp_copy) == num_scenarios(sp)
            generate!(sp_copy)
            @test num_subproblems(sp_copy) == num_subproblems(sp)
            optimize!(sp)
            optimize!(sp_copy)
            @test termination_status(sp_copy) == MOI.OPTIMAL
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
    end
end
