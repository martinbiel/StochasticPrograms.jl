# Utility #
# ========================== #
function eval_objective(objective::JuMP.GenericQuadExpr,x::AbstractVector)
    aff = objective.aff
    val = aff.constant
    for (i,var) in enumerate(aff.vars)
        val += aff.coeffs[i]*x[var.col]
    end

    return val
end

function fill_solution!(stochasticprogram::JuMP.Model)
    dep = DEP(stochasticprogram)

    # First stage
    nrows, ncols = length(stochasticprogram.linconstr), stochasticprogram.numCols
    stochasticprogram.objVal = dep.objVal
    stochasticprogram.colVal = dep.colVal[1:ncols]
    stochasticprogram.redCosts = dep.redCosts[1:ncols]
    stochasticprogram.linconstrDuals = dep.linconstrDuals[1:nrows]

    # Second stage
    for (i,subproblem) in enumerate(subproblems(stochasticprogram))
        snrows, sncols = length(subproblem.linconstr), subproblem.numCols
        subproblem.colVal = dep.colVal[ncols+1:ncols+sncols]
        subproblem.redCosts = dep.redCosts[ncols+1:ncols+sncols]
        subproblem.linconstrDuals = dep.linconstrDuals[nrows+1:nrows:snrows]
        subproblem.objVal = eval_objective(subproblem.obj,subproblem.colVal)
        ncols += sncols
        nrows += snrows
    end
    nothing
end

function invalidate_cache!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    cache = problemcache(stochasticprogram)
    delete!(cache,:evp)
    delete!(cache,:dep)
end
# ========================== #
