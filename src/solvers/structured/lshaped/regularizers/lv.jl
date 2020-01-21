# Level-set
# ------------------------------------------------------------
@with_kw mutable struct LVData{T <: Real}
    Q̃::T = 1e10
    incumbent::Int = 1
    major_iterations::Int = 0
    minor_iterations::Int = 0
    levelindex::Int = -1
    regularizerindex::Int = -1
end

@with_kw mutable struct LVParameters{T <: Real}
    λ::T = 0.5
    linearize::Bool = false
end

"""
    LevelSet

Functor object for using level-set regularization in an L-shaped algorithm. Create by supplying an [`LV`](@ref) object through `regularize ` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

...
# Parameters
- `λ::Real = 0.5`: Controls the level position L = (1-λ)*θ + λ*Q̃, a convex combination of the current lower and upper bound.
- `linearize::Bool = false`: If `true`, the quadratic terms in the master problem objective are linearized through a ∞-norm approximation.
...
"""
struct LevelSet{T <: AbstractFloat, A <: AbstractVector, P <: LQSolver} <: AbstractRegularization
    data::LVData{T}
    parameters::LVParameters{T}

    ξ::A
    Q̃_history::A
    levels::A
    incumbents::Vector{Int}

    projectionsolver::P

    function LevelSet(ξ₀::AbstractVector, projectionsolver::MPB.AbstractMathProgSolver; kw...)
        T = promote_type(eltype(ξ₀), Float32)
        ξ₀_ = convert(AbstractVector{T}, copy(ξ₀))
        A = typeof(ξ₀_)
        psolver = LQSolver(Model(), projectionsolver)
        P = typeof(psolver)
        return new{T, A, P}(LVData{T}(), LVParameters{T}(;kw...), ξ₀_, A(), A(), Vector{Int}(), psolver)
    end
end

function init_regularization!(lshaped::AbstractLShapedSolver, lv::LevelSet)
    MPB.loadproblem!(lv.projectionsolver.lqmodel, loadLP(StochasticPrograms.get_stage_one(lshaped.stochasticprogram))...)
    MPB.setobj!(lv.projectionsolver.lqmodel, zeros(decision_length(lshaped.stochasticprogram)))
    # θs
    for i = 1:nthetas(lshaped)
        MPB.addvar!(lv.projectionsolver.lqmodel, -Inf, Inf, 0.0)
    end
    if lv.parameters.linearize
        # t
        MPB.addvar!(lv.projectionsolver.lqmodel, -Inf, Inf, 1.0)
    end
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

function solve_problem!(lshaped::AbstractLShapedSolver, solver::LQSolver, lv::LevelSet)
    if lv.parameters.linearize
        solve_linearized_problem!(lshaped, solver, lv)
    else
        solver(lshaped.mastervector)
    end
    return nothing
end

function process_cut!(lshaped::AbstractLShapedSolver, cut::AbstractHyperPlane, lv::LevelSet)
    MPB.addconstr!(lv.projectionsolver.lqmodel, lowlevel(cut)...)
    return nothing
end

function project!(lshaped::AbstractLShapedSolver, lv::LevelSet)
    @unpack Q = lshaped.data
    if !handle_feasibility(lshaped.feasibility) || Q < Inf
        _project!(lshaped, lv)
    end
    return nothing
end

function _project!(lshaped::AbstractLShapedSolver, lv::LevelSet)
    @unpack θ = lshaped.data
    @unpack Q̃ = lv.data
    @unpack λ = lv.parameters
    # Update level (TODO: Rewrite with MathOptInterface)
    nt = nthetas(lshaped)
    c = sparse(MPB.getobj(lshaped.mastersolver.lqmodel))
    L = (1-λ)*θ + λ*Q̃
    push!(lv.levels, L)
    if lv.data.levelindex == -1
        MPB.addconstr!(lv.projectionsolver.lqmodel, c.nzind, c.nzval, -Inf, L)
        lv.data.levelindex = first_stage_nconstraints(lshaped.stochasticprogram)+ncuts(lshaped)+1
    else
        MPB.delconstrs!(lv.projectionsolver.lqmodel, [lv.data.levelindex])
        MPB.addconstr!(lv.projectionsolver.lqmodel, c.nzind, c.nzval, -Inf, L)
        lv.data.levelindex = first_stage_nconstraints(lshaped.stochasticprogram)+ncuts(lshaped)+1
        if lv.parameters.linearize
            lv.data.regularizerindex -= 1
        end
    end
    # Update regularizer
    add_penalty!(lshaped, lv.projectionsolver.lqmodel, zeros(length(lshaped.x)+nt), 1.0, lshaped.x, Val{lv.parameters.linearize}())
    lv.data.regularizerindex += 1
    # Solve projection problem
    solve_problem!(lshaped, lv.projectionsolver)
    if status(lv.projectionsolver) == :Infeasible
        @warn "Projection problem is infeasible, unprojected solution will be used"
        if Q̃ <= θ
            # If the upper objective bound is lower than the model lower bound for some reason, reset it.
            lv.data.Q̃ = Inf
        end
    else
        # Update master solution
        update_solution!(lshaped, lv.projectionsolver)
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
    parameters::Dict{Symbol,Any}
end
LV(; projectionsolver::MPB.AbstractMathProgSolver, kw...) = LV(projectionsolver, Dict{Symbol,Any}(kw))
WithLV(; projectionsolver::MPB.AbstractMathProgSolver, kw...) = LV(projectionsolver, Dict{Symbol,Any}(kw))
LevelSet(; projectionsolver::MPB.AbstractMathProgSolver, kw...) = LV(projectionsolver, Dict{Symbol,Any}(kw))
WithLevelSets(; projectionsolver::MPB.AbstractMathProgSolver, kw...) = LV(projectionsolver, Dict{Symbol,Any}(kw))

function add_regularization_params!(regularizer::LV; kwargs...)
    push!(regularizer.parameters, kwargs...)
    for (k,v) in kwargs
        if k == :projectionsolver
            setfield!(regularizer, k, v)
            delete!(regularizer.parameters, k)
        end
    end
    return nothing
end

function (lv::LV)(x::AbstractVector)
    return LevelSet(x, lv.projectionsolver; lv.parameters...)
end

function str(::LV)
    return "L-shaped using level sets"
end
