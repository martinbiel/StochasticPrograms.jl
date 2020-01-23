struct SubProblem{T <: AbstractFloat, A <: AbstractVector, S <: LQSolver}
    id::Int
    π::T
    solver::S
    c::A
    x::A
    y::A
    ρ::A
    optimvector::A

    function (::Type{SubProblem})(model::JuMP.Model,
                                  id::Integer,
                                  π::AbstractFloat,
                                  xdim::Integer,
                                  optimsolver::MPB.AbstractMathProgSolver)
        solver = LQSolver(model,optimsolver)
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
        subproblem = new{T,A,typeof(solver)}(id,
                                             π,
                                             solver,
                                             c_,
                                             x₀_,
                                             y₀_,
                                             zero(x₀_),
                                             optimvector_)
        return subproblem
    end

    function (::Type{SubProblem})(model::JuMP.Model,
                                  id::Integer,
                                  π::AbstractFloat,
                                  x₀::AbstractVector,
                                  y₀::AbstractVector,
                                  optimsolver::MPB.AbstractMathProgSolver)
        T = promote_type(eltype(x₀),eltype(y₀),Float32)
        c_ = convert(AbstractVector{T},JuMP.prepAffObjective(model))
        c_ *= model.objSense == :Min ? 1 : -1
        x₀_ = convert(AbstractVector{T},x₀)
        y₀_ = convert(AbstractVector{T},y₀)
        A = typeof(x₀_)
        solver = LQSolver(model,optimsolver)
        subproblem = new{T,A,typeof(solver)}(id,
                                             π,
                                             solver,
                                             c_,
                                             x₀_,
                                             y₀_,
                                             zero(x₀_),
                                             [x₀_...,y₀_...])
        return subproblem
    end
end

function update_subproblem!(subproblem::SubProblem, ξ::AbstractVector, r::AbstractFloat)
    subproblem.ρ[:] = subproblem.ρ + r*(subproblem.x - ξ)
end
update_subproblems!(subproblems::Vector{<:SubProblem}, ξ::AbstractVector, r::AbstractFloat) = map(prob -> update_subproblem!(prob,ξ,r), subproblems)

function reformulate_subproblem!(subproblem::SubProblem, ξ::AbstractVector, r::AbstractFloat)
    model = subproblem.solver.lqmodel
    # Linear part
    c = copy(subproblem.c)
    c[1:length(ξ)] += subproblem.ρ
    c[1:length(ξ)] -= r*ξ
    MPB.setobj!(model, c)
    # Quadratic part
    qidx = collect(1:length(subproblem.optimvector))
    qval = zeros(length(subproblem.optimvector))
    qval[1:length(ξ)] .= r
    if applicable(MPB.setquadobj!, model, qidx, qidx, qval)
        MPB.setquadobj!(model, qidx, qidx, qval)
    else
        error("Setting a quadratic penalty requires a solver that handles quadratic objectives")
    end
end
reformulate_subproblems!(subproblems::Vector{<:SubProblem}, ξ::AbstractVector, r::AbstractFloat) = map(prob -> reformulate_subproblem!(prob,ξ,r), subproblems)

function get_objective_value(subproblem::SubProblem)
    return subproblem.π*subproblem.c⋅subproblem.optimvector
end

function get_solution(subproblem::SubProblem)
    return copy(subproblem.y), getredcosts(subproblem.solver)[length(subproblem.x)+1:end], getduals(subproblem.solver)
end

function (subproblem::SubProblem)()
    subproblem.solver(subproblem.optimvector)
    solvestatus = status(subproblem.solver)
    if solvestatus == :Optimal
        xdim = length(subproblem.x)
        subproblem.optimvector[:] = getsolution(subproblem.solver)
        subproblem.x[:] = subproblem.optimvector[1:xdim]
        subproblem.y[:] = subproblem.optimvector[xdim+1:end]
        return get_objective_value(subproblem)
    elseif solvestatus == :Infeasible
        return Inf
    elseif solvestatus == :Unbounded
        return -Inf
    else
        error(@sprintf("Subproblem %d was not solved properly, returned status code: %s", subproblem.id, string(solvestatus)))
    end
end
