# Level-set
# ------------------------------------------------------------
const LVConstraint = CI{AffineDecisionFunction{Float64}, MOI.LessThan{Float64}}
@with_kw mutable struct LVData{T <: AbstractFloat}
    Q̃::T = 1e10
    objective::AffineDecisionFunction{T} = zero(AffineDecisionFunction{T})
    constraint::LVConstraint = LVConstraint(0)
    objective_cached::Bool = false
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
struct LevelSet{T <: AbstractFloat, A <: AbstractVector, PT <: AbstractPenaltyterm} <: AbstractRegularization
    data::LVData{T}
    parameters::LVParameters{T}

    decisions::Decisions
    projection_targets::Vector{MOI.VariableIndex}
    ξ::Vector{Decision{T}}

    Q̃_history::A
    levels::A
    incumbents::Vector{Int}

    penaltyterm::PT

    function LevelSet(decisions::Decisions, ξ₀::AbstractVector, penaltyterm::AbstractPenaltyterm; kw...)
        T = promote_type(eltype(ξ₀), Float32)
        A = Vector{T}
        ξ = map(ξ₀) do val
            KnownDecision(val, T)
        end
        PT = typeof(penaltyterm)
        return new{T, A, PT}(LVData{T}(),
                             LVParameters{T}(;kw...),
                             decisions,
                             Vector{MOI.VariableIndex}(undef, length(ξ₀)),
                             ξ,
                             A(),
                             A(),
                             Vector{Int}(),
                             penaltyterm)
    end
end

function initialize_regularization!(lshaped::AbstractLShaped, lv::LevelSet)
    # Add projection targets
    add_projection_targets!(lv, lshaped.master)
    # Run penalty initialization to check support
    initialize_penaltyterm!(lv.penaltyterm,
                            lshaped.master,
                            1.0,
                            all_decisions(lv.decisions),
                            lv.projection_targets)
    # Delete penalty-term
    remove_penalty!(lv.penaltyterm, lshaped.master)
    return nothing
end

function restore_regularized_master!(lshaped::AbstractLShaped, lv::LevelSet)
    # Delete level-set constraint
    if !iszero(lv.data.constraint.value)
        MOI.delete(lshaped.master, lv.data.constraint)
        lv.data.constraint = LVConstraint(0)
    end
    # Delete penalty-term
    remove_penalty!(lv.penaltyterm, lshaped.master)
    # Delete projection targets
    for var in lv.projection_targets
        MOI.delete(lshaped.master, var)
        StochasticPrograms.remove_decision!(lv.decisions, var)
    end
    empty!(lv.projection_targets)
    return nothing
end

function filter_variables!(lv::LevelSet, list::Vector{MOI.VariableIndex})
    # Filter projection targets
    filter!(vi -> !(vi in lv.projection_targets), list)
    # Filter any auxilliary penaltyterm variables
    remove_penalty_variables!(lv.penaltyterm, list)
    return nothing
end

function filter_constraints!(lv::LevelSet, list::Vector{<:CI})
    # Filter any auxilliary penaltyterm constraints
    remove_penalty_constraints!(lv.penaltyterm, list)
    # Filter level-set constraint
    i = something(findfirst(isequal(lv.data.constraint), list), 0)
    if !iszero(i)
        MOI.deleteat!(list, i)
    end
    return nothing
end

function log_regularization!(lshaped::AbstractLShaped, lv::LevelSet)
    @unpack Q̃,incumbent = lv.data
    push!(lv.Q̃_history, Q̃)
    push!(lv.incumbents, incumbent)
    return nothing
end

function log_regularization!(lshaped::AbstractLShaped, t::Integer, lv::LevelSet)
    @unpack Q̃,incumbent = lv.data
    lv.Q̃_history[t] = Q̃
    lv.incumbents[t] = incumbent
    return nothing
end

function take_step!(lshaped::AbstractLShaped, lv::LevelSet)
    @unpack Q = lshaped.data
    @unpack τ = lshaped.parameters
    @unpack Q̃ = lv.data
    if Q <= Q̃ - τ
        x = current_decision(lshaped)
        for i in eachindex(lv.ξ)
            lv.ξ[i].value = x[i]
        end
        lv.data.Q̃ = Q
        lv.data.incumbent = timestamp(lshaped)
        lv.data.major_iterations += 1
    else
        lv.data.minor_iterations += 1
    end
    if count(active_model_objectives(lshaped)) != num_thetas(lshaped)
        # Only project if all master variables have been added
        return nothing
    end
    if !lv.data.objective_cached
        F = MOI.get(lshaped.master, MOI.ObjectiveFunctionType())
        lv.data.objective = MOI.get(lshaped.master, MOI.ObjectiveFunction{F}())
        lv.data.objective_cached = true
    end
    @unpack Q̃, objective = lv.data
    @unpack λ = lv.parameters
    # Calculate new θ
    # ---------------- #
    # Delete level-set constraint
    if !iszero(lv.data.constraint.value)
        MOI.delete(lshaped.master, lv.data.constraint)
        lv.data.constraint = LVConstraint(0)
    end
    # Delete penalty-term
    remove_penalty!(lv.penaltyterm, lshaped.master)
    # Re-add objective
    F = typeof(objective)
    MOI.set(lshaped.master, MOI.ObjectiveFunction{F}(), objective)
    # Solve unregularized master
    status = solve_master!(lshaped)
    if !(status ∈ AcceptableTermination)
        # Early termination
        return nothing
    end
    # Update model objective
    θ = MOI.get(lshaped.master, MOI.ObjectiveValue())
    lshaped.data.θ = θ
    # Calculate new level
    L = (1-λ)*θ + λ*Q̃
    push!(lv.levels, L)
    # Reformulate projection problem
    F = MOI.ScalarAffineFunction{Float64}
    MOI.set(lshaped.master, MOI.ObjectiveFunction{F}(), zero(F))
    initialize_penaltyterm!(lv.penaltyterm,
                            lshaped.master,
                            1.0,
                            all_decisions(lv.decisions),
                            lv.projection_targets)
    # Add level constraint
    lv.data.constraint =
        MOI.add_constraint(lshaped.master, objective,
                           MOI.LessThan(L))
    return nothing
end

function process_cut!(lshaped::AbstractLShaped, cut::AnyOptimalityCut, lv::LevelSet)
    if lshaped.execution isa AsynchronousExecution
        # Shift level by cut value to prevent infeasibility
        increment = cut(lshaped.x)
        if !iszero(lv.data.constraint.value)
            L = MOI.get(lshaped.master, MOI.ConstraintSet(), lv.data.constraint)
            MOI.set(lshaped.master, MOI.ConstraintSet(), lv.data.constraint, MOIU.shift_constant(L, -increment))
        end
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
mutable struct LV <: AbstractRegularizer
    penaltyterm::AbstractPenaltyterm
    parameters::LVParameters{Float64}
end
LV(; penaltyterm = Quadratic(), kw...) = LV(penaltyterm, LVParameters(; kw...))
WithLV(; penaltyterm = Quadratic(), kw...) = LV(penaltyterm, LVParameters(; kw...))
LevelSet(; penaltyterm = Quadratic(), kw...) = LV(penaltyterm, LVParameters(; kw...))
WithLevelSets(; penaltyterm = Quadratic(), kw...) = LV(penaltyterm, LVParameters(; kw...))

function MOI.get(lv::LV, ::RegularizationPenaltyterm)
    return lv.penaltyterm
end

function MOI.set(lv::LV, ::RegularizationPenaltyterm, penaltyterm::AbstractPenaltyterm)
    return lv.penaltyterm = penaltyterm
end

function (lv::LV)(decisions::Decisions, x::AbstractVector)
    return LevelSet(decisions, x, lv.penaltyterm; type2dict(lv.parameters)...)
end

function str(::LV)
    return "L-shaped using level sets"
end
