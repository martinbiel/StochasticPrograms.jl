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

function masterterms(scenarioproblems::ScenarioProblems{D,SD,S},i::Integer) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    model = scenarioproblems.problems[i]
    parent = parentmodel(scenarioproblems)
    return [begin
              if var.m == parent
                (i,var.col,-constr.terms.coeffs[j])
              end
            end for (i,constr) in enumerate(model.linconstr) for (j,var) in enumerate(constr.terms.vars)]
end

function masterterms(scenarioproblems::DScenarioProblems{D,SD,S},i::Integer) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    j = 0
    for p in 1:length(scenarioproblems)
        n = remotecall_fetch((sp)->length(fetch(sp).scenariodata),p+1,scenarioproblems[p])
        if i <= n+j
            return remotecall_fetch((sp,idx) -> begin
                                      scenarioproblems = fetch(sp)
                                      model = scenarioproblems.problems[idx]
                                      parent = parentmodel(scenarioproblems)
                                      return [(i,var.col,-constr.terms.coeffs[j]) for (i,constr) in enumerate(model.linconstr) for (j,var) in enumerate(constr.terms.vars) if var.m == parent]
                                    end,
                                    p+1,
                                    scenarioproblems[p],
                                    i-j)
        end
        j += n
    end
    throw(BoundsError(scenarioproblems,i))
end

function transfer_model!(dest::StochasticProgramData,src::StochasticProgramData)
    empty!(dest.generator)
    copy!(dest.generator,src.generator)
end

function pick_solver(stochasticprogram,supplied_solver)
    current_solver = stochasticprogram.ext[:SP].spsolver.solver
    solver = if current_solver isa JuMP.UnsetSolver
        supplied_solver
    else
        current_solver
    end
    return solver
end

optimsolver(solver::MathProgBase.AbstractMathProgSolver) = solver
# ========================== #
