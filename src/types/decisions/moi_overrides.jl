function MOIU.map_indices(index_map::Function, change::DecisionCoefficientChange)
    return DecisionCoefficientChange(index_map(change.decision), change.new_coefficient)
end
MOIU.map_indices(index_map::Function, change::DecisionStateChange) = change
MOIU.map_indices(index_map::Function, change::KnownValuesChange) = change

function MOIU.modify_function(f::AffineDecisionFunction, change::Union{MOI.ScalarConstantChange, MOI.ScalarCoefficientChange})
    return typeof(f)(MOIU.modify_function(f.variable_part, change),
                     copy(f.decision_part))
end

function MOIU.modify_function(f::QuadraticDecisionFunction{T}, change::Union{MOI.ScalarConstantChange, MOI.ScalarCoefficientChange}) where T
    return typeof(f)(
        MOIU.modify_function(f.variable_part, change),
        copy(f.decision_part),
        copy(f.cross_terms))
end

function MOIU.modify_function(f::VectorAffineDecisionFunction, change::Union{MOI.VectorConstantChange, MOI.MultirowChange})
    return typeof(f)(MOIU.modify_function(f.variable_part, change),
                     copy(f.decision_part))
end

function MOIU.modify_function(f::AffineDecisionFunction, change::DecisionCoefficientChange)
    return typeof(f)(copy(f.variable_part),
                     MOIU.modify_function(f.decision_part,
                                          MOI.ScalarCoefficientChange(change.decision, change.new_coefficient)))
end

function MOIU.modify_function(f::QuadraticDecisionFunction{T}, change::DecisionCoefficientChange) where T
    return typeof(f)(
        copy(f.variable_part),
        MOIU.modify_function(f.decision_part,
                             MOI.ScalarCoefficientChange(change.decision, change.new_coefficient)),
        copy(f.cross_terms))
end

function MOIU.modify_function(f::VectorAffineDecisionFunction, change::DecisionMultirowChange)
    return typeof(f)(copy(f.variable_part),
                     MOIU.modify_function(f.decision_part,
                                          DecisionMultirowChange(change.decision, change.new_coefficients)))
end

function MOIU.modify_function(f::Union{SingleDecision, AffineDecisionFunction, QuadraticDecisionFunction, VectorAffineDecisionFunction}, change::Union{DecisionStateChange, KnownValuesChange})
    # Nothing to do here, handled in bridges
    return f
end

# Can rely on scalarize bridge if modifications are passed along
function MOI.modify(model::MOI.ModelLike,
                    bridge::MOIB.Constraint.ScalarizeBridge{T, AffineDecisionFunction{T}},
                    change::DecisionModification) where T
    for constraint in bridge.scalar_constraints
        MOI.modify(model, constraint, change)
    end
    return nothing
end

# Can rely on vectorize bridge if modifications are passed along
function MOI.modify(model::MOI.ModelLike,
                    bridge::MOIB.Constraint.VectorizeBridge{T, VectorAffineDecisionFunction{T}},
                    change::DecisionModification) where T
    MOI.modify(model, bridge.vector_constraint, change)
    return nothing
end

# Can rely on flipsign bridges if modifications are passed along
function MOI.modify(model::MOI.ModelLike,
                    bridge::MOIB.Constraint.FlipSignBridge,
                    change::DecisionModification)
    MOI.modify(model, bridge.constraint, change)
    return nothing
end

# Can rely on norm-bridges if modifications are passed along
function MOI.modify(model::MOI.ModelLike,
                    bridge::MOIB.Constraint.NormInfinityBridge{T, VectorAffineDecisionFunction{T}},
                    change::DecisionModification) where T
    MOI.modify(model, bridge.constraint, change)
    return nothing
end
function MOI.modify(model::MOI.ModelLike,
                    bridge::MOIB.Constraint.NormOneBridge{T, VectorAffineDecisionFunction{T}},
                    change::DecisionModification) where T
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
    constraints[ci] = (f, s)
    return ci
end

function MOI.modify(uf::MOIU.UniversalFallback, ::CI{F,S}, ::Union{DecisionStateChange,KnownValuesChange}) where {F, S}
    return nothing
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

function MOI.get(model::MOIU.CachingOptimizer,
                 attr::DecisionIndex,
                 ci::CI)
    return MOI.get(model.optimizer, attr, model.model_to_optimizer_map[ci])
end

function MOI.get(b::MOIB.AbstractBridgeOptimizer,
                 attr::DecisionIndex, ci::MOI.ConstraintIndex)
    return MOIB.call_in_context(b, ci, bridge -> MOI.get(b, attr, bridge))
end
