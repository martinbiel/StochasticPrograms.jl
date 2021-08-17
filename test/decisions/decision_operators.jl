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

@everywhere module TestDecisionOperators

using StochasticPrograms
using Test
using LinearAlgebra
using MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities
const MA = MOI.MutableArithmetics

function DecisionModel()
    m = Model()
    m.ext[:decisions] = Decisions(Val{1}())
    return m
end

macro decision_variable(m, x, args...)
    return esc(quote
        @variable($m, $x, $((args)...), set = StochasticPrograms.DecisionSet(1))
    end)
end

macro test_expression(expr)
    return esc(
        quote
            @test JuMP.isequal_canonical(@expression(model, $expr), $expr)
        end,
    )
end

macro test_expression_with_string(expr, str)
    return esc(
        quote
            realized_expr = @inferred $expr
            @test string(realized_expr) == $str
            @test JuMP.isequal_canonical(
                @expression(model, $expr),
                realized_expr,
            )
        end,
    )
end

function test_promotion()
    I = Int
    V = VariableRef
    D = DecisionRef
    VA = GenericAffExpr{Float64,V}
    DA = GenericAffExpr{Float64,D}
    VQ = GenericQuadExpr{Float64,V}
    DQ = GenericQuadExpr{Float64,D}
    A = DecisionAffExpr{Float64}
    Q = DecisionQuadExpr{Float64}
    # DecisionRef--Number
    @test promote_type(D, I) == A
    @test promote_type(I, D) == A
    # DecisionAffExpr--Number
    @test promote_type(A, I) == A
    @test promote_type(I, A) == A
    # DecisionAffExpr--VariableRef
    @test promote_type(A, V) == A
    @test promote_type(V, A) == A
    # DecisionAffExpr--DecisionRef
    @test promote_type(A, D) == A
    @test promote_type(D, A) == A
    # DecisionAffExpr--_VariableAffExpr
    @test promote_type(A, VA) == A
    @test promote_type(VA, A) == A
    # DecisionAffExpr--_DecisionAffExpr
    @test promote_type(A, DA) == A
    @test promote_type(DA, A) == A
    # DecisionQuadExpr--Number
    @test promote_type(Q, I) == Q
    @test promote_type(I, Q) == Q
    # DecisionQuadExpr--VariableRef
    @test promote_type(Q, V) == Q
    @test promote_type(V, Q) == Q
    # DecisionQuadExpr--DecisionRef
    @test promote_type(Q, D) == Q
    @test promote_type(D, Q) == Q
    # DecisionQuadExpr--_VariableAffExpr
    @test promote_type(Q, VA) == Q
    @test promote_type(VA, Q) == Q
    # DecisionQuadExpr--_DecisionAffExpr
    @test promote_type(Q, DA) == Q
    @test promote_type(DA, Q) == Q
    # DecisionQuadExpr--DecisionAffExpr
    @test promote_type(Q, A) == Q
    @test promote_type(A, Q) == Q
    # DecisionQuadExpr--_VariableQuadExpr
    @test promote_type(Q, VQ) == Q
    @test promote_type(VQ, Q) == Q
    # DecisionQuadExpr--_DecisionQuadExpr
    @test promote_type(Q, DQ) == Q
    @test promote_type(DQ, Q) == Q
end

function test_uniform_scaling()
    model = DecisionModel()
    x = @decision_variable(model, x)
    y = @variable(model, y)
    @test_expression_with_string x + 2I "x + 2"
    @test_expression_with_string (x + y + 1) + I "x + y + 2"
    @test_expression_with_string x - 2I "x - 2"
    @test_expression_with_string (x + y - 1) - I "x + y - 2"
    @test_expression_with_string 2I + x "x + 2"
    @test_expression_with_string I + (x + 1) "x + 2"
    @test_expression_with_string 2I - x "-x + 2"
    @test_expression_with_string I - (x - 1) "-x + 2"
    @test_expression_with_string I * x "x"
    @test_expression_with_string I * (x + y + 1) "x + y + 1"
    @test_expression_with_string (x + 1) * I "x + 1"
end

function test_basic_operators()
    model = DecisionModel()
    x = @decision_variable(model, x)
    y = @variable(model, y)
    z = @decision_variable(model, z)

    aff = @inferred 7.1 * x + 2.5
    @test_expression_with_string 7.1 * x + 2.5 "7.1 x + 2.5"
    aff2 = @inferred 1.2 * y + 1.2 * x
    @test_expression_with_string 1.2 * y + 1.2 * x "1.2 x + 1.2 y"
    q = @inferred 2.5 * y * z + aff
    @test_expression_with_string 2.5 * y * z + aff "7.1 x + 2.5 z*y + 2.5"
    q2 = @inferred 8 * x * z + aff2
    @test_expression_with_string 8 * x * z + aff2 "8 z*x + 1.2 x + 1.2 y"
    @test_expression_with_string 2 * x * x + 1 * y * y + z + 3 "2 x² + z + y² + 3"
end

function test_basic_operators_number()
    model = DecisionModel()
    x = @decision_variable(model, x)
    y = @variable(model, y)
    z = @decision_variable(model, z)
    w = @variable(model, w)

    aff = @inferred 7.1 * x + 2.5
    quad = @inferred 2.5 * y * z + aff
    # Number--DecisionRef
    @test_expression_with_string 4.13 + x "x + 4.13"
    @test_expression_with_string 3.16 - x "-x + 3.16"
    @test_expression_with_string 5.23 * x "5.23 x"
    @test_throws ErrorException 2.94 / x
    # Number--DecisionAffExpr
    @test_expression_with_string 1.5 + aff "7.1 x + 4"
    @test_expression_with_string 1.5 - aff "-7.1 x - 1"
    @test_expression_with_string 2 * aff "14.2 x + 5"
    @test_throws ErrorException 2 / aff
    # Number--DecisionQuadExpr
    @test_expression_with_string 1.5 + quad "7.1 x + 2.5 z*y + 4"
    @test_expression_with_string 1.5 - quad "-7.1 x - 2.5 z*y - 1"
    @test_expression_with_string 2 * quad "14.2 x + 5 z*y + 5"
    @test_throws ErrorException 2 / quad
end

function test_basic_operators_decision()
    model = DecisionModel()
    x = @decision_variable(model, x)
    y = @variable(model, y)
    z = @decision_variable(model, z)
    w = @variable(model, w)

    aff = @inferred 7.1 * x + 2.5
    vaff = @inferred 7.1 * y + 2.5
    quad = @inferred 2.5 * y * z + aff
    vquad = @inferred 2.5 * y * w + vaff

    # DecisionRef unary
    @test (+x) === x
    @test_expression_with_string -x "-x"
    # DecisionRef--Number
    @test_expression_with_string x + 4.13 "x + 4.13"
    @test_expression_with_string x - 4.13 "x - 4.13"
    @test_expression_with_string x * 4.13 "4.13 x"
    @test_expression_with_string x / 2.00 "0.5 x"
    @test x == x
    @test transpose(x) === x
    @test conj(x) === x
    @test_expression_with_string x - x "0"
    @test_expression_with_string x^2 "x²"
    @test_expression_with_string x^1 "x"
    @test_expression_with_string x^0 "1"
    @test_throws ErrorException x^3
    @test_throws ErrorException x^1.5
    # DecisionRef--VariableRef
    @test_expression_with_string w + x "x + w"
    @test_expression_with_string w - x "-x + w"
    @test_expression_with_string w * x "x*w"
    @test_throws ErrorException w / x
    @test_expression_with_string y * z - x "-x + z*y"
    # DecisionRef--DecisionRef
    @test_expression_with_string z + x "z + x"
    @test_expression_with_string z - x "z - x"
    @test_expression_with_string z * x "z*x"
    @test_throws ErrorException z / x
    # VariableRef--DecisionAffExpr
    @test_expression_with_string w + aff "7.1 x + w + 2.5"
    @test_expression_with_string w - aff "-7.1 x + w - 2.5"
    @test_expression_with_string w * aff "7.1 x*w + 2.5 w"
    @test_throws ErrorException w / aff
    @test_throws MethodError w ≤ aff
    @test_expression_with_string 7.1 * w - aff "-7.1 x + 7.1 w - 2.5"
    # DecisionRef--_VariableAffExpr
    @test_expression_with_string z + vaff "z + 7.1 y + 2.5"
    @test_expression_with_string z - vaff "z - 7.1 y - 2.5"
    @test_expression_with_string z * vaff "2.5 z + 7.1 z*y"
    @test_throws ErrorException z / vaff
    @test_throws MethodError z ≤ vaff
    @test_expression_with_string 7.1 * x - vaff "7.1 x - 7.1 y - 2.5"
    # DecisionRef--DecisionAffExpr
    @test_expression_with_string z + aff "z + 7.1 x + 2.5"
    @test_expression_with_string z - aff "z - 7.1 x - 2.5"
    @test_expression_with_string z * aff "7.1 z*x + 2.5 z"
    @test_throws ErrorException z / aff
    @test_throws MethodError z ≤ aff
    @test_expression_with_string 7.1 * x - aff "0 x - 2.5"
    # VariableRef--_DecisionQuadExpr
    @test_expression_with_string w + quad "7.1 x + 2.5 z*y + w + 2.5"
    @test_expression_with_string w - quad "-7.1 x - 2.5 z*y + w - 2.5"
    @test_throws ErrorException w * quad
    @test_throws ErrorException w / quad
    # DecisionRef--_VariableQuadExpr
    @test_expression_with_string x + vquad "x + 2.5 y*w + 7.1 y + 2.5"
    @test_expression_with_string x - vquad "x - 2.5 y*w - 7.1 y - 2.5"
    @test_throws ErrorException x * vquad
    @test_throws ErrorException x / vquad
    # DecisionRef--QuadExpr
    @test_expression_with_string z + quad "7.1 x + z + 2.5 z*y + 2.5"
    @test_expression_with_string z - quad "-7.1 x + z - 2.5 z*y - 2.5"
    @test_throws ErrorException z * quad
    @test_throws ErrorException z / quad
end

function test_basic_operators_affexpr()
    model = DecisionModel()
    x = @decision_variable(model, x)
    y = @variable(model, y)
    z = @decision_variable(model, z)
    w = @variable(model, w)

    aff = @inferred 7.1 * x + y + 2.5
    vaff = @inferred 2.4 * y + 1.2
    quad = @inferred 2.5 * y * z + aff
    vquad = @inferred w * w + vaff
    # DecisionAffExpr unary
    @test_expression_with_string +aff "7.1 x + y + 2.5"
    @test_expression_with_string -aff "-7.1 x - y - 2.5"
    # AffExpr--Number
    @test_expression_with_string aff + 1.5 "7.1 x + y + 4"
    @test_expression_with_string aff - 1.5 "7.1 x + y + 1"
    @test_expression_with_string aff * 2 "14.2 x + 2 y + 5"
    @test_expression_with_string aff / 2 "3.55 x + 0.5 y + 1.25"
    @test_throws MethodError aff ≤ 1
    @test aff == aff
    @test_throws MethodError aff ≥ 1
    @test_expression_with_string aff - 1 "7.1 x + y + 1.5"
    @test_expression_with_string aff^2 "50.41 x² + 35.5 x + 14.2 x*y + y² + 5 y + 6.25"
    @test_expression_with_string (7.1 * x + y + 2.5)^2 "50.41 x² + 35.5 x + 14.2 x*y + y² + 5 y + 6.25"
    @test_expression_with_string aff^1 "7.1 x + y + 2.5"
    @test_expression_with_string (7.1 * x + y + 2.5)^1 "7.1 x + y + 2.5"
    @test_expression_with_string aff^0 "1"
    @test_expression_with_string (7.1 * x + y + 2.5)^0 "1"
    @test_throws ErrorException aff^3
    @test_throws ErrorException (7.1 * x + y + 2.5)^3
    @test_throws ErrorException aff^1.5
    @test_throws ErrorException (7.1 * x + y + 2.5)^1.5
    # DecisionAffExpr--VariableRef
    @test_expression_with_string aff + w "7.1 x + w + y + 2.5"
    @test_expression_with_string aff - w "7.1 x - w + y + 2.5"
    @test_expression_with_string aff * w "7.1 x*w + w*y + 2.5 w"
    @test_throws ErrorException aff / w
    @test_expression_with_string aff - y "7.1 x + 0 y + 2.5"
    # DecisionAffExpr--DecisionRef
    @test_expression_with_string aff + z "z + 7.1 x + y + 2.5"
    @test_expression_with_string aff - z "-z + 7.1 x + y + 2.5"
    @test_expression_with_string aff * z "7.1 z*x + 2.5 z + z*y"
    @test_throws ErrorException aff / z
    @test_expression_with_string aff - 7.1 * x "0 x + y + 2.5"
    # DecisionAffExpr--_VariableAffExpr
    @test_expression_with_string aff + vaff "7.1 x + 3.4 y + 3.7"
    @test_expression_with_string aff - vaff "7.1 x - 1.4 y + 1.3"
    @test_expression_with_string aff * vaff "8.52 x + 17.04 x*y + 2.4 y² + 7.2 y + 3"
    @test_throws ErrorException aff / vaff
    # DecisionAffExpr--DecisionAffExpr
    @test_expression_with_string aff + aff "14.2 x + 2 y + 5"
    @test_expression_with_string aff - (x + y) "6.1 x + 0 y + 2.5"
    @test_expression_with_string aff * aff "50.41 x² + 35.5 x + 14.2 x*y + y² + 5 y + 6.25"
    @test_throws ErrorException aff / aff
    @test string((x + x) * (x + 3)) == string((x + 3) * (x + x))
    @test_expression_with_string aff - aff "0 x + 0 y"
    # _VariableAffExpr--DecisionQuadExpr
    @test_expression_with_string vaff + quad "7.1 x + 2.5 z*y + 3.4 y + 3.7"
    @test_expression_with_string vaff - quad "-7.1 x - 2.5 z*y + 1.4 y - 1.3"
    @test_throws ErrorException vaff * quad
    @test_throws ErrorException vaff / quad
    # DecisionAffExpr--_VariableQuadExpr
    @test_expression_with_string aff + vquad "7.1 x + w² + 3.4 y + 3.7"
    @test_expression_with_string aff - vquad "7.1 x - w² - 1.4 y + 1.3"
    @test_throws ErrorException aff * vquad
    @test_throws ErrorException aff / vquad
    # DecisionAffExpr--DecisionQuadExpr
    @test_expression_with_string aff + quad "14.2 x + 2.5 z*y + 2 y + 5"
    @test_expression_with_string aff - quad "0 x - 2.5 z*y + 0 y"
    @test_throws ErrorException aff * quad
    @test_throws ErrorException aff / quad
end

function test_basic_operators_quadexpr()
    model = DecisionModel()
    x = @decision_variable(model, x)
    y = @variable(model, y)
    z = @decision_variable(model, z)
    w = @variable(model, w)

    aff = @inferred 7.1 * x + y + 2.5
    vaff = @inferred 2.4 * y + 1.2
    quad = @inferred x^2 + 2.5 * y * z + aff
    vquad = @inferred w * w + vaff

    # DecisionQuadExpr unary
    @test_expression_with_string +quad "x² + 7.1 x + 2.5 z*y + y + 2.5"
    @test_expression_with_string -quad "-x² - 7.1 x - 2.5 z*y - y - 2.5"
    # DecisionQuadExpr--Number
    @test_expression_with_string quad + 1.5 "x² + 7.1 x + 2.5 z*y + y + 4"
    @test_expression_with_string quad - 1.5 "x² + 7.1 x + 2.5 z*y + y + 1"
    @test_expression_with_string quad * 2 "2 x² + 14.2 x + 5 z*y + 2 y + 5"
    @test_expression_with_string quad / 2 "0.5 x² + 3.55 x + 1.25 z*y + 0.5 y + 1.25"
    @test quad == quad
    # DecisionQuadExpr--VariableRef
    @test_expression_with_string quad + w "x² + 7.1 x + 2.5 z*y + y + w + 2.5"
    @test_expression_with_string quad - w "x² + 7.1 x + 2.5 z*y + y - w + 2.5"
    @test_throws ErrorException quad * w
    @test_throws ErrorException quad / w
    # DecisionQuadExpr--DecisionRef
    @test_expression_with_string quad + z "x² + 7.1 x + z + 2.5 z*y + y + 2.5"
    @test_expression_with_string quad - z "x² + 7.1 x - z + 2.5 z*y + y + 2.5"
    @test_throws ErrorException quad * z
    @test_throws ErrorException quad / z
    # DecisionQuadExpr--_VariableAffExpr
    @test_expression_with_string quad + vaff "x² + 7.1 x + 2.5 z*y + 3.4 y + 3.7"
    @test_expression_with_string quad - vaff "x² + 7.1 x + 2.5 z*y - 1.4 y + 1.3"
    @test_throws ErrorException quad * vaff
    @test_throws ErrorException quad / vaff
    # DecisionQuadExpr--DecisionAffExpr
    @test_expression_with_string quad + aff "x² + 14.2 x + 2.5 z*y + 2 y + 5"
    @test_expression_with_string quad - aff "x² + 0 x + 2.5 z*y + 0 y"
    @test_throws ErrorException quad * aff
    @test_throws ErrorException quad / aff
    # DecisionQuadExpr--_VariableQuadExpr
    @test_expression_with_string quad + vquad "x² + 7.1 x + 2.5 z*y + w² + 3.4 y + 3.7"
    @test_expression_with_string quad - vquad "x² + 7.1 x + 2.5 z*y - w² - 1.4 y + 1.3"
    @test_throws ErrorException quad * vquad
    @test_throws ErrorException quad / vquad
    # DecisionQuadExpr--DecisionQuadExpr
    @test_expression_with_string quad + (x^2 + x*y + y^2) "2 x² + 7.1 x + 2.5 z*y + x*y + y² + y + 2.5"
    @test_expression_with_string quad - (x^2 + x*y + y^2) "0 x² + 7.1 x - x*y + 2.5 z*y - y² + y + 2.5"
    @test_throws ErrorException quad * quad
    @test_throws ErrorException quad / quad
end

function test_dot()
    model = DecisionModel()
    @decision_variable(model, 0 ≤ x[1:3] ≤ 1)

    @test_expression_with_string dot(x[1], x[1]) "x[1]²"
    @test_expression_with_string dot(2, x[1]) "2 x[1]"
    @test_expression_with_string dot(x[1], 2) "2 x[1]"

    c = vcat(1:3)
    @test_expression_with_string dot(c, x) "x[1] + 2 x[2] + 3 x[3]"
    @test_expression_with_string dot(x, c) "x[1] + 2 x[2] + 3 x[3]"

    A = [1 3; 2 4]
    @decision_variable(model, 1 ≤ y[1:2, 1:2] ≤ 1)
    @test_expression_with_string dot(A, y) "y[1,1] + 2 y[2,1] + 3 y[1,2] + 4 y[2,2]"
    @test_expression_with_string dot(y, A) "y[1,1] + 2 y[2,1] + 3 y[1,2] + 4 y[2,2]"

    B = ones(2, 2, 2)
    @decision_variable(model, 0 ≤ z[1:2, 1:2, 1:2] ≤ 1)
    @test_expression_with_string dot(B, z) "z[1,1,1] + z[2,1,1] + z[1,2,1] + z[2,2,1] + z[1,1,2] + z[2,1,2] + z[1,2,2] + z[2,2,2]"
    @test_expression_with_string dot(z, B) "z[1,1,1] + z[2,1,1] + z[1,2,1] + z[2,2,1] + z[1,1,2] + z[2,1,2] + z[1,2,2] + z[2,2,2]"

    @objective(model, Max, dot(x, ones(3)) - dot(y, ones(2, 2)))
    for i in 1:3
        JuMP.set_start_value(x[i], 1)
    end
    for i in 1:2, j in 1:2
        JuMP.set_start_value(y[i, j], 1)
    end
    for i in 1:2, j in 1:2, k in 1:2
        JuMP.set_start_value(z[i, j, k], 1)
    end
    @test dot(c, JuMP.start_value.(x)) ≈ 6
    @test dot(A, JuMP.start_value.(y)) ≈ 10
    @test dot(B, JuMP.start_value.(z)) ≈ 8
end

function test_higher_level()
    model = DecisionModel()
    @decision_variable(model, 0 ≤ matrix[1:3, 1:3] ≤ 1, start = 1)
    @testset "sum(::Matrix{DecisionRef})" begin
        @test_expression_with_string sum(matrix) "matrix[1,1] + matrix[2,1] + matrix[3,1] + matrix[1,2] + matrix[2,2] + matrix[3,2] + matrix[1,3] + matrix[2,3] + matrix[3,3]"
    end

    @testset "sum(::Matrix{T}) where T<:Real" begin
        @test sum(JuMP.start_value.(matrix)) ≈ 9
    end
    @testset "sum(::Array{VariableRef})" begin
        @test string(sum(matrix[1:3, 1:3])) == string(sum(matrix))
    end
    @testset "sum(affs::Array{DecisionAffExpr})" begin
        @test_expression_with_string sum([
            2 * matrix[i, j] for i in 1:3, j in 1:3
        ]) "2 matrix[1,1] + 2 matrix[2,1] + 2 matrix[3,1] + 2 matrix[1,2] + 2 matrix[2,2] + 2 matrix[3,2] + 2 matrix[1,3] + 2 matrix[2,3] + 2 matrix[3,3]"
    end
    @testset "sum(quads::Array{DecisionQuadExpr})" begin
        @test_expression_with_string sum([
            2 * matrix[i, j]^2 for i in 1:3, j in 1:3
        ]) "2 matrix[1,1]² + 2 matrix[2,1]² + 2 matrix[3,1]² + 2 matrix[1,2]² + 2 matrix[2,2]² + 2 matrix[3,2]² + 2 matrix[1,3]² + 2 matrix[2,3]² + 2 matrix[3,3]²"
    end
    S = [1, 3]
    @decision_variable(model, x[S], start = 1)
    @testset "sum(::DenseAxisArray{DecisionRef})" begin
        @test_expression sum(x)
        @test length(string(sum(x))) == 11
        @test occursin("x[1]", string(sum(x)))
        @test occursin("x[3]", string(sum(x)))
    end
    @testset "sum(::DenseAxisArray{T}) where T<:Real" begin
        @test sum(JuMP.start_value.(x)) == 2
    end

    @decision_variable(model, 0 ≤ dense_matrix[i in 1:3, a in [:a,:b]] ≤ 1, start = 1)
    @testset "sum(::DenseAxisArray{DecisionRef})" begin
        @test_expression_with_string sum(dense_matrix) "dense_matrix[1,a] + dense_matrix[2,a] + dense_matrix[3,a] + dense_matrix[1,b] + dense_matrix[2,b] + dense_matrix[3,b]"
    end
end

function runtests()
    @testset "DecisionOperators" begin
        for name in names(@__MODULE__; all = true)
            if !startswith("$(name)", "test_")
                continue
            end
            f = getfield(@__MODULE__, name)
            @testset "$(name)" begin
                f()
            end
        end
    end
end

end
