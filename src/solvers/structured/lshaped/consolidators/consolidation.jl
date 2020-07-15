abstract type AbstractConsolidation end
abstract type AbstractConsolidator end
"""
    RawConsolidationParameter

An optimizer attribute used for raw parameters of the consolidator. Defers to `RawParameter`.
"""
struct RawConsolidationParameter <: ConsolidationParameter
    name::Any
end

function MOI.get(consolidator::AbstractConsolidator, param::RawConsolidationParameter)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(consolidator)))
        error("Unrecognized parameter name: $(name) for consolidator $(typeof(consolidator)).")
    end
    return getfield(consolidator, name)
end

function MOI.set(consolidator::AbstractConsolidator, param::RawConsolidationParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(consolidator)))
        error("Unrecognized parameter name: $(name) for consolidator $(typeof(consolidator)).")
    end
    setfield!(consolidator, name, value)
    return nothing
end

# No consolidation
# ------------------------------------------------------------
"""
    NoRegularization

Empty functor object for running the L-shaped algorithm without consolidation.

"""
struct NoConsolidation <: AbstractConsolidation end

function consolidate!(::AbstractLShaped, ::NoConsolidation)
    return nothing
end

function add_cut!(::AbstractLShaped, ::NoConsolidation, ::AbstractHyperPlane)
    return nothing
end

function add_cut!(::AbstractLShaped, ::NoConsolidation, ::Integer, ::AbstractHyperPlane)
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

function consolidate!(lshaped::AbstractLShaped, consolidation::Consolidation{T}) where T <: AbstractFloat
    for i in findall(map(!,consolidation.consolidated))
        nc = sum(num_subproblems.(consolidation.cuts[i]))
        nc == 0 && continue
        count = 0
        for cut in consolidation.cuts[i]
            # Check for redundance
            if !active(lshaped, cut)
                count += num_subproblems(cut)
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
    allocate!(consolidation)
    return nothing
end

function allocate!(consolidation::Consolidation{T}) where T <: AbstractFloat
    push!(consolidation.cuts, Vector{AnySparseOptimalityCut{T}}())
    push!(consolidation.feasibility_cuts, Vector{SparseFeasibilityCut{T}}())
    push!(consolidation.consolidated, false)
    push!(consolidation.redundance_count, 0)
    return nothing
end

function add_cut!(::AbstractLShaped, ::Consolidation, ::AbstractHyperPlane)
    return nothing
end

function add_cut!(lshaped::AbstractLShaped, consolidation::Consolidation{T}, cut::HyperPlane{FeasibilityCut}) where T <: AbstractFloat
    push!(consolidation.feasibility_cuts[timestamp(lshaped)], cut)
    return nothing
end

function add_cut!(lshaped::AbstractLShaped, consolidation::Consolidation{T}, cut::AnySparseOptimalityCut) where T <: AbstractFloat
    push!(consolidation.cuts[timestamp(lshaped)], cut)
    return nothing
end

function rebuild_master!(lshaped::AbstractLShaped, consolidation::Consolidation)
    # Remove all cutsa
    remove_cut_constraints!(lshaped)
    # Readd consolidated cuts
    readd_cuts!(lshaped, consolidation)
    return nothing
end

num_optimalitycuts(consolidation::Consolidation) = sum(length.(consolidation.cuts))
num_feasibilitycuts(consolidation::Consolidation) = sum(length.(consolidation.feasibility_cuts))
function num_cutconstraints(consolidation::Consolidation)
    return num_optimalitycuts(consolidation) + num_feasibilitycuts(consolidation)
end

function num_cutconstraints(lshaped::AbstractLShaped)
    return length(lshaped.cut_constraints)
end
# Rebuild functions
# ------------------------------------------------------------
function minimum_requirements(lshaped::AbstractLShaped, consolidation::Consolidation)
    return (num_optimalitycuts(consolidation) > 0 &&
        count(consolidation.consolidated) > 0) ||
        (num_feasibilitycuts(consolidation) > 0 &&
         num_feasibilitycuts(consolidation)/num_cutconstraints(lshaped) <= 0.1)
end
"""
    at_tolerance(τ = 0.4, miniter = 0)

Rebuild master when at least nconsolidations*`miniter` iterations has passed and the ratio of number of cuts in the consolidated collection and the number of cuts in the master model has decreased below `τ`.

"""
at_tolerance() = at_tolerance(0.4, 0)
function at_tolerance(τ, miniter)
    return (lshaped, consolidation) -> begin
        return lshaped.data.iterations >= (lshaped.data.consolidations+1)*miniter && num_cutconstraints(consolidation)/num_cutconstraints(lshaped) <= τ
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
mutable struct Consolidate <: AbstractConsolidator
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
