# Regularized decomposition
# ------------------------------------------------------------
@with_kw mutable struct RDData{T <: AbstractFloat}
    Q̃::T = 1e10
    σ::T = 1.0
    incumbent::Int = 1
    major_iterations::Int = 0
    minor_iterations::Int = 0
    regularizerindex::Int = -1
end

@with_kw mutable struct RDParameters{T <: AbstractFloat}
    τ::T = 1e-6
    γ::T = 0.9
    σ::T = 1.0
    σ̅::T = 4.0
    σ̲::T = 0.5
    linearize::Bool = false
end

"""
    RegularizedDecomposition

Functor object for using regularized decomposition regularization in an L-shaped algorithm. Create by supplying an [`RD`](@ref) object through `regularize ` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

...
# Parameters
- `σ::AbstractFloat = 1.0`: Initial value of regularization parameter. Controls the relative penalty of the deviation from the current major iterate.
- `σ̅::AbstractFloat = 4.0`: Maximum value of the regularization parameter.
- `σ̲::AbstractFloat = 0.5`: Minimum value of the regularization parameter.
- `log::Bool = true`: Specifices if L-shaped procedure should be logged on standard output or not.
- `linearize::Bool = false`: If `true`, the quadratic terms in the master problem objective are linearized through a ∞-norm approximation.
...
"""
struct RegularizedDecomposition{T <: AbstractFloat, A <: AbstractVector} <: AbstractRegularization
    data::RDData{T}
    parameters::RDParameters{T}

    ξ::A
    Q̃_history::A
    σ_history::A
    incumbents::Vector{Int}

    function RegularizedDecomposition(ξ₀::AbstractVector; kw...)
        T = promote_type(eltype(ξ₀), Float32)
        ξ₀_ = convert(AbstractVector{T}, copy(ξ₀))
        A = typeof(ξ₀_)
        return new{T, A}(RDData{T}(), RDParameters{T}(;kw...), ξ₀_, A(), A(), Vector{Int}())
    end
end

function initialize_regularization!(lshaped::AbstractLShapedSolver, rd::RegularizedDecomposition)
    rd.data.σ = rd.parameters.σ
    push!(rd.σ_history,rd.data.σ)
    # Add ∞-norm auxilliary variable
    if rd.parameters.linearize
        # t
        MPB.addvar!(lshaped.mastersolver.lqmodel, -Inf, Inf, 1.0)
    end
    # Add quadratic penalty
    c = copy(lshaped.c)
    append!(c, MPB.getobj(lshaped.mastersolver.lqmodel)[end-nthetas(lshaped)+1:end])
    add_penalty!(lshaped, lshaped.mastersolver.lqmodel, c, 1/rd.data.σ, rd.ξ, Val{rd.parameters.linearize}())
    return nothing
end

function log_regularization!(lshaped::AbstractLShapedSolver, rd::RegularizedDecomposition)
    @unpack Q̃,σ,incumbent = rd.data
    push!(rd.Q̃_history, Q̃)
    push!(rd.σ_history, σ)
    push!(rd.incumbents, incumbent)
    return nothing
end

function log_regularization!(lshaped::AbstractLShapedSolver, t::Integer, rd::RegularizedDecomposition)
    @unpack Q̃,σ,incumbent = rd.data
    rd.Q̃_history[t] = Q̃
    rd.σ_history[t] = σ
    rd.incumbents[t] =  incumbent
    return nothing
end

function take_step!(lshaped::AbstractLShapedSolver, rd::RegularizedDecomposition)
    @unpack Q,θ = lshaped.data
    @unpack τ = lshaped.parameters
    @unpack σ = rd.data
    @unpack γ,σ̅,σ̲ = rd.parameters
    t = timestamp(lshaped)
    σ̃ = incumbent_trustregion(lshaped, t, rd)
    Q̃ = incumbent_objective(lshaped, t, rd)
    need_update = false
    λ = rd.data.major_iterations == 0 ? zeros(1) : getduals(lshaped.mastersolver)
    if abs(θ-Q) <= τ*(1+abs(θ)) || (Q <= Q̃ + τ && count(λ .!= 0.) == length(lshaped.mastervector)) || rd.data.major_iterations == 0
        rd.ξ .= current_decision(lshaped)
        rd.data.Q̃ = copy(Q)
        need_update = true
        rd.data.incumbent = t
        rd.data.major_iterations += 1
    else
        rd.data.minor_iterations += 1
    end
    new_σ = if Q + τ <= (1-γ)*Q̃ + γ*θ
        max(σ, min(σ̅, 2*σ))
    elseif Q - τ >= γ*Q̃ + (1-γ)*θ
        min(σ, max(σ̲, 0.5*σ))
    else
        σ
    end
    if abs(new_σ - σ) > τ
        need_update = true
    end
    rd.data.σ = new_σ
    if need_update
        c = copy(lshaped.c)
	    append!(c, MPB.getobj(lshaped.mastersolver.lqmodel)[end-nthetas(lshaped)+1:end])
        add_penalty!(lshaped, lshaped.mastersolver.lqmodel, c, 1/rd.data.σ, rd.ξ, Val{rd.parameters.linearize}())
    end
    return nothing
end

function solve_problem!(lshaped::AbstractLShapedSolver, solver::LQSolver, rd::RegularizedDecomposition)
    if rd.parameters.linearize
        solve_linearized_problem!(lshaped, solver, rd)
    else
        solver(lshaped.mastervector)
    end
    return nothing
end

# API
# ------------------------------------------------------------
"""
    RD

Factory object for [`RegularizedDecomposition`](@ref). Pass to `regularize ` in the `LShapedSolver` factory function. Equivalent factory calls: `RD`, `WithRD`, `RegularizedDecomposition`, `WithRegularizedDecomposition`. See ?RegularizedDecomposition for parameter descriptions.

"""
struct RD <: AbstractRegularizer
    parameters::Dict{Symbol,Any}
end
RD(; kw...) = RD(Dict{Symbol,Any}(kw))
WithRD(; kw...) = RD(Dict{Symbol,Any}(kw))
RegularizedDecomposition(; kw...) = RD(Dict{Symbol,Any}(kw))
WithRegularizedDecomposition(; kw...) = RD(Dict{Symbol,Any}(kw))

function (rd::RD)(x::AbstractVector)
    return RegularizedDecomposition(x; rd.parameters...)
end

function str(::RD)
    return "L-shaped using regularized decomposition"
end
