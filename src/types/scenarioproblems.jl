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

        active_workers = Vector{Future}(length(procs))
        for p in procs
            scenarioproblems[p-1] = RemoteChannel(() -> Channel{ScenarioProblems{D,SD,S}}(1), p)
            active_workers[p-1] = remotecall((sp,stage,stagedata,SD)->put!(sp,ScenarioProblems(stage,stagedata,SD)),p,scenarioproblems[p-1],stage,stagedata,SD)
        end
        map(wait,active_workers)
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
        active_workers = Vector{Future}(length(procs))
        for p in procs
            scenarioproblems[p-1] = RemoteChannel(() -> Channel{ScenarioProblems{D,SD,S}}(1), p)
            active_workers[p-1] = remotecall((sp,stage,stagedata,sdata)->put!(sp,ScenarioProblems(stage,stagedata,sdata)),p,scenarioproblems[p-1],stage,stagedata,scenariodata[start:stop])
            start += nscen
            stop += nscen
            stop = min(stop,length(scenariodata))
        end
        map(wait,active_workers)
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
        active_workers = Vector{Future}(length(procs))
        for p in procs
            scenarioproblems[p-1] = RemoteChannel(() -> Channel{ScenarioProblems{D,SD,S}}(1), p)
            active_workers[p-1] = remotecall((sp,stage,stagedata,sampler)->put!(sp,ScenarioProblems(stage,stagedata,sampler)),p,scenarioproblems[p-1],stage,stagedata,sampler)
        end
        map(wait,active_workers)
        return scenarioproblems
    end
end

# Getters #
# ========================== #
function stage(scenarioproblems::ScenarioProblems)
    return scenarioproblems.stage.stage
end
function stage(scenarioproblems::DScenarioProblems)
    isempty(scenarioproblems) && error("No remote scenario problems.")
    return fetch(scenarioproblems[1]).stage.stage
end
function stage_data(scenarioproblems::ScenarioProblems)
    return scenarioproblems.stage.data
end
function stage_data(scenarioproblems::DScenarioProblems)
    isempty(scenarioproblems) && error("No remote scenario problems.")
    return fetch(scenarioproblems[1]).stage.data
end
function scenario(scenarioproblems::ScenarioProblems{D,SD,S},i::Integer) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return scenarioproblems.scenariodata[i]
end
function scenario(scenarioproblems::DScenarioProblems{D,SD,S},i::Integer) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    j = 0
    for w in workers()
        n = remotecall_fetch((sp)->length(fetch(sp).scenariodata),w,scenarioproblems[w-1])
        if i <= n+j
            return remotecall_fetch((sp,i)->fetch(sp).scenariodata[i],w,scenarioproblems[w-1],i-j)
        end
        j += n
    end
    throw(BoundsError(scenarioproblems,i))
end
function scenarios(scenarioproblems::ScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return scenarioproblems.scenariodata
end
function scenarios(scenarioproblems::DScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    scenarios = Vector{SD}()
    for w in workers()
        append!(scenarios,remotecall_fetch((sp)->fetch(sp).scenariodata,
                                           w,
                                           scenarioproblems[w-1]))
    end
    return scenarios
end
function expected(scenarioproblems::ScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return expected(scenarioproblems.scenariodata)
end
function expected(scenarioproblems::DScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    partial_expecations = Vector{Future}()
    for w in workers()
        push!(partial_expecations,remotecall((sp) -> expected(fetch(sp)),w,scenarioproblems[w-1]))
    end
    map(wait,partial_expecations)
    return expected(fetch.(partial_expecations))
end
function scenariotype(scenarioproblems::ScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return SD
end
function scenariotype(scenarioproblems::DScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return SD
end
function subproblem(scenarioproblems::ScenarioProblems{D,SD,S},i::Integer) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return scenarioproblems.problems[i]
end
function subproblem(scenarioproblems::DScenarioProblems{D,SD,S},i::Integer) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    j = 0
    for w in workers()
        n = remotecall_fetch((sp)->length(fetch(sp).scenariodata),w,scenarioproblems[w-1])
        if i <= n+j
            return remotecall_fetch((sp,i)->fetch(sp).problems[i],w,scenarioproblems[w-1],i-j)
        end
        j += n
    end
    throw(BoundsError(scenarioproblems,i))
end
function subproblems(scenarioproblems::ScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return scenarioproblems.problems
end
function subproblems(scenarioproblems::DScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    partial_subproblems = Vector{Future}()
    for w in workers()
        push!(partial_subproblems,remotecall((sp)->fetch(sp).problems,w,scenarioproblems[w-1]))
    end
    map(wait,partial_subproblems)
    return fetch.(partial_subproblems)
end
function parentmodel(scenarioproblems::ScenarioProblems)
    return scenarioproblems.parent
end
function parentmodel(scenarioproblems::DScenarioProblems)
    isempty(scenarioproblems) && error("No remote scenario problems.")
    return fetch(scenarioproblems[1]).parent
end
function probability(scenarioproblems::ScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return probability(scenarioproblems.scenariodata)
end
function probability(scenarioproblems::DScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    partial_probabilities = Vector{Future}()
    for w in workers()
        push!(partial_probabilities,remotecall((sp) -> probability(fetch(sp)),w,scenarioproblems[w-1]))
    end
    map(wait,partial_probabilities)
    return sum(fetch.(partial_probabilities))
end
function nscenarios(scenarioproblems::ScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return length(scenarioproblems.scenariodata)
end
function nscenarios(scenarioproblems::DScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    partial_nscenarios = Vector{Future}()
    for w in workers()
        push!(partial_nscenarios,remotecall((sp) -> nscenarios(fetch(sp)),w,scenarioproblems[w-1]))
    end
    map(wait,partial_nscenarios)
    return sum(fetch.(partial_nscenarios))
end
# ========================== #

# Base overloads
# ========================== #
function Base.length(scenarioproblems::ScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return length(scenarioproblems.problems)
end
function Base.length(scenarioproblems::DScenarioProblems{D,SD,S}) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    partial_lengths = Vector{Future}()
    for w in workers()
        push!(partial_lengths,remotecall((sp) -> length(fetch(sp)),w,scenarioproblems[w-1]))
    end
    map(wait,partial_lengths)
    return sum(fetch.(partial_lengths))
end
function Base.push!(scenarioproblems::ScenarioProblems{D,SD},sdata::SD) where {D,SD <: AbstractScenarioData}
    push!(scenarioproblems.scenariodata,sdata)
end
function Base.push!(scenarioproblems::DScenarioProblems{D,SD},sdata::SD) where {D,SD <: AbstractScenarioData}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    w = rand(workers())
    remotecall_fetch((sp,sdata) -> push!(fetch(sp).scenariodata,sdata),
                     w,
                     scenarioproblems[w-1],
                     sdata)
end
function Base.append!(scenarioproblems::ScenarioProblems{D,SD},sdata::Vector{SD}) where {D,SD <: AbstractScenarioData}
    append!(scenarioproblems.scenariodata,sdata)
end
function Base.append!(scenarioproblems::DScenarioProblems{D,SD},sdata::Vector{SD}) where {D,SD <: AbstractScenarioData}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    w = rand(workers())
    remotecall_fetch((sp,sdata) -> append!(fetch(sp).scenariodata,sdata),
                     w,
                     scenarioproblems[w-1],
                     sdata)
end
# ========================== #

# Sampling #
# ========================== #
sample!(scenarioproblems::ScenarioProblems,n::Integer) = _sample!(scenarioproblems,n,nscenarios(scenarioproblems),1/n)
function sample!(scenarioproblems::ScenarioProblems{D,SD,NullSampler{SD}},n::Integer) where {D,SD <: AbstractScenarioData}
    warn("No sampler provided.")
    return scenarioproblems
end
function sample!(scenarioproblems::DScenarioProblems{D,SD,S},n::Integer) where {D,SD <: AbstractScenarioData,S <: AbstractSampler{SD}}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    m = nscenarios(scenarioproblems)
    (nscen,extra) = divrem(n,nworkers())
    if extra > 0
        nscen += 1
    end
    active_workers = Vector{Future}(nworkers())
    for p in workers()
        if p == nprocs()
            nscen -= nscen*nworkers() - n
        end
        active_workers[p-1] = remotecall((sp,n,m,π)->_sample!(fetch(sp),n,m,π),p,scenarioproblems[p-1],nscen,m,1/n)
    end
    map(wait,active_workers)
    return scenarioproblems
end
function sample!(scenarioproblems::DScenarioProblems{D,SD,NullSampler{SD}},n::Integer) where {D,SD <: AbstractScenarioData}
    warn("No sampler provided.")
    return scenarioproblems
end
function _sample!(scenarioproblems::ScenarioProblems{D,SD,S},n::Integer,m::Integer,π::AbstractFloat) where {D,SD <: AbstractScenarioData,S <: AbstractSampler{SD}}
    if m > 0
        # Rescale probabilities of existing scenarios
        for scenario in scenarioproblems.scenariodata
            p = probability(scenario) * m / (m+n)
            set_probability!(scenario,p)
        end
        π *= n/(m+n)
    end
    for i = 1:n
        push!(scenarioproblems,sample(scenarioproblems.sampler,π))
    end
    return scenarioproblems
end
# ========================== #
