# Quadratic decision function #
# ========================== #

# Helper structs to differentiate between
# QuadraticDecisionFunctions that are ultimately
# linear or
abstract type LinearQuadraticPart{T} end
struct LinearPart{T} <: LinearQuadraticPart{T}
    variable_part::MOI.ScalarAffineFunction{T}
    decision_part::MOI.ScalarAffineFunction{T}
end
struct QuadraticPart{T} <: LinearQuadraticPart{T}
    variable_part::MOI.ScalarQuadraticFunction{T}
    decision_part::MOI.ScalarQuadraticFunction{T}
    cross_terms::MOI.ScalarQuadraticFunction{T}
end

struct QuadraticDecisionFunction{T, LQ <: LinearQuadraticPart{T}} <: MOI.AbstractScalarFunction
    linear_quadratic_terms::LQ
    known_part::MOI.ScalarQuadraticFunction{T}
    known_variable_terms::MOI.ScalarQuadraticFunction{T}
    known_decision_terms::MOI.ScalarQuadraticFunction{T}
end

# Base overrides #
# ========================== #
function Base.copy(lq::L) where L <: LinearPart
    return L(copy(lq.variable_part),
             copy(lq.decision_part))
end
function Base.copy(lq::Q) where Q <: QuadraticPart
    return Q(copy(lq.variable_part),
             copy(lq.decision_part),
             copy(lq.cross_terms))
end
function Base.copy(f::F) where F <: QuadraticDecisionFunction
    return F(copy(f.linear_quadratic_terms),
             copy(f.known_part),
             copy(f.known_variable_terms),
             copy(f.known_decision_terms))
end

function Base.convert(::Type{LinearPart{T}}, α::T) where T
    return LinearPart{T}(
        convert(MOI.ScalarAffineFunction{T}, α),
        convert(MOI.ScalarAffineFunction{T}, zero(T)))
end
function Base.convert(::Type{QuadraticPart{T}}, α::T) where T
    return QuadraticPart{T}(
        convert(MOI.ScalarQuadraticFunction{T}, α),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end
function Base.convert(::Type{QuadraticDecisionFunction{T,LQ}}, α::T) where {T, LQ <: LinearQuadraticPart{T}}
    return QuadraticDecisionFunction{T,LQ}(
        convert(LQ, α),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end

function Base.convert(::Type{LinearPart{T}},
                      f::MOI.SingleVariable) where T
    return LinearPart{T}(
        convert(MOI.ScalarAffineFunction{T}, f),
        convert(MOI.ScalarAffineFunction{T}, zero(T)))
end
function Base.convert(::Type{QuadraticPart{T}},
                      f::MOI.SingleVariable) where T
    return QuadraticPart{T}(
        convert(MOI.ScalarQuadraticFunction{T}, f),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end
function Base.convert(::Type{QuadraticDecisionFunction{T,LQ}},
                      f::MOI.SingleVariable) where {T, LQ <: LinearQuadraticPart{T}}
    return QuadraticDecisionFunction{T}(
        convert(LQ, f),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end

function Base.convert(::Type{LinearPart{T}},
                      f::SingleDecision) where T
    return LinearPart{T}(
        convert(MOI.ScalarAffineFunction{T}, zero(T)),
        convert(MOI.ScalarAffineFunction{T}, f))
end
function Base.convert(::Type{QuadraticPart{T}},
                      f::SingleDecision) where T
    return QuadraticPart{T}(
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, f),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end
function Base.convert(::Type{QuadraticDecisionFunction{T,LQ}},
                      f::SingleDecision) where {T, LQ <: LinearQuadraticPart{T}}
    return QuadraticDecisionFunction{T}(
        convert(LQ, f),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end

function Base.convert(::Type{QuadraticDecisionFunction{T,LQ}},
                      f::SingleKnown) where {T, LQ <: LinearQuadraticPart{T}}
    return QuadraticDecisionFunction{T}(
        convert(LQ, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, f),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end

function Base.convert(::Type{LinearPart{T}},
                      f::MOI.ScalarAffineFunction{T}) where T
    return LinearPart{T}(
        convert(MOI.ScalarAffineFunction{T}, f),
        convert(MOI.ScalarAffineFunction{T}, zero(T)))
end
function Base.convert(::Type{QuadraticPart{T}},
                      f::MOI.ScalarAffineFunction{T}) where T
    return QuadraticPart{T}(
        convert(MOI.ScalarQuadraticFunction{T}, f),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end
function Base.convert(::Type{QuadraticDecisionFunction{T,LQ}},
                      f::MOI.ScalarAffineFunction{T}) where {T, LQ <: LinearQuadraticPart{T}}
    return QuadraticDecisionFunction{T}(
        convert(LQ, f),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end

function Base.convert(::Type{QuadraticPart{T}},
                      f::MOI.ScalarQuadraticFunction{T}) where T
    return QuadraticPart{T}(
        f,
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end
function Base.convert(::Type{QuadraticDecisionFunction{T,QuadraticPart{T}}},
                      f::MOI.ScalarQuadraticFunction{T}) where T
    return QuadraticDecisionFunction{T}(
        convert(QuadraticPart{T}, f),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end

function Base.convert(::Type{LinearPart{T}},
                      f::AffineDecisionFunction{T}) where T
    return LinearPart{T}(
        f.variable_part,
        f.decision_part)
end
function Base.convert(::Type{QuadraticPart{T}},
                      f::AffineDecisionFunction{T}) where T
    return QuadraticPart{T}(
        convert(MOI.ScalarQuadraticFunction{T}, f.variable_part),
        convert(MOI.ScalarQuadraticFunction{T}, f.decision_part),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end
function Base.convert(::Type{QuadraticDecisionFunction{T,LQ}},
                      f::AffineDecisionFunction{T}) where {T, LQ <: LinearQuadraticPart{T}}
    return QuadraticDecisionFunction{T}(
        convert(LQ, f),
        convert(MOI.ScalarQuadraticFunction{T}, f.known_part),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
end

function Base.convert(::Type{QuadraticDecisionFunction{T,QuadraticPart{T}}},
                      f::QuadraticDecisionFunction{T,LinearPart{T}}) where T
    lq = f.linear_quadratic_terms
    return QuadraticDecisionFunction{T}(
        QuadraticPart(
            convert(MOI.ScalarQuadraticFunction{T}, lq.variable_part),
            convert(MOI.ScalarQuadraticFunction{T}, lq.decision_part),
            convert(MOI.ScalarQuadraticFunction{T}, zero(T))),
        copy(f.known_part),
        copy(f.known_variable_terms),
        copy(f.known_decision_terms))
end

function Base.convert(::Type{MOI.SingleVariable},
                      f::QuadraticDecisionFunction{T}) where T
    return convert(MOI.SingleVariable, convert(AffineDecisionFunction{T}, f))
end

function Base.convert(::Type{SingleDecision},
                      f::QuadraticDecisionFunction{T}) where T
    return convert(SingleDecision, convert(AffineDecisionFunction{T}, f.variable_part))
end

function Base.convert(::Type{AffineDecisionFunction{T}},
                      f::QuadraticDecisionFunction{T}) where T
    lq = f.linear_quadratic_terms
    if !Base.isempty(lq.cross_terms.quadratic_terms)
        throw(InexactError(:convert, AffineDecisionFunction{T}, f))
    end
    if !Base.isempty(f.known_cross_terms.quadratic_terms)
        throw(InexactError(:convert, AffineDecisionFunction{T}, f))
    end
    return AffineDecisionFunction{T}(
        convert(MOI.ScalarAffineFunction{T}, lq.variable_part),
        convert(MOI.ScalarAffineFunction{T}, lq.decision_part),
        convert(MOI.ScalarAffineFunction{T}, f.known_part))
end

function Base.convert(::Type{QuadraticDecisionFunction{T,LinearPart{T}}},
                      f::QuadraticDecisionFunction{T,QuadraticPart{T}}) where T
    lq = f.linear_quadratic_terms
    if !Base.isempty(lq.cross_terms.quadratic_terms)
        throw(InexactError(:convert, QuadraticDecisionFunction{T,LinearPart{T}}, f))
    end
    return QuadraticDecisionFunction(
        LinearPart(
            convert(MOI.ScalarAffineFunction{T}, lq.variable_part),
            convert(MOI.ScalarAffineFunction{T}, lq.decision_part)),
        copy(f.known_part),
        copy(f.known_variable_terms),
        copy(f.known_decision_terms))
end

function Base.zero(F::Type{QuadraticDecisionFunction{T,LQ}}) where {T, LQ <: LinearQuadraticPart{T}}
    return convert(F, zero(T))
end

function Base.iszero(f::QuadraticDecisionFunction)
    return iszero(MOI.constant(f)) && MOIU._is_constant(MOIU.canonical(f))
end

function Base.isone(f::QuadraticDecisionFunction)
    return isone(MOI.constant(f)) && MOIU._is_constant(MOIU.canonical(f))
end

function Base.one(F::Type{QuadraticDecisionFunction{T}}) where T
    return convert(F, one(T))
end

# JuMP overrides #
# ========================== #
function QuadraticDecisionFunction(quad::DQE)
    JuMP._assert_isfinite(quad)
    # Variable part
    variable_part = JuMP.moi_function(quad.variables)
    # Decision part
    decision_affine_terms =  Vector{MOI.ScalarAffineTerm{Float64}}()
    for (coef, dvar) in linear_terms(quad.decisions.aff)
        # Any fixed decision value is set in the decision bridge
        push!(decision_affine_terms, MOI.ScalarAffineTerm(coef, index(dvar)))
    end
    decision_quad_terms = Vector{MOI.ScalarQuadraticTerm{Float64}}()
    for t in quad_terms(quad.decisions)
        # Any fixed decision value is set in the decision bridge
        push!(decision_quad_terms, JuMP._moi_quadratic_term(t))
    end
    # Cross terms
    cross_terms = Vector{MOI.ScalarQuadraticTerm{Float64}}()
    for (cross_term, coeff) in quad.cross_terms
        # Any fixed decision value is set in the decision bridge
        push!(cross_terms,
              MOI.ScalarQuadraticTerm(coeff, index(cross_term.decision), index(cross_term.variable)))
    end
    # Known part
    known_affine_terms = Vector{MOI.ScalarAffineTerm{Float64}}()
    known_value = 0.0
    for (coef, kvar) in linear_terms(quad.knowns.aff)
        # Save the known terms to handle modifications in bridges
        push!(known_affine_terms, MOI.ScalarAffineTerm(coef, index(kvar)))
        # Then give the known values directly
        known_value += coef * value(kvar)
    end
    known_quad_terms = Vector{MOI.ScalarQuadraticTerm{Float64}}()
    for t in quad_terms(quad.knowns)
        # Save the known terms to handle modifications in bridges
        push!(known_quad_terms, JuMP._moi_quadratic_term(t))
        # Then give the known values directly
        (coeff, var_1, var_2) = t
        known_value += coeff * value(var_1) * value(var_2)
    end
    # Known/variable cross terms
    known_variable_terms = Vector{MOI.ScalarQuadraticTerm{Float64}}()
    for (cross_term, coeff) in quad.known_variable_terms
        # Any known decision is set in the known bridge
        push!(known_variable_terms,
              MOI.ScalarQuadraticTerm(coeff, index(cross_term.known), index(cross_term.variable)))
    end
    # Known/decision cross terms
    known_decision_terms = Vector{MOI.ScalarQuadraticTerm{Float64}}()
    for (cross_term, coeff) in quad.known_decision_terms
        # Any known decision is set in the known bridge
        push!(known_decision_terms,
              MOI.ScalarQuadraticTerm(coeff, index(cross_term.known), index(cross_term.variable)))
    end
    # Check if function has quadratic terms
    if isempty(variable_part.quadratic_terms) &&
        isempty(decision_quad_terms) &&
        isempty(cross_terms)
        # Create QuadraticDecisionFunction with LinearPart
        return QuadraticDecisionFunction(
            LinearPart(convert(MOI.ScalarAffineFunction{Float64}, variable_part),
                       MOI.ScalarAffineFunction{Float64}(decision_affine_terms, 0.0)),
            MOI.ScalarQuadraticFunction(known_affine_terms,
                                        known_quad_terms,
                                        known_value),
            MOI.ScalarQuadraticFunction(MOI.ScalarAffineTerm{Float64}[],
                                        known_variable_terms,
                                        0.0),
            MOI.ScalarQuadraticFunction(MOI.ScalarAffineTerm{Float64}[],
                                        known_decision_terms,
                                        0.0)
        )
    end
    # Return QuadraticDecisionFunction with QuadraticPart
    return QuadraticDecisionFunction(
        QuadraticPart(
            variable_part,
            MOI.ScalarQuadraticFunction(decision_affine_terms,
                                        decision_quad_terms,
                                        0.0),
            MOI.ScalarQuadraticFunction(MOI.ScalarAffineTerm{Float64}[],
                                        cross_terms,
                                        0.0)),
        MOI.ScalarQuadraticFunction(known_affine_terms,
                                    known_quad_terms,
                                    known_value),
        MOI.ScalarQuadraticFunction(MOI.ScalarAffineTerm{Float64}[],
                                    known_variable_terms,
                                    0.0),
        MOI.ScalarQuadraticFunction(MOI.ScalarAffineTerm{Float64}[],
                                    known_decision_terms,
                                    0.0))
end
JuMP.moi_function(quad::DQE) = QuadraticDecisionFunction(quad)
function JuMP.moi_function_type(::Type{DecisionQuadExpr{T}}) where T
    return QuadraticDecisionFunction{T,QuadraticPart{T}}
end

JuMP.moi_function(quad::BDE) = QuadraticDecisionFunction(quad)
function JuMP.moi_function_type(::Type{BilinearDecisionExpr{T}}) where T
    return QuadraticDecisionFunction{T,LinearPart{T}}
end

QuadraticDecisionFunction(quad::_DQE) = QuadraticDecisionFunction(convert(DQE, quad))
QuadraticDecisionFunction(quad::_KQE) = QuadraticDecisionFunction(convert(DQE, quad))

function _DecisionQuadExpr(m::Model, f::MOI.ScalarQuadraticFunction)
    quad = _DQE(_DecisionAffExpr(m, MOI.ScalarAffineFunction(f.affine_terms, 0.0)))
    for t in f.quadratic_terms
        v1 = t.variable_index_1
        v2 = t.variable_index_2
        coef = t.coefficient
        if v1 == v2
            coef /= 2
        end
        JuMP.add_to_expression!(quad, coef, DecisionRef(m, v1), DecisionRef(m, v2))
    end
    # There should not be any constants in the decision terms
    return quad
end

function _KnownQuadExpr(m::Model, f::MOI.ScalarQuadraticFunction)
    quad = _KQE(_KnownAffExpr(m, MOI.ScalarAffineFunction(f.affine_terms, 0.0)))
    for t in f.quadratic_terms
        v1 = t.variable_index_1
        v2 = t.variable_index_2
        coef = t.coefficient
        if v1 == v2
            coef /= 2
        end
        JuMP.add_to_expression!(quad, coef, KnownRef(m, v1), KnownRef(m, v2))
    end
    # There should not be any constants in the known terms
    return quad
end

function DQE(model::Model, f::QuadraticDecisionFunction{T}) where T
    lq = f.linear_quadratic_terms
    # Decision part
    cross_terms = OrderedDict{DecisionCrossTerm, Float64}()
    if lq isa QuadraticPart
        for term in lq.cross_terms.quadratic_terms
            cross_term = DecisionCrossTerm(
                DecisionRef(model, term.variable_index_1),
                VariableRef(model, term.variable_index_2))
            JuMP._add_or_set!(cross_terms, cross_term, term.coefficient)
        end
    end
    # Known/variable cross terms
    known_variable_terms = OrderedDict{KnownVariableCrossTerm, Float64}()
    for term in f.known_variable_terms.quadratic_terms
        cross_term = KnownVariableCrossTerm(
            KnownRef(model, term.variable_index_1),
            VariableRef(model, term.variable_index_2))
        JuMP._add_or_set!(known_variable_terms, cross_term, term.coefficient)
    end
    # Known/decision cross terms
    known_decision_terms = OrderedDict{KnownDecisionCrossTerm, Float64}()
    for term in f.known_decision_terms.quadratic_terms
        cross_term = KnownDecisionCrossTerm(
            KnownRef(model, term.variable_index_1),
            DecisionRef(model, term.variable_index_2))
        JuMP._add_or_set!(known_decision_terms, cross_term, term.coefficient)
    end
    return DQE(QuadExpr(model,
                        convert(MOI.ScalarQuadraticFunction{T}, lq.variable_part)),
               _DecisionQuadExpr(model,
                                convert(MOI.ScalarQuadraticFunction{T}, lq.decision_part)),
               _KnownQuadExpr(model, f.known_part),
               cross_terms,
               known_variable_terms,
               known_decision_terms)
end

function JuMP.jump_function_type(::Model,
                                 ::Type{QuadraticDecisionFunction{T,LinearPart{T}}}) where T
    return BilinearDecisionExpr{T}
end
function JuMP.jump_function_type(::Model,
                                 ::Type{QuadraticDecisionFunction{T,QuadraticPart{T}}}) where T
    return DecisionQuadExpr{T}
end
function JuMP.jump_function(model::Model, f::QuadraticDecisionFunction{T}) where T
    return DecisionQuadExpr{T}(model, f)
end

# MOI Function interface #
# ========================== #
MOI.constant(f::QuadraticDecisionFunction) =
    MOI.constant(f.linear_quadratic_terms.variable_part)
MOI.constant(f::QuadraticDecisionFunction, T::DataType) = MOI.constant(f)

function MOIU.eval_variables(varval::Function, f::LinearPart)
    var_value = MOIU.eval_variables(varval, f.variable_part)
    dvar_value = MOIU.eval_variables(varval, f.decision_part)
    return var_value + dvar_value
end
function MOIU.eval_variables(varval::Function, f::QuadraticPart)
    var_value = MOIU.eval_variables(varval, f.variable_part)
    dvar_value = MOIU.eval_variables(varval, f.decision_part)
    cross_value = MOIU.eval_variables(varval, f.cross_terms)
    return var_value + dvar_value + cross_value
end
function MOIU.eval_variables(varval::Function, f::QuadraticDecisionFunction)
    lq_value = MOIU.eval_variables(varval, f.linear_quadratic_terms)
    known_value = f.known_part.constant
    known_variable_value = MOIU.eval_variables(varval, f.known_variable_terms)
    known_decision_value = MOIU.eval_variables(varval, f.known_decision_terms)
    return lq_value + known_value + known_variable_value + known_decision_value
end

function MOIU.map_indices(index_map::Function, f::LinearPart{T}) where T
    return typeof(f)(MOIU.map_indices(index_map, f.variable_part),
                     MOIU.map_indices(index_map, f.decision_part))
end
function MOIU.map_indices(index_map::Function, f::QuadraticPart{T}) where T
    return typeof(f)(MOIU.map_indices(index_map, f.variable_part),
                     MOIU.map_indices(index_map, f.decision_part),
                     MOIU.map_indices(index_map, f.cross_terms))
end
function MOIU.map_indices(index_map::Function, f::QuadraticDecisionFunction{T}) where T
    return typeof(f)(MOIU.map_indices(index_map, f.linear_quadratic_terms),
                     MOIU.map_indices(index_map, f.known_part),
                     MOIU.map_indices(index_map, f.known_variable_terms),
                     MOIU.map_indices(index_map, f.known_decision_terms))
end

function MOIU.substitute_variables(variable_map::Function, f::QuadraticDecisionFunction{T, LinearPart{T}}) where T
    lq = f.linear_quadratic_terms
    g = QuadraticDecisionFunction(
        LinearPart(convert(MOI.ScalarAffineFunction{T}, MOI.constant(lq.variable_part)),
                   convert(MOI.ScalarAffineFunction{T}, zero(T))),
        MOI.ScalarQuadraticFunction{T}(
            f.known_part.affine_terms,
            f.known_part.quadratic_terms,
            zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
    g_lq = g.linear_quadratic_terms
    # Substitute variables
    for term in lq.variable_part.terms
        new_term = MOIU.substitute_variables(variable_map, term)
        MOIU.operate!(+, T, g_lq.variable_part, new_term)::MOI.ScalarAffineFunction{T}
    end
    # Substitute decisions
    for term in lq.decision_part.terms
        new_term = MOIU.substitute_variables(variable_map, term)
        if iszero(new_term.constant) && term != new_term.terms[1]
            # If there no fixed value, the decision has been mapped to a variable
            MOIU.operate!(+, T, g_lq.variable_part, new_term)::MOI.ScalarAffineFunction{T}
            # Otherwise, decision has been fixed and is added to decision part constant below
        end
        # Always keep the full term in order to properly unbridge and handle modifications
        MOIU.operate!(+, T, g_lq.decision_part, new_term)::MOI.ScalarAffineFunction{T}
    end
    # Substitute knowns
    _substitute_knowns(variable_map, f, g)
    return g
end

function MOIU.substitute_variables(variable_map::Function, f::QuadraticDecisionFunction{T, QuadraticPart{T}}) where T
    lq = f.linear_quadratic_terms
    g = QuadraticDecisionFunction(
        QuadraticPart(convert(MOI.ScalarQuadraticFunction{T}, MOI.constant(lq.variable_part)),
                      convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
                      convert(MOI.ScalarQuadraticFunction{T}, zero(T))),
        MOI.ScalarQuadraticFunction{T}(
            f.known_part.affine_terms,
            f.known_part.quadratic_terms,
            zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)),
        convert(MOI.ScalarQuadraticFunction{T}, zero(T)))
    g_lq = g.linear_quadratic_terms
    # Substitute variables
    for term in lq.variable_part.affine_terms
        new_term = MOIU.substitute_variables(variable_map, term)
        MOIU.operate!(+, T, g_lq.variable_part, new_term)::MOI.ScalarQuadraticFunction{T}
    end
    for term in lq.variable_part.quadratic_terms
        new_term = MOIU.substitute_variables(variable_map, term)
        MOIU.operate!(+, T, g_lq.variable_part, new_term)::MOI.ScalarQuadraticFunction{T}
    end
    # Substitute decisions
    for term in lq.decision_part.affine_terms
        new_term = MOIU.substitute_variables(variable_map, term)
        if iszero(new_term.constant) && term != new_term.terms[1]
            # If there no fixed value, the decision has been mapped to a variable
            MOIU.operate!(+, T, g_lq.variable_part, new_term)::MOI.ScalarQuadraticFunction{T}
            # Otherwise, decision has been fixed and is added to decision part constant below
        end
        # Always keep the full term in order to properly unbridge and handle modifications
        MOIU.operate!(+, T, g_lq.decision_part, new_term)::MOI.ScalarQuadraticFunction{T}
    end
    for term in lq.decision_part.quadratic_terms
        new_term = MOIU.substitute_variables(variable_map, term)
        if iszero(new_term.constant) && term != new_term.quadratic_terms[1]
            # If there no fixed value, the decision has been mapped to a variable
            MOIU.operate!(+, T, g_lq.variable_part, new_term)::MOI.ScalarQuadraticFunction{T}
            # Otherwise, decision has been fixed and is added to decision part constant below
        end
        # Remove any linear cross terms
        empty!(new_term.affine_terms)
        # Always keep the full term in order to properly unbridge and handle modifications
        MOIU.operate!(+, T, g_lq.decision_part, new_term)::MOI.ScalarQuadraticFunction{T}
    end
    # Substitute decisions in cross terms
    for term in lq.cross_terms.quadratic_terms
        new_term = MOIU.substitute_variables(variable_map, term)
        if isempty(new_term.affine_terms)
            # If there is no fixed value, the decision in the cross term has been mapped to a variable
            MOIU.operate!(+, T, g_lq.variable_part, new_term)::MOI.ScalarQuadraticFunction{T}
        else
            # Decision has been fixed to a value,
            # giving an affine term, which can be
            # repeated in g already
            for term in new_term.affine_terms
                add_term!(g_lq.variable_part.affine_terms, term)
            end
        end
        # Always keep the cross terms in order to properly unbridge and handle modifications
        MOIU.operate!(+, T, g_lq.cross_terms, new_term)::MOI.ScalarQuadraticFunction{T}
    end
    # Substitute knowns
    _substitute_knowns(variable_map, f, g)
    return g
end

function _substitute_knowns(variable_map::Function, f::QuadraticDecisionFunction{T}, g::QuadraticDecisionFunction{T}) where T
    lq = g.linear_quadratic_terms
    # Substitute known decisions
    for term in f.known_part.affine_terms
        # Known value acquired during substitution
        new_term = MOIU.substitute_variables(variable_map, term)
        # Add the known value to the constant of the known part
        MOIU.operate!(+, T, g.known_part, new_term)::MOI.ScalarQuadraticFunction{T}
    end
    for term in f.known_part.quadratic_terms
        # Known value acquired during substitution
        new_term = MOIU.substitute_variables(variable_map, term)
        # Add the known value to the constant of the known part
        MOIU.operate!(+, T, g.known_part, new_term)::MOI.ScalarQuadraticFunction{T}
    end
    # Substitute knowns in known/variable cross terms
    for term in f.known_variable_terms.quadratic_terms
        # First map only the variable part of the cross term
        known = MOI.SingleVariable(term.variable_index_1)
        mapped_variable = variable_map(term.variable_index_2)
        new_term = MOIU.operate(*, T, known, mapped_variable)::MOI.ScalarQuadraticFunction{T}
        MOIU.operate!(*, T, new_term, term.coefficient)
        # Just keep the mapped cross term to properly unbridge and handle modifications
        MOIU.operate!(+, T, g.known_variable_terms, new_term)::MOI.ScalarQuadraticFunction{T}
        # Now, perform the actual substitution
        new_term = MOIU.substitute_variables(variable_map, term)
        for term in new_term.affine_terms
            if lq isa LinearPart
                add_term!(lq.variable_part.terms, term)
            elseif lq isa QuadraticPart
                add_term!(lq.variable_part.affine_terms, term)
            end
        end
        # Always keep the full term in order to properly unbridge and handle modifications
        MOIU.operate!(+, T, g.known_variable_terms, new_term)::MOI.ScalarQuadraticFunction{T}
    end
    # Substitute knowns/decisions in known/decision cross terms
    for term in f.known_decision_terms.quadratic_terms
        # First map only the decision part of the cross term
        known = MOI.SingleVariable(term.variable_index_1)
        mapped_variable = convert(MOI.SingleVariable, variable_map(term.variable_index_2))
        new_term = MOIU.operate(*, T, known, mapped_variable)::MOI.ScalarQuadraticFunction{T}
        MOIU.operate!(*, T, new_term, term.coefficient)
        # Just keep the mapped cross term to properly unbridge and handle modifications
        MOIU.operate!(+, T, g.known_decision_terms, new_term)::MOI.ScalarQuadraticFunction{T}
        # Now, perform the actual substitution
        new_term = MOIU.substitute_variables(variable_map, term)::MOI.ScalarQuadraticFunction{T}
        if iszero(new_term.constant)
            for term in new_term.affine_terms
                # Decision has been mapped to a variable
                # giving an affine term, which can be
                # included in g already
                if lq isa LinearPart
                    add_term!(lq.variable_part.terms, term)
                    add_term!(lq.decision_part.terms, term)
                elseif lq isa QuadraticPart
                    add_term!(lq.variable_part.affine_terms, term)
                    add_term!(lq.decision_part.affine_terms, term)
                end
                # Otherwise, decision has been fixed and is added to the known/decision constant below
            end
        end
        # Always keep the full term in order to properly unbridge and handle modifications
        MOIU.operate!(+, T, g.known_decision_terms, new_term)::MOI.ScalarQuadraticFunction{T}
    end
end

MOIU.is_canonical(f::LinearPart) =
    MOIU.is_canonical(f.variable_part) &&
    MOIU.is_canonical(f.decision_part)
MOIU.is_canonical(f::QuadraticPart) =
    MOIU.is_canonical(f.variable_part) &&
    MOIU.is_canonical(f.decision_part) &&
    MOIU.is_canonical(f.cross_terms)
MOIU.is_canonical(f::QuadraticDecisionFunction) =
    MOIU.is_canonical(f.linear_quadratic_terms) &&
    MOIU.is_canonical(f.known_part) &&
    MOIU.is_canonical(f.known_variable_terms) &&
    MOIU.is_canonical(f.known_decision_terms)

MOIU.canonical(f::QuadraticDecisionFunction) = MOIU.canonicalize!(copy(f))

function MOIU.canonicalize!(f::LinearPart)
    MOIU.canonicalize!(f.variable_part)
    MOIU.canonicalize!(f.decision_part)
    return f
end
function MOIU.canonicalize!(f::QuadraticPart)
    MOIU.canonicalize!(f.variable_part)
    MOIU.canonicalize!(f.decision_part)
    MOIU.canonicalize!(f.cross_terms)
    return f
end
function MOIU.canonicalize!(f::QuadraticDecisionFunction)
    MOIU.canonicalize!(f.linear_quadratic_terms)
    MOIU.canonicalize!(f.known_part)
    MOIU.canonicalize!(f.known_variable_terms)
    MOIU.canonicalize!(f.known_decision_terms)
    return f
end

MOIU._is_constant(f::LinearPart) =
    MOIU._is_constant(f.variable_part) &&
    MOIU._is_constant(f.decision_part)
MOIU._is_constant(f::QuadraticPart) =
    MOIU._is_constant(f.variable_part) &&
    MOIU._is_constant(f.decision_part) &&
    MOIU._is_constant(f.cross_terms)
MOIU._is_constant(f::QuadraticDecisionFunction) =
    MOIU._is_constant(f.linear_quadratic_terms) &&
    MOIU._is_constant(f.known_part) &&
    MOIU._is_constant(f.known_variable_terms) &&
    MOIU._is_constant(f.known_decision_terms)

MOIU.all_coefficients(p::Function, f::LinearPart) =
    MOIU.all_coefficients(p, f.variable_part) &&
    MOIU.all_coefficients(p, f.decision_part)
MOIU.all_coefficients(p::Function, f::QuadraticPart) =
    MOIU.all_coefficients(p, f.variable_part) &&
    MOIU.all_coefficients(p, f.decision_part) &&
    MOIU.all_coefficients(p, f.cross_terms)
MOIU.all_coefficients(p::Function, f::QuadraticDecisionFunction) =
    MOIU.all_coefficients(p, f.linear_quadratic_terms) &&
    MOIU.all_coefficients(p, f.known_part) &&
    MOIU.all_coefficients(p, f.known_variable_terms) &&
    MOIU.all_coefficients(p, f.known_decision_terms)

MOIU.isapprox_zero(f::LinearPart, tol) =
    MOIU.isapprox_zero(f.variable_part, tol) &&
    MOIU.isapprox_zero(f.decision_part, tol)
MOIU.isapprox_zero(f::QuadraticPart, tol) =
    MOIU.isapprox_zero(f.variable_part, tol) &&
    MOIU.isapprox_zero(f.decision_part, tol) &&
    MOIU.isapprox_zero(f.cross_terms, tol)
MOIU.isapprox_zero(f::QuadraticDecisionFunction, tol) =
    MOIU.isapprox_zero(f.linear_quadratic_terms, tol) &&
    MOIU.isapprox_zero(f.known_part, tol) &&
    MOIU.isapprox_zero(f.known_variable_terms, tol) &&
    MOIU.isapprox_zero(f.known_decision_terms, tol)

function MOIU.filter_variables(keep::Function, f::LinearPart)
    return typeof(f)(MOIU.filter_variables(keep, f.variable_part),
                     MOIU.filter_variables(keep, f.decision_part))
end
function MOIU.filter_variables(keep::Function, f::QuadraticPart)
    return typeof(f)(MOIU.filter_variables(keep, f.variable_part),
                     MOIU.filter_variables(keep, f.decision_part),
                     MOIU.filter_variables(keep, f.cross_terms))
end
function MOIU.filter_variables(keep::Function, f::QuadraticDecisionFunction)
    # Only filter variable part, decision part and any cross terms
    return typeof(f)(MOIU.filter_variables(keep, f.linear_quadratic_terms),
                     copy(f.known_part),
                     MOIU.filter_variables(keep, f.known_variable_terms),
                     MOIU.filter_variables(keep, f.known_decision_terms))
end

function add_term!(terms::Vector{MOI.ScalarQuadraticTerm{T}},
                   term::MOI.ScalarQuadraticTerm{T}) where T
    index_1 = term.variable_index_1
    index_2 = term.variable_index_2
    coefficient = term.coefficient
    i = something(findfirst(t -> t.variable_index_1 == index_1 &&
                            t.variable_index_2 == index_2,
                            terms), 0)
    if iszero(i)
        if !iszero(coefficient)
            # The variable was not already included in the terms
            push!(terms, MOI.ScalarQuadraticTerm(coefficient, index_1, index_2))
        end
    else
        # Variable already included, increment the coefficient
        new_coeff = terms[i].coefficient + coefficient
        if iszero(new_coeff)
            deleteat!(terms, i)
        else
            terms[i] = MOI.ScalarQuadraticTerm(new_coeff, index_1, index_2)
        end
    end
    return nothing
end
