# Affine decision function #
# ========================== #
struct AffineDecisionFunction{T} <: MOI.AbstractScalarFunction
    variable_part::MOI.ScalarAffineFunction{T}
    decision_part::MOI.ScalarAffineFunction{T}
    known_part::MOI.ScalarAffineFunction{T}
end

function AffineDecisionFunction{T}(f::SingleDecision) where T
    AffineDecisionFunction(convert(MOI.ScalarAffineFunction{T}, zero(T)),
                           MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(one(T), f.decision)], zero(T)),
                           convert(MOI.ScalarAffineFunction{T}, zero(T)))
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
                      f::MOI.ScalarAffineFunction{T}) where T
    return AffineDecisionFunction(f,
                                  convert(MOI.ScalarAffineFunction{T}, zero(T)),
                                  convert(MOI.ScalarAffineFunction{T}, zero(T)))
end

function Base.convert(::Type{SingleDecision}, f::AffineDecisionFunction)
    if !iszero(f.decision_part.constant) || !isone(length(f.decision_part.terms)) || !isone(f.decision_part.terms[1].coefficient)
        throw(InexactError(:convert, SingleDecision, f))
    end
    return SingleDecision(f.decision_part.terms[1].variable_index)
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
                      f::MOI.VectorOfVariables) where T
    variable_part = MOI.VectorAffineFunction{T}(
        [MOI.VectorAffineTerm{T}(1, MOI.ScalarAffineTerm(one(T), v)) for v in f.variables],
        [zero(T)])
    return VectorAffineDecisionFunction(variable_part,
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]),
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]))
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::VectorOfDecisions) where T
    decision_part = MOI.VectorAffineFunction{T}(
        [MOI.VectorAffineTerm{T}(1, MOI.ScalarAffineTerm(one(T), d)) for d in f.decisions],
        [zero(T)])
    return VectorAffineDecisionFunction(MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]),
                                        decision_part,
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]))
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
    return iszero(f.variable_part) && iszero(f.decision_part) && iszero(f.known_part)
end

function Base.isone(f::AffineDecisionFunction)
    return isone(f.variable_part) && isone(f.decision_part) && isone(f.known_part)
end

# JuMP overrides #
# ========================== #
function JuMP.moi_function(kref::KnownRef)
    return AffineDecisionFunction(convert(MOI.ScalarAffineFunction{Float64}, 0.0),
                                  convert(MOI.ScalarAffineFunction{Float64}, 0.0),
                                  MOI.ScalarAffineFunction([ScalarAffineTerm(1.0, index(kref))], 0.0))
end
function JuMP.moi_function_type(::Type{KnownRef})
    return AffineDecisionFunction{Float64}
end

function AffineDecisionFunction(aff::CAE)
    JuMP._assert_isfinite(aff)
    decision_terms = Vector{MOI.ScalarAffineTerm{Float64}}()
    for (coef, dvar) in linear_terms(aff.decisions)
        push!(decision_terms, MOI.ScalarAffineTerm(coef, index(dvar)))
        # Any fixed decision value is set in the decision bridge
    end
    known_terms = Vector{MOI.ScalarAffineTerm{Float64}}()
    known_value = 0.0
    for (coef, kvar) in linear_terms(aff.knowns)
        push!(known_terms, MOI.ScalarAffineTerm(coef, index(kvar)))
        # We give the known values directly
        known_value += coef * JuMP.value(kvar)
    end
    return AffineDecisionFunction(JuMP.moi_function(aff.variables),
                                  MOI.ScalarAffineFunction(decision_terms, 0.0),
                                  MOI.ScalarAffineFunction(known_terms, known_value))
end
JuMP.moi_function(aff::CAE) = AffineDecisionFunction(aff)
function JuMP.moi_function_type(::Type{CombinedAffExpr{T}}) where T
    return AffineDecisionFunction{T}
end

AffineDecisionFunction(aff::DAE) = AffineDecisionFunction(convert(CAE, aff))
AffineDecisionFunction(aff::KAE) = AffineDecisionFunction(convert(CAE, aff))

function VectorAffineDecisionFunction(affs::Vector{CAE})
    # Decision part
    dlength = sum(aff -> length(linear_terms(aff.decisions)), affs)
    decision_terms = Vector{MOI.VectorAffineTerm{Float64}}(undef, dlength)
    offset = 0
    for (i, aff) in enumerate(affs)
        offset = JuMP._fill_vaf!(decision_terms, offset, i, aff.decisions)
    end
    # Known part
    klength = sum(aff -> length(linear_terms(aff.knowns)), affs)
    decision_terms = Vector{MOI.VectorAffineTerm{Float64}}(undef, klength)
    known_values = Vector{Float64}(undef, length(affs))
    offset = 0
    for (i, aff) in enumerate(affs)
        j = 1
        for (coef, kvar) in linear_terms(aff.knowns)
            known_terms[offset+j] = MOI.VectorAffineTerm(i, MOI.ScalarAffineTerm(coef, index(kvar)))
            j += 1
            # We give the known values directly
            known_values[i] += coef * JuMP.value(kvar)
        end
        offset += length(linear_terms(aff))
    end
    VectorAffineDecisionFunction(JuMP.moi_function([aff.variables for aff in affs],
                                                   MOI.VectorAffineFunction(decision_terms, zeros(length(affs))),
                                                   MOI.VectorAffineFunction(known_terms, known_values)))
end
JuMP.moi_function(affs::Vector{<:CombinedAffExpr}) = VectorAffineDecisionFunction(affs)
function JuMP.moi_function_type(::Type{<:Vector{<:CombinedAffExpr{T}}}) where {T}
    return VectorAffineDecisionFunction{T}
end

JuMP.moi_function(aff::DAE) = AffineDecisionFunction(aff)
function JuMP.moi_function_type(::Type{DecisionAffExpr{T}}) where T
    return AffineDecisionFunction{T}
end

JuMP.moi_function(aff::KAE) = AffineDecisionFunction(aff)
function JuMP.moi_function_type(::Type{KnownAffExpr{T}}) where T
    return AffineDecisionFunction{T}
end

function DecisionAffExpr(m::Model, f::MOI.ScalarAffineFunction)
    aff = DAE()
    for t in f.terms
        add_to_expression!(aff, t.coefficient, DecisionRef(m, t.variable_index))
    end
    # There should be any constants in the decision terms
    return aff
end

function KnownAffExpr(m::Model, f::MOI.ScalarAffineFunction)
    aff = KAE()
    for t in f.terms
        add_to_expression!(aff, t.coefficient, KnownRef(m, t.variable_index))
    end
    # There should be any constants in the known terms
    return aff
end

function CAE(model::Model, f::AffineDecisionFunction)
    return CAE(AffExpr(model, f.variable_part),
               DecisionAffExpr(model, f.decision_part),
               KnownAffExpr(model, f.known_part))
end

function JuMP.jump_function_type(::Model,
                                 ::Type{AffineDecisionFunction{T}}) where T
    return CombinedAffExpr{T}
end
function JuMP.jump_function(model::Model, f::AffineDecisionFunction{T}) where T
    return CombinedAffExpr{T}(model, f)
end

function JuMP.jump_function_type(::Model,
                                 ::Type{VectorAffineDecisionFunction{T}}) where T
    return Vector{CombinedAffExpr{T}}
end
function JuMP.jump_function(model::Model, f::VectorAffineDecisionFunction{T}) where T
    return CombinedAffExpr{T}[
        CombinedAffExpr{T}(model, f) for f in MOIU.eachscalar(f)]
end

# MOI Function interface #
# ========================== #
MOI.constant(f::AffineDecisionFunction) = MOI.constant(f.variable_part)
MOI.constant(f::VectorAffineDecisionFunction) = MOI.constant(f.variable_part)

function MOIU.eval_variables(varval::Function, f::AffineDecisionFunction)
    var_value = MOIU.eval_variables(varval, f.variable_part)
    dvar_value = MOIU.eval_variables(dvarval, f.decision_part)
    known_value = f.known_part.constant
    return var_value + dvar_value + known_value
end
function MOIU.eval_variables(varval::Function, f::VectorAffineDecisionFunction)
    var_value = MOIU.eval_variables(varval, f.variable_part)
    dvar_value = MOIU.eval_variables(dvarval, f.decision_part)
    known_value = f.known_part.constant
    return var_value + dvar_value + known_value
end

function MOIU.map_indices(index_map::Function, f::Union{AffineDecisionFunction, VectorAffineDecisionFunction})
    # Only map variable part and decision part
    return typeof(f)(MOIU.map_indices(index_map, f.variable_part),
                     MOIU.map_indices(index_map, f.decision_part),
                     copy(f.known_part))
end

Base.eltype(it::MOIU.ScalarFunctionIterator{VectorAffineDecisionFunction{T}}) where T = AffineDecisionFunction{T}

function Base.getindex(it::MOIU.ScalarFunctionIterator{<:VectorAffineDecisionFunction}, i::Integer)
    AffineDecisionFunction(MOIU.scalar_terms_at_index(it.f.variable_part.terms, i), it.f.variable_part.constants[i],
                           MOIU.scalar_terms_at_index(it.f.decision_part.terms, i), it.f.variable_part.constants[i],
                           MOIU.scalar_terms_at_index(it.f.known_part.terms, i), it.f.variable_part.constants[i])
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
    return VectorAffineDecisionFunction(MOI.VAF(variable_terms, variable_constant),
                                        MOI.VAF(decision_terms, decision_constant),
                                        MOI.VAF(known_terms, known_constant))
end


function MOIU.zero_with_output_dimension(::Type{VectorAffineDecisionFunction{T}}, n::Integer) where T
    return MOI.VectorAffineDecisionFunction{T}(MOIU.zero_with_output_dimension(MOI.VAF{T}, n),
                                               MOIU.zero_with_output_dimension(MOI.VAF{T}, n),
                                               MOIU.zero_with_output_dimension(MOI.VAF{T}, n))
end

function MOIU.substitute_variables(variable_map::Function, f::AffineDecisionFunction{T}) where T
    g = AffineDecisionFunction(convert(MOI.ScalarAffineFunction{T}, MOI.constant(f.variable_part)),
                               convert(MOI.ScalarAffineFunction{T}, MOI.constant(f.decision_part)),
                               copy(f.known_part))
    # Substitute variables
    for term in f.variable_part.terms
        new_term = convert(typeof(f),
                           MOIU.operate(*, T, term.coefficient,
                                        variable_map(term.variable_index)))
        MOIU.operate!(+, T, g, convert(typeof(f), new_term))::typeof(f)
    end
    # Substitute decisions
    for term in f.decision_part.terms
        new_term = MOIU.operate(*, T, term.coefficient,
                                variable_map(term.variable_index))
        if new_term isa MOI.ScalarAffineFunction{T}
            MOIU.operate!(+, T, g.decision_part, new_term)::MOI.ScalarAffineFunction{T}
        end
        if new_term isa AffineDecisionFunction
            MOIU.operate!(+, T, g, new_term)::typeof(f)
        end
    end
    # Do not substitute any known values
    return g
end

function MOIU.substitute_variables(variable_map::Function, f::VectorAffineDecisionFunction{T}) where T
    g = VectorAffineDecisionFunction(MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], copy(MOI.constant(f.variable_part))),
                                     MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], copy(MOI.constant(f.decision_part))),
                                     copy(f.known_part))
    # Substitute variables
    for term in f.variable_part.terms
        scalar_term = term.scalar_term
        new_term = convert(typeof(f),
                           MOIU.operate(*, T, scalar_term.coefficient,
                                        variable_map(scalar_term.variable_index)))
        MOIU.operate_output_index!(+, T, term.output_index, g, new_term)::typeof(func)
    end
    # Substitute decisions
    for term in f.decision_part.terms
        scalar_term = term.scalar_term
        new_term = MOIU.operate(*, T, scalar_term.coefficient,
                                variable_map(scalar_term.variable_index))
        if new_term isa MOI.ScalarAffineFunction{T}
            MOIU.operate_output_index!(+, T, term.output_index, g.decision_part, new_term)::MOI.ScalarAffineFunction{T}
        end
        if new_term isa AffineDecisionFunction
            MOIU.operate_output_index!(+, T, term.output_index, g, new_term)::typeof(func)
        end
    end
    # Do not substitute any known values
    return g
end

MOIU.constant_vector(f::AffineDecisionFunction) = [f.variable_part.constant]
MOIU.constant_vector(f::VectorAffineDecisionFunction) = f.variable_part.constants

MOIU.scalar_type(::Type{VectorAffineDecisionFunction{T}}) where T = AffineDecisionFunction{T}

MOIU.is_canonical(f::Union{AffineDecisionFunction, VectorAffineDecisionFunction}) = MOIU.is_canonical(f.variable_part) &&
    MOIU.is_canonical(f.decision_part) &&
    MOIU.is_canonical(f.known_part)

MOIU.canonical(f::Union{AffineDecisionFunction, VectorAffineDecisionFunction}) = AffineDecisionFunction(MOIU.canonical(f.variable_part),
                                                                                                        MOIU.canonical(f.decision_part),
                                                                                                        MOIU.canonical(f.known_part))

function MOIU.canonicalize!(f::Union{AffineDecisionFunction, VectorAffineDecisionFunction})
    MOIU.canonicalize!(f.variable_part)
    MOIU.canonicalize!(f.decision_part)
    MOIU.canonicalize!(f.known_part)
    return f
end

MOIU._is_constant(f::AffineDecisionFunction) = MOIU._is_constant(f.variable_part) &&
    MOIU._is_constant(f.decision_part) &&
    MOIU._is_constant(f.known_part)

MOIU.all_coefficients(p::Function, f::AffineDecisionFunction) = MOIU.all_coefficients(p, f.variable_part) &&
    MOIU.all_coefficients(p, f.decision_part) &&
    MOIU.all_coefficients(p, f.known_part)

MOIU.isapprox_zero(f::AffineDecisionFunction, tol) = MOIU.isapprox_zero(f.variable_part, tol) &&
    MOIU.isapprox_zero(f.decision_part, tol) &&
    MOIU.isapprox_zero(f.known_part, tol)

function MOIU.filter_variables(keep::Function, f::Union{AffineDecisionFunction, VectorAffineDecisionFunction})
    # Only filter variable part and decision part
    return typeof(f)(MOIU.filter_variables(keep, f.variable_part),
                     MOIU.filter_variables(keep, f.decision_part),
                     copy(f.known_part))
end

function MOIU.vectorize(funcs::AbstractVector{AffineDecisionFunction{T}}) where T
    return VectorAffineDecisionFunction{T}(
        MOIU.vectorize([f.variable_part for f in funcs]),
        MOIU.vectorize([f.decision_part for f in funcs]),
        MOIU.vectorize([f.known_part for f in funcs]))
end

function MOIU.scalarize(f::VectorAffineDecisionFunction{T}, ignore_constants::Bool = false) where T
    return AffineDecisionFunction{T}(MOIU.scalarize(f.variable_part),
                                     MOIU.scalarize(f.decision_part),
                                     MOIU.scalarize(f.known_part))
end
