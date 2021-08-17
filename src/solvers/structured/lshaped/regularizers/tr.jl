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

# Trust-region
# ------------------------------------------------------------
const TRConstraint = CI{VectorAffineDecisionFunction{Float64}, MOI.NormInfinityCone}
@with_kw mutable struct TRData{T <: AbstractFloat}
    Q̃::T = 1e10
    Δ::MOI.VariableIndex = MOI.VariableIndex(0)
    constraint::TRConstraint = TRConstraint(0)
    cΔ::Int = 0
    incumbent::Int = 1
    major_iterations::Int = 0
    minor_iterations::Int = 0
end

@with_kw mutable struct TRParameters{T <: AbstractFloat}
    γ::T = 1e-4
    Δ::T = 1.0
    Δ̅::T = 1000.0
end

"""
    TrustRegion

Functor object for using trust-region regularization in an L-shaped algorithm. Create by supplying a [`TR`](@ref) object through `regularize` in `LShaped.Optimizer` or by setting the [`Regularizer`](@ref) attribute.

...
# Parameters
- `γ::T = 1e-4`: Relative tolerance for deciding if a minor iterate should be accepted as a new major iterate.
- `Δ::AbstractFloat = 1.0`: Initial size of ∞-norm trust-region.
- `Δ̅::AbstractFloat = 1000.0`: Maximum size of ∞-norm trust-region.
...
"""
struct TrustRegion{T <: AbstractFloat, A <: AbstractVector} <: AbstractRegularization
    data::TRData{T}
    parameters::TRParameters{T}

    decisions::DecisionMap
    projection_targets::Vector{MOI.VariableIndex}
    ξ::Vector{Decision{T}}

    Q̃_history::A
    Δ_history::A
    incumbents::Vector{Int}

    function TrustRegion(decisions::DecisionMap, ξ₀::AbstractVector; kw...)
        T = promote_type(eltype(ξ₀), Float32)
        A = Vector{T}
        ξ = map(ξ₀) do val
            KnownDecision(val, T)
        end
        return new{T, A}(TRData{T}(),
                         TRParameters{T}(; kw...),
                         decisions,
                         Vector{MOI.VariableIndex}(undef, length(ξ₀)),
                         ξ,
                         A(),
                         A(),
                         Vector{Int}())
    end
end

function initialize_regularization!(lshaped::AbstractLShaped, tr::TrustRegion{T}) where T <: AbstractFloat
    n = length(tr.ξ) + 1
    # Add projection targets
    add_projection_targets!(tr, lshaped.master)
    # Add trust region
    name = string(:Δ)
    trust_region = KnownDecision(tr.parameters.Δ, T)
    set = SingleDecisionSet(1, trust_region, NoSpecifiedConstraint(), false)
    tr.data.Δ, _ = MOI.add_constrained_variable(lshaped.master, set)
    set_decision!(tr.decisions, tr.data.Δ, trust_region)
    MOI.set(lshaped.master, MOI.VariableName(), tr.data.Δ, name)
    x = VectorOfDecisions(all_decisions(tr.decisions))
    ξ = VectorOfDecisions(tr.projection_targets)
    Δ = SingleDecision(tr.data.Δ)
    # Add trust-region constraint
    f = MOIU.operate(vcat, T, Δ, x) -
        MOIU.operate(vcat, T, zero(tr.parameters.Δ), ξ)
    tr.data.constraint =
        MOI.add_constraint(lshaped.master, f,
                           MOI.NormInfinityCone(n))
    return nothing
end

function restore_regularized_master!(lshaped::AbstractLShaped, tr::TrustRegion)
    # Delete trust region constraint
    if !iszero(tr.data.constraint.value)
        MOI.delete(lshaped.master, tr.data.constraint)
        tr.data.constraint = TRConstraint(0)
    end
    # Delete trust region
    if !iszero(tr.data.Δ.value)
        MOI.delete(lshaped.master, tr.data.Δ)
        StochasticPrograms.remove_decision!(tr.decisions, tr.data.Δ)
        tr.data.Δ = MOI.VariableIndex(0)
    end
    # Delete projection targets
    for var in tr.projection_targets
        MOI.delete(lshaped.master, var)
        StochasticPrograms.remove_decision!(tr.decisions, var)
    end
    empty!(tr.projection_targets)
    return nothing
end

function filter_variables!(tr::TrustRegion, list::Vector{MOI.VariableIndex})
    # Filter projection targets
    filter!(vi -> !(vi in tr.projection_targets), list)
    # Filter Δ
    i = something(findfirst(isequal(tr.data.Δ), list), 0)
    if !iszero(i)
        MOI.deleteat!(list, i)
    end
    return nothing
end

function filter_constraints!(tr::TrustRegion, list::Vector{<:CI})
    # Filter trust-region constraint
    i = something(findfirst(isequal(tr.data.constraint), list), 0)
    if !iszero(i)
        MOI.deleteat!(list, i)
    end
    return nothing
end

function log_regularization!(lshaped::AbstractLShaped, tr::TrustRegion)
    @unpack Q̃, Δ, incumbent = tr.data
    push!(tr.Q̃_history, Q̃)
    push!(tr.Δ_history, StochasticPrograms.decision(tr.decisions, Δ).value)
    push!(tr.incumbents, incumbent)
    return nothing
end

function log_regularization!(lshaped::AbstractLShaped, t::Integer, tr::TrustRegion)
    @unpack Q̃,Δ,incumbent = tr.data
    tr.Q̃_history[t] = Q̃
    tr.Δ_history[t] = StochasticPrograms.decision(tr.decisions, Δ).value
    tr.incumbents[t] = incumbent
    return nothing
end

function take_step!(lshaped::AbstractLShaped, tr::TrustRegion)
    @unpack Q,θ = lshaped.data
    @unpack τ = lshaped.parameters
    @unpack Q̃ = tr.data
    @unpack γ = tr.parameters
    need_update = false
    t = timestamp(lshaped)
    Q̃t = incumbent_objective(lshaped, t, tr)
    if Q + τ <= Q̃ && (tr.data.major_iterations == 1 || Q <= Q̃t - γ*abs(Q̃t-θ))
        need_update = true
        enlarge_trustregion!(lshaped, tr)
        tr.data.cΔ = 0
        x = current_decision(lshaped)
        for i in eachindex(tr.ξ)
            tr.ξ[i].value = x[i]
        end
        tr.data.Q̃ = Q
        tr.data.incumbent = timestamp(lshaped)
        tr.data.major_iterations += 1
    else
        need_update = reduce_trustregion!(lshaped, tr)
        tr.data.minor_iterations += 1
    end
    if need_update
        update_trustregion!(lshaped, tr)
    end
    return nothing
end

function process_cut!(lshaped::AbstractLShaped, cut::HyperPlane{FeasibilityCut}, tr::TrustRegion)
    @unpack τ = lshaped.parameters
    if !satisfied(cut, decision(lshaped), τ)
        # Project decision to ensure prevent master infeasibility
        A = [I cut.δQ; cut.δQ' 0*I]
        b = [zeros(length(tr.ξ)); -gap(cut, decision(lshaped))]
        t = A\b
        for i in eachindex(tr.ξ)
            tr.ξ[i].value += t[i]
        end
        update_trustregion!(lshaped, tr)
    end
    return nothing
end

function update_trustregion!(lshaped::AbstractLShaped, tr::TrustRegion)
    @unpack Δ = tr.data
    # Update projection targets
    for vi in tr.projection_targets
        ci = CI{MOI.SingleVariable,SingleDecisionSet{Float64}}(vi.value)
        MOI.modify(lshaped.master,
                   ci,
                   KnownValuesChange())
    end
    # Update trust-region
    ci = CI{MOI.SingleVariable,SingleDecisionSet{Float64}}(Δ.value)
    MOI.modify(lshaped.master,
               ci,
               KnownValuesChange())
    return nothing
end

function enlarge_trustregion!(lshaped::AbstractLShaped, tr::TrustRegion)
    @unpack Q,θ = lshaped.data
    @unpack τ, = lshaped.parameters
    @unpack Δ = tr.data
    @unpack Δ̅ = tr.parameters
    t = timestamp(lshaped)
    Δ̃ = incumbent_trustregion(lshaped, t, tr)
    ξ = incumbent_decision(lshaped, t, tr)
    Q̃ = incumbent_objective(lshaped, t, tr)
    if Q̃ - Q >= 0.5*(Q̃ - θ) && abs(norm(ξ - lshaped.x, Inf) - Δ̃) <= τ
        # Enlarge the trust-region radius
        Δ = StochasticPrograms.decision(tr.decisions, tr.data.Δ)
        Δ.value = max(Δ.value, min(Δ̅, 2 * Δ̃))
        return true
    else
        return false
    end
end

function reduce_trustregion!(lshaped::AbstractLShaped, tr::TrustRegion)
    @unpack Q,θ = lshaped.data
    @unpack Q̃,Δ,cΔ = tr.data
    t = timestamp(lshaped)
    Δ̃ = incumbent_trustregion(lshaped, t, tr)
    Q̃ = incumbent_objective(lshaped, t, tr)
    ρ = min(1, Δ̃)*(Q-Q̃)/(Q̃-θ)
    if ρ > 0
        tr.data.cΔ += 1
    end
    if ρ > 3 || (cΔ >= 3 && 1 < ρ <= 3)
        # Reduce the trust-region radius
        tr.data.cΔ = 0
        Δ = StochasticPrograms.decision(tr.decisions, tr.data.Δ)
        Δ.value = min(Δ.value, (1/min(ρ,4))*Δ̃)
        return true
    else
        return false
    end
end

# API
# ------------------------------------------------------------
"""
    TR

Factory object for [`TrustRegion`](@ref). Pass to `regularize` in `LShaped.Optimizer` or set the [`Regularizer`](@ref) attribute.. Equivalent factory calls: `TR`, `WithTR`, `TrustRegion`, `WithTrustRegion`. See ?TrustRegion for parameter descriptions.

"""
mutable struct TR <: AbstractRegularizer
    parameters::TRParameters{Float64}
end
TR(; kw...) = TR(TRParameters(; kw...))
WithTR(; kw...) = TR(TRParameters(; kw...))
TrustRegion(; kw...) = TR(TRParameters(; kw...))
WithTrustRegion(; kw...) = TR(TRParameters(; kw...))

function (tr::TR)(decisions::DecisionMap, x::AbstractVector)
    return TrustRegion(decisions, x; type2dict(tr.parameters)...)
end

function str(::TR)
    return "L-shaped using trust-region"
end
