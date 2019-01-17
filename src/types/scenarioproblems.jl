mutable struct ScenarioData{D} <: AbstractScenario
    π::Float64
    data::D

    function (::Type{ScenarioData})(data::D) where D
        return new{D}(data)
    end
end

struct ScenarioProblems{D, S <: AbstractScenario}
    stage::Stage{D}
    scenarios::Vector{S}
    problems::Vector{JuMP.Model}
    parent::JuMP.Model

    function (::Type{ScenarioProblems})(stage::Integer, stagedata::D, ::Type{S}) where {D, S <: AbstractScenario}
        D_ = D == Nothing ? Any : D
        return new{D_,S}(Stage(stage, stagedata), Vector{S}(), Vector{JuMP.Model}(), Model(solver=JuMP.UnsetSolver()))
    end

    function (::Type{ScenarioProblems})(stage::Integer, stagedata::D, scenariodata::Vector{<:AbstractScenario}) where D
        S = eltype(scenariodata)
        D_ = D == Nothing ? Any : D
        return new{D_,S}(Stage(stage, stagedata), scenariodata, Vector{JuMP.Model}(), Model(solver=JuMP.UnsetSolver()))
    end
end
DScenarioProblems{D,S} = Vector{RemoteChannel{Channel{ScenarioProblems{D,S}}}}

function ScenarioProblems(stage::Integer, stagedata::D, ::Type{S}, procs::Vector{Int}) where {D, S <: AbstractScenario}
    if (length(procs) == 1 || nworkers() == 1) && procs[1] == 1
        return ScenarioProblems(stage, stagedata, S)
    else
        isempty(procs) && error("No requested procs.")
        length(procs) <= nworkers() || error("Not enough workers to satisfy requested number of procs. There are ", nworkers(), " workers, but ", length(procs), " were requested.")
        D_ = D == Nothing ? Any : D
        scenarioproblems = DScenarioProblems{D_,S}(undef, length(procs))
        active_workers = Vector{Future}(undef, length(procs))
        for p in procs
            scenarioproblems[p-1] = RemoteChannel(() -> Channel{ScenarioProblems{D_,S}}(1), p)
            active_workers[p-1] = remotecall((sp,stage,stagedata,S)->put!(sp, ScenarioProblems(stage,stagedata,S)), p, scenarioproblems[p-1], stage, stagedata, S)
        end
        map(wait, active_workers)
        return scenarioproblems
    end
end

function ScenarioProblems(stage::Integer, stagedata::D, scenarios::Vector{S}, procs::Vector{Int}) where {D, S <: AbstractScenario}
    if (length(procs) == 1 || nworkers() == 1) && procs[1] == 1
        return ScenarioProblems(stage, stagedata, scenarios)
    else
        isempty(procs) && error("No requested procs.")
        length(procs) <= nworkers() || error("Not enough workers to satisfy requested number of procs. There are ", nworkers(), " workers, but ", length(procs), " were requested.")
        D_ = D == Nothing ? Any : D
        scenarioproblems = DScenarioProblems{D_,S}(undef, length(procs))
        (nscen, extra) = divrem(length(scenarios),length(procs))
        start = 1
        stop = nscen + (extra > 0)
        extra -= 1
        active_workers = Vector{Future}(undef, length(procs))
        for p in procs
            scenarioproblems[p-1] = RemoteChannel(() -> Channel{ScenarioProblems{D_,S}}(1), p)
            active_workers[p-1] = remotecall((sp,stage,stagedata,sdata)->put!(sp, ScenarioProblems(stage,stagedata,sdata)), p, scenarioproblems[p-1], stage, stagedata, scenarios[start:stop])
            start = stop + 1
            stop += nscen + (extra > 0)
            stop = min(stop, length(scenarios))
            extra -= 1
        end
        map(wait, active_workers)
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
function scenario(scenarioproblems::ScenarioProblems{D,S}, i::Integer) where {D, S <: AbstractScenario}
    return scenarioproblems.scenarios[i]
end
function scenario(scenarioproblems::DScenarioProblems{D,S}, i::Integer) where {D, S <: AbstractScenario}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    j = 0
    for w in workers()
        n = remotecall_fetch((sp)->length(fetch(sp).scenarios), w, scenarioproblems[w-1])
        if i <= n+j
            return remotecall_fetch((sp,i)->fetch(sp).scenarios[i], w, scenarioproblems[w-1], i-j)
        end
        j += n
    end
    throw(BoundsError(scenarioproblems, i))
end
function scenarios(scenarioproblems::ScenarioProblems{D,S}) where {D, S <: AbstractScenario}
    return scenarioproblems.scenarios
end
function scenarios(scenarioproblems::DScenarioProblems{D,S}) where {D, S <: AbstractScenario}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    partial_scenarios = Vector{Future}()
    for w in workers()
        push!(partial_scenarios,remotecall((sp)->fetch(sp).scenarios, w, scenarioproblems[w-1]))
    end
    map(wait, partial_scenarios)
    return reduce(vcat, fetch.(partial_scenarios))
end
function expected(scenarioproblems::ScenarioProblems{D,S}) where {D, S <: AbstractScenario}
    return expected(scenarioproblems.scenarios)
end
function expected(scenarioproblems::DScenarioProblems{D,S}) where {D, S <: AbstractScenario}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    partial_expecations = Vector{Future}()
    for w in workers()
        push!(partial_expecations,remotecall((sp) -> expected(fetch(sp)).scenario, w, scenarioproblems[w-1]))
    end
    map(wait, partial_expecations)
    return expected(fetch.(partial_expecations))
end
function scenariotype(scenarioproblems::ScenarioProblems{D,S}) where {D, S <: AbstractScenario}
    return S
end
function scenariotype(scenarioproblems::DScenarioProblems{D,S}) where {D, S <: AbstractScenario}
    return S
end
function subproblem(scenarioproblems::ScenarioProblems{D,S}, i::Integer) where {D, S <: AbstractScenario}
    return scenarioproblems.problems[i]
end
function subproblem(scenarioproblems::DScenarioProblems{D,S}, i::Integer) where {D, S <: AbstractScenario}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    j = 0
    for w in workers()
        n = remotecall_fetch((sp)->length(fetch(sp).problems),w,scenarioproblems[w-1])
        if i <= n+j
            return remotecall_fetch((sp,i)->fetch(sp).problems[i],w,scenarioproblems[w-1],i-j)
        end
        j += n
    end
    throw(BoundsError(scenarioproblems,i))
end
function subproblems(scenarioproblems::ScenarioProblems{D,S}) where {D, S <: AbstractScenario}
    return scenarioproblems.problems
end
function subproblems(scenarioproblems::DScenarioProblems{D,S}) where {D, S <: AbstractScenario}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    partial_subproblems = Vector{Future}()
    for w in workers()
        push!(partial_subproblems,remotecall((sp)->fetch(sp).problems,w,scenarioproblems[w-1]))
    end
    map(wait,partial_subproblems)
    return reduce(vcat,fetch.(partial_subproblems))
end
function nsubproblems(scenarioproblems::ScenarioProblems{D,S}) where {D, S <: AbstractScenario}
    return length(scenarioproblems.problems)
end
function nsubproblems(scenarioproblems::DScenarioProblems{D,S}) where {D, S <: AbstractScenario}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    partial_lengths = Vector{Future}()
    for w in workers()
        push!(partial_lengths,remotecall((sp) -> nsubproblems(fetch(sp)),w,scenarioproblems[w-1]))
    end
    map(wait,partial_lengths)
    return sum(fetch.(partial_lengths))
end
function parentmodel(scenarioproblems::ScenarioProblems)
    return scenarioproblems.parent
end
function parentmodel(scenarioproblems::DScenarioProblems)
    isempty(scenarioproblems) && error("No remote scenario problems.")
    return fetch(scenarioproblems[1]).parent
end
function recourse_length(scenarioproblems::ScenarioProblems)
    return scenarioproblems.problems[1].numCols
end
function recourse_length(scenarioproblems::DScenarioProblems)
    isempty(scenarioproblems) && error("No remote scenario problems.")
    return remotecall_fetch((sp)->recourse_length(fetch(sp)), 2, scenarioproblems[1])
end
function probability(scenarioproblems::ScenarioProblems{D,S}) where {D, S <: AbstractScenario}
    return probability(scenarioproblems.scenarios)
end
function probability(scenarioproblems::DScenarioProblems{D,S}) where {D, S <: AbstractScenario}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    partial_probabilities = Vector{Future}()
    for w in workers()
        push!(partial_probabilities,remotecall((sp) -> probability(fetch(sp)), w, scenarioproblems[w-1]))
    end
    map(wait, partial_probabilities)
    return sum(fetch.(partial_probabilities))
end
function nscenarios(scenarioproblems::ScenarioProblems{D,S}) where {D, S <: AbstractScenario}
    return length(scenarioproblems.scenarios)
end
function nscenarios(scenarioproblems::DScenarioProblems{D,S}) where {D, S <: AbstractScenario}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    partial_nscenarios = Vector{Future}()
    for w in workers()
        push!(partial_nscenarios,remotecall((sp) -> nscenarios(fetch(sp)), w, scenarioproblems[w-1]))
    end
    map(wait, partial_nscenarios)
    return sum(fetch.(partial_nscenarios))
end
distributed(scenarioproblems::ScenarioProblems) = false
distributed(scenarioproblems::DScenarioProblems) = true
# ========================== #

# Setters
# ========================== #
function set_stage_data!(scenarioproblems::ScenarioProblems{D}, data::D) where D
    scenarioproblems.stage.data = data
end
function set_stage_data!(scenarioproblems::DScenarioProblems{D}, data::D) where D
    for w in workers()
        remotecall_fetch((sp, data)->set_stage_data(fetch(sp), data), w, scenarioproblems[w-1], data)
    end
end
function add_scenario!(scenarioproblems::ScenarioProblems{D,S}, scenario::S) where {D, S <: AbstractScenario}
    push!(scenarioproblems.scenarios, scenario)
end
function add_scenario!(scenarioproblems::DScenarioProblems{D,S}, scenario::S) where {D, S <: AbstractScenario}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    nscen = [remotecall_fetch((sp)->nscenarios(fetch(sp)), w, scenarioproblems[w-1]) for w in workers()]
    _, w = findmin(nscen)
    add_scenario!(scenarioproblems, scenario, w+1)
end
function add_scenario!(scenarioproblems::DScenarioProblems{D,S}, scenario::S, w::Integer) where {D, S <: AbstractScenario}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch((sp, scenario) -> add_scenario!(fetch(sp), scenario),
                     w,
                     scenarioproblems[w-1],
                     scenario)
end
function add_scenario!(scenariogenerator::Function, scenarioproblems::ScenarioProblems)
    add_scenario!(scenarioproblems, scenariogenerator())
end
function add_scenario!(scenariogenerator::Function, scenarioproblems::DScenarioProblems)
    isempty(scenarioproblems) && error("No remote scenario problems.")
    nscen = [remotecall_fetch((sp)->nscenarios(fetch(sp)), w, scenarioproblems[w-1]) for w in workers()]
    _, w = findmin(nscen)
    add_scenario!(scenariogenerator, scenarioproblems, w+1)
end
function add_scenario!(scenariogenerator::Function, scenarioproblems::DScenarioProblems, w::Integer)
    isempty(scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch((sp, generator) -> add_scenario!(fetch(sp), generator()),
                     w,
                     scenarioproblems[w-1],
                     scenariogenerator)
end
function add_scenarios!(scenarioproblems::ScenarioProblems{D,S}, scenarios::Vector{S}) where {D, S <: AbstractScenario}
    append!(scenarioproblems.scenarios, scenarios)
end
function add_scenarios!(scenariogenerator::Function, scenarioproblems::ScenarioProblems{D,S}, n::Integer) where {D, S <: AbstractScenario}
    for i = 1:n
        add_scenario!(scenarioproblems) do
            return scenariogenerator()
        end
    end
end
function add_scenarios!(scenarioproblems::DScenarioProblems{D,S}, scenarios::Vector{S}) where {D, S <: AbstractScenario}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    (nscen, extra) = divrem(length(scenarios), nworkers())
    start = 1
    stop = nscen + (extra > 0)
    extra -= 1
    for w in workers()
        remotecall_fetch((sp, scenarios) -> add_scenarios!(fetch(sp), scenarios),
                         w,
                         scenarioproblems[w-1],
                         scenarios[start:stop])
        start = stop + 1
        stop += nscen + (extra > 0)
        stop = min(stop, length(scenarios))
        extra -= 1
    end
end
function add_scenarios!(scenarioproblems::DScenarioProblems{D,S}, scenarios::Vector{S}, w::Integer) where {D, S <: AbstractScenario}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch((sp, scenarios) -> add_scenarios!(fetch(sp), scenarios),
                     w,
                     scenarioproblems[w-1],
                     scenarios)
end
function add_scenarios!(scenariogenerator::Function, scenarioproblems::DScenarioProblems, n::Integer)
    isempty(scenarioproblems) && error("No remote scenario problems.")
    (nscen, extra) = divrem(n, nworkers())
    for w in workers()
        remotecall_fetch((sp, gen, n) -> add_scenarios!(gen, fetch(sp), n),
                         w,
                         scenarioproblems[w-1],
                         scenariogenerator,
                         nscen + (extra > 0))
        extra -= 1
    end
end
function add_scenarios!(scenariogenerator::Function, scenarioproblems::DScenarioProblems{D,S}, n::Integer, w::Integer) where {D, S <: AbstractScenario}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch((sp, gen) -> add_scenarios!(gen, fetch(sp), n),
                     w,
                     scenarioproblems[w-1],
                     scenariogenerator,
                     n)
end
function remove_scenarios!(scenarioproblems::ScenarioProblems)
    empty!(scenarioproblems.scenarios)
end
function remove_scenarios!(scenarioproblems::DScenarioProblems)
    for w in workers()
        remotecall_fetch((sp)->remove_scenarios!(fetch(sp)), w, scenarioproblems[w-1])
    end
end
function remove_subproblems!(scenarioproblems::ScenarioProblems)
    empty!(scenarioproblems.problems)
end
function remove_subproblems!(scenarioproblems::DScenarioProblems)
    for w in workers()
        remotecall_fetch((sp)->remove_subproblems!(fetch(sp)), w, scenarioproblems[w-1])
    end
end
# ========================== #

# Sampling #
# ========================== #
function sample!(scenarioproblems::ScenarioProblems{D,S}, sampler::AbstractSampler{S}, n::Integer) where {D , S <: AbstractScenario}
    _sample!(scenarioproblems, sampler, n, nscenarios(scenarioproblems), 1/n)
end
function sample!(scenarioproblems::DScenarioProblems{D,S}, sampler::AbstractSampler{S}, n::Integer) where {D, S <: AbstractScenario}
    isempty(scenarioproblems) && error("No remote scenario problems.")
    m = nscenarios(scenarioproblems)
    (nscen, extra) = divrem(n, nworkers())
    active_workers = Vector{Future}(undef, nworkers())
    for p in workers()
        active_workers[p-1] = remotecall((sp,sampler,n,m,π)->_sample!(fetch(sp),sampler,n,m,π), p, scenarioproblems[p-1], sampler, nscen + (extra > 0), m, 1/n)
        extra -= 1
    end
    map(wait, active_workers)
    return scenarioproblems
end
function _sample!(scenarioproblems::ScenarioProblems{D,S}, sampler::AbstractSampler{S}, n::Integer, m::Integer, π::AbstractFloat) where {D, S <: AbstractScenario}
    if m > 0
        # Rescale probabilities of existing scenarios
        for scenario in scenarioproblems.scenarios
            p = probability(scenario) * m / (m+n)
            set_probability!(scenario, p)
        end
        π *= n/(m+n)
    end
    for i = 1:n
        add_scenario!(scenarioproblems) do
            return sample(sampler, π)
        end
    end
    return scenarioproblems
end
# ========================== #
