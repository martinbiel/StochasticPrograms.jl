function MOIU.map_indices(index_map::Function, change::DecisionCoefficientChange)
    return DecisionCoefficientChange(index_map(change.decision), change.new_coefficient)
end
function MOIU.map_indices(index_map::Function, change::KnownCoefficientChange)
    return KnownCoefficientChange(index_map(change.known), change.new_coefficient, change.known_value)
end
function MOIU.map_indices(index_map::Function, change::DecisionStateChange)
    return DecisionStateChange(index_map(change.decision), change.new_state, change.value_difference)
end
MOIU.map_indices(index_map::Function, change::DecisionsStateChange) = change
function MOIU.map_indices(index_map::Function, change::KnownValueChange)
    return change
end
MOIU.map_indices(index_map::Function, change::KnownValuesChange) = change

function MOIU.modify_function(f::AffineDecisionFunction, change::Union{MOI.ScalarConstantChange, MOI.ScalarCoefficientChange})
    return typeof(f)(MOIU.modify_function(f.variable_part, change),
                     copy(f.decision_part),
                     copy(f.known_part))
end

function MOIU.modify_function(f::QuadraticDecisionFunction, change::Union{MOI.ScalarConstantChange, MOI.ScalarCoefficientChange})
    return typeof(f)(MOIU.modify_function(f.variable_part, change),
                     copy(f.decision_part),
                     copy(f.known_part),
                     copy(f.cross_terms),
                     copy(f.known_variable_terms),
                     copy(f.known_decision_terms))
end

function MOIU.modify_function(f::VectorAffineDecisionFunction, change::MOI.VectorConstantChange)
    return typeof(f)(MOIU.modify_function(f.variable_part, change),
                     copy(f.decision_part),
                     copy(f.known_part))
end

function MOIU.modify_function(f::AffineDecisionFunction, change::DecisionCoefficientChange)
    return typeof(f)(copy(f.variable_part),
                     MOIU.modify_function(f.decision_part,
                                          MOI.ScalarCoefficientChange(change.decision, change.new_coefficient)),
                     copy(f.known_part))
    return
end

function MOIU.modify_function(f::QuadraticDecisionFunction, change::DecisionCoefficientChange)
    return typeof(f)(copy(f.variable_part),
                     MOIU.modify_function(f.decision_part,
                                          MOI.ScalarCoefficientChange(change.decision, change.new_coefficient)),
                     copy(f.known_part),
                     copy(f.cross_terms),
                     copy(f.known_variable_terms),
                     copy(f.known_decision_terms))
end

function MOIU.modify_function(f::AffineDecisionFunction, change::KnownCoefficientChange)
    return typeof(f)(copy(f.variable_part),
                     copy(f.decision_part),
                     MOIU.modify_function(f.known_part,
                                          MOI.ScalarCoefficientChange(change.known, change.new_coefficient)))
end

function MOIU.modify_function(f::QuadraticDecisionFunction, change::KnownCoefficientChange)
    return typeof(f)(copy(f.variable_part),
                     copy(f.decision_part),
                     MOIU.modify_function(f.known_part,
                                          MOI.ScalarCoefficientChange(change.known, change.new_coefficient)),
                     copy(f.cross_terms),
                     copy(f.known_variable_terms),
                     copy(f.known_decision_terms))
end

function MOIU.modify_function(f::Union{SingleDecision, AffineDecisionFunction, QuadraticDecisionFunction}, ::Union{DecisionStateChange, DecisionsStateChange})
    # Nothing to do here, handled in bridges
    return f
end

function MOIU.modify_function(f::Union{AffineDecisionFunction, QuadraticDecisionFunction, VectorAffineDecisionFunction}, change::Union{KnownValueChange, KnownValuesChange}) where T
    # Nothing to do here, handled in bridges
    return f
end

# Can rely on scalarize bridge if modifications are passed along
function MOI.modify(model::MOI.ModelLike,
                    bridge::MOIB.Constraint.ScalarizeBridge{T, AffineDecisionFunction{T}},
                    change::Union{DecisionModification, KnownModification}) where T
    for constraint in bridge.scalar_constraints
        MOI.modify(model, constraint, change)
    end
    return nothing
end

# Can rely on vectorize bridge if modifications are passed along
function MOI.modify(model::MOI.ModelLike,
                    bridge::MOIB.Constraint.VectorizeBridge{T, VectorAffineDecisionFunction{T}},
                    change::Union{DecisionModification, KnownModification}) where T
    MOI.modify(model, bridge.vector_constraint, change)
    return nothing
end

# Can rely on flipsign bridges if modifications are passed along
function MOI.modify(model::MOI.ModelLike,
                    bridge::MOIB.Constraint.FlipSignBridge,
                    change::Union{DecisionModification, KnownModification})
    MOI.modify(model, bridge.constraint, change)
    return nothing
end

# Can rely on norm-bridges if modifications are passed along
function MOI.modify(model::MOI.ModelLike,
                    bridge::MOIB.Constraint.NormInfinityBridge{T, VectorAffineDecisionFunction{T}},
                    change::Union{DecisionModification, KnownModification}) where T
    MOI.modify(model, bridge.constraint, change)
    return nothing
end
function MOI.modify(model::MOI.ModelLike,
                    bridge::MOIB.Constraint.NormOneBridge{T, VectorAffineDecisionFunction{T}},
                    change::Union{DecisionModification, KnownModification}) where T
    MOI.modify(model, bridge.nn_index, change)
    return nothing
end
