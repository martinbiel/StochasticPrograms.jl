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
        wncols = remotecall_fetch((sp)->sum([s.numCols::Int for s in fetch(sp).problems]),w,scenarioproblems[w-1])
        wnrows = remotecall_fetch((sp)->sum([length(s.linconstr)::Int for s in fetch(sp).problems]),w,scenarioproblems[w-1])
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
    map(wait,active_workers)
end

function calculate_objective_value(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    objective_value = eval_objective(stochasticprogram.obj,stochasticprogram.colVal)
    objective_value += calculate_subobjectives(scenarioproblems(stochasticprogram))
    return objective_value
end
function calculate_subobjectives(scenarioproblems::ScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return sum([(probability(scenario)*eval_objective(subprob.obj,subprob.colVal))::Float64 for (scenario,subprob) in zip(scenarios(scenarioproblems),subproblems(scenarioproblems))])
end
function calculate_subobjectives(scenarioproblems::DScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return sum([remotecall_fetch((sp) -> calculate_subobjectives(fetch(sp)),
                                 w,
                                 scenarioproblems[w-1]) for w in workers()])
end

function invalidate_cache!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    cache = problemcache(stochasticprogram)
    delete!(cache,:evp)
    delete!(cache,:dep)
    return nothing
end

function remove_subproblems!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    remove_subproblems!(stochasticprogram.ext[:SP].scenarioproblems)
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
        n = remotecall_fetch((sp)->length(fetch(sp).problems),w,scenarioproblems[w-1])
        if i <= n+j
            return remotecall_fetch((sp,idx) -> masterterms(fetch(sp),idx),w,scenarioproblems[w-1],i-j)
        end
        j += n
    end
    throw(BoundsError(scenarioproblems,i))
end

function transfer_model!(dest::StochasticProgram, src::StochasticProgram)
    empty!(dest.generator)
    merge!(dest.generator, src.generator)
    return dest
end

function transfer_scenarios!(dest::StochasticProgram, src::StochasticProgram)
    add_scenarios!(dest, scenarios(src))
    return dest
end

function Base.copy!(dest::SP, src::SP) where {SP <: Union{ScenarioProblems,DScenarioProblems}}
    set_stage_data!(dest, stage_data(src))
    add_scenarios!(dest, scenarios(src))
end

function Base.copy!(dest::SP, src::SP) where SP <: StochasticProgram
    dest.first_stage.data = src.first_stage.data
    dest.spsolver.solver = src.spsolver.solver
    transfer_model!(dest, src)
    if haskey(src.problemcache, :stage_1)
        dest.problemcache[:stage_1] = JuMP.Model()
    end
    copy!(dest.scenarioproblems, src.scenarioproblems)
    generate_parent!(dest.scenarioproblems, dest.generator[:stage_1_vars], dest.first_stage.data)
end

function Base.copy(src::StochasticProgram{D1,D2,SD,S}) where {D1, D2, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    dest = StochasticProgram(src.first_stage.data, stage_data(src.scenarioproblems), sampler(src), workers())
    dest.spsolver.solver = src.spsolver.solver
    empty!(dest.generator)
    merge!(dest.generator, src.generator)
    if haskey(src.problemcache, :stage_1)
        dest.problemcache[:stage_1] = JuMP.Model()
    end
    add_scenarios!(dest.scenarioproblems, scenarios(src.scenarioproblems))
    generate_parent!(dest.scenarioproblems, dest.generator[:stage_1_vars], dest.first_stage.data)
    return dest
end

function Base.copy(src::StochasticProgram{D1,D2,SD,NullSampler{SD}}) where {D1, D2, SD <: AbstractScenarioData}
    dest = StochasticProgram(src.first_stage.data, stage_data(src.scenarioproblems), SD, workers())
    dest.spsolver.solver = src.spsolver.solver
    empty!(dest.generator)
    merge!(dest.generator, src.generator)
    if haskey(src.problemcache, :stage_1)
        dest.problemcache[:stage_1] = JuMP.Model()
    end
    add_scenarios!(dest.scenarioproblems, scenarios(src.scenarioproblems))
    generate_parent!(dest.scenarioproblems, dest.generator[:stage_1_vars], dest.first_stage.data)
    return dest
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
