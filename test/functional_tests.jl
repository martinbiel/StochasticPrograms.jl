# MIT License
#
# Copyright (c) 2018 Martin Biel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

@info "Running functionality tests..."
@testset "Stochastic Programs: Functionality" begin
    tol = 1e-2
    for (model, _scenarios, res, name) in problems
        sp = instantiate(model, _scenarios, optimizer = GLPK.Optimizer)
        @testset "SP Constructs: $name" begin
            optimize!(sp, cache = true)
            @test termination_status(sp) == MOI.OPTIMAL
            @test isapprox(optimal_decision(sp), res.x̄, rtol = tol)
            for i in 1:num_scenarios(sp)
                @test isapprox(optimal_recourse_decision(sp, i), res.ȳ[i], rtol = tol)
            end
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
            @test VSS(sp) <= EEV(sp) - EV(sp)
            @test EVPI(sp) <= EEV(sp) - EV(sp)
        end
        @testset "Copying: $name" begin
            sp_copy = copy(sp, optimizer = GLPK.Optimizer)
            add_scenarios!(sp_copy, scenarios(sp))
            @test num_scenarios(sp_copy) == num_scenarios(sp)
            generate!(sp_copy)
            @test num_subproblems(sp_copy) == num_subproblems(sp)
            optimize!(sp)
            optimize!(sp_copy)
            @test termination_status(sp_copy) == MOI.OPTIMAL
            @test isapprox(optimal_decision(sp_copy), optimal_decision(sp), rtol = tol)
            for i in 1:num_scenarios(sp)
                @test isapprox(optimal_recourse_decision(sp_copy, i), optimal_recourse_decision(sp, i), rtol = tol)
            end
            @test isapprox(objective_value(sp_copy), objective_value(sp), rtol = tol)
            @test isapprox(EWS(sp_copy), EWS(sp), rtol = tol)
            @test isapprox(EVPI(sp_copy), EVPI(sp), rtol = tol)
            @test isapprox(VSS(sp_copy), VSS(sp), rtol = tol)
            @test isapprox(EV(sp_copy), EV(sp), rtol = tol)
            @test isapprox(EEV(sp_copy), EEV(sp), rtol = tol)
        end
    end
    @testset "Sampling" begin
        sampled_sp = instantiate(simple, sampler, 100, optimizer = GLPK.Optimizer)
        generate!(sampled_sp)
        @test num_scenarios(sampled_sp) == 100
        @test isapprox(stage_probability(sampled_sp), 1.0)
        StochasticPrograms.sample!(sampled_sp, sampler, 100)
        generate!(sampled_sp)
        @test num_scenarios(sampled_sp) == 200
        @test isapprox(stage_probability(sampled_sp), 1.0)
    end
    @testset "Instant" begin
        optimize!(simple_sp)
        @test termination_status(simple_sp) == MOI.OPTIMAL
        @test isapprox(optimal_decision(simple_sp), simple_res.x̄, rtol = tol)
        for i in 1:num_scenarios(simple_sp)
            @test isapprox(optimal_recourse_decision(simple_sp, i), simple_res.ȳ[i], rtol = tol)
        end
        @test isapprox(objective_value(simple_sp), simple_res.VRP, rtol = tol)
        @test isapprox(EWS(simple_sp), simple_res.EWS, rtol = tol)
        @test isapprox(EVPI(simple_sp), simple_res.EVPI, rtol = tol)
        @test isapprox(VSS(simple_sp), simple_res.VSS, rtol = tol)
        @test isapprox(EV(simple_sp), simple_res.EV, rtol = tol)
        @test isapprox(EEV(simple_sp), simple_res.EEV, rtol = tol)
    end
    @testset "SMPS" begin
        simple_smps = read("io/smps/simple.smps", StochasticProgram, optimizer = GLPK.Optimizer)
        optimize!(simple_smps)
        @test termination_status(simple_smps) == MOI.OPTIMAL
        @test isapprox(optimal_decision(simple_smps), simple_res.x̄, rtol = tol)
        for i in 1:num_scenarios(simple_smps)
            @test isapprox(optimal_recourse_decision(simple_smps, i), simple_res.ȳ[i], rtol = tol)
        end
        @test isapprox(objective_value(simple_smps), simple_res.VRP, rtol = tol)
        @test isapprox(EWS(simple_smps), simple_res.EWS, rtol = tol)
        @test isapprox(EVPI(simple_smps), simple_res.EVPI, rtol = tol)
        @test isapprox(VSS(simple_smps), simple_res.VSS, rtol = tol)
        @test isapprox(EV(simple_smps), simple_res.EV, rtol = tol)
        @test isapprox(EEV(simple_smps), simple_res.EEV, rtol = tol)
    end
end
