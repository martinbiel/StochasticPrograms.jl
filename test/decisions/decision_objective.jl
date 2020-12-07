@everywhere module TestDecisionObjective

using StochasticPrograms
using Test

function test_SingleDecision_objective(Structure)
    sp = StochasticProgram([Scenario()], Structure...)
    @first_stage sp = begin
        @decision(model, x)
        @objective(model, Min, x)
    end
    @second_stage sp = begin
        @recourse(model, y)
        @objective(model, Min, y)
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
    @test JuMP.objective_function_type(sp, 1) == DecisionRef
    @test JuMP.objective_function(sp, 1) == x
    @test x == @inferred JuMP.objective_function(sp, 1, DecisionRef)
    # Second-stage
    y = DecisionRef(sp[2,:y], 1)
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
    # Structure specific
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        @test JuMP.objective_function_type(sp, 2, 1) == DecisionRef
        @test JuMP.objective_function(sp, 2, 1) == y
        @test y == @inferred JuMP.objective_function(sp, 2, 1, DecisionRef)
        @test JuMP.isequal_canonical(x + y, JuMP.objective_function(sp))
        @test JuMP.isequal_canonical(x + y,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.VerticalStructure
        @test JuMP.objective_function_type(sp, 2, 1) == DecisionRef
        @test JuMP.objective_function(sp, 2, 1) == y
        @test y == @inferred JuMP.objective_function(sp, 2, 1, DecisionRef)
        @test JuMP.objective_function(sp) == x
        @test x == @inferred JuMP.objective_function(sp, DecisionRef)
    end
    if sp.structure isa StochasticPrograms.HorizontalStructure
        x = KnownRef(sp[1,:x], 2, 1)
        @test JuMP.objective_function_type(sp, 2, 1) == DecisionAffExpr{Float64}
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x + y)
        @test JuMP.isequal_canonical(x + y,
                                     @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test_throws ErrorException JuMP.objective_function(sp)
    end
    @first_stage sp = begin
        @decision(model, x)
        @objective(model, Max, x)
    end
    @second_stage sp = begin
        @recourse(model, y)
        @objective(model, Max, y)
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 1)
    @test JuMP.objective_function_type(sp, 1) == DecisionRef
    @test JuMP.objective_function(sp, 1) == x
    @test x == @inferred JuMP.objective_function(sp, 1, DecisionRef)
    # Second-stage
    y = DecisionRef(sp[2,:y], 1)
    @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
    # Structure specific
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        @test JuMP.objective_function_type(sp, 2, 1) == DecisionRef
        @test JuMP.objective_function(sp, 2, 1) == y
        @test y == @inferred JuMP.objective_function(sp, 2, 1, DecisionRef)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), x + y)
        @test JuMP.isequal_canonical(x + y,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.VerticalStructure
        @test JuMP.objective_function_type(sp, 2, 1) == DecisionRef
        @test JuMP.objective_function(sp, 2, 1) == y
        @test y == @inferred JuMP.objective_function(sp, 2, 1, DecisionRef)
        @test JuMP.objective_function(sp) == x
        @test x == @inferred JuMP.objective_function(sp, DecisionRef)
    end
    if sp.structure isa StochasticPrograms.HorizontalStructure
        x = KnownRef(sp[1,:x], 2, 1)
        @test JuMP.objective_function_type(sp, 2, 1) == DecisionAffExpr{Float64}
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x + y)
        @test JuMP.isequal_canonical(x + y, @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test_throws ErrorException JuMP.objective_function(sp)
    end
end

function test_DecisionAffExpr_objective(Structure)
    sp = StochasticProgram([Scenario()], Structure...)
    @first_stage sp = begin
        @decision(model, x)
        @objective(model, Min, 2x)
    end
    @second_stage sp = begin
        @recourse(model, y)
        @objective(model, Min, 2y)
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
    @test JuMP.objective_function_type(sp, 1) == DecisionAffExpr{Float64}
    @test JuMP.isequal_canonical(JuMP.objective_function(sp, 1), 2x)
    @test JuMP.isequal_canonical(
        2x, @inferred JuMP.objective_function(sp, 1, DecisionAffExpr{Float64}))
    # Second-stage
    y = DecisionRef(sp[2,:y], 1)
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
    @test JuMP.objective_function_type(sp, 2, 1) == DecisionAffExpr{Float64}
    # Structure specific
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2y)
        @test JuMP.isequal_canonical(
            2y, @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 2x + 2y)
        @test JuMP.isequal_canonical(2x + 2y,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.VerticalStructure
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2y)
        @test JuMP.isequal_canonical(
            2y, @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 2x)
        @test JuMP.isequal_canonical(2x,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.HorizontalStructure
        x = KnownRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2x + 2y)
        @test JuMP.isequal_canonical(
            2x + 2y, @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test_throws ErrorException JuMP.objective_function(sp)
    end
    @first_stage sp = begin
        @decision(model, x)
        @objective(model, Max, x + 3x + 1)
    end
    @second_stage sp = begin
        @known x
        @recourse(model, y)
        @objective(model, Max, x + 3x + 1 + y + 3y + 1)
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 1)
    @test JuMP.objective_function_type(sp, 1) == DecisionAffExpr{Float64}
    @test JuMP.isequal_canonical(JuMP.objective_function(sp, 1), 4x + 1)
    @test JuMP.isequal_canonical(
        4x + 1, @inferred JuMP.objective_function(sp, 1, DecisionAffExpr{Float64}))
    # Second-stage
    y = DecisionRef(sp[2,:y], 1)
    @test MOI.MAX_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
    @test JuMP.objective_function_type(sp, 2, 1) == DecisionAffExpr{Float64}
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        x = KnownRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 4x + 4y + 2)
        @test JuMP.isequal_canonical(
            4x + 4y + 2, @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 8x + 4y + 3)
        @test JuMP.isequal_canonical(8x + 4y + 3,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.VerticalStructure
        x = KnownRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 4x + 4y + 2)
        @test JuMP.isequal_canonical(
            4x + 4y + 2, @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 4x + 1)
        @test JuMP.isequal_canonical(4x + 1,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.HorizontalStructure
        x = KnownRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 8x + 4y + 3)
        @test JuMP.isequal_canonical(
            8x + 4y + 3, @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test_throws ErrorException JuMP.objective_function(sp)
    end
end

function test_DecisionQuadExpr_objective(Structure)
    sp = StochasticProgram([Scenario()], Structure...)
    @first_stage sp = begin
        @decision(model, x)
        @objective(model, Min, x^2 + 2x)
    end
    @second_stage sp = begin
        @known x
        @recourse(model, y)
        @objective(model, Min, y^2 + 2y + x^2 + 2x)
    end
    # First-stage
    x = DecisionRef(sp[1,:x])
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 1)
    @test JuMP.objective_function_type(sp, 1) == DecisionQuadExpr{Float64}
    @test JuMP.isequal_canonical(JuMP.objective_function(sp, 1), x^2 + 2x)
    @test JuMP.isequal_canonical(
        x^2 + 2x, @inferred JuMP.objective_function(sp, 1, DecisionQuadExpr{Float64}))
    # Second-stage
    y = DecisionRef(sp[2,:y], 1)
    @test MOI.MIN_SENSE == @inferred JuMP.objective_sense(sp, 2, 1)
    @test JuMP.objective_function_type(sp, 2, 1) == DecisionQuadExpr{Float64}
    # Structure specific
    x = DecisionRef(sp[1,:x])
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        x = KnownRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), y^2 + 2y + x^2 + 2x)
        @test JuMP.isequal_canonical(
            y^2 + 2y + x^2 + 2x, @inferred JuMP.objective_function(sp, 2, 1, DecisionQuadExpr{Float64}))
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 2x^2 + 4x + y^2 + 2y)
        @test JuMP.isequal_canonical(2x^2 + 4x + y^2 + 2y,
                                     @inferred JuMP.objective_function(sp, DecisionQuadExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.VerticalStructure
        x = KnownRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), y^2 + 2y + x^2 + 2x)
        @test JuMP.isequal_canonical(
            y^2 + 2y + x^2 + 2x, @inferred JuMP.objective_function(sp, 2, 1, DecisionQuadExpr{Float64}))
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), x^2 + 2x)
        @test JuMP.isequal_canonical(x^2 + 2x,
                                     @inferred JuMP.objective_function(sp, DecisionQuadExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.HorizontalStructure
        x = KnownRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2x^2 + 4x + y^2 + 2y)
        @test JuMP.isequal_canonical(
            2x^2 + 4x + y^2 + 2y, @inferred JuMP.objective_function(sp, 2, 1, DecisionQuadExpr{Float64}))
        @test_throws ErrorException JuMP.objective_function(sp)
    end
end

function test_decision_objective_coefficient_modifiction(Structure)
    sp = StochasticProgram([Scenario()], Structure...)
    @first_stage sp = begin
        @decision(model, x)
        @objective(model, Min, x)
    end
    @second_stage sp = begin
        @known x
        @recourse(model, y)
        @objective(model, Min, y)
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
    y = DecisionRef(y, 1)
    # Structure specific
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 4y)
        JuMP.set_objective_coefficient(sp, x, 2, 1, 2.0)
        x = KnownRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2x + 4y)
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 6x + 4y)
        @test JuMP.isequal_canonical(6x + 4y,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.VerticalStructure
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 4y)
        JuMP.set_objective_coefficient(sp, x, 2, 1, 2.0)
        x = KnownRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2x + 4y)
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 4x)
        @test JuMP.isequal_canonical(4x,
                                     @inferred JuMP.objective_function(sp, DecisionAffExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.HorizontalStructure
        x = KnownRef(sp[1,:x], 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 4x + 4y)
        @test JuMP.isequal_canonical(4x + 4y,
                                     @inferred JuMP.objective_function(sp, 2, 1, DecisionAffExpr{Float64}))
        @test_throws ErrorException JuMP.objective_function(sp)
    end
    @first_stage sp = begin
        @decision(model, x)
        @objective(model, Min, x^2 + x)
    end
    @second_stage sp = begin
        @known x
        @recourse(model, y)
        @objective(model, Min, x^2 + y^2 + y)
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
    # Structure specific
    if sp.structure isa StochasticPrograms.DeterministicEquivalent
        x = KnownRef(x, 2, 1)
        y = DecisionRef(y, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x^2 + y^2 + 4y)
        x = sp[1,:x]
        JuMP.set_objective_coefficient(sp, x, 2, 1, 2.0)
        x = KnownRef(x, 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x^2 + y^2 + 2x + 4y)
        # Structure specific
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), 2x^2 + 6x + y^2 + 4y)
        @test JuMP.isequal_canonical(2x^2 + 6x + y^2 + 4y,
                                     @inferred JuMP.objective_function(sp, DecisionQuadExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.VerticalStructure
        x = KnownRef(x, 2, 1)
        y = DecisionRef(y, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x^2 + y^2 + 4y)
        x = sp[1,:x]
        JuMP.set_objective_coefficient(sp, x, 2, 1, 2.0)
        x = KnownRef(x, 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), x^2 + y^2 + 2x + 4y)
        # Structure specific
        x = DecisionRef(sp[1,:x])
        @test JuMP.isequal_canonical(JuMP.objective_function(sp), x^2 + 4x)
        @test JuMP.isequal_canonical(x^2 + 4x,
                                     @inferred JuMP.objective_function(sp, DecisionQuadExpr{Float64}))
    end
    if sp.structure isa StochasticPrograms.HorizontalStructure
        x = KnownRef(x, 2, 1)
        y = DecisionRef(y, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2x^2 + y^2 + 4x + 4y)
        @test JuMP.isequal_canonical(2x^2 + y^2 + 4x + 4y,
                                     @inferred JuMP.objective_function(sp, 2, 1, DecisionQuadExpr{Float64}))
        x = sp[1,:x]
        JuMP.set_objective_coefficient(sp, x, 2, 1, 2.0)
        x = KnownRef(x, 2, 1)
        @test JuMP.isequal_canonical(JuMP.objective_function(sp, 2, 1), 2x^2 + y^2 + 2x + 4y)
        @test JuMP.isequal_canonical(2x^2 + y^2 + 2x + 4y,
                                     @inferred JuMP.objective_function(sp, 2, 1, DecisionQuadExpr{Float64}))
        # Structure specific
        x = DecisionRef(sp[1,:x])
        @test_throws ErrorException JuMP.objective_function(sp)
    end
end

function runtests()
    @testset "DecisionObjective" begin
        for structure in [(Deterministic(),),
                          (Vertical(),),
                          (Horizontal(),),
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
        for structure in [(DistributedVertical(),), (DistributedHorizontal(),)]
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
