struct SubProblem{T <: AbstractFloat, A <: AbstractVector, S <: LQSolver, PT <: PenaltyTerm}
    id::Int
    π::T
    solver::S
    penalty::PT
    c::A
    x::A
    y::A
    ρ::A
    optimvector::A

    function (::Type{SubProblem})(model::JuMP.Model,
                                  id::Integer,
                                  π::AbstractFloat,
                                  xdim::Integer,
                                  subsolver::MPB.AbstractMathProgSolver,
                                  penalty::PenaltyTerm)
        solver = LQSolver(model, subsolver)
        solver()
        optimvector = getsolution(solver)
        x₀ = optimvector[1:xdim]
        y₀ = optimvector[xdim+1:end]
        T = promote_type(eltype(optimvector),Float32)
        c_ = convert(AbstractVector{T},JuMP.prepAffObjective(model))
        c_ *= model.objSense == :Min ? 1 : -1
        x₀_ = convert(AbstractVector{T},x₀)
        y₀_ = convert(AbstractVector{T},y₀)
        optimvector_ = convert(AbstractVector{T},optimvector)
        A = typeof(x₀_)
        S = typeof(solver)
        PT = typeof(penalty)
        subproblem = new{T,A,S,PT}(id,
                                   π,
                                   solver,
                                   penalty,
                                   c_,
                                   x₀_,
                                   y₀_,
                                   zero(x₀_),
                                   optimvector_)
        initialize_penaltyterm!(penalty, solver, x₀_)
        return subproblem
    end

    function (::Type{SubProblem})(model::JuMP.Model,
                                  id::Integer,
                                  π::AbstractFloat,
                                  x₀::AbstractVector,
                                  y₀::AbstractVector,
                                  subsolver::MPB.AbstractMathProgSolver,
                                  penalty::PenaltyTerm)
        T = promote_type(eltype(x₀),eltype(y₀),Float32)
        c_ = convert(AbstractVector{T},JuMP.prepAffObjective(model))
        c_ *= model.objSense == :Min ? 1 : -1
        x₀_ = convert(AbstractVector{T},x₀)
        y₀_ = convert(AbstractVector{T},y₀)
        A = typeof(x₀_)
        solver = LQSolver(model, subsolver)
        S = typeof(solver)
        PT = typeof(penalty)
        subproblem = new{T,A,S,PT}(id,
                                   π,
                                   solver,
                                   penalty,
                                   c_,
                                   x₀_,
                                   y₀_,
                                   zero(x₀_),
                                   [x₀_...,y₀_...])
        initialize_penaltyterm!(penalty, solver, x₀_)
        return subproblem
    end
end

function update_subproblem!(subproblem::SubProblem, ξ::AbstractVector, r::AbstractFloat)
    subproblem.ρ .= subproblem.ρ + r*(subproblem.x - ξ)
end
update_subproblems!(subproblems::Vector{<:SubProblem}, ξ::AbstractVector, r::AbstractFloat) = map(prob -> update_subproblem!(prob,ξ,r), subproblems)

function reformulate_subproblem!(subproblem::SubProblem, ξ::AbstractVector, r::AbstractFloat)
    model = subproblem.solver.lqmodel
    # Cache initial cost
    c = copy(subproblem.c)
    # Linear part
    c[1:length(ξ)] += subproblem.ρ
    # Update penalty
    update_penaltyterm!(subproblem.penalty, subproblem.solver, c, r, ξ)
    return nothing
end
reformulate_subproblems!(subproblems::Vector{<:SubProblem}, ξ::AbstractVector, r::AbstractFloat) = map(prob -> reformulate_subproblem!(prob,ξ,r), subproblems)

function get_objective_value(subproblem::SubProblem)
    return subproblem.π*subproblem.c⋅subproblem.optimvector
end

function get_solution(subproblem::SubProblem)
    return copy(subproblem.y), getredcosts(subproblem.solver)[length(subproblem.x)+1:end], getduals(subproblem.solver)
end

function (subproblem::SubProblem)(ξ::AbstractVector)
    solve_penalized!(subproblem.penalty, subproblem.solver, subproblem.optimvector, subproblem.x, ξ)
    solvestatus = status(subproblem.solver)
    if solvestatus == :Optimal
        ncols = length(subproblem.optimvector)
        xdim = length(subproblem.x)
        subproblem.optimvector[1:ncols] = getsolution(subproblem.solver)[1:ncols]
        subproblem.x .= subproblem.optimvector[1:xdim]
        subproblem.y .= subproblem.optimvector[xdim+1:ncols]
        return get_objective_value(subproblem)
    elseif solvestatus == :Infeasible
        return Inf
    elseif solvestatus == :Unbounded
        return -Inf
    else
        error(@sprintf("Subproblem %d was not solved properly, returned status code: %s", subproblem.id, string(solvestatus)))
    end
end
