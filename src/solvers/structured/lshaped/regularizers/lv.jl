# Level-set
# ------------------------------------------------------------
@with_kw mutable struct LVData{T <: AbstractFloat}
    Q̃::T = 1e10
    incumbent::Int = 1
    major_iterations::Int = 0
    minor_iterations::Int = 0
    levelindex::Int = -1
end

@with_kw mutable struct LVParameters{T <: AbstractFloat}
    λ::T = 0.5
end

"""
    LevelSet

Functor object for using level-set regularization in an L-shaped algorithm. Create by supplying an [`LV`](@ref) object through `regularize ` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

...
# Parameters
- `λ::AbstractFloat = 0.5`: Controls the level position L = (1-λ)*θ + λ*Q̃, a convex combination of the current lower and upper bound.
- `penaltyterm::PenaltyTerm = Quadratic`: Specify penaltyterm variant ([`Quadratic`](@ref), [`Linearized`](@ref), [`InfNorm`](@ref), [`ManhattanNorm`][@ref])
...
"""
struct LevelSet{T <: AbstractFloat, A <: AbstractVector, P <: LQSolver, PT <: PenaltyTerm} <: AbstractRegularization
    data::LVData{T}
    parameters::LVParameters{T}

    ξ::A
    Q̃_history::A
    levels::A
    incumbents::Vector{Int}

    projectionsolver::P
    penaltyterm::PT

    function LevelSet(ξ₀::AbstractVector, projectionsolver::MPB.AbstractMathProgSolver, penaltyterm::PenaltyTerm; kw...)
        T = promote_type(eltype(ξ₀), Float32)
        ξ₀_ = convert(AbstractVector{T}, copy(ξ₀))
        A = typeof(ξ₀_)
        psolver = LQSolver(Model(), projectionsolver)
        P = typeof(psolver)
        PT = typeof(penaltyterm)
        return new{T, A, P, PT}(LVData{T}(), LVParameters{T}(;kw...), ξ₀_, A(), A(), Vector{Int}(), psolver, penaltyterm)
    end
end

function initialize_regularization!(lshaped::AbstractLShapedSolver, lv::LevelSet)
    MPB.loadproblem!(lv.projectionsolver.lqmodel, loadLP(StochasticPrograms.get_stage_one(lshaped.stochasticprogram))...)
    MPB.setobj!(lv.projectionsolver.lqmodel, zeros(decision_length(lshaped.stochasticprogram)))
    # θs
    for i = 1:nthetas(lshaped)
        MPB.addvar!(lv.projectionsolver.lqmodel, -Inf, Inf, 0.0)
    end
    initialize_penaltyterm!(lv.penaltyterm, lv.projectionsolver, lshaped.x)
    return nothing
end

function log_regularization!(lshaped::AbstractLShapedSolver, lv::LevelSet)
    @unpack Q̃,incumbent = lv.data
    push!(lv.Q̃_history, Q̃)
    push!(lv.incumbents, incumbent)
    return nothing
end

function log_regularization!(lshaped::AbstractLShapedSolver, t::Integer, lv::LevelSet)
    @unpack Q̃,incumbent = lv.data
    lv.Q̃_history[t] = Q̃
    lv.incumbents[t] = incumbent
    return nothing
end

function take_step!(lshaped::AbstractLShapedSolver, lv::LevelSet)
    @unpack Q = lshaped.data
    @unpack τ = lshaped.parameters
    @unpack Q̃ = lv.data
    if Q <= Q̃ - τ
        lv.data.Q̃ = Q
        lv.ξ .= current_decision(lshaped)
        lv.data.incumbent = timestamp(lshaped)
        lv.data.major_iterations += 1
    else
        lv.data.minor_iterations += 1
    end
    return nothing
end

function process_cut!(lshaped::AbstractLShapedSolver, cut::AbstractHyperPlane, lv::LevelSet)
    MPB.addconstr!(lv.projectionsolver.lqmodel, lowlevel(cut)...)
    return nothing
end

function project!(lshaped::AbstractLShapedSolver, lv::LevelSet)
    @unpack Q = lshaped.data
    if count(active_model_objectives(lshaped)) == nthetas(lshaped)
        _project!(lshaped, lv)
    end
    return nothing
end

function _project!(lshaped::AbstractLShapedSolver, lv::LevelSet)
    @unpack θ = lshaped.data
    @unpack Q̃ = lv.data
    @unpack λ = lv.parameters
    nt = nthetas(lshaped)
    c = sparse(MPB.getobj(lshaped.mastersolver.lqmodel))
    L = (1-λ)*θ + λ*Q̃
    push!(lv.levels, L)
    if lv.data.levelindex == -1
        MPB.addconstr!(lv.projectionsolver.lqmodel, c.nzind, c.nzval, -Inf, L)
        lv.data.levelindex = first_stage_nconstraints(lshaped.stochasticprogram)+ncuts(lshaped)+1
    else
        ub = MPB.getconstrUB(lv.projectionsolver.lqmodel)
        ub[lv.data.levelindex] = L
        MPB.setconstrUB!(lv.projectionsolver.lqmodel, ub)
    end
    # Update regularizer
    c = vcat(get_obj(lshaped), active_model_objectives(lshaped))
    update_penaltyterm!(lv.penaltyterm, lv.projectionsolver, c, 1.0, lshaped.x)
    # Solve projection problem
    solve_penalized!(lv.penaltyterm, lv.projectionsolver, lshaped.mastervector, lshaped.x, lshaped.x)
    if status(lv.projectionsolver) == :Infeasible
        @warn "Projection problem is infeasible, unprojected solution will be used"
        if Q̃ <= θ
            # If the upper objective bound is lower than the model lower bound for some reason, reset it.
            lv.data.Q̃ = Inf
        end
    elseif status(lv.projectionsolver) == :Optimal
        # Update master solution
        update_solution!(lshaped, lv.projectionsolver)
    else
        @warn "Projection problem could not be solved, unprojected solution will be used"
    end
    return nothing
end

function str(::LevelSet)
    return "L-shaped using level sets"
end

# API
# ------------------------------------------------------------
"""
    LV

Factory object for [`LevelSet`](@ref). Pass to `regularize ` in the `LShapedSolver` factory function. Equivalent factory calls: `LV`, `WithLV`, `LevelSet`, `WithLevelSets`. See ?LevelSet for parameter descriptions.

"""
struct LV <: AbstractRegularizer
    projectionsolver::MPB.AbstractMathProgSolver
    penaltyterm::PenaltyTerm
    parameters::Dict{Symbol,Any}
end
LV(; projectionsolver::MPB.AbstractMathProgSolver, penaltyterm = Quadratic(), kw...) = LV(projectionsolver, penaltyterm, Dict{Symbol,Any}(kw))
WithLV(; projectionsolver::MPB.AbstractMathProgSolver, penaltyterm = Quadratic(), kw...) = LV(projectionsolver, penaltyterm, Dict{Symbol,Any}(kw))
LevelSet(; projectionsolver::MPB.AbstractMathProgSolver, penaltyterm = Quadratic(), kw...) = LV(projectionsolver, penaltyterm, Dict{Symbol,Any}(kw))
WithLevelSets(; projectionsolver::MPB.AbstractMathProgSolver, penaltyterm = Quadratic(), kw...) = LV(projectionsolver, penaltyterm, Dict{Symbol,Any}(kw))

function add_regularization_params!(regularizer::LV; kwargs...)
    push!(regularizer.parameters, kwargs...)
    for (k,v) in kwargs
        if k ∈ [:projectionsolver, :penaltyterm]
            setfield!(regularizer, k, v)
            delete!(regularizer.parameters, k)
        end
    end
    return nothing
end

function (lv::LV)(x::AbstractVector)
    return LevelSet(x, lv.projectionsolver, lv.penalty; lv.parameters...)
end

function str(::LV)
    return "L-shaped using level sets"
end
