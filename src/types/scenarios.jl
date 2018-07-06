mutable struct ScenarioData{D} <: AbstractScenarioData
    π::Float64
    data::D

    function (::Type{ScenarioData})(data::D) where D
        return new{D}(data)
    end
end

struct ScenarioProblems{D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    stage::Stage{D}
    scenariodata::Vector{SD}
    sampler::S
    problems::Vector{JuMP.Model}
    parent::JuMP.Model

    function (::Type{ScenarioProblems})(stage::Integer,stagedata::D,::Type{SD}) where {D,SD <: AbstractScenarioData}
        S = NullSampler{SD}
        return new{D,SD,S}(Stage(stage,stagedata),Vector{SD}(),NullSampler{SD}(),Vector{JuMP.Model}(),Model(solver=JuMP.UnsetSolver()))
    end

    function (::Type{ScenarioProblems})(stage::Integer,stagedata::D,scenariodata::Vector{<:AbstractScenarioData}) where D
        SD = eltype(scenariodata)
        S = NullSampler{SD}
        return new{D,SD,S}(Stage(stage,stagedata),scenariodata,NullSampler{SD}(),Vector{JuMP.Model}(),Model(solver=JuMP.UnsetSolver()))
    end

    function (::Type{ScenarioProblems})(stage::Integer,stagedata::D,sampler::AbstractSampler{SD}) where {D,SD <: AbstractScenarioData}
        S = typeof(sampler)
        return new{D,SD,S}(Stage(stage,stagedata),Vector{SD}(),sampler,Vector{JuMP.Model}(),Model(solver=JuMP.UnsetSolver()))
    end
end
DScenarioProblems{D,SD,S} = Vector{RemoteChannel{Channel{ScenarioProblems{D,SD,S}}}}

function ScenarioProblems(stage::Integer,stagedata::D,::Type{SD},procs::Vector{Int}) where {D,SD <: AbstractScenarioData}
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
            finished_workers[p-1] = remotecall((sp,stage,stagedata,SD)->put!(sp,ScenarioProblems(stage,stagedata,SD)),p,scenarioproblems[p-1],stage,stagedata,SD)
        end
        map(wait,finished_workers)
        return scenarioproblems
    end
end

function ScenarioProblems(stage::Integer,stagedata::D,scenariodata::Vector{SD},procs::Vector{Int}) where {D,SD <: AbstractScenarioData}
    if (length(procs) == 1 || nworkers() == 1) && procs[1] == 1
        return ScenarioProblems(stage,stagedata,scenariodata)
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
            finished_workers[p-1] = remotecall((sp,stage,stagedata,sdata)->put!(sp,ScenarioProblems(stage,stagedata,sdata)),p,scenarioproblems[p-1],stage,stagedata,scenariodata[start:stop])
            start += nscen
            stop += nscen
            stop = min(stop,length(scenariodata))
        end
        map(wait,finished_workers)
        return scenarioproblems
    end
end

function ScenarioProblems(stage::Integer,stagedata::D,sampler::AbstractSampler{SD},procs::Vector{Int}) where {D,SD <: AbstractScenarioData}
    if (length(procs) == 1 || nworkers() == 1) && procs[1] == 1
        return ScenarioProblems(stage,stagedata,sampler)
    else
        isempty(procs) && error("No requested procs.")
        length(procs) <= nworkers() || error("Not enough workers to satisfy requested number of procs. There are ", nworkers(), " workers, but ", length(procs), " were requested.")
        S = typeof(sampler)
        scenarioproblems = DScenarioProblems{D,SD,S}(length(procs))
        finished_workers = Vector{Future}(length(procs))
        for p in procs
            scenarioproblems[p-1] = RemoteChannel(() -> Channel{ScenarioProblems{D,SD,S}}(1), p)
            finished_workers[p-1] = remotecall((sp,stage,stagedata,sampler)->put!(sp,ScenarioProblems(stage,stagedata,sampler)),p,scenarioproblems[p-1],stage,stagedata,sampler)
        end
        map(wait,finished_workers)
        return scenarioproblems
    end
end

# Getters #
# ========================== #
function stage(scenarioproblems::ScenarioProblems)
    return scenarioproblems.stage.stage
end
function stage(scenarioproblems::DScenarioProblems)
    length(scenarioproblems) > 0 || error("No remote scenario problems.")
    return fetch(scenarioproblems[1]).stage.stage
end
function stage_data(scenarioproblems::ScenarioProblems)
    return scenarioproblems.stage.data
end
function stage_data(scenarioproblems::DScenarioProblems)
    length(scenarioproblems) > 0 || error("No remote scenario problems.")
    return fetch(scenarioproblems[1]).stage.data
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
# ========================== #
