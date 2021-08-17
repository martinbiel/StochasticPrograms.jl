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

# VectorAffineDecisionFunction #
# ========================== #
mutable struct VectorAffineDecisionConstraintBridge{T, S} <: MOIB.Constraint.AbstractBridge
    constraint::CI{MOI.VectorAffineFunction{T}, S}
    decision_function::VectorAffineDecisionFunction{T}
    set::S
end

function MOIB.Constraint.bridge_constraint(::Type{VectorAffineDecisionConstraintBridge{T, S}},
                                           model,
                                           f::VectorAffineDecisionFunction{T},
                                           set::S) where {T, S}
    # All decisions have been mapped to the variable part terms
    # at this point.
    F = MOI.VectorAffineFunction{T}
    # Add the bridged constraint
    constraint = MOI.add_constraint(model,
                                    f.variable_part,
                                    set)
    # Save the constraint index, the decision function, and the set, to allow modifications
    return VectorAffineDecisionConstraintBridge{T, S}(constraint, f, set)
end

function MOI.supports_constraint(::Type{<:VectorAffineDecisionConstraintBridge{T}},
                                 ::Type{<:VectorAffineDecisionFunction{T}},
                                 ::Type{<:MOI.AbstractVectorSet}) where {T}
    return true
end
function MOIB.added_constrained_variable_types(::Type{<:VectorAffineDecisionConstraintBridge})
    return Tuple{DataType}[]
end
function MOIB.added_constraint_types(::Type{<:VectorAffineDecisionConstraintBridge{T, S}}) where {T, S}
    return [(MOI.VectorAffineFunction{T}, S)]
end
function MOIB.Constraint.concrete_bridge_type(::Type{<:VectorAffineDecisionConstraintBridge{T}},
                                              ::Type{<:VectorAffineDecisionFunction{T}},
                                              S::Type{<:MOI.AbstractVectorSet}) where T
    return VectorAffineDecisionConstraintBridge{T, S}
end

MOI.get(b::VectorAffineDecisionConstraintBridge{T, S}, ::MOI.NumberOfConstraints{MOI.VectorAffineFunction{T}, S}) where {T, S} = 1
MOI.get(b::VectorAffineDecisionConstraintBridge{T, S}, ::MOI.ListOfConstraintIndices{MOI.VectorAffineFunction{T}, S}) where {T, S} = [b.constraint]

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintFunction,
                 bridge::VectorAffineDecisionConstraintBridge{T}) where T
    return bridge.decision_function
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintSet,
                 bridge::VectorAffineDecisionConstraintBridge{T}) where T
    return bridge.set
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintPrimal,
                 bridge::VectorAffineDecisionConstraintBridge{T}) where T
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.get(model::MOI.ModelLike, attr::MOI.ConstraintDual,
                 bridge::VectorAffineDecisionConstraintBridge{T}) where T
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.get(model::MOI.ModelLike, ::DecisionIndex,
                 bridge::VectorAffineDecisionConstraintBridge{T}) where T
    return bridge.constraint
end

function MOI.delete(model::MOI.ModelLike, bridge::VectorAffineDecisionConstraintBridge)
    MOI.delete(model, bridge.constraint)
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintFunction,
                 bridge::VectorAffineDecisionConstraintBridge{T,S},
                 f::VectorAffineDecisionFunction{T}) where {T,S}
    # Update bridge functions and function constant
    bridge.decision_function = f
    # Modify constraint function
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            f.variable_part)
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::VectorAffineDecisionConstraintBridge{T,S}, change::S) where {T,S}
    f = bridge.decision_function
    bridge.set = change
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint, change)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::VectorAffineDecisionConstraintBridge{T,S}, change::MOI.VectorConstantChange) where {T,S}
    f = bridge.decision_function
    # Modify variable part of decision function
    f.variable_part.constants .= change.new_constant
    MOI.set(model, MOI.ConstraintFunction(), bridge.constraint,
            f.variable_part)
    return nothing
end

function MOI.modify(model::MOI.ModelLike, bridge::VectorAffineDecisionConstraintBridge{T,S}, change::MOI.MultirowChange) where {T,S}
    f = bridge.decision_function
    # Modify variable part of decision function
    modify_coefficients!(f.variable_part.terms, change.decision, change.new_coefficients)
    # Modify the variable part of the constraint as usual
    MOI.modify(model, bridge.constraint, change)
    return nothing
end
