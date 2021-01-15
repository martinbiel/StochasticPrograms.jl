"""
    NoIntegerAlgorithm

Empty functor object for running an L-shaped algorithm without dealing with integer variables.

"""
struct NoIntegerAlgorithm <: AbstractIntegerAlgorithm end

function check_optimality(::AbstractLShaped, ::NoIntegerAlgorithm)
    return true
end

function solve_subproblem(subproblem::SubProblem,
                          metadata,
                          ::NoFeasibilityAlgorithm,
                          ::NoIntegerAlgorithm,
                          x::AbstractVector)
    return solve_subproblem(subproblem, x)
end

function solve_subproblem(subproblem::SubProblem,
                          metadata,
                          feasibility_algorithm::FeasibilityCutsWorker,
                          ::NoIntegerAlgorithm,
                          x::AbstractVector)
    model = subproblem.optimizer
    if !prepared(feasibility_algorithm)
        prepare!(model, feasibility_algorithm)
    end
    # Optimize auxiliary problem
    MOI.optimize!(model)
    # Sanity check that aux problem could be solved
    status = MOI.get(subproblem.optimizer, MOI.TerminationStatus())
    if !(status ∈ AcceptableTermination)
        error("Subproblem $(subproblem.id) was not solved properly during feasibility check, returned status code: $status")
    end
    sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    w = correction * MOI.get(model, MOI.ObjectiveValue())
    # Ensure correction is available in master
    set_metadata!(metadata, subproblem.id, :correction, correction)
    # Check feasibility
    if w > sqrt(eps())
        # Subproblem is infeasible, create feasibility cut
        return FeasibilityCut(subproblem, metadata, x)
    end
    # Restore subproblem and solve as usual
    restore_subproblem!(subproblem)
    return solve_subproblem(subproblem, x)
end

"""
    IgnoreIntegers

Factory object for [`NoIntegerAlgorithm`](@ref). Passed by default to `integer_strategy` in `LShaped.Optimizer`.

"""
struct IgnoreIntegers <: AbstractIntegerStrategy end

function master(::IgnoreIntegers, ::Type{T}) where T <: AbstractFloat
    return NoIntegerAlgorithm()
end

function worker(::IgnoreIntegers, ::Type{T}) where T <: AbstractFloat
    return NoIntegerAlgorithm()
end
function worker_type(::IgnoreIntegers)
    return NoIntegerAlgorithm
end
