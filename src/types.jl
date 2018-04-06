# Types #
# ========================== #
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
        generate!(stochasticprogram)
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
# ========================== #

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
function parentmodel(scenarioproblems::ScenarioProblems)
    return scenarioproblems.parent
end
function parentmodel(scenarioproblems::DScenarioProblems)
    length(scenarioproblems) > 0 || error("No remote scenario problems.")
    return fetch(scenarioproblems[1]).parent
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
