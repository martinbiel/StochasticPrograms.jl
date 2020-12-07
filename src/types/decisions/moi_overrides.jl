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

function MOIU.modify_function(f::QuadraticDecisionFunction{T,LinearPart{T}}, change::Union{MOI.ScalarConstantChange, MOI.ScalarCoefficientChange}) where T
    lq = f.linear_quadratic_terms
    return typeof(f)(
        LinearPart(
            MOIU.modify_function(lq.variable_part, change),
            copy(lq.decision_part)),
        copy(f.known_part),
        copy(f.known_variable_terms),
        copy(f.known_decision_terms))
end

function MOIU.modify_function(f::QuadraticDecisionFunction{T,QuadraticPart{T}}, change::Union{MOI.ScalarConstantChange, MOI.ScalarCoefficientChange}) where T
    lq = f.linear_quadratic_terms
    return typeof(f)(
        QuadraticPart(
            MOIU.modify_function(lq.variable_part, change),
            copy(lq.decision_part),
            copy(lq.cross_terms)),
        copy(f.known_part),
        copy(f.known_variable_terms),
        copy(f.known_decision_terms))
end

function MOIU.modify_function(f::VectorAffineDecisionFunction, change::Union{MOI.VectorConstantChange, MOI.MultirowChange})
    return typeof(f)(MOIU.modify_function(f.variable_part, change),
                     copy(f.decision_part),
                     copy(f.known_part))
end

function MOIU.modify_function(f::AffineDecisionFunction, change::DecisionCoefficientChange)
    return typeof(f)(copy(f.variable_part),
                     MOIU.modify_function(f.decision_part,
                                          MOI.ScalarCoefficientChange(change.decision, change.new_coefficient)),
                     copy(f.known_part))
end

function MOIU.modify_function(f::QuadraticDecisionFunction{T,LinearPart{T}}, change::DecisionCoefficientChange) where T
    lq = f.linear_quadratic_terms
    return typeof(f)(
        LinearPart(
            copy(lq.variable_part),
            MOIU.modify_function(lq.decision_part,
                                 MOI.ScalarCoefficientChange(change.decision, change.new_coefficient))),
        copy(f.known_part),
        copy(f.known_variable_terms),
        copy(f.known_decision_terms))
end

function MOIU.modify_function(f::QuadraticDecisionFunction{T,QuadraticPart{T}}, change::DecisionCoefficientChange) where T
    lq = f.linear_quadratic_terms
    return typeof(f)(
        QuadraticPart(
            copy(lq.variable_part),
            MOIU.modify_function(lq.decision_part,
                                 MOI.ScalarCoefficientChange(change.decision, change.new_coefficient)),
            copy(lq.cross_terms)),
        copy(f.known_part),
        copy(f.known_variable_terms),
        copy(f.known_decision_terms))
end

function MOIU.modify_function(f::VectorAffineDecisionFunction, change::DecisionMultirowChange)
    return typeof(f)(copy(f.variable_part),
                     MOIU.modify_function(f.decision_part,
                                          DecisionMultirowChange(change.decision, change.new_coefficients)),
                     copy(f.known_part))
end

function MOIU.modify_function(f::AffineDecisionFunction, change::KnownCoefficientChange)
    return typeof(f)(copy(f.variable_part),
                     copy(f.decision_part),
                     MOIU.modify_function(f.known_part,
                                          MOI.ScalarCoefficientChange(change.known, change.new_coefficient)))
end

function MOIU.modify_function(f::QuadraticDecisionFunction, change::KnownCoefficientChange) where T
    return typeof(f)(
        copy(f.linear_quadratic_terms),
        MOIU.modify_function(f.known_part,
                             MOI.ScalarCoefficientChange(change.known, change.new_coefficient)),
        copy(f.known_variable_terms),
        copy(f.known_decision_terms))
end

function MOIU.modify_function(f::VectorAffineDecisionFunction, change::KnownMultirowChange)
    return typeof(f)(copy(f.variable_part),
                     copy(f.decision_part),
                     MOIU.modify_function(f.known_part,
                                          KnownMultirowChange(change.known, change.new_coefficients)))
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

function MOI.add_constraint(uf::MOIU.UniversalFallback, f::SingleDecision, s::MOI.AbstractScalarSet)
    F = typeof(f)
    S = typeof(s)
    # Add constraint as usual but force index
    constraints = get!(uf.constraints, (F, S)) do
        OrderedDict{CI{F, S}, Tuple{F, S}}()
    end::OrderedDict{CI{F, S}, Tuple{F, S}}
    ci = CI{typeof(f), typeof(s)}(f.decision.value)
    if !(s isa FreeDecision)
        constraints[ci] = (f, s)
    end
    return ci
end

function MOI.delete(uf::MOIU.UniversalFallback, ci::CI{F, S}) where {F <: SingleDecision, S <: MOI.AbstractScalarSet}
    decision_ci = CI{MOI.SingleVariable, SingleDecisionSet{Float64}}(ci.value)
    if !MOI.is_valid(uf, ci) && MOI.is_valid(uf, decision_ci)
        throw(MOI.InvalidIndex(ci))
    end
    # Delete constraint as usual
    if MOI.is_valid(uf, ci)
        delete!(uf.constraints[(F, S)], ci)
        delete!(uf.con_to_name, ci)
        uf.name_to_con = nothing
        for d in values(uf.conattr)
            delete!(d, ci)
        end
    end
    # Update SingleDecisionSet for printing
    if MOI.is_valid(uf, decision_ci)
        set = MOI.get(uf, MOI.ConstraintSet(), decision_ci)
        new_set = SingleDecisionSet(set.stage, set.decision, NoSpecifiedConstraint(), set.is_recourse)
        MOI.set(uf, MOI.ConstraintSet(), decision_ci, new_set)
    end
    return nothing
end
