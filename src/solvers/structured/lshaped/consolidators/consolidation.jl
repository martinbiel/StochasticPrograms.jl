abstract type AbstractConsolidation end
abstract type AbstractConsolidator end

# No consolidation
# ------------------------------------------------------------
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
    if !isempty(consolidation.cuts[end])
        push!(consolidation.cuts, Vector{AnySparseOptimalityCut{T}}())
        push!(consolidation.feasibility_cuts, Vector{SparseFeasibilityCut{T}}())
        push!(consolidation.consolidated, false)
        push!(consolidation.redundance_count, 0)
    end
    return nothing
end

function add_cut!(::AbstractLShapedSolver, ::Consolidation, ::AbstractHyperPlane)
    return nothing
end

function add_cut!(lshaped::AbstractLShapedSolver, consolidation::Consolidation{T}, cut::HyperPlane{FeasibilityCut}) where T <: AbstractFloat
    push!(consolidation.feasibility_cuts[end], cut)
    if sum(nsubproblems.(consolidation.cuts[end]))+length(consolidation.feasibility_cuts[end]) == nthetas(lshaped)
        push!(consolidation.cuts, Vector{AnySparseOptimalityCut{T}}())
        push!(consolidation.feasibility_cuts, Vector{SparseFeasibilityCut{T}}())
        push!(consolidation.consolidated, false)
        push!(consolidation.redundance_count, 0)
    end
    return nothing
end

function add_cut!(lshaped::AbstractLShapedSolver, consolidation::Consolidation{T}, cut::AnySparseOptimalityCut) where T <: AbstractFloat
    push!(consolidation.cuts[end], cut)
    if sum(nsubproblems.(consolidation.cuts[end]))+length(consolidation.feasibility_cuts[end]) == nthetas(lshaped)
        push!(consolidation.cuts, Vector{AnySparseOptimalityCut{T}}())
        push!(consolidation.feasibility_cuts, Vector{SparseFeasibilityCut{T}}())
        push!(consolidation.consolidated, false)
        push!(consolidation.redundance_count, 0)
    end
    return nothing
end

function add_cut!(::AbstractLShapedSolver, ::Consolidation, ::Integer, ::AbstractHyperPlane)
    return nothing
end

function add_cut!(lshaped::AbstractLShapedSolver, consolidation::Consolidation{T}, t::Integer, cut::HyperPlane{FeasibilityCut}) where T <: AbstractFloat
    if t > length(consolidation.cuts)
        push!(consolidation.cuts, Vector{AnySparseOptimalityCut{T}}())
        push!(consolidation.feasibility_cuts, Vector{SparseFeasibilityCut{T}}())
        push!(consolidation.consolidated, false)
        push!(consolidation.redundance_count, 0)
    end
    push!(consolidation.feasibility_cuts[t], cut)
    return nothing
end

function add_cut!(lshaped::AbstractLShapedSolver, consolidation::Consolidation{T}, t::Integer, cut::AnySparseOptimalityCut) where T <: AbstractFloat
    if t > length(consolidation.cuts)
        push!(consolidation.cuts, Vector{AnySparseOptimalityCut{T}}())
        push!(consolidation.feasibility_cuts, Vector{SparseFeasibilityCut{T}}())
        push!(consolidation.consolidated, false)
        push!(consolidation.redundance_count, 0)
    end
    push!(consolidation.cuts[t], cut)
    return nothing
end

function rebuild_master!(lshaped::AbstractLShapedSolver, consolidation::Consolidation)
    ncuts = ncutconstraints(lshaped)
    cut_indices = first_stage_nconstraints(lshaped.stochasticprogram)+1:MPB.numconstr(lshaped.mastersolver.lqmodel)
    MPB.delconstrs!(lshaped.mastersolver.lqmodel, collect(cut_indices))
    if lshaped.regularizer isa LevelSet
        # Reset projection problem if using level sets
        lv = lshaped.regularizer
        MPB.delconstrs!(lv.projectionsolver.lqmodel, [lv.data.levelindex])
        cut_indices = first_stage_nconstraints(lshaped.stochasticprogram)+1:MPB.numconstr(lv.projectionsolver.lqmodel)
        MPB.delconstrs!(lv.projectionsolver.lqmodel, collect(cut_indices))
        lv.data.levelindex = -1
        lv.data.regularizerindex = -1
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

at_tolerance() = at_tolerance(0.4, 0)
function at_tolerance(τ, miniter)
    return (lshaped, consolidation) -> begin
        return lshaped.data.iterations >= (lshaped.data.consolidations+1)*miniter && ncutconstraints(consolidation)/ncutconstraints(lshaped) <= τ
    end
end

for_loadbalance() = for_loadbalance(1.0, 0)
function for_loadbalance(τ, miniter)
    return (lshaped, consolidation) -> begin
        return for_loadbalance(lshaped, τ, miniter)
    end
end
# API
# ------------------------------------------------------------
struct DontConsolidate <: AbstractConsolidator end

function (::DontConsolidate)(::Type{T} where T <: AbstractFloat)
    return NoConsolidation()
end

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
