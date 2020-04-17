# Utility #
# ========================== #
function evaluate_objective(objective::JuMP.GenericAffExpr, x::AbstractVector)
    val = objective.constant
    for (var, coeff) in objective.terms
        val += coeff*x[index(var).value]
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
    return nothing
end
function fill_solution!(scenarioproblems::ScenarioProblems, x::AbstractVector, μ::AbstractVector, λ::AbstractVector)
    cbegin = 0
    rbegin = 0
    for (i,subproblem) in enumerate(subproblems(scenarioproblems))
        snrows, sncols = length(subproblem.linconstr), subproblem.numCols
        subproblem.colVal = x[cbegin+1:cbegin+sncols]
        subproblem.redCosts = μ[cbegin+1:cbegin+sncols]
        subproblem.linconstrDuals = λ[rbegin+1:rbegin+snrows]
        subproblem.objVal = eval_objective(subproblem.obj, subproblem.colVal)
        cbegin += sncols
        rbegin += snrows
    end
    return nothing
end
function fill_solution!(scenarioproblems::DScenarioProblems, x::AbstractVector, μ::AbstractVector, λ::AbstractVector)
    cbegin = 0
    rbegin = 0
    @sync begin
        for w in workers()
            wncols = remotecall_fetch((sp)->sum([s.numCols::Int for s in fetch(sp).problems]), w, scenarioproblems[w-1])
            wnrows = remotecall_fetch((sp)->sum([length(s.linconstr)::Int for s in fetch(sp).problems]), w, scenarioproblems[w-1])
            crange = cbegin+1:cbegin+wncols
            rrange = rbegin+1:rbegin+wnrows
            @async remotecall_fetch((sp,x,μ,λ)->fill_solution!(fetch(sp),x,μ,λ),
                                    w,
                                    scenarioproblems[w-1],
                                    x[crange],
                                    μ[crange],
                                    λ[rrange])
            cbegin += wncols
            rbegin += wnrows
        end
    end
    return nothing
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
    partial_subobjectives = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_subobjectives[i] = remotecall_fetch((sp) -> calculate_subobjectives(fetch(sp)),
                                                               w,
                                                               scenarioproblems[w-1])
        end
    end
    return sum(partial_subobjectives)
end

function invalidate_cache!(stochasticprogram::StochasticProgram)
    cache = problemcache(stochasticprogram)
    delete!(cache, :evp)
    delete!(cache, :dep)
    return nothing
end

function remove_scenarios!(stochasticprogram::StochasticProgram, s::Integer = 2)
    remove_scenarios!(scenarioproblems(stochasticprogram, s))
    return nothing
end

function remove_decision_variables!(stochasticprogram::StochasticProgram, s::Integer)
    remove_decision_variables!(scenarioproblems(stochasticprogram, s))
    return nothing
end

function remove_subproblems!(stochasticprogram::StochasticProgram, s::Integer = 2)
    remove_subproblems!(scenarioproblems(stochasticprogram, s))
    return nothing
end

function transfer_model!(dest::StochasticProgram, src::StochasticProgram)
    empty!(dest.generator)
    merge!(dest.generator, src.generator)
    return dest
end

function Base.copy(src::TwoStageStochasticProgram{T}; procs = workers(), optimizer = nothing) where T <: AbstractFloat
    opt = optimizer == nothing ? moi_optimizer(src) : optimizer
    dest = StochasticProgram(stage_parameters(src, 1), stage_parameters(src, 2), T, scenariotype(src), procs, opt)
    merge!(dest.generator, src.generator)
    generate_decision_variables!(dest)
    return dest
end

function supports_zero(types::Vector, provided_def::Bool)
    for vartype in types
        if !hasmethod(zero, (Type{vartype}, ))
            !provided_def && @warn "Zero not defined for $vartype. Cannot generate zero function."
            return false
        end
    end
    return true
end

function supports_expected(types::Vector, provided_def::Bool)
    for vartype in types
        if !hasmethod(+, (vartype, vartype))
            !provided_def && @warn "Addition not defined for $vartype. Cannot generate expectation function."
            return false
        end
        if !hasmethod(*, (Float64, vartype)) || Base.code_typed(*, (Float64, vartype))[1].second != vartype
            !provided_def && @warn "Scalar multiplication with Float64 not defined for $vartype. Cannot generate expectation function."
            return false
        end
    end
    return true
end

problemcache(stochasticprogram::StochasticProgram) = stochasticprogram.problemcache
function get_problem(stochasticprogram::StochasticProgram, key::Symbol)
    haskey(stochasticprogram.problemcache, key)|| error("No $key in problem cache")
    return stochasticprogram.problemcache[key]
end
function get_stage_one(stochasticprogram::StochasticProgram)
    haskey(stochasticprogram.problemcache, :stage_1) || error("First-stage problem not generated.")
    return stochasticprogram.problemcache[:stage_1]
end
function get_stage(stochasticprogram::StochasticProgram, stage::Integer)
    stage_key = Symbol(:stage_, stage)
    haskey(stochasticprogram.problemcache, stage_key) || error("Stage problem $stage not generated.")
    return stochasticprogram.problemcache[stage_key]
end

function pick_optimizer(stochasticprogram::StochasticProgram, supplied_optimizer)
    if supplied_optimizer == nothing
        return moi_optimizer(stochasticprogram)
    end
    return supplied_optimizer
end

internal_optimizer(optimizer::MOI.AbstractOptimizer) = optimizer

optimizerstr(optimizer::MOI.AbstractOptimizer) = JuMP._try_get_solver_name(optimizer)

typename(dtype::UnionAll) = dtype.body.name.name
typename(dtype::DataType) = dtype.name.name

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

function add_subscript(src::AbstractString, subscript::Integer)
    return @sprintf("%s%s", src, unicode_subscript(subscript))
end
add_subscript(src::Symbol, subscript::Integer) = add_subscript(String(src), subscript)

function unicode_subscript(subscript::Integer)
    if subscript < 0
        error("$subscript is negative")
    end
    return join('₀'+d for d in reverse(digits(subscript)))
end
# ========================== #
