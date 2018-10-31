# Utility #
# ========================== #
function eval_objective(objective::JuMP.GenericQuadExpr, x::AbstractVector)
    aff = objective.aff
    val = aff.constant
    for (i,var) in enumerate(aff.vars)
        val += aff.coeffs[i]*x[var.col]
    end
    return val
end

function fill_solution!(stochasticprogram::StochasticProgram)
    dep = DEP(stochasticprogram)
    # First stage
    first_stage = get_stage_one(stochasticprogram)
    nrows, ncols = length(first_stage.linconstr), first_stage.numCols
    first_stage.objVal = dep.objVal
    first_stage.colVal = dep.colVal[1:ncols]
    first_stage.redCosts = dep.redCosts[1:ncols]
    first_stage.linconstrDuals = dep.linconstrDuals[1:nrows]
    # Second stages
    fill_solution!(scenarioproblems(stochasticprogram), dep.colVal[ncols+1:end], dep.redCosts[ncols+1:end], dep.linconstrDuals[nrows+1:end])
    nothing
end
function fill_solution!(scenarioproblems::ScenarioProblems{D,SD,S}, x::AbstractVector, μ::AbstractVector, λ::AbstractVector) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    cbegin = 0
    rbegin = 0
    for (i,subproblem) in enumerate(subproblems(scenarioproblems))
        snrows, sncols = length(subproblem.linconstr), subproblem.numCols
        subproblem.colVal = x[cbegin+1:cbegin+sncols]
        subproblem.redCosts = μ[cbegin+1:cbegin+sncols]
        subproblem.linconstrDuals = λ[rbegin+1:rbegin+snrows]
        subproblem.objVal = eval_objective(subproblem.obj,subproblem.colVal)
        cbegin += sncols
        rbegin += snrows
    end
end
function fill_solution!(scenarioproblems::DScenarioProblems{D,SD,S}, x::AbstractVector, μ::AbstractVector, λ::AbstractVector) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    cbegin = 0
    rbegin = 0
    active_workers = Vector{Future}(undef,nworkers())
    for w in workers()
        wncols = remotecall_fetch((sp)->sum([s.numCols::Int for s in fetch(sp).problems]), w, scenarioproblems[w-1])
        wnrows = remotecall_fetch((sp)->sum([length(s.linconstr)::Int for s in fetch(sp).problems]), w, scenarioproblems[w-1])
        active_workers[w-1] = remotecall((sp,x,μ,λ)->fill_solution!(fetch(sp),x,μ,λ),
                                         w,
                                         scenarioproblems[w-1],
                                         x[cbegin+1:cbegin+wncols],
                                         μ[cbegin+1:cbegin+wncols],
                                         λ[rbegin+1:rbegin+wnrows]
                                         )
        cbegin += wncols
        rbegin += wnrows
    end
    map(wait, active_workers)
end

function calculate_objective_value!(stochasticprogram::StochasticProgram)
    first_stage = get_stage_one(stochasticprogram)
    objective_value = eval_objective(first_stage.obj, first_stage.colVal)
    objective_value += calculate_subobjectives(scenarioproblems(stochasticprogram))
    first_stage.objVal = objective_value
    return nothing
end
function calculate_subobjectives(scenarioproblems::ScenarioProblems)
    return sum([(probability(scenario)*eval_objective(subprob.obj,subprob.colVal))::Float64 for (scenario,subprob) in zip(scenarios(scenarioproblems),subproblems(scenarioproblems))])
end
function calculate_subobjectives(scenarioproblems::DScenarioProblems)
    return sum([remotecall_fetch((sp) -> calculate_subobjectives(fetch(sp)),
                                 w,
                                 scenarioproblems[w-1]) for w in workers()])
end

function invalidate_cache!(stochasticprogram::StochasticProgram)
    cache = problemcache(stochasticprogram)
    delete!(cache,:evp)
    delete!(cache,:dep)
    return nothing
end

function remove_first_stage!(stochasticprogram::StochasticProgram)
    delete!(stochasticprogram.problemcache, :stage_1)
    clear_parent!(scenarioproblems(stochasticprogram))
    return nothing
end
function clear_parent!(scenarioproblems::ScenarioProblems)
    empty!(scenarioproblems.parent.colLower)
    empty!(scenarioproblems.parent.colUpper)
    empty!(scenarioproblems.parent.colVal)
    empty!(scenarioproblems.parent.colCat)
    empty!(scenarioproblems.parent.colNames)
    empty!(scenarioproblems.parent.colNamesIJulia)
    empty!(scenarioproblems.parent.objDict)
    return nothing
end
function clear_parent!(scenarioproblems::DScenarioProblems)
    for w in workers()
        remotecall_fetch((sp) -> clear_parent!(sp), w, scenarioproblems[w-1])
    end
    return nothing
end

function remove_subproblems!(stochasticprogram::StochasticProgram)
    remove_subproblems!(stochasticprogram.scenarioproblems)
    return nothing
end

function masterterms(scenarioproblems::ScenarioProblems{D,SD,S},i::Integer) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    model = scenarioproblems.problems[i]
    parent = parentmodel(scenarioproblems)
    masterterms = Vector{Tuple{Int,Int,Float64}}()
    for (i,constr) in enumerate(model.linconstr)
        for (j,var) in enumerate(constr.terms.vars)
            if var.m == parent
                push!(masterterms,(i,var.col,-constr.terms.coeffs[j]))
            end
        end
    end
    return masterterms
end

function masterterms(scenarioproblems::DScenarioProblems{D,SD,S},i::Integer) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    j = 0
    for w in workers()
        n = remotecall_fetch((sp)->length(fetch(sp).problems), w, scenarioproblems[w-1])
        if i <= n+j
            return remotecall_fetch((sp,idx) -> masterterms(fetch(sp),idx), w, scenarioproblems[w-1], i-j)
        end
        j += n
    end
    throw(BoundsError(scenarioproblems, i))
end

function Base.copy!(dest::StochasticProgram, src::StochasticProgram)
    dest.first_stage.data = src.first_stage.data
    dest.spsolver.solver = src.spsolver.solver
    empty!(dest.generator)
    merge!(dest.generator, src.generator)
    set_second_stage_data!(dest, second_stage_data(src))
    add_scenarios!(dest, scenarios(src))
    return dest
end

function Base.copy(src::StochasticProgram{D1,D2,SD,S}; procs = workers()) where {D1, D2, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    dest = StochasticProgram(src.first_stage.data, stage_data(src.scenarioproblems), sampler(src), procs)
    dest.spsolver.solver = src.spsolver.solver
    empty!(dest.generator)
    merge!(dest.generator, src.generator)
    add_scenarios!(dest.scenarioproblems, scenarios(src.scenarioproblems))
    return dest
end

function Base.copy(src::StochasticProgram{D1,D2,SD,NullSampler{SD}}; procs = workers()) where {D1, D2, SD <: AbstractScenarioData}
    dest = StochasticProgram(src.first_stage.data, stage_data(src.scenarioproblems), SD; procs = procs)
    dest.spsolver.solver = src.spsolver.solver
    empty!(dest.generator)
    merge!(dest.generator, src.generator)
    add_scenarios!(dest.scenarioproblems, scenarios(src.scenarioproblems))
    return dest
end

problemcache(stochasticprogram::StochasticProgram) = stochasticprogram.problemcache
function get_problem(stochasticprogram::StochasticProgram, key::Symbol)
    haskey(stochasticprogram.problemcache, key)|| error("No $key in problem cache")
    return stochasticprogram.problemcache[key]
end
function get_stage_one(stochasticprogram::StochasticProgram)
    haskey(stochasticprogram.problemcache, :stage_1) || error("First-stage problem not defined in stochastic program. Use @first_stage when defining stochastic program. Aborting.")
    return stochasticprogram.problemcache[:stage_1]
end

function pick_solver(stochasticprogram::StochasticProgram, supplied_solver::SPSolverType)
    if supplied_solver isa JuMP.UnsetSolver
        return stochasticprogram.spsolver.solver
    end
    return supplied_solver
end

internal_solver(solver::MathProgBase.AbstractMathProgSolver) = solver

solverstr(solver::MathProgBase.AbstractMathProgSolver) = split(split(string(solver), "Solver")[1], ".")[2]

function set_decision!(stochasticprogram::StochasticProgram, x::AbstractVector)
    first_stage = get_stage_one(stochasticprogram)
    length(x) == first_stage.numCols || error("Incorrect length of given decision vector, has ", length(x), " should be ", first_stage.numCols)
    first_stage.colVal = copy(x)
    return nothing
end
function set_first_stage_redcosts!(stochasticprogram::StochasticProgram, μ::AbstractVector)
    first_stage = get_stage_one(stochasticprogram)
    length(μ) == first_stage.numCols || error("Incorrect length of given reduced costs, has ", length(μ), " should be ", first_stage.numCols)
    first_stage.redCosts = copy(μ)
    return nothing
end
function set_first_stage_duals!(stochasticprogram::StochasticProgram, λ::AbstractVector)
    first_stage = get_stage_one(stochasticprogram)
    length(λ) == length(first_stage.linconstr) || error("Incorrect length of given constraint duals, has ", length(μ), " should be ", first_stage.numCols)
    first_stage.linconstrDuals = copy(λ)
    return nothing
end
# ========================== #
