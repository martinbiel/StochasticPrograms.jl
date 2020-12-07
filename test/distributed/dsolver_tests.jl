subsolver = GLPK.Optimizer

regularizers = [DontRegularize(),
                RegularizedDecomposition(penaltyterm = Linearized()),
                TrustRegion(),
                LevelSet(penaltyterm = InfNorm())]

aggregators = [DontAggregate(),
               PartialAggregate(2),
               Aggregate(),
               DynamicAggregate(2, SelectUniform(2))]

consolidators = [Consolidate(), DontConsolidate()]

penalizations = [Fixed(),
                 Adaptive()]

executions = [Synchronous(), Asynchronous()]

@testset "Structured Solvers" begin
    @info "Running L-shaped tests..."
    @testset "L-shaped: simple problems" begin
        @testset "L-shaped: simple problems" begin
            for (model,scenarios,res,name) in problems
                tol = 1e-5
                sp = instantiate(model,
                                 scenarios,
                                 optimizer = LShaped.Optimizer)
                @test_throws UnloadableStructure optimize!(sp)
                set_silent(sp)
                for execution in executions, regularizer in regularizers, aggregator in aggregators, consolidator in consolidators
                    set_optimizer_attribute(sp, Execution(), execution)
                    set_optimizer_attribute(sp, Regularizer(), regularizer)
                    set_optimizer_attribute(sp, Aggregator(), aggregator)
                    set_optimizer_attribute(sp, Consolidator(), consolidator)
                    @testset "$(optimizer_name(sp)): $name" begin
                        set_optimizer_attribute(sp, MasterOptimizer(), subsolver)
                        set_optimizer_attribute(sp, SubproblemOptimizer(), subsolver)
                        if name == "Infeasible" || name == "Vectorized Infeasible"
                            with_logger(NullLogger()) do
                                set_optimizer_attribute(sp, FeasibilityCuts(), false)
                                optimize!(sp, crash = Crash.EVP())
                                @test termination_status(sp) == MOI.INFEASIBLE
                                set_optimizer_attribute(sp, FeasibilityCuts(), true)
                            end
                        end
                        optimize!(sp, crash = Crash.EVP())
                        @test termination_status(sp) == MOI.OPTIMAL
                        @test isapprox(objective_value(sp), res.VRP, rtol = tol)
                        @test isapprox(optimal_decision(sp), res.x̄, rtol = sqrt(tol))
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
            for execution in executions, penalizer in penalizations
                set_optimizer_attribute(sp, Execution(), execution)
                set_optimizer_attribute(sp, Penalizer(), penalizer)
                set_optimizer_attribute(sp, SubproblemOptimizer(), subsolver)
                set_optimizer_attribute(sp, PrimalTolerance(), 1e-3)
                set_optimizer_attribute(sp, DualTolerance(), 1e-2)
                set_optimizer_attribute(sp, Penaltyterm(), Linearized(num_breakpoints = 1000, spacing = 0.5))
                @testset "$(optimizer_name(sp)): $name" begin
                    optimize!(sp)
                    @test termination_status(sp) == MOI.OPTIMAL
                    @test isapprox(objective_value(sp), res.VRP, rtol = tol)
                    @test isapprox(optimal_decision(sp), res.x̄, rtol = sqrt(tol))
                end
            end
        end
    end
end
