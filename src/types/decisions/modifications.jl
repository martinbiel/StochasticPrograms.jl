struct DecisionIndex <: MOI.AbstractConstraintAttribute end
MOI.is_set_by_optimize(::DecisionIndex) = true

struct DecisionCoefficientChange{T} <: MOI.AbstractFunctionModification
    decision::MOI.VariableIndex
    new_coefficient::T
end

struct DecisionMultirowChange{T} <: MOI.AbstractFunctionModification
    decision::MOI.VariableIndex
    new_coefficients::Vector{Tuple{Int64, T}}
end

struct DecisionStateChange <: MOI.AbstractFunctionModification
    index::Int
    new_state::DecisionState
end

struct KnownValuesChange <: MOI.AbstractFunctionModification end

const DecisionModification = Union{DecisionCoefficientChange, DecisionStateChange, KnownValuesChange}
const VectorDecisionModification = Union{DecisionMultirowChange, DecisionStateChange, KnownValuesChange}
