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

subsolver = GLPK.Optimizer
qpsolver = () -> begin
    opt = Ipopt.Optimizer()
    MOI.set(opt, MOI.RawOptimizerAttribute("print_level"), 0)
    return opt
end

regularizers = [DontRegularize(),
                RegularizedDecomposition(penaltyterm = InfNorm()),
                TrustRegion(),
                LevelSet(penaltyterm = InfNorm())]

aggregators = [DontAggregate(),
               PartialAggregate(2),
               Aggregate()]

consolidators = [Consolidate(), DontConsolidate()]

penalizations = [Fixed(),
                 Adaptive()]

@testset "Structured Solvers" begin
    @info "Running L-shaped tests..."
    @testset "L-shaped: simple problems" begin
        for (model,scenarios,res,name) in problems
            tol = 1e-5
            sp = instantiate(model,
                             scenarios,
                             optimizer = LShaped.Optimizer)
            @test_throws UnloadableStructure optimize!(sp)
            set_silent(sp)
            for regularizer in regularizers, aggregator in aggregators, consolidator in consolidators
                set_optimizer_attribute(sp, Regularizer(), regularizer)
                set_optimizer_attribute(sp, Aggregator(), aggregator)
                set_optimizer_attribute(sp, Consolidator(), consolidator)
                @testset "$(optimizer_name(sp)): $name" begin
                    set_optimizer_attribute(sp, MasterOptimizer(), subsolver)
                    set_optimizer_attribute(sp, SubProblemOptimizer(), subsolver)
                    if name == "Infeasible" || name == "Vectorized Infeasible"
                        with_logger(NullLogger()) do
                            set_optimizer_attribute(sp, FeasibilityStrategy(), IgnoreFeasibility())
                            optimize!(sp, crash = Crash.EVP())
                            @test termination_status(sp) == MOI.INFEASIBLE
                            set_optimizer_attribute(sp, FeasibilityStrategy(), FeasibilityCuts())
                        end
                    end
                    optimize!(sp, crash = Crash.EVP())
                    @test termination_status(sp) == MOI.OPTIMAL
                    @test isapprox(objective_value(sp), res.VRP, rtol = tol)
                    @test isapprox(optimal_decision(sp), res.x̄, rtol = sqrt(tol))
                    for i in 1:num_scenarios(sp)
                        @test isapprox(optimal_recourse_decision(sp, i), res.ȳ[i], rtol = sqrt(tol))
                    end
                end
            end
        end
    end
    @info "Running progressive-hedging tests..."
    @testset "Progressive-hedging: simple problems" begin
        for (model,scenarios,res,name) in problems
            tol = 1e-2
            sp = instantiate(model,
                             scenarios,
                             optimizer = ProgressiveHedging.Optimizer)
            @test_throws UnloadableStructure optimize!(sp)
            set_silent(sp)
            for penalizer in penalizations
                set_optimizer_attribute(sp, Penalizer(), penalizer)
                set_optimizer_attribute(sp, SubProblemOptimizer(), qpsolver)
                set_optimizer_attribute(sp, PrimalTolerance(), 1e-3)
                set_optimizer_attribute(sp, DualTolerance(), 1e-2)
                @testset "$(optimizer_name(sp)): $name" begin
                    optimize!(sp)
                    @test termination_status(sp) == MOI.OPTIMAL
                    @test isapprox(objective_value(sp), res.VRP, rtol = tol)
                    @test isapprox(optimal_decision(sp), res.x̄, rtol = sqrt(tol))
                    for i in 1:num_scenarios(sp)
                        @test isapprox(optimal_recourse_decision(sp, i), res.ȳ[i], rtol = sqrt(tol))
                    end
                end
            end
        end
    end
    @info "Running Quasi-gradient tests..."
    @testset "Quasi-gradient: simple problems" begin
        for (model,scenarios,res,name) in problems
            tol = 1e-2
            sp = instantiate(model,
                             scenarios,
                             optimizer = QuasiGradient.Optimizer)
            @test_throws UnloadableStructure optimize!(sp)
            set_silent(sp)
            if name != "Infeasible" && name != "Vectorized Infeasible"
                # Non-smooth
                @testset "Quasi-gradient: $name" begin
                    set_optimizer_attribute(sp, MasterOptimizer(), qpsolver)
                    set_optimizer_attribute(sp, SubProblemOptimizer(), subsolver)
                    set_optimizer_attribute(sp, Prox(), DryFriction())
                    set_optimizer_attribute(sp, Termination(), AtObjectiveThreshold(res.VRP, 1e-3))
                    optimize!(sp, crash = Crash.EVP())
                    @test termination_status(sp) == MOI.OPTIMAL
                    @test isapprox(objective_value(sp), res.VRP, rtol = tol)
                    @test isapprox(optimal_decision(sp), res.x̄, rtol = sqrt(tol))
                    for i in 1:num_scenarios(sp)
                        @test isapprox(optimal_recourse_decision(sp, i), res.ȳ[i], rtol = sqrt(tol))
                    end
                end
                # Smooth
                @testset "Quasi-gradient with smoothing: $name" begin
                    set_optimizer_attribute(sp, SubProblems(), Smoothed(μ = 1e-4, objective_correction = true))
                    set_optimizer_attribute(sp, MasterOptimizer(), qpsolver)
                    set_optimizer_attribute(sp, SubProblemOptimizer(), qpsolver)
                    set_optimizer_attribute(sp, StepSize(), Constant(1e-3))
                    set_optimizer_attribute(sp, Prox(), Nesterov())
                    set_optimizer_attribute(sp, Termination(), AtObjectiveThreshold(res.VRP, 1e-3))
                    optimize!(sp, crash = Crash.EVP())
                    @test termination_status(sp) == MOI.OPTIMAL
                    @test isapprox(objective_value(sp), res.VRP, rtol = tol)
                    @test isapprox(optimal_decision(sp), res.x̄, rtol = sqrt(tol))
                    for i in 1:num_scenarios(sp)
                        @test isapprox(optimal_recourse_decision(sp, i), res.ȳ[i], rtol = sqrt(tol))
                    end
                end
            end
        end
    end
end
