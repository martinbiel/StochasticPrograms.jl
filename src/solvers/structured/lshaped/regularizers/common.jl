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

# Common
# ------------------------------------------------------------
function MOI.get(regularizer::AbstractRegularizer, param::RawRegularizationParameter)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(regularizer.parameters)))
        error("Unrecognized parameter name: $(name) for regularizer $(typeof(regularizer)).")
    end
    return getfield(regularizer.parameters, name)
end

function MOI.set(regularizer::AbstractRegularizer, param::RawRegularizationParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(regularizer.parameters)))
        error("Unrecognized parameter name: $(name) for regularizer $(typeof(regularizer)).")
    end
    setfield!(regularizer.parameters, name, value)
    return nothing
end

function add_projection_targets!(regularization::AbstractRegularization, model::MOI.AbstractOptimizer)
    ξ = regularization.ξ
    for i in eachindex(ξ)
        name = add_subscript(:ξ, i)
        set = SingleDecisionSet(1, ξ[i], NoSpecifiedConstraint(), false)
        var_index, _ = MOI.add_constrained_variable(model, set)
        set_decision!(regularization.decisions, var_index, ξ[i])
        MOI.set(model, MOI.VariableName(), var_index, name)
        regularization.projection_targets[i] = var_index
    end
    return nothing
end

function decision(::AbstractLShaped, regularization::AbstractRegularization)
    return map(regularization.ξ) do ξᵢ
        ξᵢ.value
    end
end

function objective_value(::AbstractLShaped, regularization::AbstractRegularization)
    return regularization.data.Q̃
end

function gap(lshaped::AbstractLShaped, regularization::AbstractRegularization)
    @unpack θ = lshaped.data
    @unpack Q̃ = regularization.data
    return abs(θ-Q̃)/(abs(Q̃)+1e-10)
end

function process_cut!(lshaped::AbstractLShaped, cut::AbstractHyperPlane, ::AbstractRegularization)
    return nothing
end
