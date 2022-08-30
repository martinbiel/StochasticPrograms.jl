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

# Objective #
# ========================== #
struct FunctionizeDecisionObjectiveBridge{T} <: MOIB.Objective.AbstractBridge end

function MOIB.Objective.bridge_objective(::Type{FunctionizeDecisionObjectiveBridge{T}}, model::MOI.ModelLike,
                                         f::SingleDecision) where T
    F = AffineDecisionFunction{T}
    MOI.set(model, MOI.ObjectiveFunction{F}(), convert(F, f))
    return FunctionizeDecisionObjectiveBridge{T}()
end

function MOIB.Objective.supports_objective_function(
    ::Type{<:FunctionizeDecisionObjectiveBridge}, ::Type{SingleDecision})
    return true
end
MOIB.added_constrained_variable_types(::Type{<:FunctionizeDecisionObjectiveBridge}) = Tuple{Type}[]
function MOIB.added_constraint_types(::Type{<:FunctionizeDecisionObjectiveBridge})
    return Tuple{Type, Type}[]
end
function MOIB.set_objective_function_type(::Type{FunctionizeDecisionObjectiveBridge{T}}) where T
    return AffineDecisionFunction{T}
end

# Attributes, Bridge acting as a model
function MOI.get(bridge::FunctionizeDecisionObjectiveBridge, ::MOI.NumberOfVariables)
    return 0
end
function MOI.get(bridge::FunctionizeDecisionObjectiveBridge, ::MOI.ListOfVariableIndices)
    return MOI.VariableIndex[]
end

# No variables or constraints are created in this bridge so there is nothing to
# delete.
function MOI.delete(model::MOI.ModelLike, bridge::FunctionizeDecisionObjectiveBridge) end

function MOI.set(::MOI.ModelLike, ::MOI.ObjectiveSense,
                 ::FunctionizeDecisionObjectiveBridge, ::MOI.OptimizationSense)
    # `FunctionizeDecisionObjectiveBridge` is sense agnostic, therefore, we don't need to change
    # anything.
    return nothing
end
function MOI.get(model::MOI.ModelLike,
                 attr::MOIB.ObjectiveFunctionValue{SingleDecision},
                 bridge::FunctionizeDecisionObjectiveBridge{T}) where T
    F = AffineDecisionFunction{T}
    return MOI.get(model, MOIB.ObjectiveFunctionValue{F}(attr.result_index))
end
function MOI.get(model::MOI.ModelLike, attr::MOI.ObjectiveFunction{SingleDecision},
                 bridge::FunctionizeDecisionObjectiveBridge{T}) where T
    F = AffineDecisionFunction{T}
    func = MOI.get(model, MOI.ObjectiveFunction{F}())
    return convert(SingleDecision, func)
end
