struct SubProblem{F <: AbstractFeasibility, T <: AbstractFloat, A <: AbstractVector, S <: LQSolver}
    id::Int
    π::T

    solver::S
    feasibility_solver::S

    h::Tuple{A,A}
    x::A
    y::A
    masterterms::Vector{Tuple{Int,Int,T}}

    function SubProblem(model::JuMP.Model,
                        id::Integer,
                        π::AbstractFloat,
                        x::AbstractVector,
                        y₀::AbstractVector,
                        masterterms::Vector{Tuple{Int,Int,R}},
                        optimsolver::MPB.AbstractMathProgSolver,
                        ::Type{F}) where {R <: AbstractFloat, F <: AbstractFeasibility}
        T = promote_type(eltype(x), eltype(y₀), R, Float32)
        x_ = convert(AbstractVector{T}, x)
        y₀_ = convert(AbstractVector{T}, y₀)
        masterterms_ = convert(Vector{Tuple{Int,Int,T}}, masterterms)
        A = typeof(x_)
        solver = LQSolver(model, optimsolver)
        subproblem = new{F,T,A,typeof(solver)}(id,
                                               π,
                                               solver,
                                               FeasibilitySolver(model, optimsolver, F),
                                               (convert(A, MPB.getconstrLB(solver.lqmodel)),
                                                convert(A, MPB.getconstrUB(solver.lqmodel))),
                                               x_,
                                               y₀_,
                                               masterterms_)
        return subproblem
    end

    function SubProblem(model::JuMP.Model,
                        parent::JuMP.Model,
                        id::Integer,
                        π::AbstractFloat,
                        x::AbstractVector,
                        y₀::AbstractVector,
                        optimsolver::MPB.AbstractMathProgSolver,
                        ::Type{F}) where F <: AbstractFeasibility
        T = promote_type(eltype(x), eltype(y₀), Float32)
        x_ = convert(AbstractVector{T}, x)
        y₀_ = convert(AbstractVector{T}, y₀)
        A = typeof(x_)

        solver = LQSolver(model, optimsolver)

        subproblem = new{F,T,A,typeof(solver)}(id,
                                               π,
                                               solver,
                                               FeasibilitySolver(model, optimsolver, F),
                                               (convert(A, MPB.getconstrLB(solver.lqmodel)),
                                                convert(A, MPB.getconstrUB(solver.lqmodel))),
                                               x_,
                                               y₀_,
                                               Vector{Tuple{Int,Int,T}}())
        parse_subproblem!(subproblem, model, parent)
        return subproblem
    end
end

function FeasibilitySolver(model::JuMP.Model, optimsolver::MPB.AbstractMathProgSolver, ::Type{IgnoreFeasibility})
    return LQSolver(model, optimsolver; load = false)
end

function FeasibilitySolver(model::JuMP.Model, optimsolver::MPB.AbstractMathProgSolver, ::Type{<:HandleFeasibility})
    solver = LQSolver(model, optimsolver)
    feasibility_problem!(solver)
    return solver
end

function parse_subproblem!(subproblem::SubProblem, model::JuMP.Model, parent::JuMP.Model)
    for (i, constr) in enumerate(model.linconstr)
        for (j, var) in enumerate(constr.terms.vars)
            if var.m == parent
                # var is a first stage variable
                push!(subproblem.masterterms, (i,var.col,-constr.terms.coeffs[j]))
            end
        end
    end
end

function update_subproblem!(subproblem::SubProblem, x::AbstractVector)
    lb = MPB.getconstrLB(subproblem.solver.lqmodel)
    ub = MPB.getconstrUB(subproblem.solver.lqmodel)
    for i in [term[1] for term in unique(term -> term[1], subproblem.masterterms)]
        lb[i] = subproblem.h[1][i]
        ub[i] = subproblem.h[2][i]
    end
    for (i,j,coeff) in subproblem.masterterms
        lb[i] += coeff*x[j]
        ub[i] += coeff*x[j]
    end
    MPB.setconstrLB!(subproblem.solver.lqmodel, lb)
    MPB.setconstrUB!(subproblem.solver.lqmodel, ub)
    update_feasibility_solver!(subproblem, lb, ub)
    subproblem.x[:] = x
    return nothing
end
function update_feasibility_solver!(::SubProblem{IgnoreFeasibility}, ::AbstractVector, ::AbstractVector)
    return nothing
end
function update_feasibility_solver!(subproblem::SubProblem{<:HandleFeasibility}, lb::AbstractVector, ub::AbstractVector)
    MPB.setconstrLB!(subproblem.feasibility_solver.lqmodel, lb)
    MPB.setconstrUB!(subproblem.feasibility_solver.lqmodel, ub)
end
update_subproblems!(subproblems::Vector{<:SubProblem}, x::AbstractVector) = map(prob -> update_subproblem!(prob,x), subproblems)

function get_solution(subproblem::SubProblem)
    return copy(subproblem.y), getredcosts(subproblem.solver), getduals(subproblem.solver), getobjval(subproblem.solver)
end

function solve(subproblem::SubProblem)
    subproblem.solver(subproblem.y)
    solvestatus = status(subproblem.solver)
    if solvestatus == :Optimal
        subproblem.y[:] = getsolution(subproblem.solver)
        return OptimalityCut(subproblem)
    elseif solvestatus == :Infeasible
        return Infeasible(subproblem)
    elseif solvestatus == :Unbounded
        return Unbounded(subproblem)
    else
        error(@sprintf("Subproblem %d was not solved properly, returned status code: %s", subproblem.id,string(solvestatus)))
    end
end

function (subproblem::SubProblem{<:HandleFeasibility})()
    subproblem.feasibility_solver(vcat(subproblem.y, rand(2*MPB.numconstr(subproblem.feasibility_solver.lqmodel))))
    w = getobjval(subproblem.feasibility_solver)
    if w > 0
        return FeasibilityCut(subproblem)
    end
    return solve(subproblem)
end
function (subproblem::SubProblem{IgnoreFeasibility})()
    return solve(subproblem)
end

function (subproblem::SubProblem)(x::AbstractVector)
    update_subproblem!(subproblem, x)
    subproblem.solver(subproblem.y)
    solvestatus = status(subproblem.solver)
    if solvestatus == :Optimal
        subproblem.y[:] = getsolution(subproblem.solver)
        return getobjval(subproblem.solver)
    elseif solvestatus == :Infeasible
        return Inf
    elseif solvestatus == :Unbounded
        return -Inf
    else
        error(@sprintf("Subproblem %d was not solved properly, returned status code: %s", subproblem.id, string(solvestatus)))
    end
end

function OptimalityCut(subproblem::SubProblem)
    λ = getduals(subproblem.solver)
    π = subproblem.π
    cols = zeros(length(subproblem.masterterms))
    vals = zeros(length(subproblem.masterterms))
    for (s,(i,j,coeff)) in enumerate(subproblem.masterterms)
        cols[s] = j
        vals[s] = -π*λ[i]*coeff
    end
    δQ = sparsevec(cols, vals, length(subproblem.x))
    q = π*getobjval(subproblem.solver)+δQ⋅subproblem.x

    return OptimalityCut(δQ, q, subproblem.id)
end

function FeasibilityCut(subproblem::SubProblem)
    λ = getduals(subproblem.feasibility_solver)
    cols = zeros(length(subproblem.masterterms))
    vals = zeros(length(subproblem.masterterms))
    for (s, (i,j,coeff)) in enumerate(subproblem.masterterms)
        cols[s] = j
        vals[s] = -λ[i]*coeff
    end
    G = sparsevec(cols,vals,length(subproblem.x))
    g = getobjval(subproblem.feasibility_solver)+G⋅subproblem.x

    return FeasibilityCut(G, g, subproblem.id)
end

Infeasible(subprob::SubProblem) = Infeasible(subprob.id)
Unbounded(subprob::SubProblem) = Unbounded(subprob.id)

function fill_submodel!(submodel::JuMP.Model, subproblem::SubProblem)
    fill_submodel!(submodel, get_solution(subproblem)...)
    return nothing
end

function fill_submodel!(submodel::JuMP.Model, x::AbstractVector, μ::AbstractVector, λ::AbstractVector, C::AbstractFloat)
    submodel.colVal = x
    submodel.redCosts = μ
    submodel.linconstrDuals = λ
    submodel.objVal = C
    submodel.objVal *= submodel.objSense == :Min ? 1 : -1
    return nothing
end
