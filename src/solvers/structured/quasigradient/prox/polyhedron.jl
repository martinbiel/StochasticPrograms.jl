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

"""
    PolyhedronProjection

Functor object for using polyhedral projection in the prox step of a quasigradient algorithm. Create by supplying a [`Polyhedron`](@ref) object through `prox ` to `QuasiGradient.Optimizer` or by setting the [`Prox`](@ref) attribute.

...
# Parameters
- `penaltyterm::PenaltyTerm = Quadratic`: Specify penaltyterm variant ([`Quadratic`](@ref), [`InfNorm`](@ref), [`ManhattanNorm`][@ref])
...
"""
struct PolyhedronProjection{T <: AbstractFloat, PT <: AbstractPenaltyTerm} <: AbstractProximal
    penaltyterm::PT
    projection_targets::Vector{MOI.VariableIndex}
    ξ::Vector{Decision{T}}

    function PolyhedronProjection(penaltyterm::AbstractPenaltyTerm, ξ₀::AbstractVector, ::Type{T}) where T <: AbstractFloat
        PT = typeof(penaltyterm)
        projection_targets = Vector{MOI.VariableIndex}(undef, length(ξ₀))
        ξ = map(ξ₀) do val
            KnownDecision(val, T)
        end
        return new{T, PT}(penaltyterm, projection_targets, ξ)
    end
end

function initialize_prox!(quasigradient::AbstractQuasiGradient, polyhedron::PolyhedronProjection)
    # Add projection targets
    ξ = polyhedron.ξ
    decisions = get_decisions(quasigradient.structure.first_stage)::Decisions
    for i in eachindex(ξ)
        name = add_subscript(:ξ, i)
        set = SingleDecisionSet(1, ξ[i], NoSpecifiedConstraint(), false)
        var_index, _ = MOI.add_constrained_variable(quasigradient.master, set)
        set_decision!(decisions[1], var_index, ξ[i])
        MOI.set(quasigradient.master, MOI.VariableName(), var_index, name)
        polyhedron.projection_targets[i] = var_index
    end
    # Initialize penaltyterm
    F = MOI.ScalarAffineFunction{Float64}
    MOI.set(quasigradient.master, MOI.ObjectiveFunction{F}(), zero(F))
    initialize_penaltyterm!(polyhedron.penaltyterm,
                            quasigradient.master,
                            1.0,
                            all_decisions(decisions, 1),
                            polyhedron.projection_targets)
    return nothing
end

function restore_proximal_master!(quasigradient::AbstractQuasiGradient, polyhedron::PolyhedronProjection)
    # Delete penalty-term
    remove_penalty!(polyhedron.penaltyterm, quasigradient.master)
    # Delete projection targets
    for var in polyhedron.projection_targets
        MOI.delete(quasigradient.master, var)
    end
    empty!(polyhedron.projection_targets)
    return nothing
end

function prox!(quasigradient::AbstractQuasiGradient, polyhedron::PolyhedronProjection, x::AbstractVector, ∇f::AbstractVector, γ::AbstractFloat)
    decisions = get_decisions(quasigradient.structure.first_stage)::Decisions
    # Update projection targets
    for i in eachindex(polyhedron.ξ)
        polyhedron.ξ[i].value = x[i] - γ * ∇f[i]
    end
    # Update penaltyterm
    update_penaltyterm!(polyhedron.penaltyterm,
                        quasigradient.master,
                        1.0,
                        all_decisions(decisions, 1),
                        polyhedron.projection_targets)
    # Solve projection problem
    MOI.optimize!(quasigradient.master)
    # Get solution
    x .= MOI.get.(quasigradient.master, MOI.VariablePrimal(), all_decisions(decisions, 1))
    return nothing
end

# API
# ------------------------------------------------------------
"""
    Polyhedron

Factory object for [`PolyhedronProjection`](@ref). Pass to `prox` in `Quasigradient.Optimizer` or set the [`Prox`](@ref) attribute. See ?PolyhedronProjection for parameter descriptions.

"""
mutable struct Polyhedron <: AbstractProx
    penaltyterm::AbstractPenaltyTerm
end
Polyhedron(; penaltyterm = Quadratic()) = Polyhedron(penaltyterm)

function (polyhedron::Polyhedron)(structure::StageDecompositionStructure, x₀::AbstractVector, ::Type{T}) where T <: AbstractFloat
    return PolyhedronProjection(polyhedron.penaltyterm, x₀, T)
end

function str(::Polyhedron)
    return ""
end
