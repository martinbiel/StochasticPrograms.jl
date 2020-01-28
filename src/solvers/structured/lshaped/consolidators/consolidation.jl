abstract type AbstractConsolidation end
abstract type AbstractConsolidator end

# No consolidation
# ------------------------------------------------------------
"""
    NoRegularization

Empty functor object for running the L-shaped algorithm without consolidation.

"""
struct NoConsolidation <: AbstractConsolidation end

function consolidate!(::AbstractLShapedSolver, ::NoConsolidation)
    return nothing
end

function add_cut!(::AbstractLShapedSolver, ::NoConsolidation, ::AbstractHyperPlane)
    return nothing
end

function add_cut!(::AbstractLShapedSolver, ::NoConsolidation, ::Integer, ::AbstractHyperPlane)
    return nothing
end
# Consolidation
# ------------------------------------------------------------
"""
    Consolidation

Functor object for using consolidation in an L-shaped algorithm. Create by supplying a [`Consolidate`](@ref) object through `consolidate ` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

...
# Algorithm parameters
- `tresh::T` = 0.95: Relative amount of redundant cuts in a former iteration required to consider the iteration redundant
- `at::Int = 5.0`: Number of times an iteration can be redundant before consolidation is triggered
- `rebuild::Function = at_tolerance()`: Function deciding when the master model should be rebuilt according to performed consolidations
...
"""
struct Consolidation{T <: AbstractFloat} <: AbstractConsolidation
    cuts::Vector{Vector{AnySparseOptimalityCut{T}}}
    feasibility_cuts::Vector{Vector{SparseFeasibilityCut{T}}}
    consolidated::Vector{Bool}
    redundance_count::Vector{Int}
    redundance_treshold::T
    consolidation_trigger::Int
    rebuild::Function

   function Consolidation(::Type{T}, tresh::T, at::Int, rebuild::Function) where T <: AbstractFloat
        cuts = Vector{Vector{AnySparseOptimalityCut{T}}}()
        push!(cuts, Vector{AnySparseOptimalityCut{T}}())
        feasibility_cuts = Vector{Vector{SparseFeasibilityCut{T}}}()
        push!(feasibility_cuts, Vector{SparseFeasibilityCut{T}}())
        return new{T}(cuts, feasibility_cuts, [false], [0], tresh, at, rebuild)
    end
end

function consolidate!(lshaped::AbstractLShapedSolver, consolidation::Consolidation{T}) where T <: AbstractFloat
    for i in findall(map(!,consolidation.consolidated))
        nc = sum(nsubproblems.(consolidation.cuts[i]))
        nc == 0 && continue
        count = 0
        for cut in consolidation.cuts[i]
            # Check for redundance
            if !active(lshaped, cut)
                count += nsubproblems(cut)
            end
        end
        if count/nc >= consolidation.redundance_treshold
            consolidation.redundance_count[i] += 1
        end
        if consolidation.redundance_count[i] == consolidation.consolidation_trigger
            consolidated_cut = aggregate(consolidation.cuts[i])
            empty!(consolidation.cuts[i])
            push!(consolidation.cuts[i], consolidated_cut)
            consolidation.consolidated[i] = true
        end
    end
    for i in findall(c->length(c)>0, consolidation.feasibility_cuts)
        inactive = Vector{Int}()
        for (j,cut) in enumerate(consolidation.feasibility_cuts[i])
            # Check for redundance
            if !active(lshaped, cut)
                push!(inactive, j)
            end
        end
        deleteat!(consolidation.feasibility_cuts[i], inactive)
    end
    if minimum_requirements(lshaped,consolidation) && consolidation.rebuild(lshaped, consolidation)
        # Rebuild sparingly
        rebuild_master!(lshaped, consolidation)
        lshaped.data.consolidations += 1
    end
    # Prepare memory for next iteration
    push!(consolidation.cuts, Vector{AnySparseOptimalityCut{T}}())
    push!(consolidation.feasibility_cuts, Vector{SparseFeasibilityCut{T}}())
    push!(consolidation.consolidated, false)
    push!(consolidation.redundance_count, 0)
    return nothing
end

function add_cut!(::AbstractLShapedSolver, ::Consolidation, ::AbstractHyperPlane)
    return nothing
end

function add_cut!(lshaped::AbstractLShapedSolver, consolidation::Consolidation{T}, cut::HyperPlane{FeasibilityCut}) where T <: AbstractFloat
    push!(consolidation.feasibility_cuts[timestamp(lshaped)], cut)
    return nothing
end

function add_cut!(lshaped::AbstractLShapedSolver, consolidation::Consolidation{T}, cut::AnySparseOptimalityCut) where T <: AbstractFloat
    push!(consolidation.cuts[timestamp(lshaped)], cut)
    return nothing
end

function rebuild_master!(lshaped::AbstractLShapedSolver, consolidation::Consolidation)
    ncuts = ncutconstraints(lshaped)
    cut_indices = first_stage_nconstraints(lshaped.stochasticprogram)+1:MPB.numconstr(lshaped.mastersolver.lqmodel)
    MPB.delconstrs!(lshaped.mastersolver.lqmodel, collect(cut_indices))
    if lshaped.regularization isa LevelSet
        # Reset projection problem if using level sets
        lv = lshaped.regularization
        MPB.delconstrs!(lv.projectionsolver.lqmodel, [lv.data.levelindex])
        cut_indices = first_stage_nconstraints(lshaped.stochasticprogram)+1:MPB.numconstr(lv.projectionsolver.lqmodel)
        MPB.delconstrs!(lv.projectionsolver.lqmodel, collect(cut_indices))
        lv.data.levelindex = -1
        if :index ∈ fieldnames(typeof(lv.penalty))
            lv.penalty.index = -1
        end
    elseif lshaped.regularization isa RegularizedDecomposition
        rd = lshaped.regularization
        if :index ∈ fieldnames(typeof(rd.penalty))
            rd.penalty.index = -1
        end
    end
    lshaped.data.ncuts -= ncuts
    readd_cuts!(lshaped, consolidation)
    return nothing
end

noptimalitycuts(consolidation::Consolidation) = sum(length.(consolidation.cuts))
nfeasibilitycuts(consolidation::Consolidation) = sum(length.(consolidation.feasibility_cuts))
function ncutconstraints(consolidation::Consolidation)
    return noptimalitycuts(consolidation) + nfeasibilitycuts(consolidation)
end

function ncutconstraints(lshaped::AbstractLShapedSolver)
    return MPB.numconstr(lshaped.mastersolver.lqmodel)-first_stage_nconstraints(lshaped.stochasticprogram)
end
# Rebuild functions
# ------------------------------------------------------------
function minimum_requirements(lshaped::AbstractLShapedSolver, consolidation::Consolidation)
    return (noptimalitycuts(consolidation) > 0 &&
        count(consolidation.consolidated) > 0) ||
        (nfeasibilitycuts(consolidation) > 0 &&
         nfeasibilitycuts(consolidation)/ncutconstraints(lshaped) <= 0.1)
end
"""
    at_tolerance(τ = 0.4, miniter = 0)

Rebuild master when at least nconsolidations*`miniter` iterations has passed and the ratio of number of cuts in the consolidated collection and the number of cuts in the master model has decreased below `τ`.

"""
at_tolerance() = at_tolerance(0.4, 0)
function at_tolerance(τ, miniter)
    return (lshaped, consolidation) -> begin
        return lshaped.data.iterations >= (lshaped.data.consolidations+1)*miniter && ncutconstraints(consolidation)/ncutconstraints(lshaped) <= τ
    end
end

# API
# ------------------------------------------------------------
"""
    DontConsolidate

Factory object for [`NoConsolidation`](@ref). Passed by default to `consolidate` in the `LShapedSolver` factory function.

"""
struct DontConsolidate <: AbstractConsolidator end

function (::DontConsolidate)(::Type{T} where T <: AbstractFloat)
    return NoConsolidation()
end

"""
    Consolidate

Factory object for [`Consolidation`](@ref). Pass to `consolidate` in the `LShapedSolver` factory function. See ?Consolidation for parameter descriptions.

"""
struct Consolidate <: AbstractConsolidator
    redundance_treshold::Float64
    consolidation_trigger::Int
    rebuild::Function
end
Consolidate(; tresh::Float64 = 0.95, at::Int = 5, rebuild = at_tolerance()) = Consolidate(tresh, at, rebuild)

function (consolidator::Consolidate)(::Type{T}) where T <: AbstractFloat
    return Consolidation(T,
                         consolidator.redundance_treshold,
                         consolidator.consolidation_trigger,
                         consolidator.rebuild)
end
