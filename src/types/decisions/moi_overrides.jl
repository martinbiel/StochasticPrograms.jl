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
                                          MOI.MultirowChange(change.decision, change.new_coefficients)))
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

function MOI.modify(uf::MOIU.UniversalFallback, ::CI{F,S}, ::Union{DecisionStateChange,KnownValuesChange}) where {F, S}
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
