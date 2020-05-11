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

@testset "Structured Solvers" begin
    @info "Running L-shaped tests..."
    # @testset "L-shaped: simple problems" begin
    #     for (model,scenarios,res,name) in problems
    #         tol = 1e-5
    #         sp = instantiate(model,
    #                          scenarios,
    #                          instantiation = BlockVertical())
    #         for regularizer in regularizers, aggregator in aggregators, consolidator in consolidators
    #             set_optimizer!(sp, () -> LShaped.Optimizer(subsolver,
    #                                                        regularize = regularizer,
    #                                                        aggregate = aggregator,
    #                                                        consolidate = consolidator,
    #                                                        log = false))
    #             @testset "$(optimizer_name(sp)): $name" begin
    #                 if name == "Infeasible"
    #                     with_logger(NullLogger()) do
    #                         sp.optimizer.optimizer.feasibility_cuts = false
    #                         optimize!(sp, crash = Crash.EVP())
    #                         @test termination_status(sp) == MOI.INFEASIBLE
    #                         sp.optimizer.optimizer.feasibility_cuts = true
    #                     end
    #                 end
    #                 optimize!(sp, crash = Crash.EVP())
    #                 @test termination_status(sp) == MOI.OPTIMAL
    #                 @test isapprox(objective_value(sp), res.VRP, rtol = tol)
    #                 @test isapprox(optimal_decision(sp), res.x̄, rtol = sqrt(tol))
    #             end
    #         end
    #     end
    # end
    @info "Running progressive-hedging tests..."
    @testset "Progressive-hedging: simple problems" begin
        for (model,scenarios,res,name) in problems
            tol = 1e-2
            sp = instantiate(model,
                             scenarios,
                             optimizer = () -> ProgressiveHedging.Optimizer(subsolver,
                                                                            penaltyterm = Linearized(num_breakpoints = 200, spacing = 0.5),
                                                                            τ = 1e-3,
                                                                            log = false))
            @testset "$(optimizer_name(sp)): $name" begin
                optimize!(sp)
                @test termination_status(sp) == MOI.OPTIMAL
                @test isapprox(objective_value(sp), res.VRP, rtol = tol)
                @test isapprox(optimal_decision(sp), res.x̄, rtol = sqrt(tol))
            end
        end
    end
end
