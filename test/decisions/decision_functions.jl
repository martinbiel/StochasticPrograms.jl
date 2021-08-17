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

@everywhere module TestDecisionFunctions

using StochasticPrograms
using Test
using MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities
const MA = MOI.MutableArithmetics

function test_vectorization(x, fx, y, fy, z, fz, w, fw)
    g = VectorAffineDecisionFunction(
        MOI.VectorAffineFunction(
            MOI.VectorAffineTerm.([3, 1], MOI.ScalarAffineTerm.([5, 2], [z, w])),
            [3, 1, 4],
        ),
        MOI.VectorAffineFunction(
            MOI.VectorAffineTerm.([3, 1], MOI.ScalarAffineTerm.([3, 6], [x, y])),
            zeros(Int, 3),
        ),
    )
    @testset "vectorize" begin
        g1 = AffineDecisionFunction(
            MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(2, w)], 3),
            MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(6, y)], 0),
        )
        g2 = AffineDecisionFunction(
            MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Int}[], 1),
            MOI.ScalarAffineFunction(MOI.ScalarAffineTerm{Int}[], 0),
        )
        g3 = AffineDecisionFunction(
            MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(5, z)], 4),
            MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(3, x)], 0),
        )
        @test g ≈ MOIU.vectorize([g1, g2, g3])
        vov = MOIU.vectorize(SingleDecision[])
        @test MOI.output_dimension(vov) == 0
        @test vov isa VectorOfDecisions
        aff = MOIU.vectorize(AffineDecisionFunction{Int}[])
        @test MOI.output_dimension(aff) == 0
        @test aff isa VectorAffineDecisionFunction{Int}
        # TODO
        # quad = MOIU.vectorize(QuadraticDecisionFunction{Int}[])
        # @test MOI.output_dimension(quad) == 0
        # @test quad isa VectorQuadraticDecisionFunction{Int}
    end
    @testset "operate vcat" begin
        d = VectorOfDecisions([x, y])
        @testset "Decision with $T" for T in [Int, Float64]
            @test VectorOfDecisions == MOIU.promote_operation(
                vcat,
                T,
                typeof(fx),
                typeof(d),
                typeof(fy),
            )
            vod = MOIU.operate(vcat, T, fx, d, fy)
            @test vod.decisions == [x, x, y, y]
            @test VectorOfDecisions == MOIU.promote_operation(
                vcat,
                T,
                typeof(d),
                typeof(fx),
                typeof(fy),
            )
            vod = MOIU.operate(vcat, T, d, fx, fy)
            @test vod.decisions == [x, y, x, y]
            @test VectorOfDecisions == MOIU.promote_operation(
                vcat,
                T,
                typeof(fx),
                typeof(fy),
                typeof(d),
            )
            vod = MOIU.operate(vcat, T, fx, fy, d)
            @test vod.decisions == [x, y, x, y]
        end
        v = MOI.VectorOfVariables([z, w])
        f = AffineDecisionFunction(
            MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([2, 4], [z, w]), 5),
            MOI.ScalarAffineFunction(MOI.ScalarAffineTerm.([5, 3], [x, y]), 0),
        )
        g = VectorAffineDecisionFunction(
            MOI.VectorAffineFunction(
                MOI.VectorAffineTerm.(
                    [3, 1],
                    MOI.ScalarAffineTerm.([5, 2], [z, w]),
                ),
                [3, 1, 4],
            ),
            MOI.VectorAffineFunction(
                MOI.VectorAffineTerm.(
                    [3, 1],
                    MOI.ScalarAffineTerm.([3, 6], [x, y]),
                ),
                zeros(Int, 3),
            ),
        )
        @testset "Affine" begin
            @test MOIU.promote_operation(
                vcat,
                Int,
                typeof(fx),
                typeof(f),
                typeof(d),
                typeof(fz),
                typeof(v),
                Int,
                typeof(g),
                typeof(fy),
                Int,
                typeof(fw),
            ) == VectorAffineDecisionFunction{Int}
            F = MOIU.operate(vcat, Int, fx, f, d, fz, v, 3, g, fy, -4, fw)
            expected_variable_terms =
                MOI.VectorAffineTerm.(
                    [2, 2, 5, 6, 7, 11, 9, 14],
                    MOI.ScalarAffineTerm.(
                        [2, 4, 1, 1, 1, 5, 2, 1],
                        [z, w, z, z, w, z, w, w],
                    ),
                )
            expected_decision_terms =
                MOI.VectorAffineTerm.(
                    [1, 2, 2, 3, 4, 11, 9, 12],
                    MOI.ScalarAffineTerm.(
                        [1, 5, 3, 1, 1, 3, 6, 1],
                        [x, x, y, x, y, x, y, y],
                    ),
                )
            expected_constants = [0, 5, 0, 0, 0, 0, 0, 3, 3, 1, 4, 0, -4, 0]
            @test F.variable_part.terms == expected_variable_terms
            @test F.decision_part.terms == expected_decision_terms
            @test F.variable_part.constants == expected_constants
        end
    end
end

function test_eval_variables(x, fx, y, fy, z, fz, w, fw)
    vals = Dict(x => 3, y => 1, z => 5, w => 1)
    @test MOI.output_dimension(fx) == 1
    @test MOIU.eval_variables(vi -> vals[vi], fx) ≈ 3
    @test MOIU.eval_variables(vi -> vals[vi], fx) ≈ 3
    fxy = VectorOfDecisions([x, y])
    @test MOI.output_dimension(fxy) == 2
    @test MOIU.eval_variables(vi -> vals[vi], fxy) ≈ [3, 1]
    @test MOIU.eval_variables(vi -> vals[vi], fxy) ≈ [3, 1]
    f = AffineDecisionFunction(
        MOI.ScalarAffineFunction(
            [
                MOI.ScalarAffineTerm(3.0, z),
                MOI.ScalarAffineTerm(2.0, w),
            ],
            2.0,
        ),
        MOI.ScalarAffineFunction(
            [
                MOI.ScalarAffineTerm(1.0, x),
                MOI.ScalarAffineTerm(2.0, y),
            ],
            0.0,
        ),
    )
    @test MOI.output_dimension(f) == 1
    @test MOIU.eval_variables(vi -> vals[vi], f) ≈ 24
    @test MOIU.eval_variables(vi -> vals[vi], f) ≈ 24
    f = VectorAffineDecisionFunction(
        MOI.VectorAffineFunction(
            MOI.VectorAffineTerm.(
                [2, 2],
                MOI.ScalarAffineTerm.([1.0, 2.0], [z, w]),
            ),
            [-3.0, 2.0],
        ),
        MOI.VectorAffineFunction(
            MOI.VectorAffineTerm.(
                [1, 2],
                MOI.ScalarAffineTerm.([3.0, 2.0], [x, y]),
            ),
            zeros(Float64, 2),
        ),
    )
    @test MOI.output_dimension(f) == 2
    @test MOIU.eval_variables(vi -> vals[vi], f) ≈ [6, 11]
    @test MOIU.eval_variables(vi -> vals[vi], f) ≈ [6, 11]
    f = QuadraticDecisionFunction(
        MOI.ScalarQuadraticFunction(
            MOI.ScalarAffineTerm.(1.0, [z, w]),
            MOI.ScalarQuadraticTerm.(1.0, [z, w], [z, w]),
            -12.0,
        ),
        MOI.ScalarQuadraticFunction(
            MOI.ScalarAffineTerm.(1.0, [x, y]),
            MOI.ScalarQuadraticTerm.(1.0, [x, x, y], [x, y, y]),
            0.0,
        ),
        MOI.ScalarQuadraticFunction(
            MOI.ScalarAffineTerm{Float64}[],
            MOI.ScalarQuadraticTerm.(1.0, [z, w], [x, y]),
            0.0,
        ),
    )
    @test MOI.output_dimension(f) == 1
    @test MOIU.eval_variables(vi -> vals[vi], f) ≈ 35
    @test MOIU.eval_variables(vi -> vals[vi], f) ≈ 35
    # TODO
    # f = VectorQuadraticDecisionFunction(
    #     MOI.VectorQuadraticFunction(
    #         MOI.VectorAffineTerm.([2, 1], MOI.ScalarAffineTerm.(1.0, [x, y])),
    #         MOI.VectorQuadraticTerm.(
    #             [1, 2, 2],
    #             MOI.ScalarQuadraticTerm.(1.0, [x, w, w], [z, z, y]),
    #         ),
    #         [-3.0, -2.0],
    #     ),
    #     MOI.VectorQuadraticFunction(
    #         MOI.VectorAffineTerm.([2, 1], MOI.ScalarAffineTerm.(1.0, [x, y])),
    #         MOI.VectorQuadraticTerm.(
    #             [1, 2, 2],
    #             MOI.ScalarQuadraticTerm.(1.0, [x, w, w], [z, z, y]),
    #         ),
    #         [-3.0, -2.0],
    #     ),
    #     MOI.VectorQuadraticFunction(
    #         MOI.VectorAffineTerm.([2, 1], MOI.ScalarAffineTerm.(1.0, [x, y])),
    #         MOI.VectorQuadraticTerm.(
    #             [1, 2, 2],
    #             MOI.ScalarQuadraticTerm.(1.0, [x, w, w], [z, z, y]),
    #         ),
    #         [-3.0, -2.0],
    #     ),
    # )
    # @test MOI.output_dimension(fvq) == 2
    # @test MOIU.eval_variables(vi -> vals[vi], fvq) ≈ [13, 1]
    # @test MOIU.eval_variables(vi -> vals[vi], fvq) ≈ [13, 1]
end

function test_substitute_variables(x, fx, y, fy, z, fz, w, fw)
    # We do tests twice to make sure the function is not modified
    subs = Dict(x => 2.0fy + 1.0, y => 1.0fy, z => -1.0fw, w => 1.0fy + 1.0fz)
    vals = Dict(x => 3.0, y => 1.0, z => 5.0, w => 0.0)
    subs_vals = Dict(x => 3.0, y => 1.0, z => 0.0, w => 6.0)
    # Affine
    f = fx + 2.0fy + 3.0fz + 2.0
    f_subbed = -3.0fw + 4.0fy + 3.0
    @test MOIU.eval_variables(vi -> subs_vals[vi], f) ==
        MOIU.eval_variables(vi -> vals[vi], f_subbed)
    @test MOIU.substitute_variables(vi -> subs[vi], f) ≈ f_subbed
    @test MOIU.substitute_variables(vi -> subs[vi], f) ≈ f_subbed
    # VectorAffine
    f = MOIU.operate(vcat, Float64, 3.0fz - 3.0, fx + 2.0fy + 2.0)
    f_subbed = MOIU.operate(vcat, Float64, -3.0fw - 3.0, 4.0fy + 3.0)
    @test MOIU.eval_variables(vi -> subs_vals[vi], f) ==
        MOIU.eval_variables(vi -> vals[vi], f_subbed)
    @test MOIU.substitute_variables(vi -> subs[vi], f) ≈ f_subbed
    @test MOIU.substitute_variables(vi -> subs[vi], f) ≈ f_subbed
    # Quadratic
    f = 1.0fx + 1.0fy + 1.0fx * fz + 1.0fw * fz + 1.0fw * fy + 2.0fw * fw - 3.0
    f_subbed =
        3.0fy - 1.0fw + 3.0fy * fy + 2.0fz * fz - 3.0fy * fw - 1.0fz * fw +
        5.0fy * fz - 2.0
    @test MOIU.eval_variables(vi -> subs_vals[vi], f) ==
        MOIU.eval_variables(vi -> vals[vi], f_subbed)
    @test MOIU.substitute_variables(vi -> subs[vi], f) ≈ f_subbed
    @test MOIU.substitute_variables(vi -> subs[vi], f) ≈ f_subbed
    # TODO
    # f = MOIU.operate(
    #     vcat,
    #     Float64,
    #     1.0fy + 1.0fx * fz - 3.0,
    #     1.0fx + 1.0fw * fz + 1.0fw * fy - 2.0,
    # )
    # f_subbed = MOIU.operate(
    #     vcat,
    #     Float64,
    #     1.0fy - fw - 2.0fy * fw - 3.0,
    #     2.0fy + 1.0fy * fy - 1.0fw * fy - 1.0fw * fz + 1.0fy * fz - 1.0,
    # )
    # @test MOIU.eval_variables(vi -> subs_vals[vi], f) ==
    #       MOIU.eval_variables(vi -> vals[vi], f_subbed)
    # @test MOIU.substitute_variables(vi -> subs[vi], f) ≈ f_subbed
    # @test MOIU.substitute_variables(vi -> subs[vi], f) ≈ f_subbed
end

function test_map_indices(x, fx, y, fy, z, fz, w, fw)
    f = QuadraticDecisionFunction(
        MOI.ScalarQuadraticFunction(
            MOI.ScalarAffineTerm.(1.0, [z, w]),
            MOI.ScalarQuadraticTerm.(1.0, [z, w], [z, w]),
            -12.0,
        ),
        MOI.ScalarQuadraticFunction(
            MOI.ScalarAffineTerm.(1.0, [x, y]),
            MOI.ScalarQuadraticTerm.(1.0, [x, x, y], [x, y, y]),
            0.0,
        ),
        MOI.ScalarQuadraticFunction(
            MOI.ScalarAffineTerm{Float64}[],
            MOI.ScalarQuadraticTerm.(1.0, [z, w], [x, y]),
            0.0,
        ),
    )
    index_map = Dict(x => y, y => x, w => w, z => w)
    g = MOIU.map_indices(index_map, f)
    @test g.variable_part.affine_terms ==
        MOI.ScalarAffineTerm.(1.0, [w, w])
    @test g.variable_part.quadratic_terms ==
        MOI.ScalarQuadraticTerm.(1.0, [w, w], [w, w])
    @test g.decision_part.affine_terms ==
        MOI.ScalarAffineTerm.(1.0, [y, x])
    @test g.decision_part.quadratic_terms ==
        MOI.ScalarQuadraticTerm.(1.0, [y, y, x], [y, x, x])
    @test isempty(g.cross_terms.affine_terms)
    @test g.cross_terms.quadratic_terms ==
        MOI.ScalarQuadraticTerm.(1.0, [w, w], [y, x])
    @test MOI.constant(g) == -12.0
end

function test_VectorOfDecisions_iteration(x, fx, y, fy, z, fz, w, fw)
    f = VectorOfDecisions([x, y, x])
    it = MOIU.eachscalar(f)
    @test length(it) == 3
    @test eltype(it) == SingleDecision
    @test collect(it) == [
        SingleDecision(x),
        SingleDecision(y),
        SingleDecision(x),
    ]
    @test it[2] == SingleDecision(y)
    @test it[end] == SingleDecision(x)
end

function test_VectorAffineDecisionFunction_iteration(x, fx, y, fy, z, fz, w, fw)
    f = VectorAffineDecisionFunction(
        MOI.VectorAffineFunction(
            MOI.VectorAffineTerm.(
                [3, 2, 1],
                MOI.ScalarAffineTerm.(
                    [2, 9, 1],
                    [z, z, w],
                ),
            ),
            [2, 7, 5],
        ),
        MOI.VectorAffineFunction(
            MOI.VectorAffineTerm.(
                [2, 2, 2, 3, 1, 2],
                MOI.ScalarAffineTerm.(
                    [1, 7, 3, 6, 4, 1],
                    [x, y, y, x, x, y],
                ),
            ),
            zeros(Int, 3),
        ),
    )
    it = MOIU.eachscalar(f)
    @test length(it) == 3
    @test eltype(it) == AffineDecisionFunction{Int}
    g = it[2]
    @test g isa AffineDecisionFunction{Int}
    @test g.variable_part.terms ==
        MOI.ScalarAffineTerm.([9], [z])
    @test g.decision_part.terms ==
        MOI.ScalarAffineTerm.([1, 7, 3, 1], [x, y, y, y])
    @test MOI.constant(g) == 7
    g = it[1]
    @test g isa AffineDecisionFunction{Int}
    @test g.variable_part.terms ==
        MOI.ScalarAffineTerm.([1], [w])
    @test g.decision_part.terms ==
        MOI.ScalarAffineTerm.([4], [x])
    @test MOI.constant(g) == 2
    g = it[end]
    @test g isa AffineDecisionFunction{Int}
    @test g.variable_part.terms ==
        MOI.ScalarAffineTerm.([2], [z])
    @test g.decision_part.terms ==
        MOI.ScalarAffineTerm.([6], [x])
    @test MOI.constant(g) == 5
    h = it[[2, 1]]
    @test h isa VectorAffineDecisionFunction{Int}
    @test sort(h.variable_part.terms, by = t -> t.output_index) ==
        MOI.VectorAffineTerm.(
            [1, 2],
            MOI.ScalarAffineTerm.([9, 1], [z, w]),
        )
    @test sort(h.decision_part.terms, by = t -> t.output_index) ==
        MOI.VectorAffineTerm.(
            [1, 1, 1, 1, 2],
            MOI.ScalarAffineTerm.([1, 7, 3, 1, 4], [x, y, y, y, x]),
        )
    @test MOIU.constant_vector(h) == [7, 2]
    F = MOIU.operate(vcat, Int, it[[1, 2]], it[3])
    @test F isa VectorAffineDecisionFunction{Int}
    @test sort(F.variable_part.terms, by = t -> t.output_index) ==
        MOI.VectorAffineTerm.(
            [1, 2, 3],
            MOI.ScalarAffineTerm.(
                [1, 9, 2],
                [w, z, z],
            ),
        )
    @test sort(F.decision_part.terms, by = t -> t.output_index) ==
        MOI.VectorAffineTerm.(
            [1, 2, 2, 2, 2, 3],
            MOI.ScalarAffineTerm.(
                [4, 1, 7, 3, 1, 6],
                [x, x, y, y, y, x],
            ),
        )
    @test MOIU.constant_vector(F) == MOIU.constant_vector(f)
end

function test_scalar_operations(x, fx, y, fy, z, fz, w, fw)
    @testset "Decision" begin
        f = SingleDecision(MOI.VariableIndex(0))
        g = SingleDecision(MOI.VariableIndex(1))
        @testset "one" begin
            @test !isone(f)
            @test !isone(g)
        end
        @testset "zero" begin
            @test !iszero(f)
            @test !iszero(g)
            @test f + 1 ≈ 1 + f
            @test (f + 1.0) - 1.0 ≈ (2.0f) / 2.0
            @test (f - 1.0) + 1.0 ≈ (2.0f) / 2.0
            @test (1.0 + f) - 1.0 ≈ (f * 2.0) / 2.0
            @test 1.0 - (1.0 - f) ≈ (f / 2.0) * 2.0
        end
    end
    @testset "Affine" begin
        @testset "zero" begin
            f = @inferred MOIU.zero(AffineDecisionFunction{Float64})
            @test iszero(f)
            @test MOIU.isapprox_zero(f, 1e-16)
        end
        @testset "promote_operation" begin
            @test MOIU.promote_operation(-, Int, SingleDecision) ==
                AffineDecisionFunction{Int}
            @test MOIU.promote_operation(
                -,
                Int,
                AffineDecisionFunction{Int},
            ) == AffineDecisionFunction{Int}
            @test MOIU.promote_operation(
                +,
                Float64,
                SingleDecision,
                SingleDecision,
            ) == AffineDecisionFunction{Float64}
            @test MOIU.promote_operation(
                +,
                Float64,
                MOI.SingleVariable,
                SingleDecision,
            ) == AffineDecisionFunction{Float64}
            @test MOIU.promote_operation(
                +,
                Float64,
                SingleDecision,
                MOI.SingleVariable,
            ) == AffineDecisionFunction{Float64}
            @test MOIU.promote_operation(
                +,
                Float64,
                AffineDecisionFunction{Float64},
                Float64,
            ) == AffineDecisionFunction{Float64}
            @test MOIU.promote_operation(
                +,
                Int,
                AffineDecisionFunction{Int},
                AffineDecisionFunction{Int},
            ) == AffineDecisionFunction{Int}
        end
        @testset "Comparison" begin
            @test MOIU.operate(
                +,
                Float64,
                SingleDecision(x),
                SingleDecision(y),
            ) + 1.0 ≈ AffineDecisionFunction(
                MOI.ScalarAffineFunction(
                    MOI.ScalarAffineTerm{Float64}[],
                    1.0,
                ),
                MOI.ScalarAffineFunction(
                    MOI.ScalarAffineTerm.([1, 1e-7, 1], [x, y, y]),
                    0.0,
                ),
            ) atol = 1e-6
            f1 = AffineDecisionFunction(
                MOI.ScalarAffineFunction(
                    [MOI.ScalarAffineTerm(1.0, z), MOI.ScalarAffineTerm(1e-7, w)],
                    1.0,
                ),
                MOI.ScalarAffineFunction(
                    [MOI.ScalarAffineTerm(1.0, x), MOI.ScalarAffineTerm(1e-7, y)],
                    0.0,
                ),
            )
            f2 = AffineDecisionFunction(
                MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(1.0, z)], 1.0),
                MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(1.0, x)], 0.0),
            )
            @test f1 ≈ f2 atol = 1e-6
            fdiff = f1 - f2
            @testset "With iszero" begin
                @test !iszero(fdiff)
                @test iszero(f1 - f1)
                @test iszero(f2 - f2)
            end
            @testset "With tolerance" begin
                MOIU.canonicalize!(fdiff)
                @test !MOIU.isapprox_zero(fdiff, 1e-8)
                @test MOIU.isapprox_zero(fdiff, 1e-6)
            end
        end
        @testset "canonical" begin
            f = MOIU.canonical(
                AffineDecisionFunction(
                    MOI.ScalarAffineFunction(
                        MOI.ScalarAffineTerm.([1, 1, 3, -2, -3], [w, z, z, w, z]),
                        5,
                    ),
                    MOI.ScalarAffineFunction(
                        MOI.ScalarAffineTerm.([2, 1, 3, -2, -3], [y, x, y, x, y]),
                        0,
                    ),
                )
            )
            @test MOI.output_dimension(f) == 1
            @test f.variable_part.terms == MOI.ScalarAffineTerm.([1, -1], [z, w])
            @test f.decision_part.terms == MOI.ScalarAffineTerm.([-1, 2], [x, y])
            @test MOI.constant(f) == 5
        end
        f = AffineDecisionFunction(
            MOI.ScalarAffineFunction(
                MOI.ScalarAffineTerm.([0.5, 0.5], [z, w]),
                0.5,
            ),
            MOI.ScalarAffineFunction(
                MOI.ScalarAffineTerm.([1.0, 0.5], [x, y]),
                0.0,
            ),
        )
        @testset "convert" begin
            @test_throws InexactError convert(SingleDecision, f)
            @test_throws InexactError MOIU.convert_approx(SingleDecision, f)
            @test MOIU.convert_approx(SingleDecision, f, tol = 0.5) ==
                SingleDecision(x)
            @test convert(typeof(f), f) === f
            quad_f = QuadraticDecisionFunction(
                MOI.ScalarQuadraticFunction(
                    f.variable_part.terms,
                    MOI.ScalarQuadraticTerm{Float64}[],
                    f.variable_part.constant,
                ),
                MOI.ScalarQuadraticFunction(
                    f.decision_part.terms,
                    MOI.ScalarQuadraticTerm{Float64}[],
                    0.0,
                ),
                MOI.ScalarQuadraticFunction(
                    MOI.ScalarAffineTerm{Float64}[],
                    MOI.ScalarQuadraticTerm{Float64}[],
                    0.0,
                ),
            )
            @test convert(QuadraticDecisionFunction{Float64}, f) ≈ quad_f
            for g in [
                convert(
                    AffineDecisionFunction{Float64},
                    SingleDecision(x),
                ),
                convert(
                    AffineDecisionFunction{Float64},
                    1SingleDecision(x),
                ),
            ]
                @test g isa AffineDecisionFunction{Float64}
                @test convert(SingleDecision, g) == SingleDecision(x)
                @test MOIU.convert_approx(SingleDecision, g) ==
                    SingleDecision(x)
            end
        end
        @testset "operate with Float64 coefficient type" begin
            f = AffineDecisionFunction(
                MOI.ScalarAffineFunction(
                    MOI.ScalarAffineTerm.([1.0, 4.0], [z, w]),
                    5.0,
                ),
                MOI.ScalarAffineFunction(
                    MOI.ScalarAffineTerm.([1.0, 4.0], [x, y]),
                    0.0,
                ),
            )
            @test f ≈ 2.0f / 2.0
        end
        @testset "operate with Int coefficient type" begin
            f = MOIU.canonical(
                AffineDecisionFunction(
                    MOI.ScalarAffineFunction(
                        MOI.ScalarAffineTerm.(
                            [1, 1, 2],
                            [w, w, z],
                        ),
                        2,
                    ),
                    MOI.ScalarAffineFunction(
                        MOI.ScalarAffineTerm.(
                            [3, 2, -3],
                            [y, x, x],
                        ),
                        0,
                    ),
                ) + AffineDecisionFunction(
                    MOI.ScalarAffineFunction(
                        MOI.ScalarAffineTerm.([-2, -2], [z, w]),
                        3,
                    ),
                    MOI.ScalarAffineFunction(
                        MOI.ScalarAffineTerm.([-1, 3, 2], [y, x, y]),
                        0,
                    ),
                )
            )
            @test f === +f
            @test f ≈
                SingleDecision(x) + AffineDecisionFunction(
                    MOI.ScalarAffineFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        5,
                    ),
                    MOI.ScalarAffineFunction(
                        MOI.ScalarAffineTerm.([1, 4], [x, y]),
                        0,
                    ),
                )
            @test f ≈ f * 1
            @test f ≈
                AffineDecisionFunction(
                    MOI.ScalarAffineFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        2,
                    ),
                    MOI.ScalarAffineFunction(
                        MOI.ScalarAffineTerm.([1, 2], [x, y]),
                        0,
                    ),
                ) * 2 + 1
            @test f ≈
                SingleDecision(x) - AffineDecisionFunction(
                    MOI.ScalarAffineFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        -5,
                    ),
                    MOI.ScalarAffineFunction(
                        MOI.ScalarAffineTerm.([-1, -4], [x, y]),
                        -5,
                    ),
                )
            @test f ≈
                AffineDecisionFunction(
                    MOI.ScalarAffineFunction(
                        [MOI.ScalarAffineTerm(1, w)],
                        5,
                    ),
                    MOI.ScalarAffineFunction(
                        MOI.ScalarAffineTerm.([3, 4], [x, y]),
                        5,
                    ),
                ) - SingleDecision(x) - MOI.SingleVariable(w)
        end
        @testset "modification" begin
            f = MOIU.modify_function(f, MOI.ScalarConstantChange(6))
            @test MOI.constant(f) == 6
            g = deepcopy(f)
            @test g ≈ f
            f = MOIU.modify_function(f, MOI.ScalarCoefficientChange(z, 3))
            f = MOIU.modify_function(f, StochasticPrograms.DecisionCoefficientChange(y, 3))
            @test !(g ≈ f)
            @test g.variable_part.terms == MOI.ScalarAffineTerm[]
            @test g.decision_part.terms == MOI.ScalarAffineTerm.([2, 4], [x, y])
            @test f.variable_part.terms == [MOI.ScalarAffineTerm(3, z)]
            @test f.decision_part.terms == MOI.ScalarAffineTerm.([2, 3], [x, y])
            f = MOIU.modify_function(f, StochasticPrograms.DecisionCoefficientChange(x, 0))
            @test f.decision_part.terms == MOI.ScalarAffineTerm.([3], [y])
        end
    end
    @testset "Quadratic" begin
        @testset "zero" begin
            f = @inferred MOIU.zero(QuadraticDecisionFunction{Float64})
            @test MOIU.isapprox_zero(f, 1e-16)
        end
        @testset "promote_operation" begin
            @test MOIU.promote_operation(
                -,
                Int,
                QuadraticDecisionFunction{Int},
            ) == QuadraticDecisionFunction{Int}
            @test MOIU.promote_operation(
                +,
                Int,
                QuadraticDecisionFunction{Int},
                QuadraticDecisionFunction{Int},
            ) == QuadraticDecisionFunction{Int}
            @test MOIU.promote_operation(
                +,
                Int,
                QuadraticDecisionFunction{Int},
                MOI.ScalarAffineFunction{Int},
            ) == QuadraticDecisionFunction{Int}
            @test MOIU.promote_operation(
                +,
                Int,
                MOI.ScalarAffineFunction{Int},
                QuadraticDecisionFunction{Int},
            ) == QuadraticDecisionFunction{Int}
            @test MOIU.promote_operation(
                +,
                Int,
                QuadraticDecisionFunction{Int},
                MOI.ScalarQuadraticFunction{Int},
            ) == QuadraticDecisionFunction{Int}
            @test MOIU.promote_operation(
                +,
                Int,
                MOI.ScalarQuadraticFunction{Int},
                QuadraticDecisionFunction{Int},
            ) == QuadraticDecisionFunction{Int}
            @test MOIU.promote_operation(
                +,
                Int,
                QuadraticDecisionFunction{Int},
                AffineDecisionFunction{Int},
            ) == QuadraticDecisionFunction{Int}
            @test MOIU.promote_operation(
                +,
                Int,
                AffineDecisionFunction{Int},
                QuadraticDecisionFunction{Int},
            ) == QuadraticDecisionFunction{Int}
            @test MOIU.promote_operation(
                *,
                Int,
                SingleDecision,
                SingleDecision,
            ) == QuadraticDecisionFunction{Int}
            @test MOIU.promote_operation(
                *,
                Int,
                MOI.SingleVariable,
                SingleDecision,
            ) == QuadraticDecisionFunction{Int}
            @test MOIU.promote_operation(
                *,
                Int,
                SingleDecision,
                MOI.SingleVariable,
            ) == QuadraticDecisionFunction{Int}
            @test MOIU.promote_operation(
                *,
                Float64,
                SingleDecision,
                MOI.ScalarAffineFunction{Float64},
            ) == QuadraticDecisionFunction{Float64}
            @test MOIU.promote_operation(
                *,
                Int,
                MOI.ScalarAffineFunction{Int},
                SingleDecision,
            ) == QuadraticDecisionFunction{Int}
            @test MOIU.promote_operation(
                *,
                Float64,
                MOI.SingleVariable,
                AffineDecisionFunction{Float64},
            ) == QuadraticDecisionFunction{Float64}
            @test MOIU.promote_operation(
                *,
                Int,
                AffineDecisionFunction{Int},
                MOI.SingleVariable,
            ) == QuadraticDecisionFunction{Int}
            @test MOIU.promote_operation(
                *,
                Float64,
                SingleDecision,
                AffineDecisionFunction{Float64},
            ) == QuadraticDecisionFunction{Float64}
            @test MOIU.promote_operation(
                *,
                Int,
                AffineDecisionFunction{Int},
                SingleDecision,
            ) == QuadraticDecisionFunction{Int}
            @test MOIU.promote_operation(
                *,
                Float64,
                MOI.ScalarAffineFunction{Float64},
                AffineDecisionFunction{Float64},
            ) == QuadraticDecisionFunction{Float64}
            @test MOIU.promote_operation(
                *,
                Float64,
                AffineDecisionFunction{Float64},
                MOI.ScalarAffineFunction{Float64},
            ) == QuadraticDecisionFunction{Float64}
            @test MOIU.promote_operation(
                *,
                Float64,
                AffineDecisionFunction{Float64},
                AffineDecisionFunction{Float64},
            ) == QuadraticDecisionFunction{Float64}
            @test MOIU.promote_operation(
                /,
                Float64,
                QuadraticDecisionFunction{Float64},
                Float64,
            ) == QuadraticDecisionFunction{Float64}
        end
        f = 7 + 3fx + 1fx * fx + 2fy * fy + 3fx * fy + 1fz * fz + 1fx * fz
        MOIU.canonicalize!(f)
        @test MOI.output_dimension(f) == 1
        @testset "Comparison" begin
            @testset "With iszero" begin
                @test !iszero(f)
                @test iszero(0 * f)
                @test iszero(f - f)
            end
            @testset "With tolerance" begin
                @test !MOIU.isapprox_zero(f, 1e-8)
                @test MOIU.isapprox_zero(0 * f, 1e-8)
                g = 1.0fx * fy - (1 + 1e-6) * fy * fx + 1.0fx * fz - (1 + 1e-6) * fz * fx
                MOIU.canonicalize!(g)
                @test MOIU.isapprox_zero(g, 1e-5)
                @test !MOIU.isapprox_zero(g, 1e-7)
            end
        end
        @testset "convert" begin
            @test_throws InexactError convert(SingleDecision, f)
            @test_throws InexactError convert(AffineDecisionFunction{Int}, f)
            g = convert(QuadraticDecisionFunction{Float64}, fx)
            @test convert(SingleDecision, g) == fx
        end
        @testset "Power" begin
            @testset "Affine" begin
                aff = 1fx + 2 + fy + 1fz
                @test isone(@inferred aff^0)
                @test convert(typeof(f), aff) ≈ @inferred aff^1
                @test aff * aff ≈ @inferred aff^2
                err =
                    ArgumentError("Cannot take $(typeof(aff)) to the power 3.")
                @test_throws err aff^3
            end
            @testset "Quadratic" begin
                @test isone(@inferred f^0)
                @test f ≈ @inferred f^1
                err = ArgumentError("Cannot take $(typeof(f)) to the power 2.")
                @test_throws err f^2
            end
        end
        @testset "operate" begin
            @testset "No zero affine term" begin
                qd(f) = convert(QuadraticDecisionFunction{Int}, f)
                for fzfw in [qd(1fz * fw), qd(fw * 1fz)]
                    @test isempty(fzfw.variable_part.affine_terms)
                    @test length(fzfw.variable_part.quadratic_terms) == 1
                    @test isempty(fzfw.decision_part.affine_terms)
                    @test isempty(fzfw.decision_part.quadratic_terms)
                    @test fzfw.variable_part.quadratic_terms[1] ==
                        MOI.ScalarQuadraticTerm(1, z, w) ||
                        fzfw.variable_part.quadratic_terms[1] ==
                        MOI.ScalarQuadraticTerm(1, w, z)
                end
                for fzfz in [qd(1fz * fz), qd(fz * 1fz)]
                    @test isempty(fzfz.variable_part.affine_terms)
                    @test length(fzfz.variable_part.quadratic_terms) == 1
                    @test isempty(fzfz.decision_part.affine_terms)
                    @test isempty(fzfz.decision_part.quadratic_terms)
                    @test fzfz.variable_part.quadratic_terms[1] ==
                        MOI.ScalarQuadraticTerm(2, z, z)
                end
                for fxfy in [1fx * fy, fx * 1fy]
                    @test isempty(fxfy.variable_part.affine_terms)
                    @test isempty(fxfy.variable_part.quadratic_terms)
                    @test isempty(fxfy.decision_part.affine_terms)
                    @test length(fxfy.decision_part.quadratic_terms) == 1
                    @test fxfy.decision_part.quadratic_terms[1] ==
                        MOI.ScalarQuadraticTerm(1, x, y) ||
                        fxfy.decision_part.quadratic_terms[1] ==
                        MOI.ScalarQuadraticTerm(1, y, x)
                end
                for fxfx in [1fx * fx, fx * 1fx]
                    @test isempty(fxfx.variable_part.affine_terms)
                    @test isempty(fxfx.variable_part.quadratic_terms)
                    @test isempty(fxfx.decision_part.affine_terms)
                    @test length(fxfx.decision_part.quadratic_terms) == 1
                    @test fxfx.decision_part.quadratic_terms[1] ==
                        MOI.ScalarQuadraticTerm(2, x, x)
                end
                for fxfy in [1fx * fy, fx * 1fy]
                    @test isempty(fxfy.decision_part.affine_terms)
                    @test length(fxfy.decision_part.quadratic_terms) == 1
                    @test fxfy.decision_part.quadratic_terms[1] ==
                        MOI.ScalarQuadraticTerm(1, x, y) ||
                        fxfy.decision_part.quadratic_terms[1] ==
                        MOI.ScalarQuadraticTerm(1, y, x)
                end
                for fxfx in [1fx * fx, fx * 1fx]
                    @test isempty(fxfx.decision_part.affine_terms)
                    @test length(fxfx.decision_part.quadratic_terms) == 1
                    @test fxfx.decision_part.quadratic_terms[1] ==
                        MOI.ScalarQuadraticTerm(2, x, x)
                end
                for fxfz in [1fx * fz, fz * 1fx]
                    @test isempty(fxfz.variable_part.affine_terms)
                    @test isempty(fxfz.variable_part.quadratic_terms)
                    @test isempty(fxfz.decision_part.affine_terms)
                    @test isempty(fxfz.decision_part.quadratic_terms)
                    @test isempty(fxfz.cross_terms.affine_terms)
                    @test length(fxfz.cross_terms.quadratic_terms) == 1
                    @test fxfz.cross_terms.quadratic_terms[1] ==
                        MOI.ScalarQuadraticTerm(1, x, z) ||
                        fxfz.cross_terms.quadratic_terms[1] ==
                        MOI.ScalarQuadraticTerm(1, z, x)
                end
            end
            @testset "operate!" begin
                q = 1.0fx + 1.0fy + (1.0fx) * fy + (1.0fx) * fz + (1.0fw) * fz
                @test q ≈ 1.0fx + 1.0fy + (1.0fw) * fz + (1.0fx) * fz + (1.0fx) * fy
                # This calls
                aff = 1.0fx + 1.0fy
                # which tries to mutate `aff`, gets a quadratic expression
                # and mutate it with the remaining term
                @test MOIU.operate!(
                    +,
                    Float64,
                    aff,
                    (1.0fx) * fz,
                    (1.0fw) * fz,
                ) ≈ q + (1.0fx) * fy
            end
            f = 7 + 3fx + 2fx * fx + 2fy * fy + 3fx * fy + 3fx * fz + 2fz * fz
            @test f ≈ 7 + (fx + 2fy) * (1fx + fy) + 3fx + (fx + 2fz) * (1fx + fz)
            @test f ≈ -(-7 - 3fx) + (fx + 2fy) * (1fx + fy) + (fx + 2fz) * (1fx + fz)
            @test f ≈ -((fx + 2fy) * (MOIU.operate(-, Int, fx) - fy)) + 3fx + 7 - ((fx + 2fz) * (MOIU.operate(-, Int, fx) - fz))
            @test f ≈
                7 + MOIU.operate(*, Int, fx, fx) + 3fx * (fy + 1) + 2fy * fy +
                MOIU.operate(*, Int, fx, fx) + 3fx * fz + 2fz * fz
            @test f ≈
                (fx + 2) * (fx + 1) + (fy + 1) * (2fy + 3fx) + (fx + 2) * (fx + 1) + (fz + 1) * (2fz + 3fx) + (3 - 9fx - 2fy - 2fz)
            @test f ≈ begin
                QuadraticDecisionFunction(
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([4], [z], [z]),
                        4,
                    ),
                    MOI.ScalarQuadraticFunction(
                        [MOI.ScalarAffineTerm(3, x)],
                        MOI.ScalarQuadraticTerm.([4], [x], [x]),
                        0,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm{Int}[],
                        0,
                    ),
                ) + QuadraticDecisionFunction(
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm{Int}[],
                        3,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([4, 3], [y, x], [y, y]),
                        0,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([3], [x], [z]),
                        0,
                    ),
                )
            end
            @test f ≈ begin
                QuadraticDecisionFunction(
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([4], [z], [z]),
                        10,
                    ),
                    MOI.ScalarQuadraticFunction(
                        [MOI.ScalarAffineTerm(3, x)],
                        MOI.ScalarQuadraticTerm.([2], [x], [x]),
                        0,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm{Int}[],
                        0,
                    ),
                ) - QuadraticDecisionFunction(
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm{Int}[],
                        3,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([-2, -4, -3], [x, y, x], [x, y, y]),
                        0,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([-3], [x], [z]),
                        0,
                    ),
                )
            end
            @test f ≈ begin
                AffineDecisionFunction(
                    MOI.ScalarAffineFunction{Int}(
                        MOI.ScalarAffineTerm{Int}[],
                        5,
                    ),
                    MOI.ScalarAffineFunction{Int}(
                        [MOI.ScalarAffineTerm(3, x)],
                        0,
                    ),
                ) + QuadraticDecisionFunction(
                    MOI.ScalarQuadraticFunction(
                        [MOI.ScalarAffineTerm(2, z)],
                        MOI.ScalarQuadraticTerm.([4], [z], [z]),
                        2,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([4, 4, 3], [x, y, x], [x, y, y]),
                        0,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([3], [x], [z]),
                        0,
                    ),
                ) - MOI.ScalarAffineFunction(
                    [MOI.ScalarAffineTerm(2, z)],
                    0,
                )
            end
            @test f ≈ begin
                AffineDecisionFunction(
                    MOI.ScalarAffineFunction{Int}(
                        MOI.ScalarAffineTerm{Int}[],
                        5,
                    ),
                    MOI.ScalarAffineFunction{Int}(
                        [MOI.ScalarAffineTerm(3, x)],
                        0,
                    ),
                ) - QuadraticDecisionFunction(
                    MOI.ScalarQuadraticFunction(
                        [MOI.ScalarAffineTerm(2, z)],
                        MOI.ScalarQuadraticTerm.([-4], [z], [z]),
                        -2,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([-4, -4, -3], [x, y, x], [x, y, y]),
                        0,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([3], [x], [z]),
                        0,
                    ),
                ) + MOI.ScalarAffineFunction(
                    [MOI.ScalarAffineTerm(2, z)],
                    0,
                )
            end
            @test f ≈ begin
                QuadraticDecisionFunction(
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([4], [z], [z]),
                        2,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([4, 4, 3], [x, y, x], [x, y, y]),
                        0,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([3], [x], [z]),
                        0,
                    ),
                ) + AffineDecisionFunction(
                    MOI.ScalarAffineFunction{Int}(
                        MOI.ScalarAffineTerm{Int}[],
                        5,
                    ),
                    MOI.ScalarAffineFunction{Int}(
                        [MOI.ScalarAffineTerm(3, x)],
                        0,
                    ),
                )
            end
            @test f ≈ begin
                QuadraticDecisionFunction(
                    MOI.ScalarQuadraticFunction(
                        [MOI.ScalarAffineTerm(2, z)],
                        MOI.ScalarQuadraticTerm.([4], [z], [z]),
                        9,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([4, 4, 3], [x, y, x], [x, y, y]),
                        0,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Int}[],
                        MOI.ScalarQuadraticTerm.([3], [x], [z]),
                        0,
                    ),
                ) - AffineDecisionFunction(
                    MOI.ScalarAffineFunction{Int}(
                        MOI.ScalarAffineTerm{Int}[],
                        5,
                    ),
                    MOI.ScalarAffineFunction{Int}(
                        [MOI.ScalarAffineTerm(-2, x)],
                        0,
                    ),
                ) - 2 * fz + 1 * fx + 3
            end
            @test f ≈ begin
                2.0 * QuadraticDecisionFunction(
                    MOI.ScalarQuadraticFunction(
                        [MOI.ScalarAffineTerm(2., z)],
                        MOI.ScalarQuadraticTerm.([4.], [z], [z]),
                        7.0,
                    ),
                    MOI.ScalarQuadraticFunction(
                        [MOI.ScalarAffineTerm(3., x)],
                        MOI.ScalarQuadraticTerm.([4., 4., 3.], [x, y, x], [x, y, y]),
                        0.0,
                    ),
                    MOI.ScalarQuadraticFunction(
                        MOI.ScalarAffineTerm{Float64}[],
                        MOI.ScalarQuadraticTerm.([3.], [x], [z]),
                        0.0,
                    ),
                ) / 2.0
            end
            @testset "modification" begin
                f = MOIU.modify_function(f, MOI.ScalarConstantChange(9))
                @test MOI.constant(f) == 9
                f = MOIU.modify_function(f, MOI.ScalarCoefficientChange(z, 0))
                f = MOIU.modify_function(f, StochasticPrograms.DecisionCoefficientChange(y, 0))
                @test isempty(f.variable_part.affine_terms)
                @test f.decision_part.affine_terms == MOI.ScalarAffineTerm.([3], [x])
                g = deepcopy(f)
                @test f ≈ g
                f = MOIU.modify_function(f, MOI.ScalarCoefficientChange(z, 2))
                f = MOIU.modify_function(f, StochasticPrograms.DecisionCoefficientChange(y, 2))
                @test !(f ≈ g)
                @test isempty(g.variable_part.affine_terms)
                @test f.variable_part.affine_terms == MOI.ScalarAffineTerm.([2], [z])
                @test g.decision_part.affine_terms == MOI.ScalarAffineTerm.([3], [x])
                @test f.decision_part.affine_terms == MOI.ScalarAffineTerm.([3, 2], [x, y])
            end
        end
    end
end

function test_vector_operations(x, fx, y, fy, z, fz, w, fw)
    @testset "Affine" begin
        @testset "promote_operation" begin
            @test MOIU.promote_operation(-, Int, VectorOfDecisions) ==
                VectorAffineDecisionFunction{Int}
            @test MOIU.promote_operation(
                -,
                Int,
                VectorAffineDecisionFunction{Int},
            ) == VectorAffineDecisionFunction{Int}
            @test MOIU.promote_operation(
                +,
                Float64,
                VectorOfDecisions,
                VectorOfDecisions,
            ) == VectorAffineDecisionFunction{Float64}
            @test MOIU.promote_operation(
                +,
                Float64,
                MOI.VectorOfVariables,
                VectorOfDecisions,
            ) == VectorAffineDecisionFunction{Float64}
            @test MOIU.promote_operation(
                +,
                Float64,
                VectorOfDecisions,
                MOI.VectorOfVariables,
            ) == VectorAffineDecisionFunction{Float64}
            @test MOIU.promote_operation(
                +,
                Float64,
                VectorAffineDecisionFunction{Float64},
                Vector{Float64},
            ) == VectorAffineDecisionFunction{Float64}
            @test MOIU.promote_operation(
                +,
                Int,
                VectorAffineDecisionFunction{Int},
                VectorAffineDecisionFunction{Int},
            ) == VectorAffineDecisionFunction{Int}
        end
        @testset "Comparison" begin
            @test MOIU.operate(
                +,
                Float64,
                MOI.VectorOfVariables([z, w]),
                VectorOfDecisions([x, y]),
            ) + ones(2) ≈ VectorAffineDecisionFunction(
                MOI.VectorAffineFunction(
                    MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([1., 1.], [z, w])),
                    [1., 1.],
                ),
                MOI.VectorAffineFunction(
                    MOI.VectorAffineTerm.([1, 2, 2], MOI.ScalarAffineTerm.([1., 1e-7, 1.], [x, y, y])),
                    zeros(Float64, 2),
                ),
            ) atol = 1e-6
            f1 = VectorAffineDecisionFunction(
                MOI.VectorAffineFunction(
                    MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([1.0, 1e-7], [z, w])),
                    [1., 1.],
                ),
                MOI.VectorAffineFunction(
                    MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([1., 1e-7], [x, y])),
                    zeros(Float64, 2),
                ),
            )
            f2 = VectorAffineDecisionFunction(
                MOI.VectorAffineFunction(
                    MOI.VectorAffineTerm.([1], MOI.ScalarAffineTerm.([1.], [z])),
                    [1., 1.],
                ),
                MOI.VectorAffineFunction(
                    MOI.VectorAffineTerm.([1], MOI.ScalarAffineTerm.([1.], [x])),
                    zeros(Float64, 2),
                ),
            )
            @test f1 ≈ f2 atol = 1e-6
        end
        @testset "canonical" begin
            f = MOIU.canonical(
                VectorAffineDecisionFunction(
                    MOI.VectorAffineFunction(
                        MOI.VectorAffineTerm.([2, 1, 1, 2, 1], MOI.ScalarAffineTerm.([1, 1, 3, -2, -3], [w, z, z, w, z])),
                        [5, 2],
                    ),
                    MOI.VectorAffineFunction(
                        MOI.VectorAffineTerm.([2, 1, 2, 1, 2], MOI.ScalarAffineTerm.([2, 1, 3, -2, -3], [y, x, y, x, y])),
                        zeros(Int, 2),
                    ),
                )
            )
            @test MOI.output_dimension(f) == 2
            @test f.variable_part.terms == MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([1, -1], [z, w]))
            @test f.decision_part.terms == MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([-1, 2], [x, y]))
            @test MOI.constant(f) == [5, 2]
        end
        f = VectorAffineDecisionFunction(
            MOI.VectorAffineFunction(
                MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([0.5, 0.5], [z, w])),
                [0.5, 0.5],
            ),
            MOI.VectorAffineFunction(
                MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([1., 1.], [x, y])),
                zeros(Float64, 2),
            ),
        )
        @testset "convert" begin
            @test_throws InexactError MOIU.convert_approx(VectorOfDecisions, f)
            @test MOIU.convert_approx(VectorOfDecisions, f, tol = 0.5) ==
                VectorOfDecisions([x, y])
        end
        @testset "operate with Float64 coefficient type" begin
            f = VectorAffineDecisionFunction(
                MOI.VectorAffineFunction(
                    MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([1.0, 4.0], [z, w])),
                    [5.0, 2.0],
                ),
                MOI.VectorAffineFunction(
                    MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([1., 4.], [x, y])),
                    zeros(Float64, 2),
                ),
            )
            @test f ≈ 2.0f / 2.0
        end
        @testset "operate with Int coefficient type" begin
            f = MOIU.canonical(
                VectorAffineDecisionFunction(
                    MOI.VectorAffineFunction(
                        MOI.VectorAffineTerm.([1, 1, 2], MOI.ScalarAffineTerm.([1, 1, 2], [w, w, z])),
                        [5, 0],
                    ),
                    MOI.VectorAffineFunction(
                        MOI.VectorAffineTerm.([1, 1, 2], MOI.ScalarAffineTerm.([2, -3, 3], [x, x, y])),
                        zeros(Int, 2),
                    ),
                ) + VectorAffineDecisionFunction(
                    MOI.VectorAffineFunction(
                        MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([-2, -2], [w, z])),
                        [0, 2],
                    ),
                    MOI.VectorAffineFunction(
                        MOI.VectorAffineTerm.([2, 1, 2], MOI.ScalarAffineTerm.([-1, 3, 2], [y, x, y])),
                        zeros(Int, 2),
                    ),
                )
            )
            @test f === +f
            @test f ≈
                VectorOfDecisions([x, x]) + VectorAffineDecisionFunction(
                    MOI.VectorAffineFunction(
                        MOI.VectorAffineTerm{Int}[],
                        [5, 2],
                    ),
                    MOI.VectorAffineFunction(
                        MOI.VectorAffineTerm.([1, 2, 2], MOI.ScalarAffineTerm.([1, 4, -1], [x, y, x])),
                        zeros(Int, 2),
                    ),
                )
            @test f ≈ f * 1
            @test f ≈
                VectorAffineDecisionFunction(
                    MOI.VectorAffineFunction(
                        MOI.VectorAffineTerm{Int}[],
                        [0, 1],
                    ),
                    MOI.VectorAffineFunction(
                        MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([1, 2], [x, y])),
                        zeros(Int, 2),
                    ),
                ) * 2 + [5, 0]
            @test f ≈
                VectorOfDecisions([x, y]) - VectorAffineDecisionFunction(
                    MOI.VectorAffineFunction(
                        MOI.VectorAffineTerm{Int}[],
                        [-5, -2],
                    ),
                    MOI.VectorAffineFunction(
                        MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([-1, -3], [x, y])),
                        zeros(Int, 2),
                    ),
                )
            @test f ≈ MOIU.canonical(
                VectorAffineDecisionFunction(
                    MOI.VectorAffineFunction(
                        [MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(1, w))],
                        [5, 2],
                    ),
                    MOI.VectorAffineFunction(
                        MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([3, 4], [x, y])),
                        zeros(Int, 2),
                    ),
                ) - MOIU.operate(vcat, Int, 1SingleDecision(x) + MOI.SingleVariable(w), 0)
            )
        end
        @testset "modification" begin
            f = MOIU.modify_function(f, MOI.VectorConstantChange([2, 2]))
            @test MOI.constant(f) == [2, 2]
            g = deepcopy(f)
            @test g ≈ f
            f = MOIU.modify_function(f, MOI.MultirowChange(z, [(1, 3)]))
            f = MOIU.modify_function(f, StochasticPrograms.DecisionMultirowChange(y, [(2, 3)]))
            @test !(g ≈ f)
            @test g.variable_part.terms == MOI.VectorAffineTerm{Int}[]
            @test g.decision_part.terms == MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([2, 4], [x, y]))
            @test f.variable_part.terms == [MOI.VectorAffineTerm(1, MOI.ScalarAffineTerm(3, z))]
            @test f.decision_part.terms == MOI.VectorAffineTerm.([1, 2], MOI.ScalarAffineTerm.([2, 3], [x, y]))
            f = MOIU.modify_function(f, StochasticPrograms.DecisionMultirowChange(x, [(1, 0), (2, 1)]))
            @test f.decision_part.terms == MOI.VectorAffineTerm.([2, 2], MOI.ScalarAffineTerm.([3, 1], [y, x]))
        end
    end
end

function runtests()
    x = MOI.VariableIndex(1)
    fx = SingleDecision(x)
    y = MOI.VariableIndex(2)
    fy = SingleDecision(y)
    z = MOI.VariableIndex(3)
    fz = MOI.SingleVariable(z)
    w = MOI.VariableIndex(4)
    fw = MOI.SingleVariable(w)

    @testset "DecisionFunctions" begin
        for name in names(@__MODULE__; all = true)
            if !startswith("$(name)", "test_")
                continue
            end
            f = getfield(@__MODULE__, name)
            @testset "$(name)" begin
                f(x, fx, y, fy, z, fz, w, fw)
            end
        end
    end
end

end
