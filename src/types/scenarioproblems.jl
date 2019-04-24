abstract type AbstractScenarioProblems{S <: AbstractScenario} end
struct ScenarioProblems{S <: AbstractScenario} <: AbstractScenarioProblems{S}
    scenarios::Vector{S}
    problems::Vector{JuMP.Model}
    parent::JuMP.Model

    function ScenarioProblems(::Type{S}) where S <: AbstractScenario
        return new{S}(Vector{S}(), Vector{JuMP.Model}(), JuMP.Model())
    end

    function ScenarioProblems(scenarios::Vector{S}) where S <: AbstractScenario
        return new{S}(scenarios, Vector{JuMP.Model}(), JuMP.Model())
    end
end
ScenarioProblemChannel{S} = RemoteChannel{Channel{ScenarioProblems{S}}}
struct DScenarioProblems{S <: AbstractScenario} <: AbstractScenarioProblems{S}
    parent::JuMP.Model
    scenario_distribution::Vector{Int}
    scenarioproblems::Vector{ScenarioProblemChannel{S}}

    function DScenarioProblems(scenario_distribution::Vector{Int}, scenarioproblems::Vector{ScenarioProblemChannel{S}}) where S <: AbstractScenario
        return new{S}(JuMP.Model(), scenario_distribution, scenarioproblems)
    end
end
function ScenarioProblems(::Type{S}, procs::Vector{Int}) where S <: AbstractScenario
    if (length(procs) == 1 || nworkers() == 1) && procs[1] == 1
        return ScenarioProblems(S)
    else
        isempty(procs) && error("No requested procs.")
        length(procs) <= nworkers() || error("Not enough workers to satisfy requested number of procs. There are ", nworkers(), " workers, but ", length(procs), " were requested.")
        scenarioproblems = Vector{ScenarioProblemChannel{S}}(undef, length(procs))
        @sync begin
            for (i,p) in enumerate(procs)
                scenarioproblems[i] = RemoteChannel(() -> Channel{ScenarioProblems{S}}(1), p)
                @async remotecall_fetch((sp,S)->put!(sp, ScenarioProblems(S)),
                                        p,
                                        scenarioproblems[i],
                                        S)
            end
        end
        return DScenarioProblems(zeros(Int, length(procs)), scenarioproblems)
    end
end

function ScenarioProblems(scenarios::Vector{S}, procs::Vector{Int}) where S <: AbstractScenario
    if (length(procs) == 1 || nworkers() == 1) && procs[1] == 1
        return ScenarioProblems(scenarios)
    else
        isempty(procs) && error("No requested procs.")
        length(procs) <= nworkers() || error("Not enough workers to satisfy requested number of procs. There are ", nworkers(), " workers, but ", length(procs), " were requested.")
        scenarioproblems = Vector{ScenarioProblemChannel{S}}(undef, length(procs))
        (nscen, extra) = divrem(length(scenarios), length(procs))
        start = 1
        stop = nscen + (extra > 0)
        scenario_distribution = zeros(Int, length(procs))
        @sync begin
            for (i,p) in enumerate(procs)
                n = nscen + (extra > 0)
                scenarioproblems[i] = RemoteChannel(() -> Channel{ScenarioProblems{S}}(1), p)
                scenario_range = start:stop
                @async remotecall_fetch((sp,scenarios)->put!(sp, ScenarioProblems(scenarios)),
                                        p,
                                        scenarioproblems[i],
                                        scenarios[scenario_range])
                scenario_distribution[i] = n
                start = stop + 1
                stop += n
                stop = min(stop, length(scenarios))
                extra -= 1
            end
        end
        return DScenarioProblems(scenario_distribution, scenarioproblems)
    end
end

# Base overloads #
# ========================== #
Base.getindex(sp::DScenarioProblems, i::Integer) = sp.scenarioproblems[i]
# ========================== #

# Getters #
# ========================== #
function scenario(scenarioproblems::ScenarioProblems{S}, i::Integer) where S <: AbstractScenario
    return scenarioproblems.scenarios[i]
end
function scenario(scenarioproblems::DScenarioProblems{S}, i::Integer) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    j = 0
    for w in workers()
        n = scenarioproblems.scenario_distribution[w-1]
        if i <= n+j
            return remotecall_fetch((sp,i)->fetch(sp).scenarios[i], w, scenarioproblems[w-1], i-j)
        end
        j += n
    end
    throw(BoundsError(scenarioproblems, i))
end
function scenarios(scenarioproblems::ScenarioProblems{S}) where S <: AbstractScenario
    return scenarioproblems.scenarios
end
function scenarios(scenarioproblems::DScenarioProblems{S}) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    partial_scenarios = Vector{Vector{S}}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_scenarios[i] = remotecall_fetch((sp)->fetch(sp).scenarios, w, scenarioproblems[w-1])
        end
    end
    return reduce(vcat, partial_scenarios)
end
function expected(scenarioproblems::ScenarioProblems{S}) where S <: AbstractScenario
    return expected(scenarioproblems.scenarios)
end
function expected(scenarioproblems::DScenarioProblems{S}) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    partial_expecations = Vector{S}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_expecations[i] = remotecall_fetch((sp) -> expected(fetch(sp)).scenario, w, scenarioproblems[w-1])
        end
    end
    return expected(partial_expecations)
end
function scenariotype(scenarioproblems::ScenarioProblems{S}) where S <: AbstractScenario
    return S
end
function scenariotype(scenarioproblems::DScenarioProblems{S}) where S <: AbstractScenario
    return S
end
function subproblem(scenarioproblems::ScenarioProblems{S}, i::Integer) where S <: AbstractScenario
    return scenarioproblems.problems[i]
end
function subproblem(scenarioproblems::DScenarioProblems{S}, i::Integer) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    j = 0
    for w in workers()
        n = scenarioproblems.scenario_distribution[w-1]
        if i <= n+j
            return remotecall_fetch((sp,i)->fetch(sp).problems[i],w,scenarioproblems[w-1],i-j)
        end
        j += n
    end
    throw(BoundsError(scenarioproblems,i))
end
function subproblems(scenarioproblems::ScenarioProblems{S}) where S <: AbstractScenario
    return scenarioproblems.problems
end
function subproblems(scenarioproblems::DScenarioProblems{S}) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    partial_subproblems = Vector{JuMP.Model}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_subproblems[i] = remotecall_fetch((sp)->fetch(sp).problems,w,scenarioproblems[w-1])
        end
    end
    return reduce(vcat, partial_subproblems)
end
function nsubproblems(scenarioproblems::ScenarioProblems{S}) where S <: AbstractScenario
    return length(scenarioproblems.problems)
end
function nsubproblems(scenarioproblems::DScenarioProblems{S}) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    partial_lengths = Vector{Int}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_lengths[i] = remotecall_fetch((sp) -> nsubproblems(fetch(sp)),w,scenarioproblems[w-1])
        end
    end
    return sum(partial_lengths)
end
function parentmodel(scenarioproblems::AbstractScenarioProblems)
    return scenarioproblems.parent
end
function recourse_length(scenarioproblems::ScenarioProblems)
    return scenarioproblems.problems[1].numCols
end
function recourse_length(scenarioproblems::DScenarioProblems)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    return remotecall_fetch((sp)->recourse_length(fetch(sp)), 2, scenarioproblems[1])
end
function probability(scenarioproblems::ScenarioProblems{S}) where S <: AbstractScenario
    return probability(scenarioproblems.scenarios)
end
function probability(scenarioproblems::DScenarioProblems{S}) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    partial_probabilities = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_probabilities[i] = remotecall_fetch((sp) -> probability(fetch(sp)), w, scenarioproblems[w-1])
        end
    end
    return sum(partial_probabilities)
end
function nscenarios(scenarioproblems::ScenarioProblems{S}) where S <: AbstractScenario
    return length(scenarioproblems.scenarios)
end
function nscenarios(scenarioproblems::DScenarioProblems{S}) where S <: AbstractScenario
    return sum(scenarioproblems.scenario_distribution)
end
distributed(scenarioproblems::ScenarioProblems) = false
distributed(scenarioproblems::DScenarioProblems) = true
# ========================== #

# Setters
# ========================== #
function set_stage_data!(scenarioproblems::ScenarioProblems{P}, data::P) where P
    scenarioproblems.stage.data = data
    return nothing
end
function set_stage_data!(scenarioproblems::DScenarioProblems{P}, data::P) where P
    scenarioproblems.stage.data = data
    @sync begin
        for w in workers()
            @async remotecall_fetch((sp, data)->set_stage_data(fetch(sp), data), w, scenarioproblems[w-1], data)
        end
    end
    return nothing
end
function add_scenario!(scenarioproblems::ScenarioProblems{S}, scenario::S) where S <: AbstractScenario
    push!(scenarioproblems.scenarios, scenario)
    return nothing
end
function add_scenario!(scenarioproblems::DScenarioProblems{S}, scenario::S) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    _, w = findmin(scenarioproblems.scenario_distribution)
    add_scenario!(scenarioproblems, scenario, w+1)
    return nothing
end
function add_scenario!(scenarioproblems::DScenarioProblems{S}, scenario::S, w::Integer) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch((sp, scenario) -> add_scenario!(fetch(sp), scenario),
                     w,
                     scenarioproblems[w-1],
                     scenario)
    scenarioproblems.scenario_distribution[w-1] += 1
    return nothing
end
function add_scenario!(scenariogenerator::Function, scenarioproblems::ScenarioProblems)
    add_scenario!(scenarioproblems, scenariogenerator())
    return nothing
end
function add_scenario!(scenariogenerator::Function, scenarioproblems::DScenarioProblems)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    _, w = findmin(scenarioproblems.scenario_distribution)
    add_scenario!(scenariogenerator, scenarioproblems, w+1)
    return nothing
end
function add_scenario!(scenariogenerator::Function, scenarioproblems::DScenarioProblems, w::Integer)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch((sp, generator) -> add_scenario!(fetch(sp), generator()),
                     w,
                     scenarioproblems[w-1],
                     scenariogenerator)
    scenarioproblems.scenario_distribution[w] += 1
    return nothing
end
function add_scenarios!(scenarioproblems::ScenarioProblems{S}, scenarios::Vector{S}) where S <: AbstractScenario
    append!(scenarioproblems.scenarios, scenarios)
    return nothing
end
function add_scenarios!(scenariogenerator::Function, scenarioproblems::ScenarioProblems{S}, n::Integer) where S <: AbstractScenario
    for i = 1:n
        add_scenario!(scenarioproblems) do
            return scenariogenerator()
        end
    end
    return nothing
end
function add_scenarios!(scenarioproblems::DScenarioProblems{S}, scenarios::Vector{S}) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    (nscen, extra) = divrem(length(scenarios), nworkers())
    start = 1
    stop = nscen + (extra > 0)
    @sync begin
        for w in workers()
            n = nscen + (extra > 0)
            scenario_range = start:stop
            @async remotecall_fetch((sp, scenarios) -> add_scenarios!(fetch(sp), scenarios),
                                    w,
                                    scenarioproblems[w-1],
                                    scenarios[scenario_range])
            scenarioproblems.scenario_distribution[w-1] += n
            start = stop + 1
            stop += n
            stop = min(stop, length(scenarios))
            extra -= 1
        end
    end
    return nothing
end
function add_scenarios!(scenarioproblems::DScenarioProblems{S}, scenarios::Vector{S}, w::Integer) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch((sp, scenarios) -> add_scenarios!(fetch(sp), scenarios),
                     w,
                     scenarioproblems[w-1],
                     scenarios)
    scenarioproblems.scenario_distribution[w-1] += length(scenarios)
    return nothing
end
function add_scenarios!(scenariogenerator::Function, scenarioproblems::DScenarioProblems, n::Integer)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    (nscen, extra) = divrem(n, nworkers())
    @sync begin
        for w in workers()
            m = nscen + (extra > 0)
            @async remotecall_fetch((sp, gen, n) -> add_scenarios!(gen, fetch(sp), n),
                                    w,
                                    scenarioproblems[w-1],
                                    scenariogenerator,
                                    m)
            scenarioproblems.scenario_distribution[w-1] += m
            extra -= 1
        end
    end
    return nothing
end
function add_scenarios!(scenariogenerator::Function, scenarioproblems::DScenarioProblems{S}, n::Integer, w::Integer) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch((sp, gen) -> add_scenarios!(gen, fetch(sp), n),
                     w,
                     scenarioproblems[w-1],
                     scenariogenerator,
                     n)
    scenarioproblems.scenario_distribution[w-1] += n
    return nothing
end
function remove_scenarios!(scenarioproblems::ScenarioProblems)
    empty!(scenarioproblems.scenarios)
    return nothing
end
function remove_scenarios!(scenarioproblems::DScenarioProblems)
    @sync begin
        for w in workers()
            @async remotecall_fetch((sp)->remove_scenarios!(fetch(sp)), w, scenarioproblems[w-1])
            scenarioproblems.scenario_distribution[w-1] = 0
        end
    end
    return nothing
end
function remove_subproblems!(scenarioproblems::ScenarioProblems)
    empty!(scenarioproblems.problems)
    return nothing
end
function remove_subproblems!(scenarioproblems::DScenarioProblems)
    @sync begin
        for w in workers()
            @async remotecall_fetch((sp)->remove_subproblems!(fetch(sp)), w, scenarioproblems[w-1])
        end
    end
    return nothing
end
# ========================== #

# Sampling #
# ========================== #
function sample!(scenarioproblems::ScenarioProblems{S}, sampler::AbstractSampler{S}, n::Integer) where S <: AbstractScenario
    _sample!(scenarioproblems, sampler, n, nscenarios(scenarioproblems), 1/n)
end
function sample!(scenarioproblems::DScenarioProblems{S}, sampler::AbstractSampler{S}, n::Integer) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    m = nscenarios(scenarioproblems)
    (nscen, extra) = divrem(n, nworkers())
    @sync begin
        for w in workers()
            d = nscen + (extra > 0)
            @async remotecall_fetch((sp,sampler,n,m,π)->_sample!(fetch(sp),sampler,n,m,π), w, scenarioproblems[w-1], sampler, d, m, 1/n)
            scenarioproblems.scenario_distribution[w-1] += d
            extra -= 1
        end
    end
    return nothing
end
function _sample!(scenarioproblems::ScenarioProblems{S}, sampler::AbstractSampler{S}, n::Integer, m::Integer, π::AbstractFloat) where S <: AbstractScenario
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
    return nothing
end
# ========================== #
