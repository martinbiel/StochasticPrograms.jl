# Trust-region
# ------------------------------------------------------------
@with_kw mutable struct TRData{T <: AbstractFloat}
    Q̃::T = 1e10
    Δ::T = 1.0
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

Functor object for using trust-region regularization in an L-shaped algorithm. Create by supplying a [`TR`](@ref) object through `regularize ` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

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

    ξ::A
    Q̃_history::A
    Δ_history::A
    incumbents::Vector{Int}

    function TrustRegion(ξ₀::AbstractVector; kw...)
        T = promote_type(eltype(ξ₀), Float32)
        ξ₀_ = convert(AbstractVector{T}, copy(ξ₀))
        A = typeof(ξ₀_)
        return new{T, A}(TRData{T}(), TRParameters{T}(;kw...), ξ₀_, A(), A(), Vector{Int}())
    end
end

function initialize_regularization!(lshaped::AbstractLShapedSolver, tr::TrustRegion)
    tr.data.Δ = tr.parameters.Δ
    set_trustregion!(lshaped, tr)
    return nothing
end

function log_regularization!(lshaped::AbstractLShapedSolver, tr::TrustRegion)
    @unpack Q̃,Δ,incumbent = tr.data
    push!(tr.Q̃_history, Q̃)
    push!(tr.Δ_history, Δ)
    push!(tr.incumbents, incumbent)
    return nothing
end

function log_regularization!(lshaped::AbstractLShapedSolver, t::Integer, tr::TrustRegion)
    @unpack Q̃,Δ,incumbent = tr.data
    tr.Q̃_history[t] = Q̃
    tr.Δ_history[t] = Δ
    tr.incumbents[t] = incumbent
    return nothing
end

function take_step!(lshaped::AbstractLShapedSolver, tr::TrustRegion)
    @unpack Q,θ = lshaped.data
    @unpack Q̃ = tr.data
    @unpack γ = tr.parameters
    need_update = false
    t = timestamp(lshaped)
    Q̃t = incumbent_objective(lshaped, t, tr)
    if Q < Q̃ && (tr.data.major_iterations == 1 || Q <= Q̃t - γ*abs(Q̃t-θ))
        need_update = true
        enlarge_trustregion!(lshaped, tr)
        tr.data.cΔ = 0
        tr.ξ .= current_decision(lshaped)
        tr.data.Q̃ = Q
        tr.data.incumbent = timestamp(lshaped)
        tr.data.major_iterations += 1
    else
        need_update = reduce_trustregion!(lshaped, tr)
        tr.data.minor_iterations += 1
    end
    if need_update
        set_trustregion!(lshaped, tr)
    end
    return nothing
end

function process_cut!(lshaped::AbstractLShapedSolver, cut::HyperPlane{FeasibilityCut}, tr::TrustRegion)
    @unpack τ = lshaped.parameters
    if !satisfied(cut, tr.ξ, τ)
        A = [I cut.δQ; cut.δQ' 0*I]
        b = [zeros(length(tr.ξ)); -gap(cut, tr.ξ)]
        t = A\b
        tr.ξ .= tr.ξ + t[1:length(tr.ξ)]
        set_trustregion!(lshaped, tr)
    end
    return nothing
end

function set_trustregion!(lshaped::AbstractLShapedSolver, tr::TrustRegion)
    @unpack Δ = tr.data
    nt = nthetas(lshaped)
    l = max.(StochasticPrograms.get_stage_one(lshaped.stochasticprogram).colLower, tr.ξ .- Δ)
    append!(l, fill(-Inf,nt))
    u = min.(StochasticPrograms.get_stage_one(lshaped.stochasticprogram).colUpper, tr.ξ .+ Δ)
    append!(u, fill(Inf,nt))
    MPB.setvarLB!(lshaped.mastersolver.lqmodel, l)
    MPB.setvarUB!(lshaped.mastersolver.lqmodel, u)
    return nothing
end

function enlarge_trustregion!(lshaped::AbstractLShapedSolver, tr::TrustRegion)
    @unpack Q,θ = lshaped.data
    @unpack τ, = lshaped.parameters
    @unpack Δ = tr.data
    @unpack Δ̅ = tr.parameters
    t = timestamp(lshaped)
    Δ̃ = incumbent_trustregion(lshaped, t, tr)
    ξ = incumbent_decision(lshaped, t, tr)
    Q̃ = incumbent_objective(lshaped, t, tr)
    if Q̃ - Q >= 0.5*(Q̃-θ) && abs(norm(ξ-lshaped.x,Inf) - Δ̃) <= τ
        # Enlarge the trust-region radius
        tr.data.Δ = max(Δ, min(Δ̅, 2*Δ̃))
        return true
    else
        return false
    end
end

function reduce_trustregion!(lshaped::AbstractLShapedSolver, tr::TrustRegion)
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
        tr.data.Δ = min(Δ, (1/min(ρ,4))*Δ̃)
        return true
    else
        return false
    end
end

# API
# ------------------------------------------------------------
"""
    TR

Factory object for [`TrustRegion`](@ref). Pass to `regularize ` in the `LShapedSolver` factory function. Equivalent factory calls: `TR`, `WithTR`, `TrustRegion`, `WithTrustRegion`. See ?TrustRegion for parameter descriptions.

"""
struct TR <: AbstractRegularizer
    parameters::Dict{Symbol,Any}
end
TR(; kw...) = TR(Dict{Symbol,Any}(kw))
WithTR(; kw...) = TR(Dict{Symbol,Any}(kw))
TrustRegion(; kw...) = TR(Dict{Symbol,Any}(kw))
WithTrustRegion(; kw...) = TR(Dict{Symbol,Any}(kw))

function (tr::TR)(x::AbstractVector)
    return TrustRegion(x; tr.parameters...)
end

function str(::TR)
    return "L-shaped using trust-region"
end
