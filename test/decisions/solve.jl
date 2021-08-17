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

module TestSolve

using StochasticPrograms
using Test

function DeterministicOptimizer()
    mockoptimizer = MOIU.MockOptimizer(
        MOIU.Model{Float64}(), eval_objective_value = false, eval_dual_objective_value = false, eval_variable_constraint_dual = false
    )
    return mockoptimizer, mockoptimizer, mockoptimizer
end

function StageDecompositionOptimizer()
    master = MOIU.MockOptimizer(
        MOIU.Model{Float64}(), eval_objective_value = false, eval_dual_objective_value = false, eval_variable_constraint_dual = false
    )
    sub = MOIU.MockOptimizer(
        MOIU.Model{Float64}(), eval_objective_value = false, eval_dual_objective_value = false, eval_variable_constraint_dual = false
    )
    opt = LShaped.Optimizer()
    MOI.set(opt, MasterOptimizer(), () -> master)
    MOI.set(opt, SubProblemOptimizer(), () -> sub)
    return opt, master, sub
end

function ScenarioDecompositionOptimizer()
    sub = MOIU.MockOptimizer(
        MOIU.Model{Float64}(), eval_objective_value = false, eval_variable_constraint_dual = false
    )
    opt = ProgressiveHedging.Optimizer()
    MOI.set(opt, SubProblemOptimizer(), () -> sub)
    return opt, sub, sub
end

function fill_solution!(::MOI.AbstractOptimizer, master_optimizer, subproblem_optimizer, x, y, c)
    MOI.set(master_optimizer, MOI.TerminationStatus(), MOI.OPTIMAL)
    MOI.set(master_optimizer, MOI.RawStatusString(), "solver specific string")
    MOI.set(master_optimizer, MOI.ObjectiveValue(), 4.0)
    MOI.set(master_optimizer, MOI.DualObjectiveValue(), 4.0)
    MOI.set(master_optimizer, MOI.ResultCount(), 1)
    MOI.set(master_optimizer, MOI.PrimalStatus(), MOI.FEASIBLE_POINT)
    MOI.set(master_optimizer, MOI.DualStatus(), MOI.FEASIBLE_POINT)
    MOI.set(master_optimizer, MOI.VariablePrimal(), JuMP.optimizer_index(x), 2.0)
    MOI.set(subproblem_optimizer, MOI.TerminationStatus(), MOI.OPTIMAL)
    MOI.set(subproblem_optimizer, MOI.PrimalStatus(), MOI.FEASIBLE_POINT)
    MOI.set(subproblem_optimizer, MOI.DualStatus(), MOI.FEASIBLE_POINT)
    MOI.set(subproblem_optimizer, MOI.VariablePrimal(), JuMP.optimizer_index(x), 2.0)
    MOI.set(subproblem_optimizer, MOI.VariablePrimal(), JuMP.optimizer_index(y,1), 2.0)
    MOI.set(subproblem_optimizer, MOI.ConstraintDual(), JuMP.optimizer_index(c,1), -1.0)
    MOI.set(master_optimizer, MOI.ConstraintDual(), JuMP.optimizer_index(JuMP.LowerBoundRef(x)), 2.0)
    MOI.set(subproblem_optimizer, MOI.ConstraintDual(), JuMP.optimizer_index(JuMP.LowerBoundRef(y), 1), 0.0)
    return nothing
end

function fill_solution!(optimizer::LShaped.Optimizer, master_optimizer, subproblem_optimizer, x, y, c)
    MOI.set(master_optimizer, MOI.TerminationStatus(), MOI.OPTIMAL)
    MOI.set(master_optimizer, MOI.RawStatusString(), "solver specific string")
    MOI.set(master_optimizer, MOI.ObjectiveValue(), 4.0)
    MOI.set(master_optimizer, MOI.DualObjectiveValue(), 4.0)
    MOI.set(master_optimizer, MOI.ResultCount(), 1)
    MOI.set(master_optimizer, MOI.PrimalStatus(), MOI.FEASIBLE_POINT)
    MOI.set(master_optimizer, MOI.DualStatus(), MOI.FEASIBLE_POINT)
    MOI.set(master_optimizer, MOI.VariablePrimal(), JuMP.optimizer_index(x), 2.0)
    MOI.set(subproblem_optimizer, MOI.TerminationStatus(), MOI.OPTIMAL)
    MOI.set(subproblem_optimizer, MOI.PrimalStatus(), MOI.FEASIBLE_POINT)
    MOI.set(subproblem_optimizer, MOI.DualStatus(), MOI.FEASIBLE_POINT)
    MOI.set(subproblem_optimizer, MOI.VariablePrimal(), JuMP.optimizer_index(x), 2.0)
    MOI.set(subproblem_optimizer, MOI.VariablePrimal(), JuMP.optimizer_index(y,1), 2.0)
    MOI.set(subproblem_optimizer, MOI.ConstraintDual(), JuMP.optimizer_index(c,1), -1.0)
    MOI.set(master_optimizer, MOI.ConstraintDual(), JuMP.optimizer_index(JuMP.LowerBoundRef(x)), 2.0)
    MOI.set(subproblem_optimizer, MOI.ConstraintDual(), JuMP.optimizer_index(JuMP.LowerBoundRef(y), 1), 0.0)
    # L-shaped specific
    optimizer.lshaped.data.Q = 4.0
    optimizer.lshaped.x[1] = 2
    optimizer.status = MOI.OPTIMAL
    optimizer.primal_status = MOI.FEASIBLE_POINT
    optimizer.dual_status = MOI.FEASIBLE_POINT
    optimizer.raw_status = "solver specific string"
    return nothing
end

function fill_solution!(optimizer::ProgressiveHedging.Optimizer, master_optimizer, subproblem_optimizer, x, y, c)
    master_optimizer
    MOI.set(master_optimizer, MOI.TerminationStatus(), MOI.OPTIMAL)
    MOI.set(master_optimizer, MOI.RawStatusString(), "solver specific string")
    MOI.set(master_optimizer, MOI.ObjectiveValue(), 4.0)
    MOI.set(master_optimizer, MOI.DualObjectiveValue(), 4.0)
    MOI.set(master_optimizer, MOI.ResultCount(), 1)
    MOI.set(master_optimizer, MOI.PrimalStatus(), MOI.FEASIBLE_POINT)
    MOI.set(master_optimizer, MOI.DualStatus(), MOI.FEASIBLE_POINT)
    MOI.set(subproblem_optimizer, MOI.TerminationStatus(), MOI.OPTIMAL)
    MOI.set(subproblem_optimizer, MOI.PrimalStatus(), MOI.FEASIBLE_POINT)
    MOI.set(subproblem_optimizer, MOI.DualStatus(), MOI.FEASIBLE_POINT)
    MOI.set(subproblem_optimizer, MOI.VariablePrimal(), JuMP.optimizer_index(y,1), 2.0)
    MOI.set(subproblem_optimizer, MOI.ConstraintDual(), JuMP.optimizer_index(c,1), -1.0)
    MOI.set(subproblem_optimizer, MOI.ConstraintDual(), JuMP.optimizer_index(JuMP.LowerBoundRef(x), 1), 2.0)
    MOI.set(subproblem_optimizer, MOI.ConstraintDual(), JuMP.optimizer_index(JuMP.LowerBoundRef(x), 2), 2.0)
    MOI.set(subproblem_optimizer, MOI.ConstraintDual(), JuMP.optimizer_index(JuMP.LowerBoundRef(y), 1), 0.0)
    # Progressive-hedging specific
    optimizer.progressivehedging.data.Q = 4.0
    optimizer.progressivehedging.ξ[1] = 2
    optimizer.status = MOI.OPTIMAL
    optimizer.primal_status = MOI.FEASIBLE_POINT
    optimizer.dual_status = MOI.FEASIBLE_POINT
    optimizer.raw_status = "solver specific string"
    return nothing
end

function test_solve(Structure, mockoptimizer, master_optimizer, subproblem_optimizer)
    ξ₁ = @scenario a = 2. probability = 0.5
    ξ₂ = @scenario a = 4 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure, () -> mockoptimizer)
    @first_stage sp = begin
        @decision(sp, x >= 2.)
        @variable(sp, w)
        @objective(sp, Min, x)
    end
    @second_stage sp = begin
        @uncertain a
        @known(sp, x)
        @variable(sp, z)
        @recourse(sp, y >= a)
        @objective(sp, Max, y)
        @constraint(sp, con, y <= 2)
    end
    StochasticPrograms.load_structure!(mockoptimizer, sp.structure, [0.0])
    StochasticPrograms.attach_mocks!(sp.structure)
    x = sp[1,:x]
    y = sp[2,:y]
    c = sp[2,:con]

    fill_solution!(mockoptimizer, master_optimizer, subproblem_optimizer, x, y, c)

    @test JuMP.has_values(sp)
    @test MOI.OPTIMAL == @inferred JuMP.termination_status(sp)
    @test "solver specific string" == JuMP.raw_status(sp)
    @test MOI.FEASIBLE_POINT == @inferred JuMP.primal_status(sp)

    @test  2.0 == @inferred JuMP.value(x)
    @test  2.0 == @inferred JuMP.value(y, 1)
    @test  4.0 == @inferred JuMP.value(x + y, Dict(2 => 1))
    @test  2.0 == @inferred JuMP.value(c, 1)
    @test  4.0 == @inferred JuMP.objective_value(sp)
    @test  4.0 == @inferred JuMP.dual_objective_value(sp)

    @test JuMP.has_duals(sp)
    @test MOI.FEASIBLE_POINT == @inferred JuMP.dual_status(sp)
    @test  2.0 == @inferred JuMP.reduced_cost(x)
    @test  0.0 == @inferred JuMP.reduced_cost(y, 1)
    @test -1.0 == @inferred JuMP.dual(c, 1)
    @test  2.0 == @inferred JuMP.dual(JuMP.LowerBoundRef(x))
    @test  0.0 == @inferred JuMP.dual(JuMP.LowerBoundRef(y), 1)

    # Test caching
    StochasticPrograms.cache_solution!(sp, sp.structure, mockoptimizer)
    @test haskey(sp.solutioncache, :solution)
    @test haskey(sp.solutioncache, :node_solution_1)
    @test haskey(sp.solutioncache, :node_solution_2_1)
    @test JuMP.has_values(sp)
    @test MOI.OPTIMAL == @inferred JuMP.termination_status(sp)
    @test "solver specific string" == JuMP.raw_status(sp)
    @test MOI.FEASIBLE_POINT == @inferred JuMP.primal_status(sp)

    @test  2.0 == @inferred JuMP.value(x)
    @test  2.0 == @inferred JuMP.value(y, 1)
    @test  4.0 == @inferred JuMP.value(x + y, Dict(2 => 1))
    @test  2.0 == @inferred JuMP.value(c, 1)
    @test  4.0 == @inferred JuMP.objective_value(sp)
    @test  4.0 == @inferred JuMP.dual_objective_value(sp)

    @test JuMP.has_duals(sp)
    @test MOI.FEASIBLE_POINT == @inferred JuMP.dual_status(sp)
    @test  2.0 == @inferred JuMP.reduced_cost(x)
    @test  0.0 == @inferred JuMP.reduced_cost(y, 1)
    @test -1.0 == @inferred JuMP.dual(c, 1)
    @test  2.0 == @inferred JuMP.dual(JuMP.LowerBoundRef(x))
    @test  0.0 == @inferred JuMP.dual(JuMP.LowerBoundRef(y), 1)
end

function runtests()
    @testset "Solve" begin
        for config in [(Deterministic(), DeterministicOptimizer()),
                       (StageDecomposition(), StageDecompositionOptimizer()),
                       (ScenarioDecomposition(), ScenarioDecompositionOptimizer())]
            @testset "$(config[1])" begin
                for name in names(@__MODULE__; all = true)
                    if !startswith("$(name)", "test_")
                        continue
                    end
                    f = getfield(@__MODULE__, name)
                    @testset "$(name)" begin
                        f(config[1], config[2]...)
                    end
                end
            end
        end
    end
end

end
