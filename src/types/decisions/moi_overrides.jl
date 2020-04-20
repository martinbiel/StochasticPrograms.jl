function MOIU.map_indices(index_map::Function, change::DecisionCoefficientChange)
    return DecisionCoefficientChange(index_map(change.decision), change.new_coefficient)
end
function MOIU.map_indices(index_map::Function, change::KnownCoefficientChange)
    return KnownCoefficientChange(index_map(change.known), change.new_coefficient)
end
function MOIU.map_indices(index_map::Function, change::DecisionStateChange)
    return DecisionStateChange(index_map(change.decision), change.new_state, change.value_difference)
end
MOIU.map_indices(index_map::Function, change::DecisionsStateChange) = change
function MOIU.map_indices(index_map::Function, change::KnownValueChange)
    return KnownValueChange(index_map(change.known), change.value_difference)
end
MOIU.map_indices(index_map::Function, change::KnownValuesChange) = change

function MOIU.modify_function(f::AffineDecisionFunction, change::MOI.ScalarConstantChange)
    return typeof(f)(MOIU.modify_function(f.variable_part, change),
                     copy(f.decision_part),
                     copy(f.known_part))
end

function MOIU.modify_function(f::AffineDecisionFunction, change::MOI.ScalarCoefficientChange)
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

function MOIU.modify_function(f::AffineDecisionFunction, change::KnownCoefficientChange)
    return typeof(f)(copy(f.variable_part),
                     copy(f.decision_part),
                     MOIU.modify_function(f.known_part,
                                          MOI.ScalarCoefficientChange(change.known, change.new_coefficient)))
    return
end

function MOIU.modify_function(f::Union{SingleDecision, AffineDecisionFunction}, ::DecisionStateChange)
    # Nothing to do here, handled in bridges
    return f
end

function MOIU.modify_function(f::Union{SingleDecision, AffineDecisionFunction}, ::DecisionsStateChange)
    # Nothing to do here, handled in bridges
    return f
end

function MOIU.modify_function(f::Union{SingleDecision, AffineDecisionFunction}, ::KnownValueChange)
    # Nothing to do here, handled in bridges
    return f
end

function MOIU.modify_function(f::Union{SingleDecision, AffineDecisionFunction}, ::KnownValuesChange)
    # Nothing to do here, handled in bridges
    return f
end
