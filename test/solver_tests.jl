reference_solver = GLPKSolverLP()
osqp = OSQP.OSQPMathProgBaseInterface.OSQPSolver(verbose=0)

regularizers = [DontRegularize(),
                RegularizedDecomposition(linearize = true),
                TrustRegion(),
                LevelSet(linearize = true, projectionsolver = reference_solver)]

aggregators = [DontAggregate(),
               PartialAggregate(2),
               Aggregate(),
               DynamicAggregate(2, SelectUniform(2))]

consolidators = [Consolidate(), DontConsolidate()]

penalties = [Fixed(),
             Adaptive(θ = 1.01)]

@testset "Structured Solvers" begin
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
            optimize!(sp, solver=ls)
            @test abs(optimal_value(sp) - Q̄)/(1e-10+abs(Q̄)) <= tol
            @test norm(optimal_decision(sp) - x̄)/(1e-10+norm(x̄)) <= sqrt(tol)
        end
    end
    @testset "Progressive-hedging: simple problems" begin
        @testset "$(solverstr(ph)): $name" for ph in [ProgressiveHedgingSolver(osqp,
                                                                               penalty = penalty,
                                                                               τ = 1e-3,
                                                                               log = false)
                                                      for penalty in penalties], (sp,res,name) in problems
            tol = 1e-2
            optimize!(sp, solver=reference_solver)
            x̄ = optimal_decision(sp)
            Q̄ = optimal_value(sp)
            optimize!(sp, solver=ph)
            @test abs(optimal_value(sp) - Q̄)/(1e-10+abs(Q̄)) <= tol
            @test norm(optimal_decision(sp) - x̄)/(1e-10+norm(x̄)) <= sqrt(tol)
        end
    end
end
