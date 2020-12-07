# Affine decision function #
# ========================== #
struct AffineDecisionFunction{T} <: MOI.AbstractScalarFunction
    variable_part::MOI.ScalarAffineFunction{T}
    decision_part::MOI.ScalarAffineFunction{T}
    known_part::MOI.ScalarAffineFunction{T}
end

function AffineDecisionFunction{T}(f::MOI.SingleVariable) where T
    AffineDecisionFunction(MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(one(T), f.variable)], zero(T)),
                           convert(MOI.ScalarAffineFunction{T}, zero(T)),
                           convert(MOI.ScalarAffineFunction{T}, zero(T)))
end

function AffineDecisionFunction{T}(f::SingleDecision) where T
    AffineDecisionFunction(convert(MOI.ScalarAffineFunction{T}, zero(T)),
                           MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(one(T), f.decision)], zero(T)),
                           convert(MOI.ScalarAffineFunction{T}, zero(T)))
end

function AffineDecisionFunction{T}(f::SingleKnown) where T
    AffineDecisionFunction(convert(MOI.ScalarAffineFunction{T}, zero(T)),
                           convert(MOI.ScalarAffineFunction{T}, zero(T)),
                           MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(one(T), f.known)], T(f.value)))
end

# Affine decision vector function #
# ========================== #
struct VectorAffineDecisionFunction{T} <: MOI.AbstractVectorFunction
    variable_part::MOI.VectorAffineFunction{T}
    decision_part::MOI.VectorAffineFunction{T}
    known_part::MOI.VectorAffineFunction{T}
end
MOI.output_dimension(f::VectorAffineDecisionFunction) = MOI.output_dimension(f.variable_part)

# Base overrides #
# ========================== #
function Base.copy(f::F) where F <: Union{AffineDecisionFunction,
                                          VectorAffineDecisionFunction}
    return F(copy(f.variable_part),
             copy(f.decision_part),
             copy(f.known_part))
end

function Base.convert(::Type{AffineDecisionFunction{T}}, α::T) where T
    return AffineDecisionFunction(convert(MOI.ScalarAffineFunction{T}, α),
                                  convert(MOI.ScalarAffineFunction{T}, zero(T)),
                                  convert(MOI.ScalarAffineFunction{T}, zero(T)))
end

function Base.convert(::Type{AffineDecisionFunction{T}},
                      f::MOI.SingleVariable) where T
    return AffineDecisionFunction(convert(MOI.ScalarAffineFunction{T}, f),
                                  convert(MOI.ScalarAffineFunction{T}, zero(T)),
                                  convert(MOI.ScalarAffineFunction{T}, zero(T)))
end

function Base.convert(::Type{AffineDecisionFunction{T}},
                      f::SingleDecision) where T
    return AffineDecisionFunction{T}(f)
end

function Base.convert(::Type{AffineDecisionFunction{T}},
                      f::SingleKnown) where T
    return AffineDecisionFunction{T}(f)
end

function Base.convert(::Type{AffineDecisionFunction{T}},
                      f::MOI.ScalarAffineFunction{T}) where T
    return AffineDecisionFunction(f,
                                  convert(MOI.ScalarAffineFunction{T}, zero(T)),
                                  convert(MOI.ScalarAffineFunction{T}, zero(T)))
end

function Base.convert(::Type{AffineDecisionFunction{T}},
                      f::AffineDecisionFunction{T}) where T
    return f
end

function Base.convert(::Type{AffineDecisionFunction{T}},
                      f::AffineDecisionFunction) where T
    return AffineDecisionFunction(convert(MOI.ScalarAffineFunction{T}, f.variable_part),
                                  convert(MOI.ScalarAffineFunction{T}, f.decision_part),
                                  convert(MOI.ScalarAffineFunction{T}, f.known_part))
end

function Base.convert(::Type{MOI.SingleVariable}, f::AffineDecisionFunction)
    if !iszero(f.variable_part.constant) || !isone(length(f.variable_part.terms)) || !isone(f.variable_part.terms[1].coefficient)
        throw(InexactError(:convert, MOI.SingleVariable, f))
    end
    return MOI.SingleVariable(f.variable_part.terms[1].variable_index)
end

function Base.convert(::Type{SingleDecision}, f::AffineDecisionFunction)
    if !iszero(f.decision_part.constant) || !isone(length(f.decision_part.terms)) || !isone(f.decision_part.terms[1].coefficient)
        throw(InexactError(:convert, SingleDecision, f))
    end
    return SingleDecision(f.decision_part.terms[1].variable_index)
end

function Base.convert(::Type{SingleKnown}, f::AffineDecisionFunction)
    if !iszero(f.known_part.constant) || !isone(length(f.known_part.terms)) || !isone(f.known_part.terms[1].coefficient)
        throw(InexactError(:convert, SingleKnown, f))
    end
    return SingleKnownn(f.known_part.terms[1].variable_index, f.known_part.constant)
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}}, α::T) where T
    return VectorAffineDecisionFunction(MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [α]),
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]),
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]))
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::MOI.SingleVariable) where T
    return VectorAffineDecisionFunction(
        MOI.VectorAffineFunction{T}([MOI.VectorAffineTerm{T}(1, MOI.ScalarAffineTerm(one(T), f.variable))], [zero(T)]),
        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]),
        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]))
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::SingleDecision) where T
    return VectorAffineDecisionFunction(
        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]),
        MOI.VectorAffineFunction{T}([MOI.VectorAffineTerm{T}(1, MOI.ScalarAffineTerm(one(T), f.decision))], [zero(T)]),
        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]))
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::SingleKnown) where T
    return VectorAffineDecisionFunction(
        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]),
        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]),
        MOI.VectorAffineFunction{T}([MOI.VectorAffineTerm{T}(1, MOI.ScalarAffineTerm(one(T), f.known))], [zero(T)]))
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::MOI.VectorOfVariables) where T
    n = length(f.variables)
    terms = map(1:n) do i
        MOI.VectorAffineTerm{T}(i, MOI.ScalarAffineTerm(one(T), f.variables[i]))
    end
    variable_part = MOI.VectorAffineFunction{T}(
        terms,
        zeros(T, n))
    return VectorAffineDecisionFunction(variable_part,
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], zeros(T, n)),
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], zeros(T, n)))
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::VectorOfDecisions) where T
    n = length(f.decisions)
    terms = map(1:n) do i
        MOI.VectorAffineTerm{T}(i, MOI.ScalarAffineTerm(one(T), f.decisions[i]))
    end
    decision_part = MOI.VectorAffineFunction{T}(
        terms,
        zeros(T, n))
    return VectorAffineDecisionFunction(MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], zeros(T, n)),
                                        decision_part,
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], zeros(T, n)))
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::VectorOfKnowns) where T
    n = length(f.knowns)
    terms = map(1:n) do i
        MOI.VectorAffineTerm{T}(i, MOI.ScalarAffineTerm(one(T), f.knowns[i]))
    end
    known_part = MOI.VectorAffineFunction{T}(
        terms,
        zeros(T, n))
    return VectorAffineDecisionFunction(MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], zeros(T, n)),
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], zeros(T, n)),
                                        known_part)
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::MOI.ScalarAffineFunction{T}) where T
    variable_part = MOI.VectorAffineFunction{T}([MOI.VectorAffineTerm{T}(1, t) for t in f.part.terms],
                                                [f.constant])
    return VectorAffineDecisionFunction(variable_part,
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]),
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]))
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::AffineDecisionFunction{T}) where T
    variable_part = MOI.VectorAffineFunction{T}([MOI.VectorAffineTerm{T}(1, t) for t in f.variable_part.terms],
                                                [f.variable_part.constant])
    decision_part = MOI.VectorAffineFunction{T}([MOI.VectorAffineTerm{T}(1, t) for t in f.decision_part.terms],
                                                [f.decision_part.constant])
    known_part = MOI.VectorAffineFunction{T}([MOI.VectorAffineTerm{T}(1, t) for t in f.known_part.terms],
                                                [f.known_part.constant])
    return VectorAffineDecisionFunction(variable_part,
                                        decision_part,
                                        known_part)
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::MOI.VectorAffineFunction{T}) where T
    n = MOI.output_dimension(f)
    return VectorAffineDecisionFunction(f,
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], zeros(T, n)),
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], zeros(T, n)))
end

function Base.zero(F::Type{AffineDecisionFunction{T}}) where T
    return convert(F, zero(T))
end

function Base.iszero(f::AffineDecisionFunction)
    return iszero(MOI.constant(f)) && MOIU._is_constant(MOIU.canonical(f))
end

function Base.isone(f::AffineDecisionFunction)
    return isone(MOI.constant(f)) && MOIU._is_constant(MOIU.canonical(f))
end

function Base.one(F::Type{AffineDecisionFunction{T}}) where T
    return convert(F, one(T))
end

# JuMP overrides #
# ========================== #
function AffineDecisionFunction(aff::DAE)
    JuMP._assert_isfinite(aff)
    decision_terms = Vector{MOI.ScalarAffineTerm{Float64}}()
    for (coef, dvar) in linear_terms(aff.decisions)
        # Any fixed decision value is set in the decision bridge
        push!(decision_terms, MOI.ScalarAffineTerm(coef, index(dvar)))
    end
    known_terms = Vector{MOI.ScalarAffineTerm{Float64}}()
    for (coef, kvar) in linear_terms(aff.knowns)
        # Any known decision is set in the known bridge bridges
        push!(known_terms, MOI.ScalarAffineTerm(coef, index(kvar)))
    end
    return AffineDecisionFunction(JuMP.moi_function(aff.variables),
                                  MOI.ScalarAffineFunction(decision_terms, 0.0),
                                  MOI.ScalarAffineFunction(known_terms, 0.0))
end
JuMP.moi_function(aff::DAE) = AffineDecisionFunction(aff)
function JuMP.moi_function_type(::Type{DecisionAffExpr{T}}) where T
    return AffineDecisionFunction{T}
end

is_decision_type(::Type{<:AffineDecisionFunction}) = true

AffineDecisionFunction(aff::_DAE) = AffineDecisionFunction(convert(DAE, aff))
AffineDecisionFunction(aff::_KAE) = AffineDecisionFunction(convert(DAE, aff))

function VectorAffineDecisionFunction(affs::Vector{DAE})
    # Decision part
    dlength = sum(aff -> length(linear_terms(aff.decisions)), affs)
    decision_terms = Vector{MOI.VectorAffineTerm{Float64}}(undef, dlength)
    offset = 0
    for (i, aff) in enumerate(affs)
        offset = JuMP._fill_vaf!(decision_terms, offset, i, aff.decisions)
    end
    # Known part
    klength = sum(aff -> length(linear_terms(aff.knowns)), affs)
    known_terms = Vector{MOI.VectorAffineTerm{Float64}}(undef, klength)
    offset = 0
    for (i, aff) in enumerate(affs)
        j = 1
        for (coef, kvar) in linear_terms(aff.knowns)
            # Any known decision is set in the known bridge
            known_terms[offset+j] = MOI.VectorAffineTerm(i, MOI.ScalarAffineTerm(coef, index(kvar)))
            j += 1
        end
        offset += length(linear_terms(aff.knowns))
    end
    VectorAffineDecisionFunction(JuMP.moi_function([aff.variables for aff in affs]),
                                                   MOI.VectorAffineFunction(decision_terms, zeros(length(affs))),
                                                   MOI.VectorAffineFunction(known_terms, zeros(length(affs))))
end
JuMP.moi_function(affs::Vector{<:DecisionAffExpr}) = VectorAffineDecisionFunction(affs)
function JuMP.moi_function_type(::Type{<:Vector{<:DecisionAffExpr{T}}}) where {T}
    return VectorAffineDecisionFunction{T}
end

is_decision_type(::Type{<:VectorAffineDecisionFunction}) = true

JuMP.moi_function(aff::_DAE) = AffineDecisionFunction(aff)
function JuMP.moi_function_type(::Type{_DecisionAffExpr{T}}) where T
    return AffineDecisionFunction{T}
end

JuMP.moi_function(aff::_KAE) = AffineDecisionFunction(aff)
function JuMP.moi_function_type(::Type{_KnownAffExpr{T}}) where T
    return AffineDecisionFunction{T}
end

function _DecisionAffExpr(m::Model, f::MOI.ScalarAffineFunction)
    aff = _DAE()
    for t in f.terms
        JuMP.add_to_expression!(aff, t.coefficient, DecisionRef(m, t.variable_index))
    end
    # There should be not any constants in the decision terms
    return aff
end

function _KnownAffExpr(m::Model, f::MOI.ScalarAffineFunction)
    aff = _KAE()
    for t in f.terms
        JuMP.add_to_expression!(aff, t.coefficient, KnownRef(m, t.variable_index))
    end
    # There should not be any constants in the known terms
    return aff
end

function DAE(model::Model, f::AffineDecisionFunction)
    return DAE(AffExpr(model, f.variable_part),
               _DecisionAffExpr(model, f.decision_part),
               _KnownAffExpr(model, f.known_part))
end

function JuMP.jump_function_type(::Model,
                                 ::Type{AffineDecisionFunction{T}}) where T
    return DecisionAffExpr{T}
end
function JuMP.jump_function(model::Model, f::AffineDecisionFunction{T}) where T
    return DecisionAffExpr{T}(model, f)
end

function JuMP.jump_function_type(::Model,
                                 ::Type{VectorAffineDecisionFunction{T}}) where T
    return Vector{DecisionAffExpr{T}}
end
function JuMP.jump_function(model::Model, f::VectorAffineDecisionFunction{T}) where T
    return DecisionAffExpr{T}[
        DecisionAffExpr{T}(model, f) for f in MOIU.eachscalar(f)]
end

# MOI Function interface #
# ========================== #
MOI.constant(f::AffineDecisionFunction) = MOI.constant(f.variable_part)
MOI.constant(f::AffineDecisionFunction, T::DataType) = MOI.constant(f)
MOI.constant(f::VectorAffineDecisionFunction) = MOI.constant(f.variable_part)
MOI.constant(f::VectorAffineDecisionFunction, T::DataType) = MOI.constant(f)

function MOIU.eval_variables(varval::Function, f::AffineDecisionFunction)
    var_value = MOIU.eval_variables(varval, f.variable_part)
    dvar_value = MOIU.eval_variables(varval, f.decision_part)
    known_value = MOIU.eval_variables(varval, f.known_part)
    return var_value + dvar_value + known_value
end
function MOIU.eval_variables(varval::Function, f::VectorAffineDecisionFunction)
    var_value = MOIU.eval_variables(varval, f.variable_part)
    dvar_value = MOIU.eval_variables(varval, f.decision_part)
    known_value = MOIU.eval_variables(varval, f.known_part)
    return var_value + dvar_value + known_value
end

function MOIU.map_indices(index_map::Function, f::Union{AffineDecisionFunction, VectorAffineDecisionFunction})
    return typeof(f)(MOIU.map_indices(index_map, f.variable_part),
                     MOIU.map_indices(index_map, f.decision_part),
                     MOIU.map_indices(index_map, f.known_part))
end

Base.eltype(it::MOIU.ScalarFunctionIterator{VectorAffineDecisionFunction{T}}) where T = AffineDecisionFunction{T}

function Base.getindex(it::MOIU.ScalarFunctionIterator{<:VectorAffineDecisionFunction}, i::Integer)
    AffineDecisionFunction(
        MOI.ScalarAffineFunction(
            MOIU.scalar_terms_at_index(it.f.variable_part.terms, i),
            it.f.variable_part.constants[i]),
        MOI.ScalarAffineFunction(
            MOIU.scalar_terms_at_index(it.f.decision_part.terms, i),
            it.f.decision_part.constants[i]),
        MOI.ScalarAffineFunction(
            MOIU.scalar_terms_at_index(it.f.known_part.terms, i),
            it.f.known_part.constants[i]))
end
function Base.getindex(it::MOIU.ScalarFunctionIterator{VectorAffineDecisionFunction{T}}, I::AbstractVector) where T
    variable_terms = MOI.VectorAffineTerm{T}[]
    decision_terms = MOI.VectorAffineTerm{T}[]
    known_terms = MOI.VectorAffineTerm{T}[]
    variable_constant = Vector{T}(undef, length(I))
    decision_constant = Vector{T}(undef, length(I))
    known_constant = Vector{T}(undef, length(I))
    for (i, j) in enumerate(I)
        g = it[j]
        append!(variable_terms, map(t -> MOI.VectorAffineTerm(i, t), g.variable_part.terms))
        append!(decision_terms, map(t -> MOI.VectorAffineTerm(i, t), g.decision_part.terms))
        append!(known_terms, map(t -> MOI.VectorAffineTerm(i, t), g.known_part.terms))
        variable_constant[i] = g.variable_part.constant
        decision_constant[i] = g.decision_part.constant
        known_constant[i] = g.known_part.constant
    end
    return VectorAffineDecisionFunction(MOIU.VAF(variable_terms, variable_constant),
                                        MOIU.VAF(decision_terms, decision_constant),
                                        MOIU.VAF(known_terms, known_constant))
end


function MOIU.zero_with_output_dimension(::Type{VectorAffineDecisionFunction{T}}, n::Integer) where T
    return MOI.VectorAffineDecisionFunction{T}(MOIU.zero_with_output_dimension(MOI.VAF{T}, n),
                                               MOIU.zero_with_output_dimension(MOI.VAF{T}, n),
                                               MOIU.zero_with_output_dimension(MOI.VAF{T}, n))
end

function MOIU.substitute_variables(variable_map::Function, f::AffineDecisionFunction{T}) where T
    g = AffineDecisionFunction(convert(MOI.ScalarAffineFunction{T}, MOI.constant(f.variable_part)),
                               convert(MOI.ScalarAffineFunction{T}, zero(T)),
                               MOI.ScalarAffineFunction{T}(f.known_part.terms, zero(T)))
    # Substitute variables
    for term in f.variable_part.terms
        new_term = MOIU.substitute_variables(variable_map, term)
        MOIU.operate!(+, T, g.variable_part, new_term)::MOI.ScalarAffineFunction{T}
    end
    # Substitute decisions
    for term in f.decision_part.terms
        new_term = MOIU.substitute_variables(variable_map, term)
        mapped_term = only(new_term.terms)
        mapped_variable = MOI.ScalarAffineFunction{T}([mapped_term], zero(T))
        if term != mapped_term
            # Add mapped variable
            MOIU.operate!(+, T, g.variable_part, mapped_variable)::MOI.ScalarAffineFunction{T}
        end
        # Always keep the term as decision in order to properly unbridge and handle modifications
        MOIU.operate!(+, T, g.decision_part, mapped_variable)::MOI.ScalarAffineFunction{T}
    end
    # Substitute knowns
    for term in f.known_part.terms
        # Known value acquired during substitution
        new_term = MOIU.substitute_variables(variable_map, term)
        # Add the known value to the constant of the known part
        MOIU.operate!(+, T, g.known_part, new_term)::MOI.ScalarAffineFunction{T}
    end
    return g
end

function MOIU.substitute_variables(variable_map::Function, f::VectorAffineDecisionFunction{T}) where T
    n = MOI.output_dimension(f)
    g = VectorAffineDecisionFunction(MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], copy(MOI.constant(f.variable_part))),
                                     MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], zeros(T, n)),
                                     MOI.VectorAffineFunction(f.known_part.terms, zeros(T, n)))
    # Substitute variables
    for term in f.variable_part.terms
        new_term = MOIU.substitute_variables(variable_map, term.scalar_term)
        MOIU.operate_output_index!(+, T, term.output_index, g, new_term)::typeof(g)
    end
    # Substitute decisions
    for term in f.decision_part.terms
        new_term = MOIU.substitute_variables(variable_map, term.scalar_term)
        mapped_term = only(new_term.terms)
        mapped_variable = MOI.ScalarAffineFunction{T}([mapped_term], zero(T))
        if term.scalar_term != mapped_term
            # Add mapped variable
            MOIU.operate_output_index!(+, T, term.output_index, g.variable_part, mapped_variable)::MOI.VectorAffineFunction{T}
        end
        # Always keep the term as decision in order to properly unbridge and handle modifications
        MOIU.operate_output_index!(+, T, term.output_index, g.decision_part, mapped_variable)::MOI.VectorAffineFunction{T}
    end
    # Substitute knowns
    for term in f.known_part.terms
        new_term = MOIU.substitute_variables(variable_map, term.scalar_term)
        MOIU.operate_output_index!(+, T, term.output_index, g.known_part, new_term)::MOI.VectorAffineFunction{T}
    end
    return g
end

MOIU.constant_vector(f::AffineDecisionFunction) = [f.variable_part.constant]
MOIU.constant_vector(f::VectorAffineDecisionFunction) = f.variable_part.constants

MOIU.scalar_type(::Type{VectorAffineDecisionFunction{T}}) where T = AffineDecisionFunction{T}

MOIU.is_canonical(f::Union{AffineDecisionFunction, VectorAffineDecisionFunction}) = MOIU.is_canonical(f.variable_part) &&
    MOIU.is_canonical(f.decision_part) &&
    MOIU.is_canonical(f.known_part)

MOIU.canonical(f::Union{AffineDecisionFunction, VectorAffineDecisionFunction}) = MOIU.canonicalize!(copy(f))

function MOIU.canonicalize!(f::Union{AffineDecisionFunction, VectorAffineDecisionFunction})
    MOIU.canonicalize!(f.variable_part)
    MOIU.canonicalize!(f.decision_part)
    MOIU.canonicalize!(f.known_part)
    return f
end

MOIU._is_constant(f::AffineDecisionFunction) =
    MOIU._is_constant(f.variable_part) &&
    MOIU._is_constant(f.decision_part) &&
    MOIU._is_constant(f.known_part)

MOIU.all_coefficients(p::Function, f::AffineDecisionFunction) =
    MOIU.all_coefficients(p, f.variable_part) &&
    MOIU.all_coefficients(p, f.decision_part) &&
    MOIU.all_coefficients(p, f.known_part)

MOIU.isapprox_zero(f::AffineDecisionFunction, tol) =
    MOIU.isapprox_zero(f.variable_part, tol) &&
    MOIU.isapprox_zero(f.decision_part, tol) &&
    MOIU.isapprox_zero(f.known_part, tol)

function MOIU.filter_variables(keep::Function, f::Union{AffineDecisionFunction, VectorAffineDecisionFunction})
    # Only filter variable part and decision part
    return typeof(f)(MOIU.filter_variables(keep, f.variable_part),
                     MOIU.filter_variables(keep, f.decision_part),
                     MOIU.filter_variables(keep, f.known_part))
end

function MOIU.operate_coefficients(f, func::Union{AffineDecisionFunction, VectorAffineDecisionFunction})
    return typeof(func)(MOIU.operate_coefficients(f, func.variable_part),
                        MOIU.operate_coefficients(f, func.decision_part),
                        MOIU.operate_coefficients(f, func.known_part))
end

function MOIU.vectorize(funcs::AbstractVector{AffineDecisionFunction{T}}) where T
    return VectorAffineDecisionFunction{T}(
        MOIU.vectorize([f.variable_part for f in funcs]),
        MOIU.vectorize([f.decision_part for f in funcs]),
        MOIU.vectorize([f.known_part for f in funcs]))
end

function MOIU.scalarize(f::VectorAffineDecisionFunction{T}, ignore_constants::Bool = false) where T
    variable_part = MOIU.scalarize(f.variable_part, ignore_constants)
    decision_part = MOIU.scalarize(f.decision_part, ignore_constants)
    known_part = MOIU.scalarize(f.known_part, false) # Keep any known values
    return map(zip(variable_part, decision_part, known_part)) do (var_part, dvar_part, kvar_part)
        AffineDecisionFunction(var_part, dvar_part, kvar_part)
    end
end

function modify_coefficient!(terms::Vector{MOI.ScalarAffineTerm{T}},
                             index::MOI.VariableIndex,
                             new_coefficient::Number) where T
    i = something(findfirst(t -> t.variable_index == index,
                            terms), 0)
    if iszero(i)
        # The variable was not already included in the terms
        if !iszero(new_coefficient)
            # Add it
            push!(terms,
                  MOI.ScalarAffineTerm(T(new_coefficient), index))
        end
    else
        # The variable is included in the terms
        if iszero(new_coefficient)
            # Remove it
            deleteat!(terms, i)
        else
            # Update coefficient
            terms[i] = MOI.ScalarAffineTerm(T(new_coefficient), index)
        end
    end
    return nothing
end

function modify_coefficients!(terms::Vector{MOI.VectorAffineTerm{T}},
                              index::MOI.VariableIndex,
                              new_coefficients::AbstractVector) where T
    rowmap = Dict(c[1]=>i for (i,c) in enumerate(new_coefficients))
    del = Int[]
    for i in findall(t -> t.variable_index == index, terms)
        row = terms[i].output_index
        j = Base.get(rowmap, row, 0)
        if !iszero(j)
            if iszero(new_coefficients[j][2])
                push!(del, i)
            else
                terms[i] = MOI.VectorAffineTerm(row, MOI.ScalarAffineTerm(new_coefficients[j][2], index))
            end
            rowmap[row] = 0
        end
    end
    deleteat!(terms, del)
    for (row, j) in rowmap
        new_coefficient = new_coefficients[j][2]
        if !iszero(j) && !iszero(new_coefficient)
            push!(terms, MOI.VectorAffineTerm(row, MOI.ScalarAffineTerm(new_coefficient, index)))
        end
    end
    return nothing
end

function add_term!(terms::Vector{MOI.ScalarAffineTerm{T}},
                   term::MOI.ScalarAffineTerm{T}) where T
    index = term.variable_index
    coefficient = term.coefficient
    i = something(findfirst(t -> t.variable_index == index,
                            terms), 0)
    if iszero(i)
        if !iszero(coefficient)
            # The variable was not already included in the terms
            push!(terms, MOI.ScalarAffineTerm(coefficient, index))
        end
    else
        # Variable already included, increment the coefficient
        new_coeff = terms[i].coefficient + coefficient
        if iszero(new_coeff)
            deleteat!(terms, i)
        else
            terms[i] = MOI.ScalarAffineTerm(new_coeff, index)
        end
    end
    return nothing
end

function remove_term!(terms::Vector{MOI.ScalarAffineTerm{T}},
                      term::MOI.ScalarAffineTerm{T}) where T
    index = term.variable_index
    coefficient = term.coefficient
    i = something(findfirst(t -> t.variable_index == index,
                            terms), 0)
    if iszero(i) && !iszero(coefficient)
        # The variable was not already included in the terms
        push!(terms, MOI.ScalarAffineTerm(-coefficient, index))
    else
        # Variable already included, increment the coefficient
        new_coeff = terms[i].coefficient - coefficient
        if iszero(new_coeff)
            deleteat!(terms, i)
        else
            terms[i] = MOI.ScalarAffineTerm(new_coeff, index)
        end
    end
    return nothing
end
