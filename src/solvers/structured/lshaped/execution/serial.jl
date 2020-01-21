"""
    SerialExecution

Functor object for using serial execution in a lshaped algorithm. Create by supplying a [`Serial`](@ref) object through `execution` in the `LShapedSolver` factory function and then pass to a `StochasticPrograms.jl` model.

"""
struct SerialExecution{F <: AbstractFeasibility,
                       T <: AbstractFloat,
                       A <: AbstractVector,
                       S <: LQSolver} <: AbstractExecution
    subproblems::Vector{SubProblem{F,T,A,S}}
    subobjectives::A
    model_objectives::A

    function SerialExecution(::Type{F}, ::Type{T}, ::Type{A}, ::Type{S}) where {F <: AbstractFeasibility, T <: AbstractFloat, A <: AbstractVector, S <: LQSolver}
        return new{F,T,A,S}(Vector{SubProblem{F,T,A,S}}(), A(), A())
    end
end

function nthetas(lshaped::AbstractLShapedSolver, ::SerialExecution)
    return nthetas(lshaped.nscenarios, lshaped.aggregation)
end

function initialize_subproblems!(execution::SerialExecution{F,T,A,S},
                                 scenarioproblems::ScenarioProblems,
                                 x::AbstractVector,
                                 subsolver::MPB.AbstractMathProgSolver) where {F <: AbstractFeasibility,
                                                                               T <: AbstractFloat,
                                                                               A <: AbstractVector,
                                                                               S <: LQSolver}
    for i = 1:StochasticPrograms.nscenarios(scenarioproblems)
        m = subproblem(scenarioproblems, i)
        y₀ = convert(A, rand(m.numCols))
        push!(execution.subproblems, SubProblem(m,
                                                parentmodel(scenarioproblems),
                                                i,
                                                probability(scenario(scenarioproblems,i)),
                                                copy(x),
                                                y₀,
                                                subsolver,
                                                F))
    end
    return nothing
end

function initialize_subproblems!(execution::SerialExecution{F,T,A,S},
                                 scenarioproblems::DScenarioProblems,
                                 x::AbstractVector,
                                 subsolver::MPB.AbstractMathProgSolver) where {F <: AbstractFeasibility,
                                                                               T <: AbstractFloat,
                                                                               A <: AbstractVector,
                                                                               S <: LQSolver}
    for i = 1:StochasticPrograms.nscenarios(scenarioproblems)
        m = subproblem(scenarioproblems, i)
        y₀ = convert(A, rand(m.numCols))
        push!(execution.subproblems,SubProblem(m,
                                               i,
                                               probability(scenario(scenarioproblems,i)),
                                               copy(x),
                                               y₀,
                                               masterterms(scenarioproblems,i),
                                               subsolver,
                                               F))
    end
    return nothing
end

function finish_initilization!(lshaped::AbstractLShapedSolver, execution::SerialExecution)
    append!(execution.subobjectives, fill(1e10, nthetas(lshaped)))
    append!(execution.model_objectives, fill(-1e10, nthetas(lshaped)))
    return nothing
end

function resolve_subproblems!(lshaped::AbstractLShapedSolver, execution::SerialExecution{F,T}) where {F <: AbstractFeasibility, T <: AbstractFloat}
    # Update subproblems
    update_subproblems!(execution.subproblems, lshaped.x)
    # Assume no cuts are added
    added = false
    # Solve subproblems
    for subproblem ∈ execution.subproblems
        cut::SparseHyperPlane{T} = subproblem()
        added |= aggregate_cut!(lshaped, lshaped.aggregation, cut)
    end
    added |= flush!(lshaped, lshaped.aggregation)
    # Return current objective value and cut_added flag
    return current_objective_value(lshaped), added
end

function calculate_objective_value(lshaped::AbstractLShapedSolver, execution::SerialExecution)
    return lshaped.c⋅decision(lshaped) + sum([subproblem.π*subproblem(decision(lshaped)) for subproblem in execution.subproblems])
end

function fill_submodels!(lshaped::AbstractLShapedSolver, scenarioproblems::ScenarioProblems, execution::SerialExecution)
    for (i, submodel) in enumerate(scenarioproblems.problems)
        execution.subproblems[i](decision(lshaped))
        fill_submodel!(submodel, execution.subproblems[i])
    end
    return nothing
end

function fill_submodels!(lshaped::AbstractLShapedSolver, scenarioproblems::DScenarioProblems, execution::SerialExecution)
    j = 0
    @sync begin
        for w in workers()
            n = remotecall_fetch((sp)->length(fetch(sp).problems), w, scenarioproblems[w-1])
            for i in 1:n
                k = i+j
                execution.subproblems[k](decision(lshaped))
                @async remotecall_fetch((sp,i,x,μ,λ,C) -> fill_submodel!(fetch(sp).problems[i],x,μ,λ,C),
                                        w,
                                        scenarioproblems[w-1],
                                        i,
                                        get_solution(execution.subproblems[k])...)
            end
            j += n
        end
    end
    return nothing
end

# API
# ------------------------------------------------------------
function (execution::Serial)(::Integer, ::Type{F}, ::Type{T}, ::Type{A}, ::Type{S}) where {F <: AbstractFeasibility, T <: AbstractFloat, A <: AbstractVector, S <: LQSolver}
    return SerialExecution(F, T, A, S)
end

function str(::Serial)
    return ""
end
