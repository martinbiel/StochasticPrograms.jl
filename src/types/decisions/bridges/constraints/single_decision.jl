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

# SingleDecision #
# ========================== #
mutable struct SingleDecisionConstraintBridge{T, S <: MOI.AbstractScalarSet} <: MOIB.Constraint.AbstractBridge
    constraint::CI{MOI.VariableIndex, S}
    decision::SingleDecision
end

function MOIB.Constraint.bridge_constraint(::Type{SingleDecisionConstraintBridge{T,S}},
                                           model,
                                           f::SingleDecision,
                                           set::S) where {T, S <: MOI.AbstractScalarSet}
    # Perform the bridge mapping manually
    g = MOIB.bridged_variable_function(model, f.decision)
    mapped_variable = MOI.VariableIndex(only(g.terms).variable.value)
    # Add the bridged constraint
    constraint = MOI.add_constraint(model,
                                    mapped_variable,
                                    set)
    # Save the constraint index and the decision to allow modifications
    return SingleDecisionConstraintBridge{T,S}(constraint, f)
end

function MOI.supports_constraint(::Type{<:SingleDecisionConstraintBridge{T}},
                                 ::Type{SingleDecision},
                                 ::Type{<:MOI.AbstractScalarSet}) where T
    return true
end
function MOIB.added_constrained_variable_types(::Type{<:SingleDecisionConstraintBridge})
    return Tuple{Type}[]
end
function MOIB.added_constraint_types(::Type{<:SingleDecisionConstraintBridge{T,S}}) where {T,S}
    return [(MOI.VariableIndex, S), (MOI.ScalarAffineFunction{T}, MOI.EqualTo{T})]
end
function MOIB.Constraint.concrete_bridge_type(::Type{<:SingleDecisionConstraintBridge{T}},
                              ::Type{SingleDecision},
                              S::Type{<:MOI.AbstractScalarSet}) where T
    return SingleDecisionConstraintBridge{T,S}
end

MOI.get(b::SingleDecisionConstraintBridge{T,S}, ::MOI.NumberOfConstraints{MOI.VariableIndex, S}) where {T,S} = 1
MOI.get(b::SingleDecisionConstraintBridge{T}, ::MOI.ListOfConstraintIndices{MOI.VariableIndex, S}) where {T,S} = [b.constraint]

function MOI.get(model::MOI.ModelLike, attr::MOI.AbstractConstraintAttribute,
                 bridge::SingleDecisionConstraintBridge)
    return MOI.get(model, attr, bridge.constraint)
end

function MOI.get(model::MOI.ModelLike, ::DecisionIndex,
                 bridge::SingleDecisionConstraintBridge{T}) where T
    return bridge.constraint
end

function MOI.delete(model::MOI.ModelLike, bridge::SingleDecisionConstraintBridge)
    if bridge.constraint.value != 0
        MOI.delete(model, bridge.constraint)
    end
    return nothing
end

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::SingleDecisionConstraintBridge{T,S}, change::S) where {T, S <: MOI.AbstractScalarSet}
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint, change)
    return nothing
end
