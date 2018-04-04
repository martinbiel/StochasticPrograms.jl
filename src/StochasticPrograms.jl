module StochasticPrograms

using JuMP
using MathProgBase
using MacroTools
using MacroTools: @q, postwalk

export
    StochasticProgram,
    AbstractScenarioData,
    AbstractStructuredSolver,
    AbstractStructuredModel,
    StructuredModel,
    stochastic,
    scenarioproblems,
    scenario,
    scenarios,
    probability,
    subproblem,
    subproblems,
    nscenarios,
    stage_two_model,
    outcome_model,
    eval_decision,
    @first_stage,
    @second_stage,
    WS,
    EWS,
    DEP,
    RP,
    EVPI,
    EVP,
    EV,
    EEV,
    VSS

abstract type AbstractStructuredSolver end

abstract type AbstractScenarioData end
probability(sd::AbstractScenarioData) = sd.π
function expected(::Vector{SD}) where SD <: AbstractScenarioData
   error("Expected value operation not implemented for scenariodata type: ", SD)
end

abstract type AbstractSampler{SD <: AbstractScenarioData} end
struct NullSampler{SD <: AbstractScenarioData} <: AbstractSampler{SD} end

mutable struct CommonData{D}
    data::D

    function (::Type{CommonData})(data::D) where D
        return new{D}(data)
    end
end

struct ScenarioProblems{D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    commondata::CommonData{D}
    scenariodata::Vector{SD}
    sampler::S
    problems::Vector{JuMP.Model}
    parent::JuMP.Model

    function (::Type{ScenarioProblems})(common::D,::Type{SD}) where {D,SD <: AbstractScenarioData}
        S = NullSampler{SD}
        return new{D,SD,S}(CommonData(common),Vector{SD}(),NullSampler{SD}(),Vector{JuMP.Model}(),Model(solver=JuMP.UnsetSolver()))
    end

    function (::Type{ScenarioProblems})(common::D,scenariodata::Vector{<:AbstractScenarioData}) where D
        SD = eltype(scenariodata)
        S = NullSampler{SD}
        return new{D,SD,S}(CommonData(common),scenariodata,NullSampler{SD}(),Vector{JuMP.Model}(),Model(solver=JuMP.UnsetSolver()))
    end

    function (::Type{ScenarioProblems})(common::D,sampler::AbstractSampler{SD}) where {D,SD <: AbstractScenarioData}
        S = typeof(sampler)
        return new{D,SD,S}(CommonData(common),Vector{SD}(),sampler,Vector{JuMP.Model}(),Model(solver=JuMP.UnsetSolver()))
    end
end
DScenarioProblems{D,SD,S} = Vector{RemoteChannel{Channel{ScenarioProblems{D,SD,S}}}}

function ScenarioProblems(common::D,::Type{SD},procs::Vector{Int}) where {D,SD <: AbstractScenarioData}
    if (length(procs) == 1 || nworkers() == 1) && procs[1] == 1
        return ScenarioProblems(common,SD)
    else
        isempty(procs) && error("No requested procs.")
        length(procs) <= nworkers() || error("Not enough workers to satisfy requested number of procs. There are ", nworkers(), " workers, but ", length(procs), " were requested.")

        S = NullSampler{SD}
        scenarioproblems = DScenarioProblems{D,SD,S}(length(procs))

        finished_workers = Vector{Future}(length(procs))
        for p in procs
            scenarioproblems[p-1] = RemoteChannel(() -> Channel{ScenarioProblems{D,SD,S}}(1), p)
            finished_workers[p-1] = remotecall((sp,common,SD)->put!(sp,ScenarioProblems(common,SD)),p,scenarioproblems[p-1],common,SD)
        end
        map(wait,finished_workers)
        return scenarioproblems
    end
end

function ScenarioProblems(common::D,scenariodata::Vector{SD},procs::Vector{Int}) where {D,SD <: AbstractScenarioData}
    if (length(procs) == 1 || nworkers() == 1) && procs[1] == 1
        return ScenarioProblems(common,scenariodata)
    else
        isempty(procs) && error("No requested procs.")
        length(procs) <= nworkers() || error("Not enough workers to satisfy requested number of procs. There are ", nworkers(), " workers, but ", length(procs), " were requested.")

        S = NullSampler{SD}
        scenarioproblems = DScenarioProblems{D,SD,S}(length(procs))

        (nscen,extra) = divrem(length(scenariodata),length(procs))
        if extra > 0
            nscen += 1
        end
        start = 1
        stop = nscen
        finished_workers = Vector{Future}(length(procs))
        for p in procs
            scenarioproblems[p-1] = RemoteChannel(() -> Channel{ScenarioProblems{D,SD,S}}(1), p)
            finished_workers[p-1] = remotecall((sp,common,sdata)->put!(sp,ScenarioProblems(common,sdata)),p,scenarioproblems[p-1],common,scenariodata[start:stop])
            start += nscen
            stop += nscen
            stop = min(stop,length(scenariodata))
        end
        map(wait,finished_workers)
        return scenarioproblems
    end
end

function ScenarioProblems(common::D,sampler::AbstractSampler{SD},procs::Vector{Int}) where {D,SD <: AbstractScenarioData}
    if (length(procs) == 1 || nworkers() == 1) && procs[1] == 1
        return ScenarioProblems(common,sampler)
    else
        isempty(procs) && error("No requested procs.")
        length(procs) <= nworkers() || error("Not enough workers to satisfy requested number of procs. There are ", nworkers(), " workers, but ", length(procs), " were requested.")
        S = typeof(sampler)
        scenarioproblems = DScenarioProblems{D,SD,S}(length(procs))
        finished_workers = Vector{Future}(length(procs))
        for p in procs
            scenarioproblems[p-1] = RemoteChannel(() -> Channel{ScenarioProblems{D,SD,S}}(1), p)
            finished_workers[p-1] = remotecall((sp,common,sampler)->put!(sp,ScenarioProblems(common,sampler)),p,scenarioproblems[p-1],common,sampler)
        end
        map(wait,finished_workers)
        return scenarioproblems
    end
end

struct StochasticProgramData{D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}, SP <: Union{ScenarioProblems{D,SD,S},
                                                                                                  DScenarioProblems{D,SD,S}}}
    commondata::CommonData{D}
    scenarioproblems::SP
    generator::Dict{Symbol,Function}
    problemcache::Dict{Symbol,JuMP.Model}

    function (::Type{StochasticProgramData})(common::D,::Type{SD},procs::Vector{Int}) where {D,SD <: AbstractScenarioData}
        S = NullSampler{SD}
        scenarioproblems = ScenarioProblems(common,SD,procs)
        return new{D,SD,S,typeof(scenarioproblems)}(CommonData(common),scenarioproblems,Dict{Symbol,Function}(),Dict{Symbol,JuMP.Model}())
    end

    function (::Type{StochasticProgramData})(common::D,scenariodata::Vector{<:AbstractScenarioData},procs::Vector{Int}) where D
        SD = eltype(scenariodata)
        S = NullSampler{SD}
        scenarioproblems = ScenarioProblems(common,scenariodata,procs)
        return new{D,SD,S,typeof(scenarioproblems)}(CommonData(common),scenarioproblems,Dict{Symbol,Function}(),Dict{Symbol,JuMP.Model}())
    end

    function (::Type{StochasticProgramData})(common::D,sampler::AbstractSampler{SD},procs::Vector{Int}) where {D,SD <: AbstractScenarioData}
        S = typeof(sampler)
        scenarioproblems = ScenarioProblems(common,sampler,procs)
        return new{D,SD,S,typeof(scenarioproblems)}(CommonData(common),scenarioproblems,Dict{Symbol,Function}(),Dict{Symbol,JuMP.Model}())
    end
end

StochasticProgram(::Type{SD}; solver = JuMP.UnsetSolver(), procs = workers()) where SD <: AbstractScenarioData = StochasticProgram(nothing,SD; solver = solver, procs = procs)
function StochasticProgram(common::Any,::Type{SD}; solver = JuMP.UnsetSolver(), procs = workers) where SD <: AbstractScenarioData
    stochasticprogram = JuMP.Model(solver=solver)
    stochasticprogram.ext[:SP] = StochasticProgramData(common,SD,procs)

    # Set hooks
    JuMP.setsolvehook(stochasticprogram, _solve)
    JuMP.setprinthook(stochasticprogram, _printhook)

    return stochasticprogram
end
StochasticProgram(scenariodata::Vector{<:AbstractScenarioData}; solver = JuMP.UnsetSolver(), procs = workers()) = StochasticProgram(nothing,scenariodata; solver = solver, procs = procs)
function StochasticProgram(common::Any,scenariodata::Vector{<:AbstractScenarioData}; solver = JuMP.UnsetSolver(), procs = workers())
    stochasticprogram = JuMP.Model(solver=solver)
    stochasticprogram.ext[:SP] = StochasticProgramData(common,scenariodata,procs)

    # Set hooks
    JuMP.setsolvehook(stochasticprogram, _solve)
    JuMP.setprinthook(stochasticprogram, _printhook)

    return stochasticprogram
end
StochasticProgram(sampler::AbstractSampler; solver = JuMP.UnsetSolver(), procs = workers()) = StochasticProgram(nothing,sampler; solver = solver, procs = procs)
function StochasticProgram(common::Any,sampler::AbstractSampler; solver = JuMP.UnsetSolver(), procs = workers())
    stochasticprogram = JuMP.Model(solver=solver)
    stochasticprogram.ext[:SP] = StochasticProgramData(common,sampler,procs)

    # Set hooks
    JuMP.setsolvehook(stochasticprogram, _solve)
    JuMP.setprinthook(stochasticprogram, _printhook)

    return stochasticprogram
end

function _solve(stochasticprogram::JuMP.Model; suppress_warnings=false, solver = JuMP.UnsetSolver(), kwargs...)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    if length(subproblems(stochasticprogram)) != length(scenarios(stochasticprogram))
        generate_subproblems!(stochasticprogram)
    end

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    if optimsolver isa MathProgBase.AbstractMathProgSolver
        # Standard mathprogbase solver. Fallback to solving DEP model, relying on JuMP.
        dep = DEP(stochasticprogram,optimsolver)
        status = solve(dep; kwargs...)
        fill_solution!(stochasticprogram)
        return status
    elseif optimsolver isa AbstractStructuredSolver
        # Use structured solver
        structuredmodel = StructuredModel(optimsolver,stochasticprogram; kwargs...)
        stochasticprogram.internalModel = structuredmodel
        stochasticprogram.internalModelLoaded = true
        status = optimize_structured!(structuredmodel)
        fill_solution!(structuredmodel,stochasticprogram)
        return status
    else
        error("Unknown solver object given. Aborting.")
    end
end

function _printhook(io::IO, stochasticprogram::JuMP.Model)
    print(io, "First-stage \n")
    print(io, "============== \n")
    print(io, stochasticprogram, ignore_print_hook=true)
    print(io, "Second-stage \n")
    print(io, "============== \n")
    for (id, subproblem) in enumerate(subproblems(stochasticprogram))
      @printf(io, "Subproblem %d:\n", id)
      print(io, subproblem)
      print(io, "\n")
    end
end

# Getters #
# ========================== #
function stochastic(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP]
end
function scenarioproblems(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP].scenarioproblems
end
function common(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP].commondata.data
end
function common(scenarioproblems::ScenarioProblems)
    return scenarioproblems.commondata.data
end
function scenario(scenarioproblems::ScenarioProblems{D,SD,S},i::Integer) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return scenarioproblems.scenariodata[i]
end
function scenario(scenarioproblems::DScenarioProblems{D,SD,S},i::Integer) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    j = 0
    for p in 1:length(scenarioproblems)
        n = remotecall_fetch((sp)->length(fetch(sp).scenariodata),p+1,scenarioproblems[p])
        if i <= n+j
            return remotecall_fetch((sp,i)->fetch(sp).scenariodata[i],p+1,scenarioproblems[p],i-j)
        end
        j += n
    end
    throw(BoundsError(scenarioproblems,i))
end
function scenario(stochasticprogram::JuMP.Model,i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return scenario(scenarioproblems(stochasticprogram),i)
end
function scenarios(scenarioproblems::ScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return scenarioproblems.scenariodata
end
function scenarios(scenarioproblems::DScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    scenarios = Vector{SD}()
    for p in 1:length(scenarioproblems)
        append!(scenarios,remotecall_fetch((sp)->fetch(sp).scenariodata,
                                           p+1,
                                           scenarioproblems[p]))
    end
    return scenarios
end
function scenarios(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return scenarios(scenarioproblems(stochasticprogram))
end
function probability(stochasticprogram::JuMP.Model,i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return probability(scenario(stochasticprogram,i))
end
function has_generator(stochasticprogram::JuMP.Model,key::Symbol)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return haskey(stochasticprogram.ext[:SP].generator,key)
end
function generator(stochasticprogram::JuMP.Model,key::Symbol)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return stochasticprogram.ext[:SP].generator[key]
end
function subproblem(scenarioproblems::ScenarioProblems{D,SD,S},i::Integer) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return scenarioproblems.problems[i]
end
function subproblem(scenarioproblems::DScenarioProblems{D,SD,S},i::Integer) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    j = 0
    for p in 1:length(scenarioproblems)
        n = remotecall_fetch((sp)->length(fetch(sp).scenariodata),p+1,scenarioproblems[p])
        if i <= n+j
            return remotecall_fetch((sp,i)->fetch(sp).problems[i],p+1,scenarioproblems[p],i-j)
        end
        j += n
    end
    throw(BoundsError(scenarioproblems,i))
end
function subproblem(stochasticprogram::JuMP.Model,i::Integer)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return subproblem(scenarioproblems(stochasticprogram),i)
end
function subproblems(scenarioproblems::ScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return scenarioproblems.problems
end
function subproblems(scenarioproblems::DScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    subproblems = Vector{JuMP.Model}()
    for p in 1:length(scenarioproblems)
        append!(subproblems,remotecall_fetch((sp)->fetch(sp).problems,
                                             p+1,
                                             scenarioproblems[p]))
    end
    return subproblems
end
function subproblems(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return subproblems(scenarioproblems(stochasticprogram))
end
function parent(scenarioproblems::ScenarioProblems)
    return scenarioproblems.parent
end
function nscenarios(scenarioproblems::ScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return length(scenarioproblems.problems)
end
function nscenarios(scenarioproblems::DScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return sum([remotecall_fetch((sp) -> length(fetch(sp).problems),
                                 p+1,
                                 scenarioproblems[p]) for p in 1:length(scenarioproblems)])
end
function nscenarios(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    return nscenarios(scenarioproblems(stochasticprogram))
end
problemcache(stochasticprogram::JuMP.Model) = stochasticprogram.ext[:SP].problemcache
# ========================== #

# Base overloads
# ========================== #
function Base.push!(sp::ScenarioProblems{D,SD},sdata::SD) where {D,SD <: AbstractScenarioData}
    push!(sp.scenariodata,sdata)
end
function Base.push!(sp::DScenarioProblems{D,SD},sdata::SD) where {D,SD <: AbstractScenarioData}
    p = rand(1:length(sp))
    remotecall_fetch((sp,sdata) -> push!(fetch(sp).scenariodata,sdata),
                     p+1,
                     sp[p],
                     sdata)
end
function Base.push!(stochasticprogram::JuMP.Model,sdata::AbstractScenarioData)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    push!(stochastic(stochasticprogram).scenarioproblems,sdata)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
function Base.append!(sp::ScenarioProblems{D,SD},sdata::Vector{SD}) where {D,SD <: AbstractScenarioData}
    append!(sp.scenariodata,sdata)
end
function Base.append!(sp::DScenarioProblems{D,SD},sdata::Vector{SD}) where {D,SD <: AbstractScenarioData}
    p = rand(1:length(sp))
    remotecall_fetch((sp,sdata) -> append!(fetch(sp).scenariodata,sdata),
                     p+1,
                     sp[p],
                     sdata)
end
function Base.append!(stochasticprogram::JuMP.Model,sdata::Vector{<:AbstractScenarioData})
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    append!(stochastic(stochasticprogram).scenarioproblems,sdata)
    invalidate_cache!(stochasticprogram)
    return stochasticprogram
end
# ========================== #

# Problem generation #
# ========================== #
function stage_one_model(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:first_stage) || error("First-stage problem not defined in stochastic program. Use @first_stage when defining stochastic program. Aborting.")
    stage_one_model = Model(solver=JuMP.UnsetSolver())
    generator(stochasticprogram,:first_stage)(stage_one_model,common(stochasticprogram))
    return stage_one_model
end

function _stage_two_model(generator::Function,common::Any,scenario::AbstractScenarioData,parent::JuMP.Model)
    stage_two_model = Model(solver=JuMP.UnsetSolver())
    generator(stage_two_model,common,scenario,parent)
    return stage_two_model
end
function stage_two_model(stochasticprogram::JuMP.Model,scenario::AbstractScenarioData)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Use @second_stage when defining stochastic program. Aborting.")
    generator(stochasticprogram,:second_stage)(stage_two_model,common(stochasticprogram),scenario,stochasticprogram)
    return _stage_two_model(generator(stochasticprogram,:second_stage),common(stochasticprogram),scenario,stochasticprogram)
end

function generate_parent!(scenarioproblems::ScenarioProblems{D,SD},generator::Function) where {D,SD <: AbstractScenarioData}
    generator(parent(scenarioproblems),common(scenarioproblems))
    nothing
end
function generate_parent!(scenarioproblems::DScenarioProblems{D,SD},generator::Function) where {D,SD <: AbstractScenarioData}
    finished_workers = Vector{Future}(length(scenarioproblems))
    for p in 1:length(scenarioproblems)
        finished_workers[p] = remotecall((sp,generator)->generate_parent!(fetch(sp),generator),p+1,scenarioproblems[p],generator)
    end
    map(wait,finished_workers)
    nothing
end

function generate_stage_one!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:first_stage) && has_generator(stochasticprogram,:first_stage_vars) || error("First-stage problem not defined in stochastic program. Use @first_stage when defining stochastic program. Aborting.")

    generator(stochasticprogram,:first_stage)(stochasticprogram,common(stochasticprogram))
    generate_parent!(scenarioproblems(stochasticprogram),generator(stochasticprogram,:first_stage_vars))
    nothing
end

function generate_stage_two!(scenarioproblems::ScenarioProblems{D,SD},generator::Function) where {D,SD <: AbstractScenarioData}
    for i in nscenarios(scenarioproblems)+1:length(scenarioproblems.scenariodata)
        push!(scenarioproblems.problems,_stage_two_model(generator,common(scenarioproblems),scenario(scenarioproblems,i),parent(scenarioproblems)))
    end
    nothing
end
function generate_stage_two!(scenarioproblems::DScenarioProblems{D,SD},generator::Function) where {D,SD <: AbstractScenarioData}
    finished_workers = Vector{Future}(length(scenarioproblems))
    for p in 1:length(scenarioproblems)
        finished_workers[p] = remotecall((sp,generator)->generate_stage_two!(fetch(sp),generator),p+1,scenarioproblems[p],generator)
    end
    map(wait,finished_workers)
    nothing
end
function generate_stage_two!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Use @second_stage when defining stochastic program. Aborting.")
    generate_stage_two!(scenarioproblems(stochasticprogram),generator(stochasticprogram,:second_stage))
    nothing
end

function _outcome_model(stage_one_generator::Function,
                        stage_two_generator::Function,
                        common::Any,
                        scenario::AbstractScenarioData,
                        x::AbstractVector,
                        solver::MathProgBase.AbstractMathProgSolver)
    outcome_model = Model(solver = solver)
    stage_one_generator(outcome_model,common)
    for obj in values(outcome_model.objDict)
        if isa(obj,JuMP.Variable)
            val = x[obj.col]
            outcome_model.colCat[obj.col] = :Fixed
            outcome_model.colVal[obj.col] = val
            outcome_model.colLower[obj.col] = val
            outcome_model.colUpper[obj.col] = val
        elseif isa(obj,JuMP.JuMPArray{JuMP.Variable})
            for var in obj.innerArray
                val = x[var.col]
                outcome_model.colCat[var.col] = :Fixed
                outcome_model.colVal[var.col] = val
                outcome_model.colLower[var.col] = val
                outcome_model.colUpper[var.col] = val
            end
        else
            continue
        end
    end
    stage_two_generator(outcome_model,common,scenario,outcome_model)

    return outcome_model
end
function outcome_model(stochasticprogram::JuMP.Model,scenario::AbstractScenarioData,x::AbstractVector,solver::MathProgBase.AbstractMathProgSolver)
    has_generator(stochasticprogram,:first_stage_vars) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    return _outcome_model(generator(stochasticprogram,:first_stage_vars),generator(stochasticprogram,:second_stage),common(stochasticprogram),scenario,x,solver)
end
# ========================== #

# Problem evaluation #
# ========================== #
function _eval_first_stage(stochasticprogram::JuMP.Model,x::AbstractVector)
    return eval_objective(stochasticprogram.obj,x)
end

function _eval_second_stage(stochasticprogram::JuMP.Model,x::AbstractVector,scenario::AbstractScenarioData,solver::MathProgBase.AbstractMathProgSolver)
    outcome = outcome_model(stochasticprogram,scenario,x,solver)
    solve(outcome)

    return probability(scenario)*getobjectivevalue(outcome)
end

function _eval_second_stages(stochasticprogram::StochasticProgramData{D,SD,S,ScenarioProblems{D,SD,S}},
                             x::AbstractVector,
                             solver::MathProgBase.AbstractMathProgSolver) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return sum([begin
                outcome = _outcome_model(stochasticprogram.generator[:first_stage_vars],
                                         stochasticprogram.generator[:second_stage],
                                         common(stochasticprogram.scenarioproblems),
                                         scenario,
                                         x,
                                         solver)
                solve(outcome)
                probability(scenario)*getobjectivevalue(outcome)
                end for scenario in scenarios(stochasticprogram.scenarioproblems)])
end

function _eval_second_stages(stochasticprogram::StochasticProgramData{D,SD,S,DScenarioProblems{D,SD,S}},
                             x::AbstractVector,
                             solver::MathProgBase.AbstractMathProgSolver) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    finished_workers = Vector{Future}(length(stochasticprogram.scenarioproblems))
    for p in 1:length(stochasticprogram.scenarioproblems)
        finished_workers[p] = remotecall((sp,stage_one_generator,stage_two_generator,x,solver)->begin
                                         scenarioproblems = fetch(sp)
                                         isempty(scenarioproblems.scenariodata) && return zero(eltype(x))
                                         return sum([begin
                                                     outcome = _outcome_model(stage_one_generator,
                                                                              stage_two_generator,
                                                                              common(scenarioproblems),
                                                                              scenario,
                                                                              x,
                                                                              solver)
                                                     solve(outcome)
                                                     probability(scenario)*getobjectivevalue(outcome)
                                                     end for scenario in scenarioproblems.scenariodata])
                                         end,
                                         p+1,
                                         stochasticprogram.scenarioproblems[p],
                                         stochasticprogram.generator[:first_stage_vars],
                                         stochasticprogram.generator[:second_stage],
                                         x,
                                         solver)
    end
    map(wait,finished_workers)
    return sum(fetch.(finished_workers))
end

function _eval(stochasticprogram::JuMP.Model,x::AbstractVector,solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    length(x) == stochasticprogram.numCols || error("Incorrect length of given decision vector, has ",length(x)," should be ",stochasticprogram.numCols)
    all(.!(isnan.(x))) || error("Given decision vector has NaN elements")

    val = _eval_first_stage(stochasticprogram,x)
    val += _eval_second_stages(stochastic(stochasticprogram),x,solver)

    return val
end

function eval_decision(stochasticprogram::JuMP.Model,x::AbstractVector; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot evaluate decision without a solver.")
    end

    return _eval(stochasticprogram,x,optimsolver)
end
# ========================== #

# SP Constructs #
# ========================== #
function _WS(stage_one_generator::Function,
             stage_two_generator::Function,
             common::Any,
             scenario::AbstractScenarioData,
             solver::MathProgBase.AbstractMathProgSolver)
    ws_model = Model(solver = solver)
    stage_one_generator(ws_model,common)
    ws_obj = copy(ws_model.obj)
    stage_two_generator(ws_model,common,scenario,ws_model)
    append!(ws_obj,ws_model.obj)
    ws_model.obj = ws_obj

    return ws_model
end

WS(stochasticprogram::JuMP.Model,scenario::AbstractScenarioData) = WS(stochasticprogram,scenario,JuMP.UnsetSolver())
function WS(stochasticprogram::JuMP.Model, scenario::AbstractScenarioData, solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot create WS model without a solver.")
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    return _WS(generator(stochasticprogram,:first_stage),generator(stochasticprogram,:second_stage),common(stochasticprogram),scenario,optimsolver)
end

function _EWS(stochasticprogram::StochasticProgramData{D,SD,S,ScenarioProblems{D,SD,S}},
              solver::MathProgBase.AbstractMathProgSolver) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return sum([begin
                ws = _WS(stochasticprogram.generator[:first_stage],
                         stochasticprogram.generator[:second_stage],
                         common(stochasticprogram.scenarioproblems),
                         scenario,
                         solver)
                solve(ws)
                probability(scenario)*getobjectivevalue(ws)
                end for scenario in scenarios(stochasticprogram.scenarioproblems)])
end

function _EWS(stochasticprogram::StochasticProgramData{D,SD,S,DScenarioProblems{D,SD,S}},
              solver::MathProgBase.AbstractMathProgSolver) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    finished_workers = Vector{Future}(length(stochasticprogram.scenarioproblems))
    for p in 1:length(stochasticprogram.scenarioproblems)
        finished_workers[p] = remotecall((sp,stage_one_generator,stage_two_generator,solver)->begin
                                         scenarioproblems = fetch(sp)
                                         isempty(scenarioproblems.scenariodata) && return 0.0
                                         return sum([begin
                                                     ws = _WS(stage_one_generator,
                                                              stage_two_generator,
                                                              common(scenarioproblems),
                                                              scenario,
                                                              solver)
                                                     solve(ws)
                                                     probability(scenario)*getobjectivevalue(ws)
                                                     end for scenario in scenarioproblems.scenariodata])
                                         end,
                                         p+1,
                                         stochasticprogram.scenarioproblems[p],
                                         stochasticprogram.generator[:first_stage],
                                         stochasticprogram.generator[:second_stage],
                                         solver)
    end
    map(wait,finished_workers)
    return sum(fetch.(finished_workers))
end

function EWS(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end

    # Solve all possible WS models and compute EWS
    return _EWS(stochastic(stochasticprogram),optimsolver)
end

DEP(stochasticprogram::JuMP.Model) = DEP(stochasticprogram,JuMP.UnsetSolver())
function DEP(stochasticprogram::JuMP.Model, solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:dep)
        return cache[:dep]
    end
    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end
    # Abort at this stage if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot create new DEP model without a solver.")
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    # Define first-stage problem
    dep_model = Model(solver = optimsolver)
    generator(stochasticprogram,:first_stage)(dep_model,common(stochasticprogram))
    dep_obj = copy(dep_model.obj)

    # Define second-stage problems, renaming variables according to scenario.
    visited_objs = collect(keys(dep_model.objDict))
    for (i,scenario) in enumerate(scenarios(stochasticprogram))
        generator(stochasticprogram,:second_stage)(dep_model,common(stochasticprogram),scenario,dep_model)
        append!(dep_obj,probability(scenario)*dep_model.obj)
        for (objkey,obj) ∈ dep_model.objDict
            if objkey ∉ visited_objs
                newkey = if (isa(obj,JuMP.Variable))
                    varname = @sprintf("%s_%d",dep_model.colNames[obj.col],i)
                    dep_model.colNames[obj.col] = varname
                    dep_model.colNamesIJulia[obj.col] = varname
                    newkey = Symbol(varname)
                elseif isa(obj,JuMP.ConstraintRef)
                    arrayname = @sprintf("%s_%d",objkey,i)
                    newkey = Symbol(arrayname)
                elseif isa(obj,JuMP.JuMPArray)
                    newkey = if isa(obj,JuMP.JuMPArray{JuMP.ConstraintRef})
                        arrayname = @sprintf("%s_%d",objkey,i)
                        newkey = Symbol(arrayname)
                    else
                        JuMP.fill_var_names(JuMP.REPLMode, dep_model.colNames, obj)
                        arrayname = @sprintf("%s_%d",dep_model.varData[obj].name,i)
                        newkey = Symbol(arrayname)
                        dep_model.varData[obj].name = newkey
                        for var in obj.innerArray
                            splitname = split(dep_model.colNames[var.col],"[")
                            varname = @sprintf("%s_%d[%s",splitname[1],i,splitname[2])
                            dep_model.colNames[var.col] = varname
                            dep_model.colNamesIJulia[var.col] = varname
                        end
                        newkey
                    end
                 else
                    continue
                end
                dep_model.objDict[newkey] = obj
                delete!(dep_model.objDict,objkey)
                push!(visited_objs,newkey)
            end
        end
    end
    dep_model.obj = dep_obj

    # Cache dep model
    cache[:dep] = dep_model

    return dep_model
end

function RP(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end

    # Solve EVP model
    solve(stochasticprogram)

    return getobjectivevalue(stochasticprogram)
end

function EVPI(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end

    # Solve DEP model
    solve(stochasticprogram)
    evpi = getobjectivevalue(stochasticprogram)

    # Solve all possible WS models
    evpi -= EWS(stochasticprogram)

    return evpi
end

EVP(stochasticprogram::JuMP.Model) = EVP(stochasticprogram,JuMP.UnsetSolver())
function EVP(stochasticprogram::JuMP.Model, solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:evp)
        return cache[:evp]
    end
    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end
    # Abort at this stage if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot create new EVP model without a solver.")
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    ev_model = Model(solver = optimsolver)
    generator(stochasticprogram,:first_stage)(ev_model,common(stochasticprogram))
    ev_obj = copy(ev_model.obj)
    generator(stochasticprogram,:second_stage)(ev_model,common(stochasticprogram),expected(scenarios(stochasticprogram)),ev_model)
    append!(ev_obj,ev_model.obj)
    ev_model.obj = ev_obj

    # Cache evp model
    cache[:evp] = ev_model

    return ev_model
end

function EV(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end

    # Solve EVP model
    evp = EVP(stochasticprogram, solver)
    solve(evp)

    return getobjectivevalue(evp)
end

function EEV(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot evaluate decision without a solver.")
    end

    # Solve EVP model
    evp = EVP(stochasticprogram,optimsolver)
    solve(evp)

    eev = _eval(stochasticprogram,evp.colVal[1:stochasticprogram.numCols],optimsolver)

    return eev
end

function VSS(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot evaluate decision without a solver.")
    end

    # Solve EVP and determine EEV
    vss = EEV(stochasticprogram; solver = optimsolver)

    # Solve DEP model
    solve(stochasticprogram)
    vss -= getobjectivevalue(stochasticprogram)

    return vss
end
# ========================== #

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

# Creation macros #
# ========================== #
macro first_stage(args)
    @capture(args, model_Symbol = modeldef_) || error("Invalid syntax. Expected stochasticprogram = begin JuMPdef end")
    vardefs = Expr(:block)
    for line in modeldef.args
        (@capture(line, @constraint(m_Symbol,constdef__)) || @capture(line, @objective(m_Symbol,objdef__))) && continue
        push!(vardefs.args,line)
    end
    code = @q begin
        $(esc(model)).ext[:SP].generator[:first_stage_vars] = ($(esc(:model))::JuMP.Model,$(esc(:commondata))) -> begin
            $(esc(vardefs))
	    return $(esc(:model))
        end
        $(esc(model)).ext[:SP].generator[:first_stage] = ($(esc(:model))::JuMP.Model,$(esc(:commondata))) -> begin
            $(esc(modeldef))
	    return $(esc(:model))
        end
        generate_stage_one!($(esc(model)))
    end
    return code
end

macro second_stage(args)
    @capture(args, model_Symbol = modeldef_) || error("Invalid syntax. Expected stochasticprogram = begin JuMPdef end")
    def = postwalk(modeldef) do x
        @capture(x, @decision args__) || return x
        code = Expr(:block)
        for var in args
            varkey = Meta.quot(var)
            push!(code.args,:($var = parent.objDict[$varkey]))
        end
        return code
    end

    code = @q begin
        $(esc(model)).ext[:SP].generator[:second_stage] = ($(esc(:model))::JuMP.Model,$(esc(:commondata)),$(esc(:scenario))::AbstractScenarioData,$(esc(:parent))::JuMP.Model) -> begin
            $(esc(def))
	    return $(esc(:model))
        end
        generate_stage_two!($(esc(model)))
        nothing
    end
    return prettify(code)
end
# ========================== #

# Structured solver interface
# ========================== #
abstract type AbstractStructuredSolver end
abstract type AbstractStructuredModel end

function StructuredModel(solver::AbstractStructuredSolver,stochasticprogram::JuMP.Model)
    throw(MethodError(StructuredModel,(solver,stochasticprogram)))
end

function optimize_structured!(structuredmodel::AbstractStructuredModel)
    throw(MethodError(optimize!,structuredmodel))
end

function fill_solution!(structuredmodel::AbstractStructuredModel,stochasticprogram::JuMP.Model)
    throw(MethodError(optimize!,structuredmodel))
end

end # module
