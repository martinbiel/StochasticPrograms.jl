# Regularized decomposition
# ------------------------------------------------------------
@with_kw mutable struct WeakCutsData{T <: AbstractFloat}
    L::T = -1e10
end
"""
    WeakCutsMaster

Master functor object for using weak optimality cuts in an integer L-shaped algorithm. Requires all first-stage decisions to be binary. Create by supplying a [`UseWeakCuts`](@ref) object through `integer_strategy` in `LShaped.Optimizer` or set the [`IntegerStrategy`](@ref) attribute.

"""
struct WeakCutsMaster{T <: AbstractFloat} <: AbstractIntegerAlgorithm
    data::WeakCutsData{T}

    function WeakCutsMaster(::Type{T}) where T <: AbstractFloat
        T_ = promote_type(T, Float32)
        return new{T_}(WeakCutsData{T_}())
    end
end
"""
    WeakCutsWorker

Worker functor object for using weak optimality cuts in an integer L-shaped algorithm. Create by supplying a [`UseWeakCuts`](@ref) object through `integer_strategy` in `LShaped.Optimizer` or set the [`IntegerStrategy`](@ref) attribute.

"""
struct WeakCutsWorker{T <: AbstractFloat} <: AbstractIntegerAlgorithm
    data::WeakCutsData{T}

    function WeakCutsWorker(::Type{T}) where T <: AbstractFloat
        T_ = promote_type(T, Float32)
        return new{T_}(WeakCutsData{T_}())
    end
end

function solve_subproblem(subproblem::SubProblem,
                          ::NoFeasibilityAlgorithm,
                          worker::WeakCutsWorker,
                          x::AbstractVector)
    if worker.data.L <= -1e10

    end
    return solve_subproblem(subproblem, x)
end

function solve_subproblem(subproblem::SubProblem,
                          feasibility_algorithm::FeasibilityCutsWorker,
                          ::WeakCutsWorker,
                          x::AbstractVector)
    error("The weak-cuts integer L-shaped algorithm does not support feasibility cuts")
end

# API
# ------------------------------------------------------------
"""
    UseWeakCuts

Factory object for [`WeakCuts`](@ref). Pass to `integer_strategy` in `LShaped.Optimizer` or set the [`IntegerStrategy`](@ref) attribute.

"""
struct UseWeakCuts <: AbstractIntegerStrategy end

function master(::UseWeakCuts, ::Type{T}) where T <: AbstractFloat
    return WeakCutsMaster(T)
end

function worker(::UseWeakCuts, ::Type{T}) where T <: AbstractFloat
    return WeakCutsWorker(T)
end
