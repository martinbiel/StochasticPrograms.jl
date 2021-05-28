@everywhere module TestDecisionObjective

using StochasticPrograms
using Test

function test_SingleDecision_objective(Structure)
    ξ₁ = @scenario a = 1. probability = 0.5
    ξ₂ = @scenario a = 2. probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
        @objective(sp, Min, x)
    end
    @second_stage sp = begin
        @variable(sp, z)
        @recourse(sp, y)
        @objective(sp, Min, y)
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
    @test JuMP.objective_function_type(sp, 1) == DecisionRef
    @test JuMP.objective_function(sp, 1) == x
    @test x == @inferred JuMP.objective_function(sp, 1, DecisionRef)
    # Second-stage
    y1 = DecisionRef(sp[2,:y], 1)
    y2 = DecisionRef(sp[2,:y], 2)
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
    # Structure specific
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        @test JuMP.objective_function_type(sp, 2, 1) == DecisionRef
        @test JuMP.objective_function_type(sp, 2, 2) == DecisionRef
        @test JuMP.objective_function(sp, 2, 1) == y1
        @test JuMP.objective_function(sp, 2, 2) == y2
        @test y1 == @inferred JuMP.objective_function(sp, 2, 1, DecisionRef)
        @test y2 == @inferred JuMP.objective_function(sp, 2, 2, DecisionRef)
        @test JuMP.isequal_canonical(x + 0.5*y1 + 0.5*y2, JuMP.objective_function(sp))
        @test JuMP.isequal_canonical(x + 0.5*y1 + 0.5*y2,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.StageDecompositionStructure
        @test JuMP.objective_function_type(sp, 2, 1) == DecisionRef
        @test JuMP.objective_function_type(sp, 2, 2) == DecisionRef
        @test JuMP.objective_function(sp, 2, 1) == y1
        @test JuMP.objective_function(sp, 2, 2) == y2
        @test y1 == @inferred JuMP.objective_function(sp, 2, 1, DecisionRef)
        @test y2 == @inferred JuMP.objective_function(sp, 2, 2, DecisionRef)
        @test JuMP.objective_function(sp) == x
        @test x == @inferred JuMP.objective_function(sp, DecisionRef)
    end
    if sp.structure isa StochasticPrograms.ScenarioDecompositionStructure
        x1 = DecisionRef(sp[1,:x], 2, 1)
        x2 = DecisionRef(sp[1,:x], 2, 2)
        @test JuMP.objective_function_type(sp, 2, 1) == DecisionAffExpr{Float64}
        @test JuMP.objective_function_type(sp, 2, 2) == DecisionAffExpr{Float64}
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x1 + y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), x2 + y2)
        @test JuMP.isequal_canonical(x1 + y1,
                                     @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test JuMP.isequal_canonical(x2 + y2,
                                     @inferred JuMP.objective_function(sp, 2, 2, DecisionAffExpr{Float64}))
        @test_throws ErrorException JuMP.objective_function(sp)
    end
    @first_stage sp = begin
        @decision(sp, x)
        @objective(sp, Max, x)
    end
    @second_stage sp = begin
        @recourse(sp, y)
        @objective(sp, Max, y)
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 1)
    @test JuMP.objective_function_type(sp, 1) == DecisionRef
    @test JuMP.objective_function(sp, 1) == x
    @test x == @inferred JuMP.objective_function(sp, 1, DecisionRef)
    # Second-stage
    y1 = DecisionRef(sp[2,:y], 1)
    y2 = DecisionRef(sp[2,:y], 2)
    @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
    # Structure specific
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        @test JuMP.objective_function_type(sp, 2, 1) == DecisionRef
        @test JuMP.objective_function_type(sp, 2, 2) == DecisionRef
        @test JuMP.objective_function(sp, 2, 1) == y1
        @test JuMP.objective_function(sp, 2, 2) == y2
        @test y1 == @inferred JuMP.objective_function(sp, 2, 1, DecisionRef)
        @test y2 == @inferred JuMP.objective_function(sp, 2, 2, DecisionRef)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), x + 0.5*y1 + 0.5*y2)
        @test JuMP.isequal_canonical(x + 0.5*y1 + 0.5*y2,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.StageDecompositionStructure
        @test JuMP.objective_function_type(sp, 2, 1) == DecisionRef
        @test JuMP.objective_function_type(sp, 2, 2) == DecisionRef
        @test JuMP.objective_function(sp, 2, 1) == y1
        @test JuMP.objective_function(sp, 2, 1) == y2
        @test y1 == @inferred JuMP.objective_function(sp, 2, 1, DecisionRef)
        @test y2 == @inferred JuMP.objective_function(sp, 2, 1, DecisionRef)
        @test JuMP.objective_function(sp) == x
        @test x == @inferred JuMP.objective_function(sp, DecisionRef)
    end
    if sp.structure isa StochasticPrograms.ScenarioDecompositionStructure
        x1 = DecisionRef(sp[1,:x], 2, 1)
        x2 = DecisionRef(sp[1,:x], 2, 2)
        @test JuMP.objective_function_type(sp, 2, 1) == DecisionAffExpr{Float64}
        @test JuMP.objective_function_type(sp, 2, 2) == DecisionAffExpr{Float64}
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x1 + y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), x2 + y2)
        @test JuMP.isequal_canonical(x1 + y1,
                                     @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test JuMP.isequal_canonical(x2 + y2,
                                     @inferred JuMP.objective_function(sp, 2, 2, DecisionAffExpr{Float64}))
        @test_throws ErrorException JuMP.objective_function(sp)
    end
end

function test_DecisionAffExpr_objective(Structure)
    ξ₁ = @scenario a = 2. probability = 0.5
    ξ₂ = @scenario a = 4 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
        @objective(sp, Min, 2x)
    end
    @second_stage sp = begin
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y)
        @objective(sp, Min, a*y)
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
    @test JuMP.objective_function_type(sp, 1) == DecisionAffExpr{Float64}
    @test JuMP.isequal_canonical(JuMP.objective_function(sp, 1), 2x)
    @test JuMP.isequal_canonical(
        2x, @inferred JuMP.objective_function(sp, 1, DecisionAffExpr{Float64}))
    # Second-stage
    y1 = DecisionRef(sp[2,:y], 1)
    y2 = DecisionRef(sp[2,:y], 2)
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
    @test JuMP.objective_function_type(sp, 2, 1) == DecisionAffExpr{Float64}
    @test JuMP.objective_function_type(sp, 2, 2) == DecisionAffExpr{Float64}
    # Structure specific
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), 4y2)
        @test JuMP.isequal_canonical(
            2y1, @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test JuMP.isequal_canonical(
            4y2, @inferred JuMP.objective_function(sp, 2, 2, DecisionAffExpr{Float64}))
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 2x + y1 + 2y2)
        @test JuMP.isequal_canonical(2x + y1 + 2y2,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.StageDecompositionStructure
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), 4y2)
        @test JuMP.isequal_canonical(
            2y1, @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test JuMP.isequal_canonical(
            4y2, @inferred JuMP.objective_function(sp, 2, 2, DecisionAffExpr{Float64}))
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 2x)
        @test JuMP.isequal_canonical(2x,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.ScenarioDecompositionStructure
        x1 = DecisionRef(sp[1,:x], 2, 1)
        x2 = DecisionRef(sp[1,:x], 2, 2)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2x1 + 2y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), 2x2 + 4y2)
        @test JuMP.isequal_canonical(
            2x1 + 2y1, @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test JuMP.isequal_canonical(
            2x2 + 4y2, @inferred JuMP.objective_function(sp, 2, 2, DecisionAffExpr{Float64}))
        @test_throws ErrorException JuMP.objective_function(sp)
    end
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
        @objective(sp, Max, x + 3x + 1)
    end
    @second_stage sp = begin
        @known(sp, x)
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y)
        @objective(sp, Max, x + a*x + 1 + y + 3y + 1)
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 1)
    @test JuMP.objective_function_type(sp, 1) == DecisionAffExpr{Float64}
    @test JuMP.isequal_canonical(JuMP.objective_function(sp, 1), 4x + 1)
    @test JuMP.isequal_canonical(
        4x + 1, @inferred JuMP.objective_function(sp, 1, DecisionAffExpr{Float64}))
    # Second-stage
    y1 = DecisionRef(sp[2,:y], 1)
    y2 = DecisionRef(sp[2,:y], 2)
    @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
    @test JuMP.objective_function_type(sp, 2, 1) == DecisionAffExpr{Float64}
    @test JuMP.objective_function_type(sp, 2, 2) == DecisionAffExpr{Float64}
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        x = DecisionRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 3x + 4y1 + 2)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), 5x + 4y2 + 2)
        @test JuMP.isequal_canonical(
            3x + 4y1 + 2, @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test JuMP.isequal_canonical(
            5x + 4y2 + 2, @inferred JuMP.objective_function(sp, 2, 2, DecisionAffExpr{Float64}))
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 8x + 2y1 + 2y2 + 3)
        @test JuMP.isequal_canonical(8x + 2y1 + 2y2 + 3,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.StageDecompositionStructure
        x = DecisionRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 3x + 4y1 + 2)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), 5x + 4y2 + 2)
        @test JuMP.isequal_canonical(
            3x + 4y1 + 2, @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test JuMP.isequal_canonical(
            5x + 4y2 + 2, @inferred JuMP.objective_function(sp, 2, 2, DecisionAffExpr{Float64}))
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 4x + 1)
        @test JuMP.isequal_canonical(4x + 1,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.ScenarioDecompositionStructure
        x1 = DecisionRef(sp[1,:x], 2, 1)
        x2 = DecisionRef(sp[1,:x], 2, 2)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 7x1 + 4y1 + 3)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), 9x2 + 4y2 + 3)
        @test JuMP.isequal_canonical(
            7x1 + 4y1 + 3, @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test JuMP.isequal_canonical(
            9x2 + 4y2 + 3, @inferred JuMP.objective_function(sp, 2, 2, DecisionAffExpr{Float64}))
        @test_throws ErrorException JuMP.objective_function(sp)
    end
end

function test_DecisionQuadExpr_objective(Structure)
    ξ₁ = @scenario a = 2. probability = 0.5
    ξ₂ = @scenario a = 4 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
        @objective(sp, Min, x^2 + 2x)
    end
    @second_stage sp = begin
        @known(sp, x)
        @uncertain a
        @variable(sp, z)
        @recourse(sp, y)
        @objective(sp, Min, y^2 + a*y + x^2 + 2x)
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
    @test JuMP.objective_function_type(sp, 1) == DecisionQuadExpr{Float64}
    @test JuMP.isequal_canonical(JuMP.objective_function(sp, 1), x^2 + 2x)
    @test JuMP.isequal_canonical(
        x^2 + 2x, @inferred JuMP.objective_function(sp, 1, DecisionQuadExpr{Float64}))
    # Second-stage
    y1 = DecisionRef(sp[2,:y], 1)
    y2 = DecisionRef(sp[2,:y], 2)
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
    @test JuMP.objective_function_type(sp, 2, 1) == DecisionQuadExpr{Float64}
    # Structure specific
    x = DecisionRef(sp[1,:x])
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        x = DecisionRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), y1^2 + 2y1 + x^2 + 2x)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), y2^2 + 4y2 + x^2 + 2x)
        @test JuMP.isequal_canonical(
            y1^2 + 2y1 + x^2 + 2x, @inferred JuMP.objective_function(sp, 2, 1, DecisionQuadExpr{Float64}))
        @test JuMP.isequal_canonical(
            y2^2 + 4y2 + x^2 + 2x, @inferred JuMP.objective_function(sp, 2, 2, DecisionQuadExpr{Float64}))
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 2x^2 + 4x + 0.5*y1^2 + y1 + 0.5*y2^2 + 2y2)
        @test JuMP.isequal_canonical(2x^2 + 4x + 0.5*y1^2 + y1 + 0.5*y2^2 + 2y2,
                                     @inferred JuMP.objective_function(sp, DecisionQuadExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.StageDecompositionStructure
        x = DecisionRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), y1^2 + 2y1 + x^2 + 2x)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), y2^2 + 4y2 + x^2 + 2x)
        @test JuMP.isequal_canonical(
            y1^2 + 2y1 + x^2 + 2x, @inferred JuMP.objective_function(sp, 2, 1, DecisionQuadExpr{Float64}))
        @test JuMP.isequal_canonical(
            y2^2 + 4y2 + x^2 + 2x, @inferred JuMP.objective_function(sp, 2, 2, DecisionQuadExpr{Float64}))
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), x^2 + 2x)
        @test JuMP.isequal_canonical(x^2 + 2x,
                                     @inferred JuMP.objective_function(sp, DecisionQuadExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.ScenarioDecompositionStructure
        x1 = DecisionRef(sp[1,:x], 2, 1)
        x2 = DecisionRef(sp[1,:x], 2, 2)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2x1^2 + 4x1 + y1^2 + 2y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), 2x2^2 + 4x2 + y2^2 + 4y2)
        @test JuMP.isequal_canonical(
            2x1^2 + 4x1 + y1^2 + 2y1, @inferred JuMP.objective_function(sp, 2, 1, DecisionQuadExpr{Float64}))
        @test JuMP.isequal_canonical(
            2x2^2 + 4x2 + y2^2 + 4y2, @inferred JuMP.objective_function(sp, 2, 2, DecisionQuadExpr{Float64}))
        @test_throws ErrorException JuMP.objective_function(sp)
    end
end

function test_decision_objective_coefficient_modifiction(Structure)
    ξ₁ = @scenario a = 2. probability = 0.5
    ξ₂ = @scenario a = 4 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
        @objective(sp, Min, x)
    end
    @second_stage sp = begin
        @known(sp, x)
        @variable(sp, z)
        @recourse(sp, y)
        @objective(sp, Min, y)
    end
    # First-stage
    x = sp[1,:x]
    JuMP.set_objective_coefficient(sp, x, 1, 4.0)
    x = DecisionRef(x)
    @test JuMP.isequal_canonical(JuMP.objective_function(sp, 1), 4x)
    # Second-stage
    x = sp[1,:x]
    y = sp[2,:y]
    JuMP.set_objective_coefficient(sp, y, 2, 1, 4.0)
    JuMP.set_objective_coefficient(sp, y, 2, 2, 4.0)
    y1 = DecisionRef(y, 1)
    y2 = DecisionRef(y, 2)
    # Structure specific
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 4y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), 4y2)
        JuMP.set_objective_coefficient(sp, x, 2, 1, 2.0)
        JuMP.set_objective_coefficient(sp, x, 2, 2, 4.0)
        x = DecisionRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2x + 4y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), 4x + 4y2)
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 7x + 2y1 + 2y2)
        @test JuMP.isequal_canonical(7x + 2y1 + 2y2,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.StageDecompositionStructure
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 4y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), 4y2)
        JuMP.set_objective_coefficient(sp, x, 2, 1, 2.0)
        JuMP.set_objective_coefficient(sp, x, 2, 2, 4.0)
        x = DecisionRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2x + 4y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), 4x + 4y2)
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 4x)
        @test JuMP.isequal_canonical(4x,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.ScenarioDecompositionStructure
        x = DecisionRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 4x + 4y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), 4x + 4y2)
        @test JuMP.isequal_canonical(4x + 4y1,
                                     @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test JuMP.isequal_canonical(4x + 4y2,
                                     @inferred JuMP.objective_function(sp, 2, 2, DecisionAffExpr{Float64}))
        @test_throws ErrorException JuMP.objective_function(sp)
    end
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
        @objective(sp, Min, x^2 + x)
    end
    @second_stage sp = begin
        @known(sp, x)
        @variable(sp, z)
        @recourse(sp, y)
        @objective(sp, Min, x^2 + y^2 + y)
    end
    # First-stage
    x = sp[1,:x]
    JuMP.set_objective_coefficient(sp, x, 1, 4.0)
    x = DecisionRef(x)
    @test JuMP.isequal_canonical(JuMP.objective_function(sp, 1), x^2 + 4x)
    # Second-stage
    x = sp[1,:x]
    y = sp[2,:y]
    JuMP.set_objective_coefficient(sp, y, 2, 1, 4.0)
    JuMP.set_objective_coefficient(sp, y, 2, 2, 4.0)
    # Structure specific
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        x = DecisionRef(x, 2, 1)
        y1 = DecisionRef(y, 1)
        y2 = DecisionRef(y, 2)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x^2 + y1^2 + 4y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), x^2 + y2^2 + 4y2)
        x = sp[1,:x]
        JuMP.set_objective_coefficient(sp, x, 2, 1, 2.0)
        JuMP.set_objective_coefficient(sp, x, 2, 2, 4.0)
        x = DecisionRef(x, 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x^2 + y1^2 + 2x + 4y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), x^2 + y2^2 + 4x + 4y2)
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 2x^2 + 7x + 0.5*y1^2 + 2y1 + 0.5*y2^2 + 2y2)
        @test JuMP.isequal_canonical(2x^2 + 7x + 0.5*y1^2 + 2y1 + 0.5*y2^2 + 2y2,
                                     @inferred JuMP.objective_function(sp, DecisionQuadExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.StageDecompositionStructure
        x = DecisionRef(x, 2, 1)
        y1 = DecisionRef(y, 1)
        y2 = DecisionRef(y, 2)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x^2 + y1^2 + 4y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), x^2 + y2^2 + 4y2)
        x = sp[1,:x]
        JuMP.set_objective_coefficient(sp, x, 2, 1, 2.0)
        JuMP.set_objective_coefficient(sp, x, 2, 2, 4.0)
        x = DecisionRef(x, 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x^2 + y1^2 + 2x + 4y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), x^2 + y2^2 + 4x + 4y2)
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), x^2 + 4x)
        @test JuMP.isequal_canonical(x^2 + 4x,
                                     @inferred JuMP.objective_function(sp, DecisionQuadExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.ScenarioDecompositionStructure
        x = DecisionRef(x, 2, 1)
        y1 = DecisionRef(y, 1)
        y2 = DecisionRef(y, 2)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2x^2 + y1^2 + 4x + 4y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), 2x^2 + y2^2 + 4x + 4y2)
        @test JuMP.isequal_canonical(2x^2 + y1^2 + 4x + 4y1,
                                     @inferred JuMP.objective_function(sp, 2, 1, DecisionQuadExpr{Float64}))
        @test JuMP.isequal_canonical(2x^2 + y2^2 + 4x + 4y2,
                                     @inferred JuMP.objective_function(sp, 2, 2, DecisionQuadExpr{Float64}))
        x = sp[1,:x]
        JuMP.set_objective_coefficient(sp, x, 2, 1, 2.0)
        JuMP.set_objective_coefficient(sp, x, 2, 2, 4.0)
        x = DecisionRef(x, 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2x^2 + y1^2 + 2x + 4y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), 2x^2 + y2^2 + 4x + 4y2)
        @test JuMP.isequal_canonical(2x^2 + y1^2 + 2x + 4y1,
                                     @inferred JuMP.objective_function(sp, 2, 1, DecisionQuadExpr{Float64}))
        @test JuMP.isequal_canonical(2x^2 + y2^2 + 4x + 4y2,
                                     @inferred JuMP.objective_function(sp, 2, 2, DecisionQuadExpr{Float64}))
        @test_throws ErrorException JuMP.objective_function(sp)
    end
end

function test_decision_objective_sense_modification(Structure)
    ξ₁ = @scenario a = 2. probability = 0.5
    ξ₂ = @scenario a = 4 probability = 0.5
    sp = StochasticProgram([ξ₁,ξ₂], Structure...)
    @first_stage sp = begin
        @decision(sp, x)
        @variable(sp, w)
        @objective(sp, Min, x)
    end
    @second_stage sp = begin
        @variable(sp, z)
        @recourse(sp, y)
        @objective(sp, Min, y)
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
    # Second-stage
    y1 = DecisionRef(sp[2,:y], 1)
    y2 = DecisionRef(sp[2,:y], 2)
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 2)
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 2, 2)
    # Structure specific
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        @test JuMP.isequal_canonical(x + 0.5*y1 + 0.5*y2, JuMP.objective_function(sp))
        set_objective_sense(sp, 2, MOI.MAX_SENSE)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 2)
        @test JuMP.isequal_canonical(x - 0.5*y1 - 0.5*y2, JuMP.objective_function(sp))
        set_objective_sense(sp, 1, MOI.MAX_SENSE)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 2)
        @test JuMP.isequal_canonical(x + 0.5*y1 + 0.5*y2, JuMP.objective_function(sp))
        set_objective_sense(sp, MOI.MIN_SENSE)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 2)
        @test JuMP.isequal_canonical(x - 0.5*y1 - 0.5*y2, JuMP.objective_function(sp))
        set_objective_sense(sp, 2, 1, MOI.MIN_SENSE)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 2)
        @test JuMP.isequal_canonical(x + 0.5*y1 - 0.5*y2, JuMP.objective_function(sp))
    end
    if sp.structure isa StochasticPrograms.StageDecompositionStructure
        @test JuMP.objective_function(sp) == x
        @test JuMP.objective_function(sp, 1) == x
        @test JuMP.objective_function(sp, 2, 1) == y1
        @test JuMP.objective_function(sp, 2, 2) == y2
        set_objective_sense(sp, 2, MOI.MAX_SENSE)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 2)
        @test JuMP.objective_function(sp) == x
        @test JuMP.objective_function(sp, 2, 1) == y1
        @test JuMP.objective_function(sp, 2, 2) == y2
        set_objective_sense(sp, 1, MOI.MAX_SENSE)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 2)
        @test JuMP.objective_function(sp) == x
        @test JuMP.objective_function(sp, 2, 1) == y1
        @test JuMP.objective_function(sp, 2, 2) == y2
        set_objective_sense(sp, MOI.MIN_SENSE)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 2)
        @test JuMP.objective_function(sp) == x
        @test JuMP.objective_function(sp, 2, 1) == y1
        @test JuMP.objective_function(sp, 2, 2) == y2
        set_objective_sense(sp, 2, 1, MOI.MIN_SENSE)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 2)
        @test JuMP.objective_function(sp) == x
        @test JuMP.objective_function(sp, 2, 1) == y1
        @test JuMP.objective_function(sp, 2, 2) == y2
    end
    if sp.structure isa StochasticPrograms.ScenarioDecompositionStructure
        x1 = DecisionRef(sp[1,:x], 2, 1)
        x2 = DecisionRef(sp[1,:x], 2, 2)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x1 + y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), x2 + y2)
        set_objective_sense(sp, 2, MOI.MAX_SENSE)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 2)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x1 - y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), x2 - y2)
        set_objective_sense(sp, 1, MOI.MAX_SENSE)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 2)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x1 + y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), x2 + y2)
        set_objective_sense(sp, MOI.MIN_SENSE)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 2)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x1 - y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), x2 - y2)
        set_objective_sense(sp, 2, 1, MOI.MIN_SENSE)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2)
        @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
        @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 2)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x1 + y1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 2), x2 - y2)
    end
end

function runtests()
    @testset "DecisionObjective" begin
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
    @testset "DecisionObjective" begin
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
