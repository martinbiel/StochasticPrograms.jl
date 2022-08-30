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

@everywhere module TestDecisionConstraint

using StochasticPrograms
using Test

function test_SingleDecision_constraints(Structure)
    ξ₁ = @scenario a = 1. probability = 0.5
    ξ₂ = @scenario a = 2. probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x)
        @decision(sp, z[1:2])
        @variable(sp, t)
        @constraint(sp, con11, x in MOI.LessThan(10.0))
        @constraint(sp, con12[i in 1:2], z[i] in MOI.LessThan(float(i)))
    end
    @second_stage sp = begin
        @uncertain a
        @variable(sp, r)
        @recourse(sp, y)
        @recourse(sp, w[1:2])
        @constraint(sp, con21, y in MOI.LessThan(a))
        @constraint(sp, con22[i in 1:2], w[i] in MOI.LessThan(float(i)))
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    z = DecisionRef.(sp[1,:z])
    con11 = sp[1,:con11]
    @test "con11" == @inferred JuMP.name(con11)
    @test index(con11) == JuMP.constraint_by_name(owner_model(con11), 1, "con11").index
    c = JuMP.constraint_object(con11)
    @test c.func == x
    @test c.set == MOI.LessThan(10.0)
    con12 = sp[1,:con12]
    @test "con12[1]" == @inferred JuMP.name(con12[1])
    @test index(con12[1]) == JuMP.constraint_by_name(owner_model(con12[1]), 1, "con12[1]").index
    c = JuMP.constraint_object(con12[1])
    @test c.func == z[1]
    @test c.set == MOI.LessThan(1.0)
    # Scenario-dependent
    y1 = DecisionRef(sp[2,:y], 1)
    y2 = DecisionRef(sp[2,:y], 2)
    w1 = DecisionRef.(sp[2,:w], 1)
    w2 = DecisionRef.(sp[2,:w], 2)
    con21 = sp[2,:con21]
    @test "con21" == @inferred JuMP.name(con21)
    @test index(con21) == JuMP.constraint_by_name(owner_model(con21), 2, "con21").index
    c1 = JuMP.constraint_object(con21, 1)
    c2 = JuMP.constraint_object(con21, 2)
    @test c1.func == y1
    @test c2.func == y2
    @test c1.set == MOI.LessThan(1.0)
    @test c2.set == MOI.LessThan(2.0)
    con22 = sp[2,:con22]
    @test "con22[1]" == @inferred JuMP.name(con22[1])
    @test index(con22[1]) == JuMP.constraint_by_name(owner_model(con22[1]), 2, "con22[1]").index
    c1 = JuMP.constraint_object(con22[1], 1)
    c2 = JuMP.constraint_object(con22[1], 2)
    @test c1.func == w1[1]
    @test c2.func == w2[1]
    @test c.set == MOI.LessThan(1.0)
end

function test_VectorOfDecisions_constraints(Structure)
    ξ₁ = @scenario a = 1. probability = 0.5
    ξ₂ = @scenario a = 2. probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x[1:2])
        @variable(sp, w)
        @constraint(sp, con11, x in MOI.Zeros(2))
        @constraint(sp, con12, [x[2],x[1]] in MOI.Zeros(2))
    end
    @second_stage sp = begin
        @variable(sp, z)
        @recourse(sp, y[1:2])
        @constraint(sp, con21, y in MOI.Zeros(2))
        @constraint(sp, con22, [y[2],y[1]] in MOI.Zeros(2))
    end
    # First-stage
    x = DecisionRef.(sp[1,:x])
    sp_cref = sp[1,:con11]
    c = JuMP.constraint_object(sp_cref)
    @test c.func == x
    @test c.set == MOI.Zeros(2)
    sp_cref = sp[1,:con12]
    c = JuMP.constraint_object(sp_cref)
    @test c.func == [x[2],x[1]]
    @test c.set == MOI.Zeros(2)
    # Scenario-dependent
    y = DecisionRef.(sp[2,:y], 2)
    sp_cref = sp[2,:con21]
    c = JuMP.constraint_object(sp_cref, 2)
    @test c.func == y
    @test c.set == MOI.Zeros(2)
    sp_cref = sp[2,:con22]
    c = JuMP.constraint_object(sp_cref, 2)
    @test c.func == [y[2],y[1]]
    @test c.set == MOI.Zeros(2)
end

function test_DecisionAffExpr_scalar_constraints(Structure)
    ξ₁ = @scenario a = 1. probability = 0.5
    ξ₂ = @scenario a = 2. probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
        @constraint(sp, con11, x >= 1.)
        @constraint(sp, con12, 2x <= 10)
        @constraint(sp, con13, 3x + 1 >= 10)
        @constraint(sp, con14, 1 == -x)
        @constraint(sp, con15, 2 == 1)
    end
    @second_stage sp = begin
        @known(sp, x)
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y)
        @constraint(sp, con21, y >= a)
        @constraint(sp, con22, 2x + a*y <= 10)
        @constraint(sp, con23, a*x + 3y + 1 >= 10)
        @constraint(sp, con24, 1 == -y - x)
        @constraint(sp, con25, 2 == 1)
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    c = JuMP.constraint_object(sp[1,:con11])
    @test JuMP.isequal_canonical(c.func, 1.0x)
    @test c.set == MOI.GreaterThan(1.0)
    c = JuMP.constraint_object(sp[1,:con12])
    @test JuMP.isequal_canonical(c.func, 2x)
    @test c.set == MOI.LessThan(10.0)
    c = JuMP.constraint_object(sp[1,:con13])
    @test JuMP.isequal_canonical(c.func, 3x)
    @test c.set == MOI.GreaterThan(9.0)
    c = JuMP.constraint_object(sp[1,:con14])
    @test JuMP.isequal_canonical(c.func, 1.0x)
    @test c.set == MOI.EqualTo(-1.0)
    @test_throws ErrorException JuMP.constraint_object(sp[1,:con15])
    # Scenario-dependent
    x = DecisionRef(sp[1,:x], 2, 1)
    y1 = DecisionRef(sp[2,:y], 1)
    y2 = DecisionRef(sp[2,:y], 2)
    c1 = JuMP.constraint_object(sp[2,:con21], 1)
    c2 = JuMP.constraint_object(sp[2,:con21], 2)
    @test JuMP.isequal_canonical(c1.func, 1.0y1)
    @test JuMP.isequal_canonical(c2.func, 1.0y2)
    @test c1.set == MOI.GreaterThan(1.0)
    @test c2.set == MOI.GreaterThan(2.0)
    c1 = JuMP.constraint_object(sp[2,:con22], 1)
    c2 = JuMP.constraint_object(sp[2,:con22], 2)
    @test JuMP.isequal_canonical(c1.func, 2x + y1)
    @test JuMP.isequal_canonical(c2.func, 2x + 2y2)
    @test c1.set == MOI.LessThan(10.0)
    @test c2.set == MOI.LessThan(10.0)
    c1 = JuMP.constraint_object(sp[2,:con23], 1)
    c2 = JuMP.constraint_object(sp[2,:con23], 2)
    @test JuMP.isequal_canonical(c1.func, x + 3y1)
    @test JuMP.isequal_canonical(c2.func, 2x + 3y2)
    @test c1.set == MOI.GreaterThan(9.0)
    @test c2.set == MOI.GreaterThan(9.0)
    c1 = JuMP.constraint_object(sp[2,:con24], 1)
    c2 = JuMP.constraint_object(sp[2,:con24], 2)
    @test JuMP.isequal_canonical(c1.func, 1.0x + 1.0y1)
    @test JuMP.isequal_canonical(c2.func, 1.0x + 1.0y2)
    @test c1.set == MOI.EqualTo(-1.0)
    @test c2.set == MOI.EqualTo(-1.0)
    @test_throws ErrorException JuMP.constraint_object(sp[2,:con25], 1)
end

function test_DecisionAffExpr_vectorized_constraints(Structure)
    ξ₁ = @scenario a = 1. probability = 0.5
    ξ₂ = @scenario a = 2. probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
        @constraint(sp, con1, [x, 2x] .== [1-x, 3])
    end
    @second_stage sp = begin
        @known(sp, x)
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y)
        @constraint(sp, con2, [a*x + y, 2x + a*y] .== [1-x-y, 3])
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    c = JuMP.constraint_object.(sp[1,:con1])
    @test JuMP.isequal_canonical(c[1].func, 2.0x)
    @test c[1].set == MOI.EqualTo(1.0)
    @test JuMP.isequal_canonical(c[2].func, 2.0x)
    @test c[2].set == MOI.EqualTo(3.0)
    # Scenario-dependent
    x = DecisionRef(sp[1,:x], 2, 1)
    y1 = DecisionRef(sp[2,:y], 1)
    y2 = DecisionRef(sp[2,:y], 2)
    c1 = JuMP.constraint_object.(sp[2,:con2], 1)
    c2 = JuMP.constraint_object.(sp[2,:con2], 2)
    @test JuMP.isequal_canonical(c1[1].func, 2.0x + 2.0y1)
    @test JuMP.isequal_canonical(c2[1].func, 3.0x + 2.0y2)
    @test c1[1].set == MOI.EqualTo(1.0)
    @test c2[1].set == MOI.EqualTo(1.0)
    @test JuMP.isequal_canonical(c1[2].func, 2.0x + y1)
    @test JuMP.isequal_canonical(c2[2].func, 2.0x + 2.0y2)
    @test c1[2].set == MOI.EqualTo(3.0)
    @test c2[2].set == MOI.EqualTo(3.0)
end

function test_delete_constraints(Structure)
    ξ₁ = @scenario a = 1. probability = 0.5
    ξ₂ = @scenario a = 2. probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
        @constraint(sp, con1, 2x <= 1)
    end
    @second_stage sp = begin
        @known(sp, x)
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y)
        @constraint(sp, con2, a*x + 2y <= 1)
    end
    # First-stage
    sp_cref = sp[1,:con1]
    @test JuMP.is_valid(sp, sp_cref)
    JuMP.delete(sp, sp_cref)
    @test !JuMP.is_valid(sp, sp_cref)
    second_sp = StochasticProgram([Scenario()], Structure...)
    @test_throws Exception JuMP.delete(second_sp, sp_cref)
    # Scenario-dependent
    sp_cref = sp[2,:con2]
    @test_throws UndefVarError JuMP.is_valid(sp, sp_cref)
    @test JuMP.is_valid(sp, sp_cref, 1)
    @test JuMP.is_valid(sp, sp_cref, 2)
    @test_throws UndefVarError JuMP.delete(sp, sp_cref)
    JuMP.delete(sp, sp_cref, 1)
    @test !JuMP.is_valid(sp, sp_cref, 1)
    @test JuMP.is_valid(sp, sp_cref, 2)
    JuMP.delete(sp, sp_cref, 2)
    @test !JuMP.is_valid(sp, sp_cref, 2)
    @first_stage sp = begin
        @decision(sp, x[1:9])
        @variable(sp, w)
        @constraint(sp, con11, sum(x[1:2:9]) <= 3)
        @constraint(sp, con12, sum(x[2:2:8]) <= 2)
        @constraint(sp, con13, sum(x[1:3:9]) <= 1)
    end
    @second_stage sp = begin
        @known(sp, x)
        @variable(sp, z)
        @recourse(sp, y[1:9])
        @constraint(sp, con21, sum(x[1:2:9]) + sum(y[1:2:9]) <= 3)
        @constraint(sp, con22, sum(x[2:2:8]) + sum(y[2:2:8]) <= 2)
        @constraint(sp, con23, sum(x[1:3:9]) + sum(y[1:3:9]) <= 1)
    end
    # First-stage
    cons = all_constraints(sp, 1, DecisionAffExpr{Float64}, MOI.LessThan{Float64})
    @test all(JuMP.is_valid.(sp, cons))
    JuMP.delete(sp, cons[[1, 3]])
    @test all((!JuMP.is_valid).(sp, cons[[1, 3]]))
    @test JuMP.is_valid(sp, cons[2])
    # Scenario-dependent
    cons = all_constraints(sp, 2, DecisionAffExpr{Float64}, MOI.LessThan{Float64})
    @test_throws UndefVarError all(JuMP.is_valid.(sp, cons))
    @test all(JuMP.is_valid.(sp, cons, 1))
    @test all(JuMP.is_valid.(sp, cons, 2))
    @test_throws UndefVarError JuMP.delete(sp, cons[[1, 3]])
    JuMP.delete(sp, cons[[1, 3]], 1)
    @test all((!JuMP.is_valid).(sp, cons[[1, 3]], 1))
    @test JuMP.is_valid(sp, cons[2], 1)
    @test all(JuMP.is_valid.(sp, cons, 2))
    JuMP.delete(sp, cons[[1, 3]], 2)
    @test all((!JuMP.is_valid).(sp, cons[[1, 3]], 2))
    @test JuMP.is_valid(sp, cons[2], 2)
end

function test_DecisionQuadrExpr_constraints(Structure)
    ξ₁ = @scenario a = 1. probability = 0.5
    ξ₂ = @scenario a = 2. probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
        @constraint(sp, con1, x^2 + x <= 1)
    end
    @second_stage sp = begin
        @known(sp, x)
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y)
        @constraint(sp, con2, y^2 + a*y*x - 1.0 == 0.0)
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    sp_cref = sp[1,:con1]
    c = JuMP.constraint_object(sp_cref)
    @test JuMP.isequal_canonical(c.func, x^2 + x)
    @test c.set == MOI.LessThan(1.0)
    # Scenario-dependent
    sp_cref = sp[2,:con2]
    x = DecisionRef(sp[1,:x], 2, 1)
    y1 = DecisionRef(sp[2,:y], 1)
    y2 = DecisionRef(sp[2,:y], 2)
    c1 = JuMP.constraint_object(sp_cref, 1)
    c2 = JuMP.constraint_object(sp_cref, 2)
    @test JuMP.isequal_canonical(c1.func, y1^2 + x*y1)
    @test JuMP.isequal_canonical(c2.func, y2^2 + 2*x*y2)
    @test c1.set == MOI.EqualTo(1.0)
    @test c2.set == MOI.EqualTo(1.0)
    # sp_cref = sp[2,:con3]
    # c = JuMP.constraint_object(cref)
    # @test JuMP.isequal_canonical(c.func[1], -1 + 3x^2 - 4x*y + 2x)
    # @test JuMP.isequal_canonical(c.func[2],  1 - 2x^2 + 2x*y - 3y)
    # @test c.set == MOI.SecondOrderCone(2)
end

function test_all_decision_constraints(Structure)
    ξ₁ = @scenario a = 1. probability = 0.5
    ξ₂ = @scenario a = 2. probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x >= 0)
        @variable(sp, w)
    end
    @second_stage sp = begin
        @known(sp, x)
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y >= 0)
        @constraint(sp, x + a*y >= 0)
    end
    # First-stage
    x = sp[1,:x]
    @test 1 == @inferred num_constraints(sp, 1, DecisionRef, MOI.GreaterThan{Float64})
    ref = @inferred all_constraints(sp, 1, DecisionRef, MOI.GreaterThan{Float64})
    @test ref == [LowerBoundRef(x)]
    @test 0 == @inferred num_constraints(sp, 1, DecisionAffExpr{Float64},
                                            MOI.GreaterThan{Float64})
    aff_constraints = all_constraints(sp, 1, DecisionAffExpr{Float64},
                                        MOI.GreaterThan{Float64})
    @test isempty(aff_constraints)
    # Scenario-dependent
    y = sp[2,:y]
    ref = @inferred all_constraints(sp, 2, DecisionRef, MOI.GreaterThan{Float64})
    @test ref == [LowerBoundRef(y)]
    @test 1 == @inferred num_constraints(sp, 2, DecisionAffExpr{Float64},
                                            MOI.GreaterThan{Float64})
    aff_constraints = all_constraints(sp, 2, DecisionAffExpr{Float64},
                                      MOI.GreaterThan{Float64})
    x = DecisionRef(x, 2, 1)
    y1 = DecisionRef(y, 1)
    y2 = DecisionRef(y, 2)
    c1 = constraint_object(aff_constraints[1], 1)
    c2 = constraint_object(aff_constraints[1], 2)
    @test JuMP.isequal_canonical(c1.func, x + y1)
    @test JuMP.isequal_canonical(c2.func, x + 2y2)
end

function test_list_of_constraint_types(Structure)
    ξ₁ = @scenario a = 1. probability = 0.5
    ξ₂ = @scenario a = 2. probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x >= 0, Bin)
        @variable(sp, w)
        @constraint(sp, 2x <= 1)
        @constraint(sp, [x, x] in SecondOrderCone())
        @constraint(sp, x^2- x <= 2)
    end
    @second_stage sp = begin
        @known(sp, x)
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y >= 0, Bin)
        @constraint(sp, 2x + 2y <= a)
        @constraint(sp, [x + y, x] in SecondOrderCone())
        @constraint(sp, x^2+y^2 - x*y <= 1)
    end
    # First-stage
    constraint_types = @inferred list_of_constraint_types(sp, 1)
    @test Set(constraint_types) == Set(
        [(DecisionRef, MOI.ZeroOne),
         (DecisionRef, MOI.GreaterThan{Float64}),
         (DecisionAffExpr{Float64}, MOI.LessThan{Float64}),
         (Vector{DecisionRef}, MOI.SecondOrderCone),
         (DecisionQuadExpr{Float64}, MOI.LessThan{Float64})])
    # First-stage
    constraint_types = @inferred list_of_constraint_types(sp, 1)
    @test Set(constraint_types) == Set(
        [(DecisionRef, MOI.ZeroOne),
         (DecisionRef, MOI.GreaterThan{Float64}),
         (DecisionAffExpr{Float64}, MOI.LessThan{Float64}),
         (Vector{DecisionRef}, MOI.SecondOrderCone),
         (DecisionQuadExpr{Float64}, MOI.LessThan{Float64})])
    # Second-stage
    constraint_types = @inferred list_of_constraint_types(sp, 2)
    @test Set(constraint_types) == Set(
        [(DecisionRef, MOI.ZeroOne),
        (DecisionRef, MOI.GreaterThan{Float64}),
        (DecisionAffExpr{Float64}, MOI.LessThan{Float64}),
        (Vector{DecisionAffExpr{Float64}}, MOI.SecondOrderCone),
        (DecisionQuadExpr{Float64}, MOI.LessThan{Float64})])
end

function test_change_decision_coefficient(Structure)
    ξ₁ = @scenario a = 1. probability = 0.5
    ξ₂ = @scenario a = 2. probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
        @constraint(sp, con1, 2 * x == -1)
        @constraint(sp, quadcon1, x^2 == 0)
    end
    @second_stage sp = begin
        @known(sp, x)
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y)
        @constraint(sp, con2, 2x + a*y == 0)
        @constraint(sp, quadcon2, y^2 + a*x == 0)
    end
    # First-stage
    x = sp[1,:x]
    sp_cref = sp[1,:con1]
    @test JuMP.normalized_coefficient(sp_cref, x) == 2.0
    JuMP.set_normalized_coefficient(sp_cref, x, 1.0)
    @test JuMP.normalized_coefficient(sp_cref, x) == 1.0
    JuMP.set_normalized_coefficient(sp_cref, x, 3)
    @test JuMP.normalized_coefficient(sp_cref, x) == 3.0
    quad_con = sp[1,:quadcon1]
    @test JuMP.normalized_coefficient(quad_con, x) == 0.0
    JuMP.set_normalized_coefficient(quad_con, x, 2)
    @test JuMP.normalized_coefficient(quad_con, x) == 2.0
    x = DecisionRef(x)
    @test JuMP.isequal_canonical(
        JuMP.constraint_object(quad_con).func, x^2 + 2x)
    # Scenario-dependent
    x = sp[1,:x]
    y = sp[2,:y]
    sp_cref = sp[2,:con2]
    @test_throws UndefVarError JuMP.normalized_coefficient(sp_cref, y) == 2.0
    @test JuMP.normalized_coefficient(sp_cref, y, 1) == 1.0
    @test JuMP.normalized_coefficient(sp_cref, y, 2) == 2.0
    @test_throws UndefVarError JuMP.set_normalized_coefficient(sp_cref, y, 1.0)
    JuMP.set_normalized_coefficient(sp_cref, y, 1, 2.0)
    JuMP.set_normalized_coefficient(sp_cref, y, 2, 1.0)
    @test JuMP.normalized_coefficient(sp_cref, y, 1) == 2.0
    @test JuMP.normalized_coefficient(sp_cref, y, 2) == 1.0
    JuMP.set_normalized_coefficient(sp_cref, y, 1, 3)
    JuMP.set_normalized_coefficient(sp_cref, y, 2, 3)
    @test JuMP.normalized_coefficient(sp_cref, y, 1) == 3.0
    @test JuMP.normalized_coefficient(sp_cref, y, 2) == 3.0
    quad_con = sp[2,:quadcon2]
    @test_throws UndefVarError JuMP.normalized_coefficient(quad_con, y) == 0.0
    @test JuMP.normalized_coefficient(quad_con, y, 1) == 0.0
    @test JuMP.normalized_coefficient(quad_con, y, 2) == 0.0
    @test_throws UndefVarError JuMP.set_normalized_coefficient(quad_con, y, 2)
    JuMP.set_normalized_coefficient(quad_con, y, 1, 2)
    JuMP.set_normalized_coefficient(quad_con, y, 2, 2)
    @test JuMP.normalized_coefficient(quad_con, y, 1) == 2.0
    @test JuMP.normalized_coefficient(quad_con, y, 2) == 2.0
    x = DecisionRef(x, 2, 1)
    y1 = DecisionRef(y, 1)
    y2 = DecisionRef(y, 2)
    @test JuMP.isequal_canonical(
        JuMP.constraint_object(quad_con, 1).func, y1^2 + 2y1 + x)
    @test JuMP.isequal_canonical(
        JuMP.constraint_object(quad_con, 2).func, y2^2 + 2y2 + 2x)
end

function test_change_decision_rhs(Structure)
    ξ₁ = @scenario a = 1. probability = 0.5
    ξ₂ = @scenario a = 2. probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
        @constraint(sp, con1, 2 * x <= 1)
    end
    @second_stage sp = begin
        @known(sp, x)
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y)
        @constraint(sp, con2, 2x + y <= a)
    end
    # First-stage
    sp_cref = sp[1,:con1]
    @test JuMP.normalized_rhs(sp_cref) == 1.0
    JuMP.set_normalized_rhs(sp_cref, 2.0)
    @test JuMP.normalized_rhs(sp_cref) == 2.0
    JuMP.set_normalized_rhs(sp_cref, 3)
    @test JuMP.normalized_rhs(sp_cref) == 3.0
    # Scenario-dependent
    sp_cref = sp[2,:con2]
    @test_throws UndefVarError JuMP.normalized_rhs(sp_cref)
    @test JuMP.normalized_rhs(sp_cref, 1) == 1.0
    @test JuMP.normalized_rhs(sp_cref, 2) == 2.0
    @test_throws UndefVarError JuMP.set_normalized_rhs(sp_cref, 2.0)
    JuMP.set_normalized_rhs(sp_cref, 1, 2.0)
    JuMP.set_normalized_rhs(sp_cref, 2, 1.0)
    @test JuMP.normalized_rhs(sp_cref, 1) == 2.0
    @test JuMP.normalized_rhs(sp_cref, 2) == 1.0
    JuMP.set_normalized_rhs(sp_cref, 1, 3)
    JuMP.set_normalized_rhs(sp_cref, 2, 3)
    @test JuMP.normalized_rhs(sp_cref, 1) == 3.0
    @test JuMP.normalized_rhs(sp_cref, 2) == 3.0
end

function runtests()
    @testset "DecisionConstraint" begin
        for structure in [(Deterministic(),),
                          (StageDecomposition(),),
                          (ScenarioDecomposition(),),
                          (Deterministic(), () -> MOIU.MockOptimizer(MOIU.Model{Float64}()))]
            @testset "$(structure)" begin
                for name in names(@__MODULE__; all = true)
                    if !startswith("$(name)", "test_")
                        continue
                    end
                    f = getfield(@__MODULE__, name)
                    @testset "$(name)" begin
                        f(structure)
                    end
                end
            end
        end
    end
end

function run_dtests()
    @testset "DecisionConstraint" begin
        for structure in [(DistributedStageDecomposition(),), (DistributedScenarioDecomposition(),)]
            @testset "$(structure)" begin
                for name in names(@__MODULE__; all = true)
                    if !startswith("$(name)", "test_")
                        continue
                    end
                    f = getfield(@__MODULE__, name)
                    @testset "$(name)" begin
                        f(structure)
                    end
                end
            end
        end
    end
end

end
