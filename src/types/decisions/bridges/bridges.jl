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

# Variables #
# ========================== #
include("variable.jl")
# Objective #
# ========================== #
include("objectives/objective.jl")
# Constraint #
# ========================== #
include("constraints/constraints.jl")
# SingleDecision #
# ========================== #
# SingleDecision support is achieved by adding a few methods to MathOptInterface
# as well as two specialized functionize bridges which behave as their SingleVariable
# counterparts
include("functionize.jl")

function MOIB.Variable.function_for(map::MOIB.Variable.Map, ci::MOI.ConstraintIndex{SingleDecision})
    return SingleDecision(MOI.VariableIndex(ci.value))
end

function MOIB.Variable.function_for(map::MOIB.Variable.Map, ci::MOI.ConstraintIndex{VectorOfDecisions})
    decisions = MOI.VariableIndex[]
    for i in ci.value:-1:-length(map.bridges)
        vi = MOI.VariableIndex(i)
        if map.index_in_vector[-vi.value] == -1
            continue
        elseif bridge_index(map, vi) == -ci.value
            push!(decisions, vi)
        else
            break
        end
    end
    return VectorOfDecisions(decisions)
end

function MOIB.is_variable_bridged(
    b::MOIB.AbstractBridgeOptimizer,
    ci::MOI.ConstraintIndex{<:Union{SingleDecision, VectorOfDecisions}})
    return ci.value < 0 && !haskey(MOIB.Constraint.bridges(b), ci)
end

function MOIB.bridged_function(b::MOIB.AbstractBridgeOptimizer, f::SingleDecision)
    return f
end

function MOIB.unbridged_function(bridge::MOIB.AbstractBridgeOptimizer,
                                 f::Union{SingleDecision, VectorOfDecisions})
    return f
end

function MOI.set(b::MOIB.AbstractBridgeOptimizer,
                 attr::MOI.ObjectiveFunction,
                 f::SingleDecision)
    if MOIB.Variable.has_bridges(MOIB.Variable.bridges(b))
        if MOIB.is_bridged(b, f.decision)
            BridgeType = MOIB.Objective.concrete_bridge_type(
                FunctionizeDecisionObjectiveBridge{Float64}, typeof(f))
            MOIB._bridge_objective(b, BridgeType, f)
        end
    end
end

function MOI.add_constraint(b::MOIB.AbstractBridgeOptimizer,
                            f::SingleDecision,
                            s::MOI.AbstractSet)
    if MOIB.is_bridged(b, f.decision)
        if MOI.is_valid(b, MOI.ConstraintIndex{MOI.SingleVariable, typeof(s)}(f.decision.value))
            # The other constraint could have been through a variable bridge.
            error("Cannot add two `SingleDecision`-in-`$(typeof(s))`",
                  " on the same decision $(f.decision).")
        end
        BridgeType = MOIB.Constraint.concrete_bridge_type(
            SingleDecisionConstraintBridge{Float64}, typeof(f), typeof(s))
        return MOIB.add_bridged_constraint(b, BridgeType, f, s)
    end
    error("`SingleDecision`-in-`$(typeof(s))` is only supported through variable bridging.")
end

function MOI.add_constraint(b::MOIB.AbstractBridgeOptimizer,
                            f::VectorOfDecisions,
                            s::MOI.AbstractSet)
    if any(vi -> MOIB.is_bridged(b, vi), f.decisions)
        if MOI.is_valid(b, MOI.ConstraintIndex{MOI.VectorOfVariables, typeof(s)}(first(f.decisions).value))
            # The other constraint could have been through a variable bridge.
            error("Cannot add two `VectorOfDecisions`-in-`$(typeof(s))`",
                  " on the same first decision $(first(f.decisions)).")
        end
        if !MOIB.is_bridged(b, first(f.decisions)) && !MOIB.is_bridged(b, typeof(f), typeof(s))
            # The index of the contraint will have positive value hence
            # it would clash with the index space of `b.model` since
            # the constraint type is normally not bridged.
            error("Cannot `VectorOfDecisions`-in-`$(typeof(s))` for",
                  " which some decisions are bridged but not the",
                  " first one `$(first(f.decisions))`.")
        end
        BridgeType = MOIB.Constraint.concrete_bridge_type(
            VectorDecisionConstraintBridge{Float64}, typeof(f), typeof(s))
        return MOIB.add_bridged_constraint(b, BridgeType, f, s)
    end
    error("`VectorOfDecisions`-in-`$(typeof(s))` is only supported through variable bridging.")
end

function MOI.add_constraints(b::MOIB.AbstractBridgeOptimizer,
                             f::Vector{SingleDecision},
                             s::Vector{S}) where S <: MOI.AbstractSet
    MOI.add_constraint.(b, f, s)
end

function MOI.add_constraints(b::MOIB.AbstractBridgeOptimizer,
                             f::Vector{VectorOfDecisions},
                             s::Vector{S}) where S <: MOI.AbstractSet
    MOI.add_constraint.(b, f, s)
end

function MOI.get(b::MOIB.AbstractBridgeOptimizer, attr::MOI.ConstraintSet,
                 ci::MOI.ConstraintIndex{SingleDecision})
    return if MOIB.is_bridged(b, ci)
        MOI.throw_if_not_valid(b, ci)
        MOIB.call_in_context(b, ci, bridge -> MOI.get(b, attr, bridge))
    else
        MOI.get(b.model, attr, ci)
    end
end

function MOIB.bridged_constraint_function(
    b::MOIB.AbstractBridgeOptimizer, f::SingleDecision,
    set::MOI.AbstractScalarSet)
    return MOIB.bridged_function(b, f), set
end

function MOIB.unbridged_constraint_function(
    b::MOIB.AbstractBridgeOptimizer, f::SingleDecision)
    return MOIB.unbridged_function(b, f)
end

# Bridge addition #
# ========================== #
function add_decision_bridges!(model::JuMP.Model)
    add_bridge(model, DecisionBridge)
    add_bridge(model, DecisionsBridge)
    add_bridge(model, AffineDecisionObjectiveBridge)
    add_bridge(model, QuadraticDecisionObjectiveBridge)
    add_bridge(model, AffineDecisionConstraintBridge)
    add_bridge(model, QuadraticDecisionConstraintBridge)
    add_bridge(model, VectorAffineDecisionConstraintBridge)
    add_bridge(model, FunctionizeDecisionObjectiveBridge)
end
