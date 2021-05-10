@everywhere module TestDecisionExpressions

using StochasticPrograms
using Test
using MathOptInterface
const MOI = MathOptInterface
const MOIU = MOI.Utilities
const MA = MOI.MutableArithmetics

function DecisionModel()
    m = Model()
    m.ext[:decisions] = Decisions(Val{1}())
    return m
end

macro decision_variable(m, x)
    return esc(quote
        @variable($m, $x, set = StochasticPrograms.DecisionSet(1))
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

function test_affine_expressions()
    @testset "isequal(::DecisionAffExpr)" begin
        m = DecisionModel()
        @decision_variable(m, x)
        @variable(m, y)
        @test isequal(x + y + 1, x + y + 1)
    end

    @testset "hash(::DecisionAffExpr)" begin
        m = DecisionModel()
        @decision_variable(m, x)
        @variable(m, y)
        @test hash(x + y + 1) == hash(x + y + 1)
    end

    @testset "drop_zeros!(::DecisionAffExpr)" begin
        m = DecisionModel()
        @decision_variable(m, x[1:2])
        @variable(m, y[1:2])
        expr = x[1] + x[2] + y[1] + y[2] - x[2] - y[2] + 1
        @test !isequal(expr, x[1] + y[1] + 1)
        JuMP.drop_zeros!(expr)
        @test isequal(expr, x[1] + y[1] + 1)
    end

    @testset "iszero(::DecisionAffExpr)" begin
        m = DecisionModel()
        @decision_variable(m, x)
        @variable(m, y)
        @test !iszero(x + y + 1)
        @test !iszero(x + y + 0)
        @test iszero(0 * x + 0 * y + 0)
        @test iszero(x - x + y - y)
    end

    @testset "add_to_expression!(::DecisionAffExpr{C}, ::VariableRef/DecisionRef)" begin
        m = DecisionModel()
        @decision_variable(m, x)
        @variable(m, y)
        aff = DecisionAffExpr(
            JuMP.GenericAffExpr(1.0, y => 2.0),
            zero(JuMP.GenericAffExpr{Float64,DecisionRef}),
        )
        @test JuMP.isequal_canonical(
            JuMP.add_to_expression!(aff, x),
            DecisionAffExpr(
                JuMP.GenericAffExpr(1.0, y => 2.0),
                JuMP.GenericAffExpr(0.0, x => 1.0),
            ),
        )
        @test JuMP.isequal_canonical(
            JuMP.add_to_expression!(aff, y),
            DecisionAffExpr(
                JuMP.GenericAffExpr(1.0, y => 3.0),
                JuMP.GenericAffExpr(0.0, x => 1.0),
            ),
        )
    end

    @testset "add_to_expression!(::DecisionAffExpr{C}, ::C)" begin
        m = DecisionModel()
        @decision_variable(m, x)
        @variable(m, y)
        aff = DecisionAffExpr(
            JuMP.GenericAffExpr(1.0, y => 2.0),
            JuMP.GenericAffExpr(0.0, x => 2.0),
        )
        @test JuMP.isequal_canonical(
            JuMP.add_to_expression!(aff, 1.0),
            DecisionAffExpr(
                JuMP.GenericAffExpr(2.0, y => 2.0),
                JuMP.GenericAffExpr(0.0, x => 2.0),
            ),
        )
    end

    @testset "coefficient(aff::DecisionAffExpr, v::VariableRef/DecisionRef)" begin
        m = DecisionModel()
        x1 = @decision_variable(m, x1)
        x2 = @decision_variable(m, x2)
        y1 = @variable(m, y1)
        y2 = @variable(m, y2)
        aff = @expression(m, 1.0 * x1 + 1.0 * y1)
        @test coefficient(aff, x1) == 1.0
        @test coefficient(aff, y1) == 1.0
        @test coefficient(aff, x2) == 0.0
        @test coefficient(aff, y2) == 0.0
    end

    @testset "coefficient(aff::DecisionAffExpr, v1::VariableRef/DecisionRef, v2::VariableRef/DecisionRef)" begin
        m = DecisionModel()
        x = @decision_variable(m, x1)
        y = @variable(m, y1)
        aff = @expression(m, 1.0 * x + 1.0 * y)
        @test coefficient(aff, x, x) == 0.0
        @test coefficient(aff, x, y) == 0.0
        @test coefficient(aff, y, x) == 0.0
        @test coefficient(aff, y, y) == 0.0
    end

    @testset "(+)(::DecisionAffExpr)" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string (+)(x + y + 1) "x + y + 1"
    end

    @testset "sum(::Vector{VariableRef/DecisionRef})" begin
        model = DecisionModel()
        x = @decision_variable(model, x[1:2])
        y = @variable(model, y[1:2])
        @test_expression_with_string sum(x) + sum(y) "x[1] + x[2] + y[1] + y[2]"
    end
end

function test_mutable_arithmetics()
    @testset "MA.add_mul!(ex::Number, c::Number, x::DecisionAffExpr)" begin
        m = DecisionModel()
        x = @decision_variable(m, x)
        y = @variable(m, y)
        aff = MA.add_mul!(1.0, 2.0, DecisionAffExpr(
            JuMP.GenericAffExpr(1.0, y => 1.0),
            JuMP.GenericAffExpr(0.0, x => 1.0),
        ))
        @test JuMP.isequal_canonical(aff, DecisionAffExpr(
            JuMP.GenericAffExpr(3.0, y => 2.0),
            JuMP.GenericAffExpr(0.0, x => 2.0),
        ))
    end

    @testset "MA.add_mul!(ex::Number, c::Number, x::DecisionQuadExpr) with c == 0" begin
        quad = MA.add_mul!(2.0, 0.0, DecisionQuadExpr{Float64}())
        @test JuMP.isequal_canonical(quad, convert(DecisionQuadExpr{Float64}, 2.0))
    end

    @testset "MA.add_mul!(ex::Number, c::VariableRef/DecisionRef, x::VariableRef/DecisionRef)" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(5.0, x, x) "x² + 5"
        @test_expression_with_string MA.add_mul!(5.0, x, x) "x² + 5"
        @test_expression_with_string MA.add_mul(5.0, x, y) "x*y + 5"
        @test_expression_with_string MA.add_mul!(5.0, x, y) "x*y + 5"
        @test_expression_with_string MA.add_mul(5.0, y, x) "x*y + 5"
        @test_expression_with_string MA.add_mul!(5.0, y, x) "x*y + 5"

    end

    @testset "MA.add_mul!(ex::Number, c::T, x::T) where T<:DecisionAffExpr" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(1.0, 2x + 2y, x + y + 1) "2 x² + 2 x + 4 x*y + 2 y² + 2 y + 1"
        @test_expression_with_string MA.add_mul!(1.0, 2x + 2y, x + y + 1) "2 x² + 2 x + 4 x*y + 2 y² + 2 y + 1"
    end

    @testset "MA.add_mul!(ex::Number, c::DecisionAffExpr{C}, x::VariableRef/DecisionRef) where C" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(1.0, 2x + 2y, x) "2 x² + 2 x*y + 1"
        @test_expression_with_string MA.add_mul!(1.0, 2x + 2y, x) "2 x² + 2 x*y + 1"
        @test_expression_with_string MA.add_mul(1.0, 2x + 2y, y) "2 x*y + 2 y² + 1"
        @test_expression_with_string MA.add_mul!(1.0, 2x + 2y, y) "2 x*y + 2 y² + 1"
    end

    @testset "MA.add_mul!(ex::Number, c::DecisionQuadExpr, x::Number)" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(0.0, x^2 + y^2 + x * y, 1.0) "x² + x*y + y²"
        @test_expression_with_string MA.add_mul!(0.0, x^2 + y^2 + x * y, 1.0) "x² + x*y + y²"
    end

    @testset "MA.add_mul!(ex::Number, c::DecisionQuadExpr, x::Number) with c == 0" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(0.0, x^2 + y^2 + x * y, 0.0) "0"
        @test_expression_with_string MA.add_mul!(0.0, x^2 + y^2 + x * y, 0.0) "0"
    end

    @testset "MA.add_mul!(aff::DecisionAffExpr{C}, c::VariableRef, x::GenericAffExpr{C,VariableRef}) where C" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(2x, y, y + 1) "2 x + y² + y"
        @test_expression_with_string MA.add_mul!(2x, y, y + 1) "2 x + y² + y"
    end

    @testset "MA.add_mul!(aff::DecisionAffExpr{C}, c::DecisionRef, x::GenericAffExpr{C,VariableRef}) where C" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(2x, x, y + 1) "3 x + x*y"
        @test_expression_with_string MA.add_mul!(2x, x, y + 1) "3 x + x*y"
    end

    @testset "MA.add_mul!(aff::DecisionAffExpr, c::VariableRef, x::DecisionAffExpr)" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(2x, y, x + 1) "2 x + x*y + y"
        @test_expression_with_string MA.add_mul!(2x, y, x + 1) "2 x + x*y + y"
    end

    @testset "MA.add_mul!(aff::DecisionAffExpr, c::DecisionRef, x::DecisionAffExpr)" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(2x, x, x + y + 1) "x² + 3 x + x*y"
        @test_expression_with_string MA.add_mul!(2x, x, x + y + 1) "x² + 3 x + x*y"
    end

    @testset "MA.add_mul!(aff::DecisionAffExpr{C}, c::GenericAffExpr{C,VariableRef}, x::Number) where C" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(2x, 2y, 1) "2 x + 2 y"
        @test_expression_with_string MA.add_mul!(2x, 2y, 1) "2 x + 2 y"
    end

    @testset "MA.add_mul!(aff::DecisionAffExpr{C}, c::GenericAffExpr{C,DecisionRef}, x::Number) where C" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        @test_expression_with_string MA.add_mul(2x, 2x, 1) "4 x"
        @test_expression_with_string MA.add_mul!(2x, 2x, 1) "4 x"
    end

    @testset "MA.add_mul!(aff::DecisionAffExpr{C}, c::GenericQuadExpr{C,VariableRef}, x::Number) where C" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(2x, y^2, 1) "2 x + y²"
        @test_expression_with_string MA.add_mul!(2x, y^2, 1) "2 x + y²"
    end

    @testset "MA.add_mul!(aff::DecisionAffExpr{C}, c::DecisionQuadExpr{C}, x::Number) where C" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(2x + 2y, x^2 + y^2, 1) "x² + 2 x + y² + 2 y"
        @test_expression_with_string MA.add_mul!(2x + 2y, x^2 + y^2, 1) "x² + 2 x + y² + 2 y"
    end

    @testset "MA.add_mul!(aff::DecisionAffExpr, c::DecisionQuadExpr, x::Number) with x == 0" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(2x + 2y, x^2 + y^2, 0) "2 x + 2 y"
        @test_expression_with_string MA.add_mul!(2x + 2y, x^2 + y^2, 0) "2 x + 2 y"
    end

    @testset "MA.add_mul!(aff::DecisionQuadExpr, c::Number, x::DecisionAffExpr) with c == 0" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(2x + 2y, 0, x^2 + y^2) "2 x + 2 y"
        @test_expression_with_string MA.add_mul!(2x + 2y, 0, x^2 + y^2) "2 x + 2 y"
    end

    @testset "MA.add_mul!(ex::DecisionAffExpr, c::DecisionAffExpr, x::DecisionAffExpr)" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        # GenericAffExpr, DecisionAffExpr
        @test_expression_with_string MA.add_mul(2x + 2y, y + 1, x + 0) "3 x + x*y + 2 y"
        @test_expression_with_string MA.add_mul!(2x + 2y, y + 1, x + 0) "3 x + x*y + 2 y"
        # DecisionAffExpr, GenericAffExpr
        @test_expression_with_string MA.add_mul(2x + 2y, x + 1, y + 0) "2 x + x*y + 3 y"
        @test_expression_with_string MA.add_mul!(2x + 2y, x + 1, y + 0) "2 x + x*y + 3 y"
        # DecisionAffExpr, DecisionAffExpr
        @test_expression_with_string MA.add_mul(2x + 2y, x + 1, x + 0) "x² + 3 x + 2 y"
        @test_expression_with_string MA.add_mul!(2x + 2y, x + 1, x + 0) "x² + 3 x + 2 y"
    end

    @testset "MA.add_mul!(quad::DecisionQuadExpr, c::DecisionAffExpr, x::Number)" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        # GenericAffExpr
        @test_expression_with_string MA.add_mul(x^2 + y^2, y + 1, 1) "x² + y² + y + 1"
        @test_expression_with_string MA.add_mul!(x^2 + y^2, y + 1, 1) "x² + y² + y + 1"
        # DecisionAffExpr
        @test_expression_with_string MA.add_mul(x^2 + y^2, x + y + 1, 1) "x² + x + y² + y + 1"
        @test_expression_with_string MA.add_mul!(x^2 + y^2, x + y + 1, 1) "x² + x + y² + y + 1"
    end

    @testset "MA.add_mul!(quad::DecisionQuadExpr, c::VariableRef, x::DecisionAffExpr)" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(x^2 + y^2, y, x + 1) "x² + x*y + y² + y"
        @test_expression_with_string MA.add_mul!(x^2 + y^2, y, x + 1) "x² + x*y + y² + y"
    end

    @testset "MA.add_mul!(quad::DecisionQuadExpr, c::DecisionRef, x::DecisionAffExpr)" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string MA.add_mul(x^2 + y^2, x, x + y + 1) "2 x² + x + x*y + y²"
        @test_expression_with_string MA.add_mul!(x^2 + y^2, x, x + y + 1) "2 x² + x + x*y + y²"
    end

    @testset "MA.add_mul!(quad::DecisionQuadExpr, c::DecisionQuadExpr, x::Number)" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        # GenericQuadExpr
        @test_expression_with_string MA.add_mul(x^2 + y^2 + x, y^2 + y, 2.0) "x² + x + 3 y² + 2 y"
        @test_expression_with_string MA.add_mul!(x^2 + y^2 + x, y^2 + y, 2.0) "x² + x + 3 y² + 2 y"
        # DecisionQuadExpr
        @test_expression_with_string MA.add_mul(x^2 + y^2 + x, x^2 + x, 2.0) "3 x² + 3 x + y²"
        @test_expression_with_string MA.add_mul!(x^2 + y^2 + x, x^2 + x, 2.0) "3 x² + 3 x + y²"
    end

    @testset "MA.add_mul!(ex::DecisionQuadExpr, c::DecisionAffExpr, x::DecisionAffExpr)" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        # GenericAffExpr, GenericAffExpr
        @test_expression_with_string MA.add_mul(x^2 + y^2 + x, y + 0, y + 1) "x² + x + 2 y² + y"
        @test_expression_with_string MA.add_mul!(x^2 + y^2 + x, y + 0, y + 1) "x² + x + 2 y² + y"
        # DecisionAffExpr, GenericAffExpr
        @test_expression_with_string MA.add_mul(x^2 + y^2 + x, x + 0, y + 1) "x² + 2 x + x*y + y²"
        @test_expression_with_string MA.add_mul!(x^2 + y^2 + x, x + 0, y + 1) "x² + 2 x + x*y + y²"
        # GenericAffExpr, DecisionAffExpr
        @test_expression_with_string MA.add_mul(x^2 + y^2 + x, y + 0, x + 1) "x² + x + x*y + y² + y"
        @test_expression_with_string MA.add_mul!(x^2 + y^2 + x, y + 0, x + 1) "x² + x + x*y + y² + y"
        # DecisionAffExpr, DecisionAffExpr
        @test_expression_with_string MA.add_mul(x^2 + y^2 + x, x + y, x + y + 1) "2 x² + 2 x + 2 x*y + 2 y² + y"
        @test_expression_with_string MA.add_mul!(x^2 + y^2 + x, x + y, x + y + 1) "2 x² + 2 x + 2 x*y + 2 y² + y"
    end
end

function test_quadratic_expressions()
    @testset "isequal(::DecisionQuadExpr)" begin
        m = DecisionModel()
        @decision_variable(m, x)
        @variable(m, y)
        @test isequal(x^2 + 2*x*y + y^2 + 1, x^2 + 2*x*y + y^2 + 1)
    end

    @testset "hash(::DecisionQuadExpr)" begin
        m = DecisionModel()
        @decision_variable(m, x)
        @variable(m, y)
        @test hash(x^2 + 2*x*y + y^2 + 1) == hash(x^2 + 2*x*y + y^2 + 1)
    end

    @testset "drop_zeros!(::DecisionQuadExpr)" begin
        m = DecisionModel()
        @decision_variable(m, x[1:2])
        @variable(m, y[1:2])
        expr = x[1]^2 + x[2]^2 + x[1] + x[2] + 2*x[1]*y[1] + 2*x[2]*y[2] + y[1]^2 + y[2]^2 + y[1] + y[2] - x[2]^2 - y[2]^2 - 2*x[2]*y[2] - x[2] - y[2] + 1
        @test !isequal(expr, x[1]^2 + x[1] + 2*x[1]*y[1] + y[1]^2 + y[1] + 1)
        JuMP.drop_zeros!(expr)
        @test isequal(expr, x[1]^2 + x[1] + 2*x[1]*y[1] + y[1]^2 + y[1] + 1)
    end

    @testset "iszero(::DecisionQuadExpr)" begin
        m = DecisionModel()
        @decision_variable(m, x)
        @variable(m, y)
        @test !iszero(x^2 + x*y + y^2 + 1)
        @test !iszero(x^2 + x*y + y^2 + 0)
        @test iszero(0 * x^2 + 0 * x + 0 * x * y + 0 * y^2 + 0 * y + 0)
        @test iszero(x^2 - x^2 + y^2 - y^2 + x*y - x*y)
    end

    @testset "coefficient(quad::DecisionQuadExpr, v::VariableRef/DecisionRef)" begin
        m = DecisionModel()
        x = @decision_variable(m, x)
        y = @variable(m, y)
        z = @decision_variable(m, z)
        w = @variable(m, w)
        quad = @expression(m, 6.0 * x^2 + 5.0 * x * y + 2.0 * y + 3.0 * x)
        @test coefficient(quad, x) == 3.0
        @test coefficient(quad, y) == 2.0
        @test coefficient(quad, z) == 0.0
        @test coefficient(quad, w) == 0.0
    end

    @testset "coefficient(quad::Quad, v1::VariableRef/DecisionRef, v2::VariableRef/DecisionRef)" begin
        m = DecisionModel()
        x = @decision_variable(m, x)
        y = @variable(m, y)
        z = @decision_variable(m, z)
        w = @variable(m, w)
        quad = @expression(m, 6.0 * x^2 + 5.0 * x * y + 4.0 * y^2 + 2.0 * y + 3.0 * x + y * w)
        @test coefficient(quad, x, y) == 5.0
        @test coefficient(quad, x, x) == 6.0
        @test coefficient(quad, y, y) == 4.0
        @test coefficient(quad, x, y) == coefficient(quad, y, x)
        @test coefficient(quad, y, w) == 1.0
        @test coefficient(quad, z, z) == 0.0
        @test coefficient(quad, w, w) == 0.0
    end

    @testset "(+)(::DecisionQuadExpr)" begin
        model = DecisionModel()
        x = @decision_variable(model, x)
        y = @variable(model, y)
        @test_expression_with_string (+)(x^2 + 2*x*y + y^2 + 1) "x² + 2 x*y + y² + 1"
    end
end

function runtests()
    @testset "DecisionExpressions" begin
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
