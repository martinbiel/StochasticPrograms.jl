abstract type PenaltyTerm end

@with_kw mutable struct PenaltyTermData{T <: AbstractFloat}
    index::Int = -1
end

struct Quadratic <: PenaltyTerm


end

struct Linearized <: PenaltyTerm


end

struct InfNorm <: PenaltyTerm


end

struct 1Norm <: PenaltyTerm


end

function add_penalty!(lshaped::AbstractLShapedSolver, model::MPB.AbstractLinearQuadraticModel, c::AbstractVector, α::Real, ξ::AbstractVector, ::Val{true})
    nt = nthetas(lshaped)
    ncols = decision_length(lshaped.stochasticprogram)
    tidx = ncols+nt+1
    j = lshaped.regularization.data.regularizerindex
    if j != -1
        MPB.delconstrs!(model, collect(j:j+2*ncols-1))
    end
    for i in 1:ncols
        MPB.addconstr!(model, [i,tidx], [-α,1], -α*ξ[i], Inf)
        MPB.addconstr!(model, [i,tidx], [-α,-1], -Inf, -α*ξ[i])
    end
    lshaped.regularization.data.regularizerindex = MPB.numconstr(model)-(2*ncols-1)
    return nothing
end

function add_penalty!(lshaped::AbstractLShapedSolver, model::MPB.AbstractLinearQuadraticModel, c::AbstractVector, α::Real, ξ::AbstractVector, ::Val{false})
    nt = nthetas(lshaped)
    # Linear part
    c[1:length(ξ)] -= α*ξ
    MPB.setobj!(model,c)
    # Quadratic part
    qidx = collect(1:length(ξ)+nt)
    qval = fill(α, length(ξ))
    append!(qval, zeros(nt))
    if applicable(MPB.setquadobj!, model, qidx, qidx, qval)
        MPB.setquadobj!(model, qidx, qidx, qval)
    else
        error("Setting a quadratic penalty requires a solver that handles quadratic objectives")
    end
    return nothing
end

function solve_linearized_problem!(lshaped::AbstractLShapedSolver, solver::LQSolver, regularization::AbstractRegularization)
    push!(lshaped.mastervector, norm(lshaped.x-regularization.ξ, Inf))
    solver(lshaped.mastervector)
    pop!(lshaped.mastervector)
    return nothing
end
