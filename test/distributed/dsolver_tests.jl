reference_solver = GLPKSolverLP()

regularizers = [DontRegularize(),
                RegularizedDecomposition(penaltyterm = Linearized()),
                TrustRegion(),
                LevelSet(penaltyterm = InfNorm(), projectionsolver = reference_solver)]

aggregators = [DontAggregate(),
               PartialAggregate(2),
               Aggregate(),
               DynamicAggregate(2, SelectUniform(2))]

consolidators = [Consolidate(), DontConsolidate()]

executors = [Synchronous(), Asynchronous()]

@testset "Structured Solvers" begin
    @info "Running L-shaped tests..."
    @testset "L-shaped: simple problems" begin
        @testset "$(solverstr(ls)): $name" for ls in [LShapedSolver(reference_solver,
                                                                    crash = Crash.EVP(),
                                                                    execution = executor,
                                                                    regularize = regularizer,
                                                                    aggregate = aggregator,
                                                                    log = false)
                                                      for executor in executors, regularizer in regularizers, aggregator in aggregators], (sp,res,name) in problems
            @testset "Distributed data" begin
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
            @testset "Data on single remote node" begin
                tol = 1e-5
                sp_onenode = copy(sp)
                add_scenarios!(sp_onenode, scenarios(sp), workers()[1])
                optimize!(sp_onenode, solver=reference_solver)
                x̄ = optimal_decision(sp_onenode)
                Q̄ = optimal_value(sp_onenode)
                if name == "Infeasible"
                    with_logger(NullLogger()) do
                        add_params!(ls, feasibility_cuts = false)
                        @test optimize!(infeasible, solver=ls) == :Infeasible
                        add_params!(ls, feasibility_cuts = true)
                    end
                end
                @test optimize!(sp, solver=ls) == :Optimal
                @test isapprox(optimal_value(sp_onenode), Q̄, rtol = tol)
                @test isapprox(optimal_decision(sp_onenode), x̄, rtol = sqrt(tol))
            end
            @testset "Local data" begin
                tol = 1e-5
                sp_nondist = copy(sp, procs = [1])
                add_scenarios!(sp_nondist, scenarios(sp))
                optimize!(sp_nondist, solver=reference_solver)
                x̄ = optimal_decision(sp_nondist)
                Q̄ = optimal_value(sp_nondist)
                if name == "Infeasible"
                    with_logger(NullLogger()) do
                        add_params!(ls, feasibility_cuts = false)
                        @test optimize!(infeasible, solver=ls) == :Infeasible
                        add_params!(ls, feasibility_cuts = true)
                    end
                end
                @test optimize!(sp_nondist, solver=ls) == :Optimal
                @test isapprox(optimal_value(sp_nondist), Q̄, rtol = tol)
                @test isapprox(optimal_decision(sp_nondist), x̄, rtol = sqrt(tol))
            end
        end
        @testset "$(solverstr(ls)) on distributed data: $name" for ls in [LShapedSolver(reference_solver,
                                                                                        crash = Crash.EVP(),
                                                                                        regularize = regularizer,
                                                                                        aggregate = aggregator,
                                                                                        log = false)
                                                                          for regularizer in regularizers, aggregator in aggregators], (sp,res,name) in problems
            tol = 1e-5
            optimize!(sp, solver=reference_solver)
            x̄ = optimal_decision(sp)
            Q̄ = optimal_value(sp)
            with_logger(NullLogger()) do
                if name == "Infeasible"
                    add_params!(ls, feasibility_cuts = false)
                    @test optimize!(infeasible, solver=ls) == :Infeasible
                    add_params!(ls, feasibility_cuts = true)
                end
                optimize!(sp, solver=ls)
            end
            @test isapprox(optimal_value(sp), Q̄, rtol = tol)
            @test isapprox(optimal_decision(sp), x̄, rtol = sqrt(tol))
        end
    end
    @testset "Progressive-hedging: simple problems" begin
        @info "Running progressive-hedging tests..."
        @testset "$(solverstr(ph)): $name" for ph in [ProgressiveHedgingSolver(reference_solver,
                                                                               penaltyterm = Linearized(nbreakpoints = 30),
                                                                               execution = executor,
                                                                               τ = 1e-4,
                                                                               log = false)
                                                      for executor in executors], (sp,res,name) in problems
            @testset "Distributed data" begin
                tol = 1e-2
                optimize!(sp, solver=reference_solver)
                x̄ = optimal_decision(sp)
                Q̄ = optimal_value(sp)
                @test optimize!(sp, solver=ph) == :Optimal
                @test isapprox(optimal_value(sp), Q̄, rtol = tol)
                @test isapprox(optimal_decision(sp), x̄, rtol = sqrt(tol))
            end
            @testset "Data on single remote node" begin
                tol = 1e-2
                sp_onenode = copy(sp)
                add_scenarios!(sp_onenode, scenarios(sp), workers()[1])
                optimize!(sp_onenode, solver=reference_solver)
                x̄ = optimal_decision(sp_onenode)
                Q̄ = optimal_value(sp_onenode)
                @test optimize!(sp, solver=ph) == :Optimal
                @test isapprox(optimal_value(sp_onenode), Q̄, rtol = tol)
                @test isapprox(optimal_decision(sp_onenode), x̄, rtol = sqrt(tol))
            end
            @testset "Local data" begin
                tol = 1e-2
                sp_nondist = copy(sp, procs = [1])
                add_scenarios!(sp_nondist, scenarios(sp))
                optimize!(sp_nondist, solver=reference_solver)
                x̄ = optimal_decision(sp_nondist)
                Q̄ = optimal_value(sp_nondist)
                @test optimize!(sp, solver=ph) == :Optimal
                @test isapprox(optimal_value(sp_nondist), Q̄, rtol = tol)
                @test isapprox(optimal_decision(sp_nondist), x̄, rtol = sqrt(tol))
            end
        end
        @testset "Progressive-hedging on distributed data: $name" for (sp,res,name) in problems
            tol = 1e-2
            ph = ProgressiveHedgingSolver(reference_solver, penaltyterm = Linearized(nbreakpoints = 30), τ = 1e-4, log = false)
            optimize!(sp, solver=reference_solver)
            x̄ = optimal_decision(sp)
            Q̄ = optimal_value(sp)
            with_logger(NullLogger()) do
                @test optimize!(sp, solver=ph) == :Optimal
            end
            @test isapprox(optimal_value(sp), Q̄, rtol = tol)
            @test isapprox(optimal_decision(sp), x̄, rtol = sqrt(tol))
        end
    end
end
