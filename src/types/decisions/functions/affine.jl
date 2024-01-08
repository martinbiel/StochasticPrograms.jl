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

# Affine decision function #
# ========================== #
struct AffineDecisionFunction{T} <: MOI.AbstractScalarFunction
    variable_part::MOI.ScalarAffineFunction{T}
    decision_part::MOI.ScalarAffineFunction{T}
end

function AffineDecisionFunction{T}(f::MOI.VariableIndex) where T
    AffineDecisionFunction(MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(one(T), f)], zero(T)),
                           convert(MOI.ScalarAffineFunction{T}, zero(T)))
end

function AffineDecisionFunction{T}(f::SingleDecision) where T
    AffineDecisionFunction(convert(MOI.ScalarAffineFunction{T}, zero(T)),
                           MOI.ScalarAffineFunction([MOI.ScalarAffineTerm(one(T), f.decision)], zero(T)))
end

# Affine decision vector function #
# ========================== #
struct VectorAffineDecisionFunction{T} <: MOI.AbstractVectorFunction
    variable_part::MOI.VectorAffineFunction{T}
    decision_part::MOI.VectorAffineFunction{T}
end
MOI.output_dimension(f::VectorAffineDecisionFunction) = MOI.output_dimension(f.variable_part)

# Base overrides #
# ========================== #
function Base.copy(f::F) where F <: Union{AffineDecisionFunction,
                                          VectorAffineDecisionFunction}
    return F(copy(f.variable_part),
             copy(f.decision_part))
end

function Base.convert(::Type{AffineDecisionFunction{T}}, α::T) where T
    return AffineDecisionFunction(convert(MOI.ScalarAffineFunction{T}, α),
                                  convert(MOI.ScalarAffineFunction{T}, zero(T)))
end

function Base.convert(::Type{AffineDecisionFunction{T}},
                      f::MOI.VariableIndex) where T
    return AffineDecisionFunction(convert(MOI.ScalarAffineFunction{T}, f),
                                  convert(MOI.ScalarAffineFunction{T}, zero(T)))
end

function Base.convert(::Type{AffineDecisionFunction{T}},
                      f::SingleDecision) where T
    return AffineDecisionFunction{T}(f)
end

function Base.convert(::Type{AffineDecisionFunction{T}},
                      f::MOI.ScalarAffineFunction{T}) where T
    return AffineDecisionFunction(f, convert(MOI.ScalarAffineFunction{T}, zero(T)))
end

function Base.convert(::Type{AffineDecisionFunction{T}},
                      f::AffineDecisionFunction{T}) where T
    return f
end

function Base.convert(::Type{AffineDecisionFunction{T}},
                      f::AffineDecisionFunction) where T
    return AffineDecisionFunction(convert(MOI.ScalarAffineFunction{T}, f.variable_part),
                                  convert(MOI.ScalarAffineFunction{T}, f.decision_part))
end

function Base.convert(::Type{MOI.VariableIndex}, f::AffineDecisionFunction)
    if !iszero(f.variable_part.constant) || !isone(length(f.variable_part.terms)) || !isone(f.variable_part.terms[1].coefficient)
        throw(InexactError(:convert, MOI.VariableIndex, f))
    end
    return MOI.VariableIndex(f.variable_part.terms[1].variable.value)
end

function Base.convert(::Type{SingleDecision}, f::AffineDecisionFunction)
    if !iszero(f.decision_part.constant) || !isone(length(f.decision_part.terms)) || !isone(f.decision_part.terms[1].coefficient)
        throw(InexactError(:convert, SingleDecision, f))
    end
    return SingleDecision(f.decision_part.terms[1].variable)
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}}, α::T) where T
    return VectorAffineDecisionFunction(MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [α]),
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]))
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::MOI.VariableIndex) where T
    return VectorAffineDecisionFunction(
        MOI.VectorAffineFunction{T}([MOI.VectorAffineTerm{T}(1, MOI.ScalarAffineTerm(one(T), f))], [zero(T)]),
        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]))
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::SingleDecision) where T
    return VectorAffineDecisionFunction(
        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]),
        MOI.VectorAffineFunction{T}([MOI.VectorAffineTerm{T}(1, MOI.ScalarAffineTerm(one(T), f.decision))], [zero(T)]))
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
                                        decision_part)
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::MOI.ScalarAffineFunction{T}) where T
    variable_part = MOI.VectorAffineFunction{T}([MOI.VectorAffineTerm{T}(1, t) for t in f.terms],
                                                [f.constant])
    return VectorAffineDecisionFunction(variable_part,
                                        MOI.VectorAffineFunction{T}(MOI.VectorAffineTerm{T}[], [zero(T)]))
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::AffineDecisionFunction{T}) where T
    variable_part = MOI.VectorAffineFunction{T}([MOI.VectorAffineTerm{T}(1, t) for t in f.variable_part.terms],
                                                [f.variable_part.constant])
    decision_part = MOI.VectorAffineFunction{T}([MOI.VectorAffineTerm{T}(1, t) for t in f.decision_part.terms],
                                                [f.decision_part.constant])
    return VectorAffineDecisionFunction(variable_part,
                                        decision_part)
end

function Base.convert(::Type{VectorAffineDecisionFunction{T}},
                      f::MOI.VectorAffineFunction{T}) where T
    n = MOI.output_dimension(f)
    return VectorAffineDecisionFunction(f,
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

function MOI._dicts(f::Union{AffineDecisionFunction, VectorAffineDecisionFunction})
    return (MOI.sum_dict(MOI.term_pair.(f.variable_part.terms)),
            MOI.sum_dict(MOI.term_pair.(f.decision_part.terms)))
end

function Base.isapprox(f::F, g::G; kwargs...) where {
    F<:Union{
        AffineDecisionFunction,
        VectorAffineDecisionFunction,
    },
    G<:Union{
        AffineDecisionFunction,
        VectorAffineDecisionFunction,
    },
}
    return isapprox(MOI.constant(f), MOI.constant(g); kwargs...) && all(
        MOI.dict_compare.(
            MOI._dicts(f),
            MOI._dicts(g),
            (α, β) -> isapprox(α, β; kwargs...),
        ),
    )
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
    return AffineDecisionFunction(JuMP.moi_function(aff.variables),
                                  MOI.ScalarAffineFunction(decision_terms, 0.0))
end
JuMP.moi_function(aff::DAE) = AffineDecisionFunction(aff)
function JuMP.moi_function_type(::Type{DecisionAffExpr{T}}) where T
    return AffineDecisionFunction{T}
end

is_decision_type(::Type{<:AffineDecisionFunction}) = true

AffineDecisionFunction(aff::_DAE) = AffineDecisionFunction(convert(DAE, aff))

function VectorAffineDecisionFunction(affs::Vector{DAE})
    # Decision part
    dlength = sum(aff -> length(linear_terms(aff.decisions)), affs)
    decision_terms = Vector{MOI.VectorAffineTerm{Float64}}(undef, dlength)
    offset = 0
    for (i, aff) in enumerate(affs)
        offset = JuMP._fill_vaf!(decision_terms, offset, i, aff.decisions)
    end
    VectorAffineDecisionFunction(JuMP.moi_function([aff.variables for aff in affs]),
                                 MOI.VectorAffineFunction(decision_terms, zeros(length(affs))))
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

function _DecisionAffExpr(m::Model, f::MOI.ScalarAffineFunction)
    aff = _DAE()
    for t in f.terms
        JuMP.add_to_expression!(aff, t.coefficient, DecisionRef(m, t.variable))
    end
    # There should be not any constants in the decision terms
    return aff
end

function DAE(model::Model, f::AffineDecisionFunction)
    return DAE(AffExpr(model, f.variable_part),
               _DecisionAffExpr(model, f.decision_part))
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
MOI.constant(f::AffineDecisionFunction, T::Type) = MOI.constant(f)
MOI.constant(f::VectorAffineDecisionFunction) = MOI.constant(f.variable_part)
MOI.constant(f::VectorAffineDecisionFunction, T::Type) = MOI.constant(f)

function MOIU.eval_variables(varval::Function, f::AffineDecisionFunction)
    var_value = MOIU.eval_variables(varval, f.variable_part)
    dvar_value = MOIU.eval_variables(varval, f.decision_part)
    return var_value + dvar_value
end
function MOIU.eval_variables(varval::Function, f::VectorAffineDecisionFunction)
    var_value = MOIU.eval_variables(varval, f.variable_part)
    dvar_value = MOIU.eval_variables(varval, f.decision_part)
    return var_value + dvar_value
end

function MOIU.map_indices(index_map::Function, f::Union{AffineDecisionFunction, VectorAffineDecisionFunction})
    return typeof(f)(MOIU.map_indices(index_map, f.variable_part),
                     MOIU.map_indices(index_map, f.decision_part))
end

Base.eltype(it::MOIU.ScalarFunctionIterator{VectorAffineDecisionFunction{T}}) where T = AffineDecisionFunction{T}

function MOIU.ScalarFunctionIterator(f::VectorAffineDecisionFunction)
    return MOIU.ScalarFunctionIterator(
        f,
        (
            MOIU.output_index_iterator(f.variable_part.terms, MOI.output_dimension(f)),
            MOIU.output_index_iterator(f.decision_part.terms, MOI.output_dimension(f))
        ),
    )
end

function Base.getindex(it::MOIU.ScalarFunctionIterator{VectorAffineDecisionFunction{T}}, output_index::Integer) where T
    variable_part = MOI.ScalarAffineFunction{T}(
        MOI.ScalarAffineTerm{T}[
            it.f.variable_part.terms[i].scalar_term for
            i in MOIU.ChainedIteratorAtIndex(it.cache[1], output_index)
        ],
        it.f.variable_part.constants[output_index],
    )
    decision_part = MOI.ScalarAffineFunction{T}(
        MOI.ScalarAffineTerm{T}[
            it.f.decision_part.terms[i].scalar_term for
            i in MOIU.ChainedIteratorAtIndex(it.cache[2], output_index)
        ],
        it.f.decision_part.constants[output_index],
    )
    AffineDecisionFunction(variable_part, decision_part)
end
function Base.getindex(it::MOIU.ScalarFunctionIterator{VectorAffineDecisionFunction{T}}, output_indices::AbstractVector) where T
    variable_terms = MOI.VectorAffineTerm{T}[]
    decision_terms = MOI.VectorAffineTerm{T}[]
    for (i, output_index) in enumerate(output_indices)
        for j in MOIU.ChainedIteratorAtIndex(it.cache[1], output_index)
            push!(variable_terms, MOI.VectorAffineTerm(i, it.f.variable_part.terms[j].scalar_term))
        end
        for j in MOIU.ChainedIteratorAtIndex(it.cache[2], output_index)
            push!(decision_terms, MOI.VectorAffineTerm(i, it.f.decision_part.terms[j].scalar_term))
        end
    end
    return VectorAffineDecisionFunction(MOI.VectorAffineFunction(variable_terms, it.f.variable_part.constants[output_indices]),
                                        MOI.VectorAffineFunction(decision_terms, it.f.decision_part.constants[output_indices]))
end


function MOIU.zero_with_output_dimension(::Type{VectorAffineDecisionFunction{T}}, n::Integer) where T
    return MOI.VectorAffineDecisionFunction{T}(MOIU.zero_with_output_dimension(MOI.VectorAffineFunction{T}, n),
                                               MOIU.zero_with_output_dimension(MOI.VectorAffineFunction{T}, n))
end

function MOIU.substitute_variables(variable_map::Function, f::AffineDecisionFunction{T}) where T
    g = AffineDecisionFunction(convert(MOI.ScalarAffineFunction{T}, MOI.constant(f.variable_part)),
                               convert(MOI.ScalarAffineFunction{T}, zero(T)))
    # Substitute variables
    for term in f.variable_part.terms
        func::AffineDecisionFunction{T} = variable_map(term.variable)
        new_term = MOIU.operate(*, T, term.coefficient, func)::AffineDecisionFunction{T}
        MOIU.operate!(+, T, g, new_term)::AffineDecisionFunction{T}
    end
    # Substitute decisions
    for term in f.decision_part.terms
        func::AffineDecisionFunction{T} = variable_map(term.variable)
        new_term = MOIU.operate(*, T, term.coefficient, func)::AffineDecisionFunction{T}
        MOIU.operate!(+, T, g, new_term)::AffineDecisionFunction{T}
    end
    return g
end

function MOIU.substitute_variables(variable_map::Function, f::VectorAffineDecisionFunction{T}) where T
    n = MOI.output_dimension(f)
    g = VectorAffineDecisionFunction(MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], copy(MOI.constant(f.variable_part))),
                                     MOI.VectorAffineFunction(MOI.VectorAffineTerm{T}[], zeros(T, n)))
    # Substitute variables
    for term in f.variable_part.terms
        func::AffineDecisionFunction{T} = variable_map(term.scalar_term.variable)
        new_term = MOIU.operate(*, T, term.scalar_term.coefficient, func)::AffineDecisionFunction{T}
        MOIU.operate_output_index!(+, T, term.output_index, g, new_term)::typeof(g)
    end
    # Substitute decisions
    for term in f.decision_part.terms
        func::AffineDecisionFunction{T} = variable_map(term.scalar_term.variable)
        new_term = MOIU.operate(*, T, term.scalar_term.coefficient, func)::AffineDecisionFunction{T}
        MOIU.operate_output_index!(+, T, term.output_index, g, new_term)::VectorAffineDecisionFunction{T}
    end
    return g
end

MOIU.constant_vector(f::AffineDecisionFunction) = [f.variable_part.constant]
MOIU.constant_vector(f::VectorAffineDecisionFunction) = f.variable_part.constants

MOIU.scalar_type(::Type{VectorAffineDecisionFunction{T}}) where T = AffineDecisionFunction{T}

MOIU.is_canonical(f::Union{AffineDecisionFunction, VectorAffineDecisionFunction}) =
    MOIU.is_canonical(f.variable_part) &&
    MOIU.is_canonical(f.decision_part)

MOIU.canonical(f::Union{AffineDecisionFunction, VectorAffineDecisionFunction}) = MOIU.canonicalize!(copy(f))

function MOIU.canonicalize!(f::Union{AffineDecisionFunction, VectorAffineDecisionFunction})
    MOIU.canonicalize!(f.variable_part)
    MOIU.canonicalize!(f.decision_part)
    return f
end

MOIU._is_constant(f::AffineDecisionFunction) =
    MOIU._is_constant(f.variable_part) &&
    MOIU._is_constant(f.decision_part)

MOIU.all_coefficients(p::Function, f::AffineDecisionFunction) =
    MOIU.all_coefficients(p, f.variable_part) &&
    MOIU.all_coefficients(p, f.decision_part)

MOIU.isapprox_zero(f::AffineDecisionFunction, tol) =
    MOIU.isapprox_zero(f.variable_part, tol) &&
    MOIU.isapprox_zero(f.decision_part, tol)

function MOIU.filter_variables(keep::Function, f::Union{AffineDecisionFunction, VectorAffineDecisionFunction})
    # Only filter variable part and decision part
    return typeof(f)(MOIU.filter_variables(keep, f.variable_part),
                     MOIU.filter_variables(keep, f.decision_part))
end

function MOIU.operate_coefficients(f, func::Union{AffineDecisionFunction, VectorAffineDecisionFunction})
    return typeof(func)(MOIU.operate_coefficients(f, func.variable_part),
                        MOIU.operate_coefficients(f, func.decision_part))
end

function MOIU.vectorize(funcs::AbstractVector{AffineDecisionFunction{T}}) where T
    return VectorAffineDecisionFunction{T}(
        MOIU.vectorize([f.variable_part for f in funcs]),
        MOIU.vectorize([f.decision_part for f in funcs]))
end

function MOIU.scalarize(f::VectorAffineDecisionFunction{T}, ignore_constants::Bool = false) where T
    variable_part = MOIU.scalarize(f.variable_part, ignore_constants)
    decision_part = MOIU.scalarize(f.decision_part, ignore_constants)
    return map(zip(variable_part, decision_part)) do (var_part, dvar_part)
        AffineDecisionFunction(var_part, dvar_part)
    end
end

function MOIU.convert_approx(::Type{SingleDecision},
                             func::AffineDecisionFunction{T};
                             tol = MOIU.tol_default(T)) where {T}
    f = MOIU.canonical(func)
    i = findfirst(t -> isapprox(t.coefficient, one(T), atol = tol), f.decision_part.terms)
    if abs(MOI.constant(f)) > tol ||
        i === nothing ||
        any(j -> j != i && abs(f.decision_part.terms[j].coefficient) > tol, eachindex(f.decision_part.terms)) ||
        any(j -> abs(f.variable_part.terms[j].coefficient) > tol, eachindex(f.variable_part.terms))
        throw(InexactError(:convert_approx, SingleDecision, func))
    end
    return SingleDecision(f.decision_part.terms[i].variable)
end

function MOIU.convert_approx(::Type{VectorOfDecisions},
                             func::VectorAffineDecisionFunction{T};
                             tol = MOIU.tol_default(T)) where {T}
    return VectorOfDecisions([
        MOIU.convert_approx(SingleDecision, f, tol = tol).decision for
        f in MOIU.scalarize(func)
    ])
end

function modify_coefficient!(terms::Vector{MOI.ScalarAffineTerm{T}},
                             index::MOI.VariableIndex,
                             new_coefficient::Number) where T
    i = something(findfirst(t -> t.variable == index,
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
    for i in findall(t -> t.variable == index, terms)
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
    index = term.variable
    coefficient = term.coefficient
    i = something(findfirst(t -> t.variable == index,
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
    index = term.variable
    coefficient = term.coefficient
    i = something(findfirst(t -> t.variable == index,
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
