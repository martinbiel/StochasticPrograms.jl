struct DecisionCoefficientChange{T} <: MOI.AbstractFunctionModification
    decision::MOI.VariableIndex
    new_coefficient::T
end

struct DecisionMultirowChange{T} <: MOI.AbstractFunctionModification
    decision::MOI.VariableIndex
    new_coefficients::Vector{Tuple{Int64, T}}
end

struct KnownCoefficientChange{T} <: MOI.AbstractFunctionModification
    known::MOI.VariableIndex
    new_coefficient::T
end

struct KnownMultirowChange{T} <: MOI.AbstractFunctionModification
    known::MOI.VariableIndex
    new_coefficients::Vector{Tuple{Int64, T}}
end

struct DecisionStateChange{T} <: MOI.AbstractFunctionModification
    decision::MOI.VariableIndex
    new_state::DecisionState
    value_difference::T
end

struct DecisionsStateChange <: MOI.AbstractFunctionModification end

struct KnownValueChange{T} <: MOI.AbstractFunctionModification
    known::MOI.VariableIndex
    value_difference::T
end

struct KnownValuesChange <: MOI.AbstractFunctionModification end

const DecisionModification = Union{DecisionCoefficientChange, DecisionStateChange, DecisionsStateChange}
const KnownModification = Union{KnownCoefficientChange, KnownValueChange, KnownValuesChange}
