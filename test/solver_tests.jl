reference_solver = GLPKSolverLP()

regularizers = [DontRegularize(),
                RegularizedDecomposition(penalty = Linearized()),
                TrustRegion(),
                LevelSet(penalty = InfNorm(), projectionsolver = reference_solver)]

aggregators = [DontAggregate(),
               PartialAggregate(2),
               Aggregate(),
               DynamicAggregate(2, SelectUniform(2))]

consolidators = [Consolidate(), DontConsolidate()]

@testset "Structured Solvers" begin
    @info "Running L-shaped tests..."
    @testset "L-shaped: simple problems" begin
        @testset "$(solverstr(ls)): $name" for ls in [LShapedSolver(reference_solver,
                                                                    crash = Crash.EVP(),
                                                                    regularize = regularizer,
                                                                    aggregate = aggregator,
                                                                    consolidate = consolidator,
                                                                    log = false)
                                                      for regularizer in regularizers, aggregator in aggregators, consolidator in consolidators], (sp,res,name) in problems
            tol = 1e-5
            optimize!(sp, solver=reference_solver)
            x̄ = optimal_decision(sp)
            Q̄ = optimal_value(sp)
            if name == "Infeasible"
                with_logger(NullLogger()) do
                    @test optimize!(infeasible, solver=ls) == :Infeasible
                    add_params!(ls, feasibility_cuts = true)
                end
            end
            @test optimize!(sp, solver=ls) == :Optimal
            @test isapprox(optimal_value(sp), Q̄, rtol = tol)
            @test isapprox(optimal_decision(sp), x̄, rtol = sqrt(tol))
        end
    end
    @info "Running progressive-hedging tests..."
    @testset "Progressive-hedging: simple problems" begin
        @testset "Progressive-hedging: $name" for (sp,res,name) in problems
            tol = 1e-2
            ph = ProgressiveHedgingSolver(reference_solver, penaltyterm = Linearized(nbreakpoints=30), log = false)
            optimize!(sp, solver=reference_solver)
            x̄ = optimal_decision(sp)
            Q̄ = optimal_value(sp)
            @test optimize!(sp, solver=ph) == :Optimal
            @test isapprox(optimal_value(sp), Q̄, rtol = tol)
            @test isapprox(optimal_decision(sp), x̄, rtol = sqrt(tol))
        end
    end
end
