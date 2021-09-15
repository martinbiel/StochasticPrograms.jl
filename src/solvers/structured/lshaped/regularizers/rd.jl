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

# Regularized decomposition
# ------------------------------------------------------------
@with_kw mutable struct RDData{T <: AbstractFloat}
    Q̃::T = 1e10
    σ::T = 1.0
    incumbent::Int = 1
    major_iterations::Int = 0
    minor_iterations::Int = 0
end

@with_kw mutable struct RDParameters{T <: AbstractFloat}
    τ::T = 1e-6
    γ::T = 0.9
    σ::T = 1.0
    σ̅::T = 4.0
    σ̲::T = 0.5
end

"""
    RegularizedDecomposition

Functor object for using regularized decomposition regularization in an L-shaped algorithm. Create by supplying an [`RD`](@ref) object through `regularize` in `LShaped.Optimizer` or by setting the [`Regularizer`](@ref) attribute.

...
# Parameters
- `σ::AbstractFloat = 1.0`: Initial value of regularization parameter. Controls the relative penalty of the deviation from the current major iterate.
- `σ̅::AbstractFloat = 4.0`: Maximum value of the regularization parameter.
- `σ̲::AbstractFloat = 0.5`: Minimum value of the regularization parameter.
- `log::Bool = true`: Specifices if L-shaped procedure should be logged on standard output or not.
- `penaltyterm::PenaltyTerm = Quadratic`: Specify penaltyterm variant ([`Quadratic`](@ref), [`InfNorm`](@ref), [`ManhattanNorm`][@ref])
...
"""
struct RegularizedDecomposition{T <: AbstractFloat, A <: AbstractVector, PT <: AbstractPenaltyTerm} <: AbstractRegularization
    data::RDData{T}
    parameters::RDParameters{T}

    decisions::DecisionMap
    projection_targets::Vector{MOI.VariableIndex}
    ξ::Vector{Decision{T}}

    Q̃_history::A
    σ_history::A
    incumbents::Vector{Int}

    penaltyterm::PT

    function RegularizedDecomposition(decisions::DecisionMap, ξ₀::AbstractVector, penaltyterm::AbstractPenaltyTerm; kw...)
        T = promote_type(eltype(ξ₀), Float32)
        A = Vector{T}
        ξ = map(ξ₀) do val
            KnownDecision(val, T)
        end
        PT = typeof(penaltyterm)
        return new{T, A, PT}(RDData{T}(),
                             RDParameters{T}(; kw...),
                             decisions,
                             Vector{MOI.VariableIndex}(undef, length(ξ₀)),
                             ξ,
                             A(),
                             A(),
                             Vector{Int}(),
                             penaltyterm)
    end
end

function initialize_regularization!(lshaped::AbstractLShaped, rd::RegularizedDecomposition{T}) where T <: AbstractFloat
    # Add projection targets
    add_projection_targets!(rd, lshaped.master)
    # Prepare penalty constant
    rd.data.σ = rd.parameters.σ
    push!(rd.σ_history,rd.data.σ)
    @unpack σ = rd.data
    # Initialize penalty
    initialize_penaltyterm!(rd.penaltyterm,
                            lshaped.master,
                            1 / (2 * σ),
                            all_decisions(rd.decisions),
                            rd.projection_targets)
    return nothing
end

function restore_regularized_master!(lshaped::AbstractLShaped, rd::RegularizedDecomposition)
    # Delete penalty-term
    remove_penalty!(rd.penaltyterm, lshaped.master)
    # Delete projection targets
    for var in rd.projection_targets
        MOI.delete(lshaped.master, var)
        StochasticPrograms.remove_decision!(rd.decisions, var)
    end
    empty!(rd.projection_targets)
    return nothing
end

function filter_variables!(rd::RegularizedDecomposition, list::Vector{MOI.VariableIndex})
    # Filter projection targets
    filter!(vi -> !(vi in rd.projection_targets), list)
    # Filter any auxiliary penaltyterm variables
    remove_penalty_variables!(rd.penaltyterm, list)
    return nothing
end

function filter_constraints!(rd::RegularizedDecomposition, list::Vector{<:CI})
    # Filter any auxiliary penaltyterm constraints
    remove_penalty_constraints!(rd.penaltyterm, list)
    return nothing
end

function log_regularization!(lshaped::AbstractLShaped, rd::RegularizedDecomposition)
    @unpack Q̃,σ,incumbent = rd.data
    push!(rd.Q̃_history, Q̃)
    push!(rd.σ_history, σ)
    push!(rd.incumbents, incumbent)
    return nothing
end

function log_regularization!(lshaped::AbstractLShaped, t::Integer, rd::RegularizedDecomposition)
    @unpack Q̃,σ,incumbent = rd.data
    rd.Q̃_history[t] = Q̃
    rd.σ_history[t] = σ
    rd.incumbents[t] =  incumbent
    return nothing
end

function take_step!(lshaped::AbstractLShaped, rd::RegularizedDecomposition)
    @unpack Q,θ = lshaped.data
    @unpack τ = lshaped.parameters
    @unpack σ = rd.data
    @unpack γ,σ̅,σ̲ = rd.parameters
    t = timestamp(lshaped)
    σ̃ = incumbent_trustregion(lshaped, t, rd)
    Q̃ = incumbent_objective(lshaped, t, rd)
    sense = MOI.get(lshaped.master, MOI.ObjectiveSense())
    coeff = sense == MOI.MIN_SENSE ? 1.0 : -1.0
    need_update = false
    if abs(θ-Q) <= τ*(1+abs(θ)) || coeff*Q <= coeff*Q̃ + τ || rd.data.major_iterations == 0
        need_update = true
        x = current_decision(lshaped)
        for i in eachindex(rd.ξ)
            rd.ξ[i].value = x[i]
        end
        rd.data.Q̃ = copy(Q)
        rd.data.incumbent = t
        rd.data.major_iterations += 1
    else
        rd.data.minor_iterations += 1
    end
    rd.data.σ = if coeff*Q + τ <= coeff*(1-γ)*Q̃ + coeff*γ*θ
        max(σ, min(σ̅, 2*σ))
    elseif coeff*Q - τ >= coeff*γ*Q̃ + coeff*(1-γ)*θ
        min(σ, max(σ̲, 0.5*σ))
    else
        σ
    end
    need_update |= abs(rd.data.σ - σ) > τ
    if need_update
        @unpack σ = rd.data
        update_penaltyterm!(rd.penaltyterm,
                            lshaped.master,
                            1 / (2 * σ),
                            all_decisions(rd.decisions),
                            rd.projection_targets)
    end
    return nothing
end

# API
# ------------------------------------------------------------
"""
    RD

Factory object for [`RegularizedDecomposition`](@ref). Pass to `regularize` in `LShaped.Optimizer` or set the [`Regularizer`](@ref) attribute. Equivalent factory calls: `RD`, `WithRD`, `RegularizedDecomposition`, `WithRegularizedDecomposition`. See ?RegularizedDecomposition for parameter descriptions.

"""
mutable struct RD <: AbstractRegularizer
    penaltyterm::AbstractPenaltyTerm
    parameters::RDParameters{Float64}
end
RD(; penaltyterm = Quadratic(), kw...) = RD(penaltyterm, RDParameters(; kw...))
WithRD(; penaltyterm = Quadratic(), kw...) = RD(penaltyterm, RDParameters(; kw...))
RegularizedDecomposition(; penaltyterm = Quadratic(), kw...) = RD(penaltyterm, RDParameters(; kw...))
WithRegularizedDecomposition(; penaltyterm = Quadratic(), kw...) = RD(penaltyterm, RDParameters(; kw...))

function MOI.get(rd::RD, ::RegularizationPenaltyTerm)
    return rd.penaltyterm
end

function MOI.set(rd::RD, ::RegularizationPenaltyTerm, penaltyterm::AbstractPenaltyTerm)
    return rd.penaltyterm = penaltyterm
end

function (rd::RD)(decisions::DecisionMap, x::AbstractVector)
    return RegularizedDecomposition(decisions, x, rd.penaltyterm; type2dict(rd.parameters)...)
end

function str(::RD)
    return "L-shaped using regularized decomposition"
end
