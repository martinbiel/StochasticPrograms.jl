# Utility
# ------------------------------------------------------------
function add_penalty!(lshaped::AbstractLShapedSolver, model::MPB.AbstractLinearQuadraticModel, c::AbstractVector, α::Real, ξ::AbstractVector, ::Val{true})
    nt = nthetas(lshaped)
    ncols = decision_length(lshaped.stochasticprogram)
    tidx = ncols+nt+1
    j = lshaped.regularizer.data.regularizerindex
    if j != -1
        MPB.delconstrs!(model, collect(j:j+2*ncols-1))
    end
    for i in 1:ncols
        MPB.addconstr!(model, [i,tidx], [-α,1], -α*ξ[i], Inf)
        MPB.addconstr!(model, [i,tidx], [-α,-1], -Inf, -α*ξ[i])
    end
    lshaped.regularizer.data.regularizerindex = first_stage_nconstraints(lshaped.stochasticprogram)+ncuts(lshaped)+1
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

function solve_linearized_problem!(lshaped::AbstractLShapedSolver, solver::LQSolver, regularizer::AbstractRegularization)
    push!(lshaped.mastervector, norm(lshaped.x-regularizer.ξ, Inf))
    solver(lshaped.mastervector)
    pop!(lshaped.mastervector)
    return nothing
end
