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

@everywhere module TestDecisionVariable

using StochasticPrograms
using Test

function test_decision_no_bound(Structure)
    ξ₁ = @scenario a = 1 probability = 0.5
    ξ₂ = @scenario a = 2 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
    end
    @second_stage sp = begin
        @variable(sp, z)
        @recourse(sp, y)
    end
    # First-stage
    x = sp[1,:x]
    @test StochasticPrograms.stage(x) == 1
    @test !JuMP.has_lower_bound(x)
    @test !JuMP.has_upper_bound(x)
    @test !JuMP.is_fixed(x)
    @test "x" == @inferred JuMP.name(x)
    @test x == decision_by_name(owner_model(x), 1, "x")
    # Scenario-dependent
    y = sp[2,:y]
    @test StochasticPrograms.stage(y) == 2
    @test_throws ErrorException JuMP.has_lower_bound(y)
    @test !JuMP.has_lower_bound(y, 1)
    @test !JuMP.has_lower_bound(y, 2)
    @test_throws ErrorException JuMP.has_upper_bound(y)
    @test !JuMP.has_upper_bound(y, 1)
    @test !JuMP.has_upper_bound(y, 2)
    @test_throws ErrorException JuMP.is_fixed(y)
    @test !JuMP.is_fixed(y, 1)
    @test !JuMP.is_fixed(y, 2)
    @test_throws ErrorException JuMP.is_integer(y)
    @test !JuMP.is_integer(y, 1)
    @test !JuMP.is_integer(y, 2)
    @test_throws ErrorException JuMP.is_binary(y)
    @test !JuMP.is_binary(y, 1)
    @test !JuMP.is_binary(y, 2)
    @test "y" == @inferred JuMP.name(y)
    @test y == decision_by_name(owner_model(y), 2, "y")
end

function test_decision_lower_bound(Structure)
    ξ₁ = @scenario a = 1 probability = 0.5
    ξ₂ = @scenario a = 2 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x >= 0, Bin)
        @variable(sp, w)
    end
    @second_stage sp = begin
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y >= a, Bin)
    end
    # First-stage
    x = sp[1,:x]
    @test JuMP.has_lower_bound(x)
    @test 0.0 == @inferred JuMP.lower_bound(x)
    @test !JuMP.has_upper_bound(x)
    @test !JuMP.is_fixed(x)
    @test JuMP.is_binary(x)
    @test !JuMP.is_integer(x)
    JuMP.delete_lower_bound(x)
    @test !JuMP.has_lower_bound(x)
    # Scenario-dependent
    y = sp[2,:y]
    @test JuMP.has_lower_bound(y, 1)
    @test JuMP.has_lower_bound(y, 2)
    @test 1.0 == @inferred JuMP.lower_bound(y, 1)
    @test 2.0 == @inferred JuMP.lower_bound(y, 2)
    @test !JuMP.has_upper_bound(y, 1)
    @test !JuMP.has_upper_bound(y, 2)
    @test !JuMP.is_fixed(y, 1)
    @test !JuMP.is_fixed(y, 2)
    @test JuMP.is_binary(y, 1)
    @test JuMP.is_binary(y, 2)
    @test !JuMP.is_integer(y, 1)
    @test !JuMP.is_integer(y, 2)
    JuMP.delete_lower_bound(y, 1)
    @test !JuMP.has_lower_bound(y, 1)
    JuMP.delete_lower_bound(y, 2)
    @test !JuMP.has_lower_bound(y, 2)
end

function test_decision_upper_bound(Structure)
    ξ₁ = @scenario a = 1 probability = 0.5
    ξ₂ = @scenario a = 2 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x <= 1.0, Int)
        @variable(sp, w)
    end
    @second_stage sp = begin
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y <= a, Int)
    end
    # First-stage
    x = sp[1,:x]
    @test !JuMP.has_lower_bound(x)
    @test JuMP.has_upper_bound(x)
    @test 1.0 == @inferred JuMP.upper_bound(x)
    @test !JuMP.is_fixed(x)
    @test !JuMP.is_binary(x)
    @test JuMP.is_integer(x)
    JuMP.delete_upper_bound(x)
    @test !JuMP.has_upper_bound(x)
    # Scenario-dependent
    y = sp[2,:y]
    @test !JuMP.has_lower_bound(y, 1)
    @test !JuMP.has_lower_bound(y, 2)
    @test JuMP.has_upper_bound(y, 1)
    @test JuMP.has_upper_bound(y, 2)
    @test 1.0 == @inferred JuMP.upper_bound(y, 1)
    @test 2.0 == @inferred JuMP.upper_bound(y, 2)
    @test !JuMP.is_fixed(y, 1)
    @test !JuMP.is_fixed(y, 2)
    @test !JuMP.is_binary(y, 1)
    @test !JuMP.is_binary(y, 2)
    @test JuMP.is_integer(y, 1)
    @test JuMP.is_integer(y, 2)
    JuMP.delete_upper_bound(y, 1)
    @test !JuMP.has_upper_bound(y, 1)
    JuMP.delete_upper_bound(y, 2)
    @test !JuMP.has_upper_bound(y, 2)
end

function test_decision_fix(Structure)
    ξ₁ = @scenario a = 1 probability = 0.5
    ξ₂ = @scenario a = 2 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x == 1)
        @variable(sp, w)
    end
    @second_stage sp = begin
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y == a)
    end
    # First-stage
    x = sp[1,:x]
    @test !JuMP.has_lower_bound(x)
    @test !JuMP.has_upper_bound(x)
    @test JuMP.is_fixed(x)
    @test 1.0 == @inferred JuMP.value(x)
    JuMP.unfix(x)
    @test !JuMP.is_fixed(x)
    JuMP.fix(x, 2.0)
    @test !JuMP.has_lower_bound(x)
    @test !JuMP.has_upper_bound(x)
    @test JuMP.is_fixed(x)
    @test 2.0 == @inferred JuMP.value(x)
    # Scenario-dependent
    y = sp[2,:y]
    @test !JuMP.has_lower_bound(y, 1)
    @test !JuMP.has_lower_bound(y, 2)
    @test !JuMP.has_upper_bound(y, 1)
    @test !JuMP.has_upper_bound(y, 2)
    @test JuMP.is_fixed(y, 1)
    @test JuMP.is_fixed(y, 2)
    @test 1.0 == @inferred JuMP.value(y, 1)
    @test 2.0 == @inferred JuMP.value(y, 2)
    JuMP.unfix(y, 1)
    @test !JuMP.is_fixed(y, 1)
    @test JuMP.is_fixed(y, 2)
    JuMP.unfix(y, 2)
    @test !JuMP.is_fixed(y, 2)
    JuMP.fix(y, 1, 2.0)
    @test !JuMP.has_lower_bound(y, 1)
    @test !JuMP.has_upper_bound(y, 1)
    @test JuMP.is_fixed(y, 1)
    @test !JuMP.is_fixed(y, 2)
    @test 2.0 == @inferred JuMP.value(y, 1)
    JuMP.fix(y, 2, 1.0)
    @test !JuMP.has_lower_bound(y, 2)
    @test !JuMP.has_upper_bound(y, 2)
    @test JuMP.is_fixed(y, 2)
    @test 1.0 == @inferred JuMP.value(y, 2)
end

function test_decision_custom_index_sets(Structure)
    ξ₁ = @scenario a = 1 probability = 0.5
    ξ₂ = @scenario a = 2 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x[0:1, 10:20, 1:1] >= 2)
        @variable(sp, w)
    end
    @second_stage sp = begin
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y[0:1, 10:20, 1:1] >= a)
    end
    # First-stage
    x = sp[1,:x]
    @test JuMP.has_lower_bound(x[0, 15, 1])
    @test 2 == @inferred JuMP.lower_bound(x[0, 15, 1])
    @test !JuMP.has_upper_bound(x[0, 15, 1])
    @first_stage sp = begin
        @decision(sp, x[i in -10:10, s in [:a,:b]] <= 5.5, Int)
        @variable(sp, w)
    end
    generate!(sp)
    x = sp[1,:x]
    @test 5.5 == @inferred JuMP.upper_bound(x[-4, :a])
    @test "x[-10,a]" == @inferred JuMP.name(x[-10,:a])
    @test x[-10,:a] == decision_by_name(sp, 1, "x[-10,a]")
    # Scenario-dependent
    y = sp[2,:y]
    @test JuMP.has_lower_bound(y[0, 15, 1], 1)
    @test JuMP.has_lower_bound(y[0, 15, 1], 2)
    @test 1 == @inferred JuMP.lower_bound(y[0, 15, 1], 1)
    @test 2 == @inferred JuMP.lower_bound(y[0, 15, 1], 2)
    @test !JuMP.has_upper_bound(y[0, 15, 1], 1)
    @test !JuMP.has_upper_bound(y[0, 15, 1], 2)
    @second_stage sp = begin
        @variable(sp, z)
        @recourse(sp, y[i in -10:10, s in [:a,:b]] <= 5.5, Int)
    end
    y = sp[2,:y]
    @test 5.5 == @inferred JuMP.upper_bound(y[-4, :a], 1)
    @test 5.5 == @inferred JuMP.upper_bound(y[-4, :a], 2)
    @test "y[-10,a]" == @inferred JuMP.name(y[-10,:a])
    @test nothing === decision_by_name(sp, 1, "y[-10,a]")
    @test y[-10,:a] == decision_by_name(sp, 2, "y[-10,a]")
end

function test_variable_is_valid_delete(Structure)
    ξ₁ = @scenario a = 1 probability = 0.5
    ξ₂ = @scenario a = 2 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
    end
    @second_stage sp = begin
        @variable(sp, z)
        @recourse(sp, y)
    end
    # First-stage
    x = sp[1,:x]
    @test JuMP.is_valid(sp, x)
    JuMP.delete(sp, x)
    @test !JuMP.is_valid(sp, x)
    @test_throws Exception JuMP.delete(sp, x)
    # Scenario-dependent
    y = sp[2,:y]
    @test_throws ErrorException JuMP.is_valid(sp, y)
    @test JuMP.is_valid(sp, y, 1)
    @test JuMP.is_valid(sp, y, 2)
    @test_throws ErrorException JuMP.delete(sp, y)
    JuMP.delete(sp, y, 1)
    @test !JuMP.is_valid(sp, y, 1)
    @test JuMP.is_valid(sp, y, 2)
    JuMP.delete(sp, y, 2)
    @test !JuMP.is_valid(sp, y, 2)
    @test_throws Exception JuMP.delete(sp, y, 1)
    @first_stage sp = begin
        @decision(sp, x[1:3] >= 1)
        @variable(sp, w)
    end
    @second_stage sp = begin
        @variable(sp, z)
        @recourse(sp, y[1:3] >= 1)
    end
    # First-stage
    x = sp[1,:x]
    @test all(is_valid.(sp, x))
    delete(sp, x)
    @test all((!is_valid).(sp, x))
    second_sp = StochasticProgram([Scenario()], Structure...)
    @test_throws Exception JuMP.delete(second_sp, x[1])
    @test_throws Exception JuMP.delete(second_sp, x)
    # Scenario-dependent
    y = sp[2,:y]
    @test_throws ErrorException is_valid.(sp, y)
    @test all(is_valid.(sp, y, 1))
    @test all(is_valid.(sp, y, 2))
    @test_throws ErrorException delete.(sp, y)
    delete(sp, y, 1)
    @test all((!is_valid).(sp, y, 1))
    @test all(is_valid.(sp, y, 2))
    delete(sp, y, 2)
    @test all((!is_valid).(sp, y, 2))
end

function test_variable_bounds_set_get(Structure)
    ξ₁ = @scenario a = 1 probability = 0.5
    ξ₂ = @scenario a = 2 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, 0 <= x <= 2)
        @variable(sp, w)
    end
    @second_stage sp = begin
        @uncertain a
        @variable(sp, z)
        @recourse(sp, 0 <= y <= a)
    end
    # First-stage
    x = sp[1,:x]
    @test 0 == @inferred JuMP.lower_bound(x)
    @test 2 == @inferred JuMP.upper_bound(x)
    set_lower_bound(x, 1.)
    @test 1. == @inferred JuMP.lower_bound(x)
    set_upper_bound(x, 3.)
    @test 3. == @inferred JuMP.upper_bound(x)
    # Scenario-dependent
    y = sp[2,:y]
    @test_throws ErrorException JuMP.lower_bound(y)
    @test 0 == @inferred JuMP.lower_bound(y, 1)
    @test 0 == @inferred JuMP.lower_bound(y, 2)
    @test_throws ErrorException JuMP.upper_bound(y)
    @test 1 == @inferred JuMP.upper_bound(y, 1)
    @test 2 == @inferred JuMP.upper_bound(y, 2)
    set_lower_bound(y, 1, 1.)
    @test 1. == @inferred JuMP.lower_bound(y, 1)
    set_lower_bound(y, 2, 1.)
    @test 1. == @inferred JuMP.lower_bound(y, 2)
    JuMP.set_lower_bound(y, 2.)
    @test 2. == @inferred JuMP.lower_bound(y, 1)
    @test 2. == @inferred JuMP.lower_bound(y, 2)
    set_upper_bound(y, 1, 3.)
    @test 3. == @inferred JuMP.upper_bound(y, 1)
    set_upper_bound(y, 2, 3.)
    @test 3. == @inferred JuMP.upper_bound(y, 2)
    JuMP.set_upper_bound(y, 2.)
    @test 2. == @inferred JuMP.upper_bound(y, 1)
    @test 2. == @inferred JuMP.upper_bound(y, 2)
end

function test_variable_starts_set_get(Structure)
    ξ₁ = @scenario a = 1 probability = 0.5
    ξ₂ = @scenario a = 2 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x[1:3])
        @variable(sp, w)
    end
    @second_stage sp = begin
        @variable(sp, z)
        @recourse(sp, y[1:3])
    end
    # First-stage
    x = sp[1,:x]
    x0 = collect(1:3)
    JuMP.set_start_value.(x, x0)
    @test JuMP.start_value.(x) == x0
    @test JuMP.start_value.([x[1],x[2],x[3]]) == x0
    # First-stage
    y = sp[2,:y]
    @test_throws ErrorException JuMP.set_start_value.(y, x0)
    JuMP.set_start_value.(y, 1, x0)
    JuMP.set_start_value.(y, 2, x0)
    @test_throws ErrorException JuMP.start_value.(y)
    @test JuMP.start_value.(y, 1) == x0
    @test JuMP.start_value.(y, 2) == x0
    @test_throws ErrorException JuMP.start_value.([y[1],y[2],y[3]])
    @test JuMP.start_value.([y[1],y[2],y[3]], 1) == x0
    @test JuMP.start_value.([y[1],y[2],y[3]], 2) == x0
end

function test_variable_integrality_set_get(Structure)
    ξ₁ = @scenario a = 1 probability = 0.5
    ξ₂ = @scenario a = 2 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x[1:3])
        @variable(sp, w)
    end
    @second_stage sp = begin
        @variable(sp, z)
        @recourse(sp, y[1:3])
    end
    # First-stage
    x = sp[1,:x]
    JuMP.set_integer(x[2])
    JuMP.set_integer(x[2])
    @test JuMP.is_integer(x[2])
    JuMP.unset_integer(x[2])
    @test !JuMP.is_integer(x[2])
    JuMP.set_binary(x[1])
    JuMP.set_binary(x[1])
    @test JuMP.is_binary(x[1])
    @test_throws Exception JuMP.set_integer(x[1])
    JuMP.unset_binary(x[1])
    @test !JuMP.is_binary(x[1])
    # Scenario-dependent
    y = sp[2,:y]
    @test_throws ErrorException JuMP.set_integer(y[2])
    JuMP.set_integer(y[2], 1)
    JuMP.set_integer(y[2], 1)
    JuMP.set_integer(y[3], 2)
    JuMP.set_integer(y[3], 2)
    @test_throws ErrorException JuMP.is_integer(y[2])
    @test JuMP.is_integer(y[2], 1)
    @test !JuMP.is_integer(y[2], 2)
    @test JuMP.is_integer(y[3], 2)
    @test !JuMP.is_integer(y[3], 1)
    @test_throws ErrorException JuMP.unset_integer(y[2])
    JuMP.unset_integer(y[2], 1)
    JuMP.unset_integer(y[3], 2)
    @test !JuMP.is_integer(y[2], 1)
    @test_throws ErrorException JuMP.set_binary(y[2])
    JuMP.set_binary(y[1], 1)
    JuMP.set_binary(y[1], 1)
    JuMP.set_binary(y[1], 2)
    JuMP.set_binary(y[1], 2)
    @test_throws ErrorException JuMP.is_binary(y[1])
    @test JuMP.is_binary(y[1], 1)
    @test JuMP.is_binary(y[1], 2)
    @test_throws Exception JuMP.set_integer(y[1], 1)
    @test_throws Exception JuMP.set_integer(y[1], 2)
    @test_throws ErrorException JuMP.unset_binary(y[1])
    JuMP.unset_binary(y[1], 1)
    @test !JuMP.is_binary(y[1], 1)
    JuMP.unset_binary(y[1], 2)
    @test !JuMP.is_binary(y[1], 2)
end

function test_variables_constrained_on_creation(Structure)
    ξ₁ = @scenario a = 1 probability = 0.5
    ξ₂ = @scenario a = 2 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x[1:2] in SecondOrderCone())
        @variable(sp, w)
    end
    @second_stage sp = begin
        @variable(sp, r)
        @recourse(sp, y[1:2] in SecondOrderCone())
    end
    x = sp[1,:x]
    y = sp[2,:y]
    @test num_constraints(sp, 1, typeof(x), MOI.SecondOrderCone) == 1
    @test num_constraints(sp, 2, typeof(y), MOI.SecondOrderCone) == 1
    @test name(x[1]) ==  "x[1]"
    @test name(x[2]) ==  "x[2]"
    @test name(y[1]) == "y[1]"
    @test name(y[2]) == "y[2]"
    @first_stage sp = begin
        @decision(sp, x[1:2] in SecondOrderCone())
        @decision(sp, [1:2] in SecondOrderCone())
        @variable(sp, w)
    end
    @second_stage sp = begin
        @variable(sp, r)
        @recourse(sp, y[1:2] in SecondOrderCone())
        @recourse(sp, [1:2] in SecondOrderCone())
    end
    x = sp[1,:x]
    y = sp[2,:y]
    @test num_constraints(sp, 1, typeof(x), MOI.SecondOrderCone) == 2
    @test num_constraints(sp, 2, typeof(y), MOI.SecondOrderCone) == 2
    @first_stage sp = begin
        @decision(sp, x[1:2] in SecondOrderCone())
        @decision(sp, [1:2] in SecondOrderCone())
        @decision(sp, [1:3] in SecondOrderCone())
        @variable(sp, w)
    end
    @second_stage sp = begin
        @variable(sp, r)
        @recourse(sp, y[1:2] in SecondOrderCone())
        @recourse(sp, [1:2] in SecondOrderCone())
        @recourse(sp, [1:3] in SecondOrderCone())
    end
    x = sp[1,:x]
    y = sp[2,:y]
    @test num_constraints(sp, 1, typeof(x), MOI.SecondOrderCone) == 3
    @test num_constraints(sp, 2, typeof(y), MOI.SecondOrderCone) == 3
    @first_stage sp = begin
        @decision(sp, z in MOI.Semiinteger(1.0, 2.0))
        @variable(sp, w)
    end
    generate!(sp)
    z = sp[1,:z]
    @test num_constraints(sp, 1, typeof(z), MOI.Semiinteger{Float64}) == 1
    @first_stage sp = begin
        @variable(sp, w)
        @decision(sp, z in MOI.Semiinteger(1.0, 2.0))
        @decision(sp, set = MOI.Semiinteger(1.0, 2.0))
    end
    generate!(sp)
    z = sp[1,:z]
    @test num_constraints(sp, 1, typeof(z), MOI.Semiinteger{Float64}) == 2
end

function test_all_decision_variables(Structure)
    ξ₁ = @scenario a = 1 probability = 0.5
    ξ₂ = @scenario a = 2 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x₁)
        @decision(sp, x₂)
        @variable(sp, w)
    end
    @second_stage sp = begin
        @variable(sp, z)
        @recourse(sp, y₁)
        @recourse(sp, y₂)
    end
    # First-stage
    x₁ = sp[1,:x₁]
    x₂ = sp[1,:x₂]
    @test [x₁, x₂] == @inferred all_decision_variables(sp, 1)
    # Scenario-dependent
    y₁ = sp[2,:y₁]
    y₂ = sp[2,:y₂]
    @test [y₁, y₂] == @inferred all_decision_variables(sp, 2)
end

function runtests()
    @testset "DecisionVariable" begin
        for structure in [(Deterministic(),),
                          (StageDecomposition(),),
                          (ScenarioDecomposition(),),
                          (Deterministic(), () -> MOIU.MockOptimizer(MOIU.Model{Float64}()))]
            name = length(structure) == 1 ? "$(structure[1])" : "$(structure[1]) with decision bridges"
            @testset "$name" begin
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
    @testset "DecisionVariable" begin
        for structure in [(DistributedStageDecomposition(),), (DistributedScenarioDecomposition(),)]
            @testset "$(structure[1])" begin
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
