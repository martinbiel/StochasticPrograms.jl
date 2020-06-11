struct ScenarioProblems{S <: AbstractScenario} <: AbstractScenarioProblems{S}
    scenarios::Vector{S}
    problems::Vector{JuMP.Model}

    function ScenarioProblems(scenarios::Vector{S}) where S <: AbstractScenario
        # ScenarioProblems are initialized without any subproblems.
        # These are added during generation.
        return new{S}(scenarios, Vector{JuMP.Model}())
    end
end
ScenarioProblemChannel{S} = RemoteChannel{Channel{ScenarioProblems{S}}}
DecisionChannel = RemoteChannel{Channel{Decisions}}
struct DistributedScenarioProblems{S <: AbstractScenario} <: AbstractScenarioProblems{S}
    scenario_distribution::Vector{Int}
    scenarioproblems::Vector{ScenarioProblemChannel{S}}
    decisions::Vector{DecisionChannel}

    function DistributedScenarioProblems(scenario_distribution::Vector{Int},
                                         scenarioproblems::Vector{ScenarioProblemChannel{S}},
                                         decisions::Vector{DecisionChannel}) where S <: AbstractScenario
        return new{S}(scenario_distribution, scenarioproblems, decisions)
    end
end

function DistributedScenarioProblems(_scenarios::Vector{S}) where S <: AbstractScenario
    scenarioproblems = Vector{ScenarioProblemChannel{S}}(undef, nworkers())
    decisions = Vector{DecisionChannel}(undef, nworkers())
    (nscen, extra) = divrem(length(_scenarios), nworkers())
    start = 1
    stop = nscen + (extra > 0)
    scenario_distribution = zeros(Int, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            n = nscen + (extra > 0)
            scenarioproblems[i] = RemoteChannel(() -> Channel{ScenarioProblems{S}}(1), w)
            decisions[i] = RemoteChannel(() -> Channel{Decisions}(1), w)
            scenario_range = start:stop
            @async remotecall_fetch(
                w,
                scenarioproblems[i],
                _scenarios[scenario_range]) do sp, scenarios
                    put!(sp, ScenarioProblems(scenarios))
                end
            @async remotecall_fetch(
                w,
                decisions[i]) do channel
                    put!(channel, Decisions())
                end
            scenario_distribution[i] = n
            start = stop + 1
            stop += n
            stop = min(stop, length(_scenarios))
            extra -= 1
        end
    end
    return DistributedScenarioProblems(scenario_distribution, scenarioproblems, decisions)
end

ScenarioProblems(::Type{S}, instantiation) where S <: AbstractScenario = ScenarioProblems(Vector{S}(), instantiation)

function ScenarioProblems(scenarios::Vector{S}, ::Union{BlockVertical, BlockHorizontal}) where S <: AbstractScenario
    ScenarioProblems(scenarios)
end

function ScenarioProblems(scenarios::Vector{S}, ::Union{DistributedBlockVertical, DistributedBlockHorizontal}) where S <: AbstractScenario
    DistributedScenarioProblems(scenarios)
end


# Base overloads #
# ========================== #
Base.getindex(sp::DistributedScenarioProblems, i::Integer) = sp.scenarioproblems[i]
# ========================== #

# MOI #
# ========================== #
function MOI.set(scenarioproblems::ScenarioProblems, attr::MOI.AbstractModelAttribute, value)
    for problem in subproblems(scenarioproblems)
        MOI.set(backend(problem), attr, value)
    end
end
function MOI.set(scenarioproblems::DistributedScenarioProblems, attr::MOI.AbstractModelAttribute, value)
    @sync begin
        for (i,w) in enumerate(workers())
            @async remotecall_fetch(
                w, scenarioproblems[w-1], attr, value) do sp, attr, value
                    MOI.set(fetch(sp), attr, value)
                end
        end
    end
end
function MOI.set(scenarioproblems::ScenarioProblems, attr::MOI.AbstractOptimizerAttribute, value)
    for problem in subproblems(scenarioproblems)
        MOI.set(backend(problem), attr, value)
    end
end
function MOI.set(scenarioproblems::DistributedScenarioProblems, attr::MOI.AbstractOptimizerAttribute, value)
    @sync begin
        for (i,w) in enumerate(workers())
            @async remotecall_fetch(
                w, scenarioproblems[w-1], attr, value) do sp, attr, value
                    MOI.set(fetch(sp), attr, value)
                end
        end
    end
end
function MOI.set(scenarioproblems::ScenarioProblems, attr::MOI.AbstractVariableAttribute,
                 index::MOI.VariableIndex, value)
    for problem in subproblems(scenarioproblems)
        MOI.set(backend(problem), attr, index, value)
    end
    return nothing
end
function MOI.set(scenarioproblems::DistributedScenarioProblems, attr::MOI.AbstractVariableAttribute,
                 index::MOI.VariableIndex, value)
    @sync begin
        for (i,w) in enumerate(workers())
            @async remotecall_fetch(
                w, scenarioproblems[w-1], attr, index, value) do sp, attr, index, value
                    MOI.set(fetch(sp), attr, index, value)
                end
        end
    end
end
function MOI.set(scenarioproblems::ScenarioProblems, attr::MOI.AbstractConstraintAttribute, cindex::MOI.ConstraintIndex, value)
    for problem in subproblems(scenarioproblems)
        MOI.set(backend(problem), attr, index, value)
    end
    return nothing
end
function MOI.set(scenarioproblems::DistributedScenarioProblems, attr::MOI.AbstractConstraintAttribute,
                 cindex::MOI.ConstraintIndex, value)
    @sync begin
        for (i,w) in enumerate(workers())
            @async remotecall_fetch(
                w, scenarioproblems[w-1], attr, index, value) do sp, attr, index, value
                    MOI.set(fetch(sp), attr, index, value)
                end
        end
    end
end

# Getters #
# ========================== #
function scenario(scenarioproblems::ScenarioProblems, i::Integer)
    return scenarioproblems.scenarios[i]
end
function scenario(scenarioproblems::DistributedScenarioProblems, i::Integer)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    j = 0
    for w in workers()
        n = scenarioproblems.scenario_distribution[w-1]
        if i <= n+j
            return remotecall_fetch(
                w, scenarioproblems[w-1], i-j) do sp, i
                    fetch(sp).scenarios[i]
                end
        end
        j += n
    end
    throw(BoundsError(scenarioproblems, i))
end
function scenarios(scenarioproblems::ScenarioProblems)
    return scenarioproblems.scenarios
end
function scenarios(scenarioproblems::DistributedScenarioProblems{S}) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    partial_scenarios = Vector{Vector{S}}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_scenarios[i] = remotecall_fetch(
                w, scenarioproblems[w-1]) do sp
                    fetch(sp).scenarios
                end
        end
    end
    return reduce(vcat, partial_scenarios)
end
function expected(scenarioproblems::ScenarioProblems)
    return expected(scenarioproblems.scenarios)
end
function expected(scenarioproblems::DistributedScenarioProblems{S}) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    partial_expecations = Vector{S}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_expecations[i] = remotecall_fetch(
                w, scenarioproblems[w-1]) do sp
                    expected(fetch(sp)).scenario
                end
        end
    end
    return expected(partial_expecations)
end
function scenario_type(scenarioproblems::ScenarioProblems{S}) where S <: AbstractScenario
    return S
end
function scenario_type(scenarioproblems::DistributedScenarioProblems{S}) where S <: AbstractScenario
    return S
end
function subproblem(scenarioproblems::ScenarioProblems, i::Integer)
    return scenarioproblems.problems[i]
end
function subproblem(scenarioproblems::DistributedScenarioProblems, i::Integer)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    j = 0
    for w in workers()
        n = scenarioproblems.scenario_distribution[w-1]
        if i <= n+j
            return remotecall_fetch(
                w,scenarioproblems[w-1],i-j) do sp, i
                    fetch(sp).problems[i]
                end
        end
        j += n
    end
    throw(BoundsError(scenarioproblems,i))
end
function subproblems(scenarioproblems::ScenarioProblems)
    return scenarioproblems.problems
end
function subproblems(scenarioproblems::DistributedScenarioProblems)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    partial_subproblems = Vector{Vector{JuMP.Model}}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_subproblems[i] = remotecall_fetch(
                w,scenarioproblems[w-1]) do sp
                    fetch(sp).problems
                end
        end
    end
    return reduce(vcat, partial_subproblems)
end
function num_subproblems(scenarioproblems::ScenarioProblems)
    return length(scenarioproblems.problems)
end
function num_subproblems(scenarioproblems::DistributedScenarioProblems)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    partial_lengths = Vector{Int}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_lengths[i] = remotecall_fetch(
                w,scenarioproblems[w-1]) do sp
                    num_subproblems(fetch(sp))
                end
        end
    end
    return sum(partial_lengths)
end
function decision_variables(scenarioproblems::ScenarioProblems)
    return scenarioproblems.decision_variables
end
function probability(scenarioproblems::ScenarioProblems, i::Integer)
    return probability(scenario(scenarioproblems, i))
end
function probability(scenarioproblems::DistributedScenarioProblems, i::Integer)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    j = 0
    for w in workers()
        n = scenarioproblems.scenario_distribution[w-1]
        if i <= n+j
            return remotecall_fetch(
                w, scenarioproblems[w-1], i-j) do sp, i
                    probability(fetch(sp).scenarios[i])
                end
        end
        j += n
    end
    throw(BoundsError(scenarioproblems, i))
end
function probability(scenarioproblems::ScenarioProblems)
    return probability(scenarioproblems.scenarios)
end
function probability(scenarioproblems::DistributedScenarioProblems)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    partial_probabilities = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_probabilities[i] = remotecall_fetch(
                w, scenarioproblems[w-1]) do sp
                    probability(fetch(sp))
                end
        end
    end
    return sum(partial_probabilities)
end
function num_scenarios(scenarioproblems::ScenarioProblems)
    return length(scenarioproblems.scenarios)
end
function num_scenarios(scenarioproblems::DistributedScenarioProblems)
    return sum(scenarioproblems.scenario_distribution)
end
distributed(scenarioproblems::ScenarioProblems) = false
distributed(scenarioproblems::DistributedScenarioProblems) = true
# ========================== #

# Setters
# ========================== #
function update_decisions!(scenarioproblems::ScenarioProblems, change::DecisionModification)
    map(subproblems(scenarioproblems)) do subprob
        update_decisions!(subprob, change)
    end
    return nothing
end
function update_decisions!(scenarioproblems::DistributedScenarioProblems, change::DecisionModification)
    @sync begin
        for (i,w) in enumerate(workers())
            @async remotecall_fetch(
                w, scenarioproblems[w-1], change) do sp, change
                    update_decisions!(fetch(sp), change)
                end
        end
    end
    return nothing
end
function set_optimizer!(scenarioproblems::ScenarioProblems, optimizer)
    map(subproblems(scenarioproblems)) do subprob
        set_optimizer(subprob, optimizer)
    end
    return nothing
end
function set_optimizer!(scenarioproblems::DistributedScenarioProblems, optimizer)
    @sync begin
        for (i,w) in enumerate(workers())
            @async remotecall_fetch(
                w, scenarioproblems[w-1], optimizer) do sp, opt
                    set_optimizer!(fetch(sp), opt)
                end
        end
    end
    return nothing
end
function add_scenario!(scenarioproblems::ScenarioProblems{S}, scenario::S) where S <: AbstractScenario
    push!(scenarioproblems.scenarios, scenario)
    return nothing
end
function add_scenario!(scenarioproblems::DistributedScenarioProblems{S}, scenario::S) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    _, w = findmin(scenarioproblems.scenario_distribution)
    add_scenario!(scenarioproblems, scenario, w+1)
    return nothing
end
function add_scenario!(scenarioproblems::DistributedScenarioProblems{S}, scenario::S, w::Integer) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch(
        w,
        scenarioproblems[w-1],
        scenario) do sp, scenario
            add_scenario!(fetch(sp), scenario)
        end
    scenarioproblems.scenario_distribution[w-1] += 1
    return nothing
end
function add_scenario!(scenariogenerator::Function, scenarioproblems::ScenarioProblems)
    add_scenario!(scenarioproblems, scenariogenerator())
    return nothing
end
function add_scenario!(scenariogenerator::Function, scenarioproblems::DistributedScenarioProblems)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    _, w = findmin(scenarioproblems.scenario_distribution)
    add_scenario!(scenariogenerator, scenarioproblems, w + 1)
    return nothing
end
function add_scenario!(scenariogenerator::Function, scenarioproblems::DistributedScenarioProblems, w::Integer)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch(
        w,
        scenarioproblems[w-1],
        scenariogenerator) do sp, generator
            add_scenario!(fetch(sp), generator())
        end
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
function add_scenarios!(scenarioproblems::DistributedScenarioProblems{S}, scenarios::Vector{S}) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    (nscen, extra) = divrem(length(scenarios), nworkers())
    start = 1
    stop = nscen + (extra > 0)
    @sync begin
        for w in workers()
            n = nscen + (extra > 0)
            scenario_range = start:stop
            @async remotecall_fetch(
                w,
                scenarioproblems[w-1],
                scenarios[scenario_range]) do sp, scenarios
                    add_scenarios!(fetch(sp), scenarios)
                end
            scenarioproblems.scenario_distribution[w-1] += n
            start = stop + 1
            stop += n
            stop = min(stop, length(scenarios))
            extra -= 1
        end
    end
    return nothing
end
function add_scenarios!(scenarioproblems::DistributedScenarioProblems{S}, scenarios::Vector{S}, w::Integer) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch(
        w,
        scenarioproblems[w-1],
        scenarios) do sp, scenarios
            add_scenarios!(fetch(sp), scenarios)
        end
    scenarioproblems.scenario_distribution[w-1] += length(scenarios)
    return nothing
end
function add_scenarios!(scenariogenerator::Function, scenarioproblems::DistributedScenarioProblems, n::Integer)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    (nscen, extra) = divrem(n, nworkers())
    @sync begin
        for w in workers()
            m = nscen + (extra > 0)
            @async remotecall_fetch(
                w,
                scenarioproblems[w-1],
                scenariogenerator,
                m) do sp, gen, n
                    add_scenarios!(gen, fetch(sp), n)
                end
            scenarioproblems.scenario_distribution[w-1] += m
            extra -= 1
        end
    end
    return nothing
end
function add_scenarios!(scenariogenerator::Function, scenarioproblems::DistributedScenarioProblems, n::Integer, w::Integer)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    remotecall_fetch(
        w,
        scenarioproblems[w-1],
        scenariogenerator,
        n) do sp, gen
            add_scenarios!(gen, fetch(sp), n)
        end
    scenarioproblems.scenario_distribution[w-1] += n
    return nothing
end
function clear_scenarios!(scenarioproblems::ScenarioProblems)
    empty!(scenarioproblems.scenarios)
    return nothing
end
function clear_scenarios!(scenarioproblems::DistributedScenarioProblems)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    @sync begin
        for w in workers()
            @async remotecall_fetch(
                w, scenarioproblems[w-1]) do sp
                    remove_scenarios!(fetch(sp))
                end
            scenarioproblems.scenario_distribution[w-1] = 0
        end
    end
    return nothing
end
function clear!(scenarioproblems::ScenarioProblems)
    map(empty!, scenarioproblems.problems)
    empty!(scenarioproblems.problems)
    return nothing
end
function clear!(scenarioproblems::DistributedScenarioProblems)
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    @sync begin
        for w in workers()
            @async remotecall_fetch(
                w, scenarioproblems[w-1]) do sp
                    clear!(fetch(sp))
                end
        end
    end
    return nothing
end
# ========================== #

# Sampling #
# ========================== #
function sample!(scenarioproblems::ScenarioProblems{S}, sampler::AbstractSampler{S}, n::Integer) where S <: AbstractScenario
    _sample!(scenarioproblems, sampler, n, num_scenarios(scenarioproblems), 1/n)
end
function sample!(scenarioproblems::ScenarioProblems{S}, sampler::AbstractSampler{Scenario}, n::Integer) where S <: AbstractScenario
    _sample!(scenarioproblems, sampler, n, num_scenarios(scenarioproblems), 1/n)
end
function sample!(scenarioproblems::DistributedScenarioProblems{S}, sampler::AbstractSampler{S}, n::Integer) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    m = nscenarios(scenarioproblems)
    (nscen, extra) = divrem(n, nworkers())
    @sync begin
        for w in workers()
            d = nscen + (extra > 0)
            @async remotecall_fetch(
                w,
                scenarioproblems[w-1],
                sampler,
                d,
                m,
                1/n) do sp, sampler, n, m, π
                    _sample!(fetch(sp), sampler, n, m, π)
                end
            scenarioproblems.scenario_distribution[w-1] += d
            extra -= 1
        end
    end
    return nothing
end
function sample!(scenarioproblems::DistributedScenarioProblems{S}, sampler::AbstractSampler{Scenario}, n::Integer) where S <: AbstractScenario
    isempty(scenarioproblems.scenarioproblems) && error("No remote scenario problems.")
    m = nscenarios(scenarioproblems)
    (nscen, extra) = divrem(n, nworkers())
    @sync begin
        for w in workers()
            d = nscen + (extra > 0)
            @async remotecall_fetch(
                w,
                scenarioproblems[w-1],
                sampler,
                d,
                m,
                1/n) do sp, sampler, n, m, π
                    _sample!(fetch(sp), sampler, n, m, π)
                end
            scenarioproblems.scenario_distribution[w-1] += d
            extra -= 1
        end
    end
    return nothing
end
function _sample!(scenarioproblems::ScenarioProblems, sampler::AbstractSampler, n::Integer, m::Integer, π::AbstractFloat)
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
