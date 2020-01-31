struct StochasticProgram{N, M, S <: NTuple{N, Stage}, SP <: Union{AbstractScenarioProblems, NTuple{M, AbstractScenarioProblems}}}
    stages::S
    scenarioproblems::SP
    generator::Dict{Symbol, Function}
    problemcache::Dict{Symbol, JuMP.Model}
    sp_optimizer::SPOptimizer

    function StochasticProgram(first_stage_params::Any,
                               second_stage_params::Any,
                               ::Type{S},
                               procs::Vector{Int},
                               optimizer_factory::Union{Nothing, OptimizerFactory}) where S <: AbstractScenario
        stages = (Stage(1, first_stage_params), Stage(2, second_stage_params))
        scenarioproblems = ScenarioProblems(S, procs)
        SP = typeof(scenarioproblems)
        return new{2, 1, typeof(stages), SP}(stages,
                                             scenarioproblems,
                                             Dict{Symbol, Function}(),
                                             Dict{Symbol, JuMP.Model}(),
                                             SPOptimizer(optimizer_factory))
    end

    function StochasticProgram(first_stage_params::Any,
                               second_stage_params::Any,
                               scenarios::Vector{<:AbstractScenario},
                               procs::Vector{Int},
                               optimizer_factory::Union{Nothing, OptimizerFactory})
        stages = (Stage(1, first_stage_params), Stage(2, second_stage_params))
        S = typeof(stages)
        scenarioproblems = ScenarioProblems(scenarios, procs)
        SP = typeof(scenarioproblems)
        return new{2, 1, S, SP}(stages,
                                scenarioproblems,
                                Dict{Symbol, Function}(),
                                Dict{Symbol, JuMP.Model}(),
                                SPOptimizer(optimizer_factory))
    end

    function StochasticProgram(stage_params::NTuple{N, Any},
                               scenario_types::NTuple{M, DataType},
                               solver::SPSolverType, procs::Vector{Int},
                               optimizer_factory::Union{Nothing, OptimizerFactory}) where {N, M}
        N >= 2 || error("Stochastic program needs at least two stages.")
        M == N - 1 || error("Inconsistent number of stages $N and number of scenario types $M")
        stages = ntuple(Val(N)) do i
            Stage(i, stage_params[i])
        end
        S = typeof(stages)
        scenarioproblems = ntuple(Val(M)) do i
            ScenarioProblems(scenarios[i], procs)
        end
        SP = typeof(scenarioproblems)
        return new{N, M, S, SP}(stages,
                                scenarioproblems,
                                Dict{Symbol, Function}(),
                                Dict{Symbol, JuMP.Model}(),
                                SPOptimizer(optimizer_factory))
    end

    function StochasticProgram(stage_params::NTuple{N, Any},
                               scenarios::NTuple{M, Vector{<:AbstractScenario}},
                               procs::Vector{Int},
                               optimizer_factory::Union{Nothing, OptimizerFactory}) where {N, M}
        N >= 2 || error("Stochastic program needs at least two stages.")
        M == N - 1 || error("Inconsistent number of stages $N and number of scenario types $M")
        stages = ntuple(Val(N)) do i
            Stage(i, stage_params[i])
        end
        S = typeof(stages)
        scenarioproblems = ntuple(Val(M)) do i
            ScenarioProblems(scenarios[i], procs)
        end
        SP = typeof(scenarioproblems)
        return new{N, M, S, SP}(stages,
                                scenarioproblems,
                                Dict{Symbol, Function}(),
                                Dict{Symbol, JuMP.Model}(),
                                SPOptimizer(optimizer_factory))
    end
end
TwoStageStochasticProgram{S <: Tuple{Stage, Stage}, SP <: AbstractScenarioProblems} = StochasticProgram{2, 1, S, SP}

# Constructors #
# ========================== #
# Two-stage
# ========================== #
"""
    StochasticProgram(first_stage_params::Any,
                      second_stage_params::Any,
                      optimizer_factory::Union{Nothing, OptimizerFactory}=nothing;
                      procs = workers())

Create a new two-stage stochastic program with stage data given by `first_stage_params` and `second_stage_params`. After construction, scenarios of type `Scenario` can be added through `add_scenario!`. Optionally, a capable `optimizer_factory` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(first_stage_params::Any,
                           second_stage_params::Any,
                           optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                           procs = workers()) where S <: AbstractScenario
    return StochasticProgram(first_stage_params, second_stage_params, Scenario, procs, optimizer_factory)
end
"""
    StochasticProgram(first_stage_params::Any,
                      second_stage_params::Any,
                      ::Type{S},
                      optimizer_factory::Union{Nothing, OptimizerFactory}=nothing;
                      procs = workers()) where S <: AbstractScenario

Create a new two-stage stochastic program with stage data given by `first_stage_params` and `second_stage_params`. After construction, scenarios of type `S` can be added through `add_scenario!`. Optionally, a capable `optimizer_factory` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(first_stage_params::Any,
                           second_stage_params::Any,
                           ::Type{S},
                           optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                           procs = workers()) where S <: AbstractScenario
    return StochasticProgram(first_stage_params, second_stage_params, S, procs, optimizer_factory)
end
"""
    StochasticProgram(optimizer_factory::Union{Nothing, OptimizerFactory}=nothing;
                      procs = workers())

Create a new two-stage stochastic program with scenarios of type `S` and no stage data. Optionally, a capable `optimizer_factory` can be supplied to later optimize the stochastic program.
"""
function StochasticProgram(optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                           procs = workers()) where S <: AbstractScenario
    return StochasticProgram(nothing, nothing, Scenario, optimizer_factory; procs = procs)
end
"""
    StochasticProgram(::Type{S},
                      optimizer_factory::Union{Nothing, OptimizerFactory}=nothing;
                      procs = workers()) where S <: AbstractScenario

Create a new two-stage stochastic program with scenarios of type `S` and no stage data. Optionally, a capable `optimizer_factory` can be supplied to later optimize the stochastic program.
"""
function StochasticProgram(::Type{S},
                           optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                           procs = workers()) where S <: AbstractScenario
    return StochasticProgram(nothing, nothing, S, optimizer_factory; procs = procs)
end
"""
    StochasticProgram(first_stage_params::Any,
                      second_stage_params::Any,
                      scenarios::Vector{<:AbstractScenario},
                      optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                      procs = workers())

Create a new two-stage stochastic program with a given collection of `scenarios`. Optionally, a capable `optimizer_factory` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(first_stage_params::Any,
                           second_stage_params::Any,
                           scenarios::Vector{<:AbstractScenario},
                           optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                           procs = workers())
    return StochasticProgram(first_stage_params, second_stage_params, scenarios, procs, optimizer_factory)
end
"""
    StochasticProgram(scenarios::Vector{<:AbstractScenario},
                      optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                      procs = workers()) where {SD <: AbstractScenario}

Create a new two-stage stochastic program with a given collection of `scenarios` and no stage data. Optionally, a capable `optimizer_factory` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(scenarios::Vector{<:AbstractScenario},
                           optimizer_factory::Union{Nothing, OptimizerFactory} = nothing;
                           procs = workers())
    return StochasticProgram(nothing, nothing, scenarios, optimizer_factory; procs = procs)
end

# Printing #
# ========================== #
function Base.show(io::IO, stochasticprogram::StochasticProgram{N}) where N
    plural(n) = (n==1 ? "" : "s")
    defer_stage(sp, s) = begin
        if deferred_stage(sp,s)
            return " * deferred stage $s"
        else
            xdim = decision_length(sp, s)
            n = nscenarios(sp, s)
            if s == 1
                if N == 2
                    return " * $(xdim) decision variable$(plural(xdim))"
                else
                    return " * Stage $s:\n   * $(xdim) decision variable$(plural(xdim))"
                end
            elseif s == 2 && N == 2
                stype = typename(scenariotype(stochasticprogram))
                return " * $(xdim) recourse variable$(plural(xdim))\n * $(n) scenario$(plural(n)) of type $stype"
            else
                stype = typename(scenariotype(stochasticprogram, s))
                if distributed(stochasticprogram, s)
                    return " * Distributed stage $s:\n   * $(xdim) decision variable$(plural(xdim))\n   * $(n) scenario$(plural(n)) of type $stype"
                else
                    return " * Stage $s:\n   * $(xdim) decision variable$(plural(xdim))\n   * $(n) scenario$(plural(n)) of type $stype"
                end
            end
        end
    end
    stage(sp, s) = begin
        stage_key = Symbol(:stage_,s)
        if has_generator(sp, stage_key)
            return defer_stage(sp,s)
        else
            " * undefined stage $s"
        end
    end
    if N == 2 && distributed(stochasticprogram)
        println(io, "Distributed stochastic program with:")
    else
        println(io, "Stochastic program with:")
    end
    println(io, stage(stochasticprogram, 1))
    for s = 2:N
        println(io, stage(stochasticprogram, s))
    end
    print(io, "Solver name: ")
    if sp_optimizer_factory(stochasticprogram) == nothing
        print(io, "No optimizer attached.")
    else
        print(io, optimizerstr(optimizer(stochasticprogram)))
    end
end
function Base.print(io::IO, stochasticprogram::StochasticProgram{N}) where N
    print(io, "Stage 1\n")
    print(io, "============== \n")
    print(io, get_stage_one(stochasticprogram))
    for s = 2:N
        print(io, "\nStage $s\n")
        print(io, "============== \n")
        for (id, subproblem) in enumerate(subproblems(stochasticprogram, s))
            @printf(io, "Subproblem %d (p = %.2f):\n", id, probability(scenario(stochasticprogram, id, s)))
            print(io, subproblem)
            print(io, "\n")
        end
    end
end
function Base.print(io::IO, stochasticprogram::StochasticProgram{2})
    print(io, "First-stage \n")
    print(io, "============== \n")
    print(io, get_stage_one(stochasticprogram))
    print(io, "\nSecond-stage \n")
    print(io, "============== \n")
    for (id, subproblem) in enumerate(subproblems(stochasticprogram))
        @printf(io, "Subproblem %d (p = %.2f):\n", id, probability(scenario(stochasticprogram, id)))
        print(io, subproblem)
        print(io, "\n")
    end
end
# ========================== #
