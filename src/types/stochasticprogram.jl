
struct StochasticProgram{N, M, T <: AbstractFloat, S <: NTuple{N, Stage}, SP <: Union{AbstractScenarioProblems, NTuple{M, AbstractScenarioProblems}}}
    stages::S
    scenarioproblems::SP
    decision_variables::NTuple{M, DecisionVariables{T}}
    generator::Dict{Symbol, Function}
    problemcache::Dict{Symbol, JuMP.Model}
    optimizer::StochasticProgramOptimizer

    function StochasticProgram(first_stage_params::Any,
                               second_stage_params::Any,
                               ::Type{T},
                               ::Type{S},
                               procs::Vector{Int},
                               optimizer_constructor) where {T <: AbstractFloat, S <: AbstractScenario}
        stages = (Stage(1, first_stage_params), Stage(2, second_stage_params))
        scenarioproblems = ScenarioProblems(T, S, procs)
        SP = typeof(scenarioproblems)
        return new{2, 1, T, typeof(stages), SP}(stages,
                                                scenarioproblems,
                                                (DecisionVariables(T),),
                                                Dict{Symbol, Function}(),
                                                Dict{Symbol, JuMP.Model}(),
                                                StochasticProgramOptimizer(optimizer_constructor))
    end

    function StochasticProgram(first_stage_params::Any,
                               second_stage_params::Any,
                               ::Type{T},
                               scenarios::Vector{<:AbstractScenario},
                               procs::Vector{Int},
                               optimizer_constructor) where T <: AbstractFloat
        stages = (Stage(1, first_stage_params), Stage(2, second_stage_params))
        S = typeof(stages)
        scenarioproblems = ScenarioProblems(T, scenarios, procs)
        SP = typeof(scenarioproblems)
        return new{2, 1, T, S, SP}(stages,
                                   scenarioproblems,
                                   (DecisionVariables(T),),
                                   Dict{Symbol, Function}(),
                                   Dict{Symbol, JuMP.Model}(),
                                   StochasticProgramOptimizer(optimizer_constructor))
    end

    function StochasticProgram(::Type{T},
                               stage_params::NTuple{N, Any},
                               scenario_types::NTuple{M, DataType},
                               optimizer_constructor) where {N, M, T <: AbstractFloat}
        N >= 2 || error("Stochastic program needs at least two stages.")
        M == N - 1 || error("Inconsistent number of stages $N and number of scenario types $M")
        stages = ntuple(Val(N)) do i
            Stage(i, stage_params[i])
        end
        S = typeof(stages)
        scenarioproblems = ntuple(Val(M)) do i
            ScenarioProblems(T, scenarios[i], procs)
        end
        decision_variables = ntuple(Val(M)) do i
            DecisionVariables(T)
        end
        SP = typeof(scenarioproblems)
        return new{N, M, T, S, SP}(stages,
                                   scenarioproblems,
                                   decision_variables,
                                   Dict{Symbol, Function}(),
                                   Dict{Symbol, JuMP.Model}(),
                                   StochasticProgram(optimizer_constructor))
    end

    function StochasticProgram(::Type{T},
                               stage_params::NTuple{N, Any},
                               scenarios::NTuple{M, Vector{<:AbstractScenario}},
                               procs::Vector{Int},
                               optimizer_constructor) where {N, M, T <: AbstractFloat}
        N >= 2 || error("Stochastic program needs at least two stages.")
        M == N - 1 || error("Inconsistent number of stages $N and number of scenario types $M")
        stages = ntuple(Val(N)) do i
            Stage(i, stage_params[i])
        end
        S = typeof(stages)
        scenarioproblems = ntuple(Val(M)) do i
            ScenarioProblems(T, scenarios[i], procs)
        end
        decision_variables = ntuple(Val(M)) do i
            DecisionVariables(T)
        end
        SP = typeof(scenarioproblems)
        return new{N, M, T, S, SP}(stages,
                                   scenarioproblems,
                                   decision_variables,
                                   Dict{Symbol, Function}(),
                                   Dict{Symbol, JuMP.Model}(),
                                   StochasticProgram(optimizer_constructor))
    end
end
TwoStageStochasticProgram{T, S <: Tuple{Stage, Stage}, SP <: AbstractScenarioProblems} = StochasticProgram{2, 1, T, S, SP}

# Constructors #
# ========================== #
# Two-stage
# ========================== #
"""
    StochasticProgram(first_stage_params::Any,
                      second_stage_params::Any,
                      ::Type{T},
                      optimizer_constructor=nothing;
                      procs = workers()) where T <: AbstractFloat

Create a new two-stage stochastic program with stage data given by `first_stage_params` and `second_stage_params`. After construction, scenarios of type `Scenario` can be added through `add_scenario!`. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(first_stage_params::Any,
                           second_stage_params::Any,
                           ::Type{T},
                           optimizer_constructor = nothing;
                           procs = workers()) where T <: AbstractFloat
    return StochasticProgram(first_stage_params, second_stage_params, T, Scenario, procs, optimizer_constructor)
end
"""
    StochasticProgram(first_stage_params::Any,
                      second_stage_params::Any,
                      ::Type{T},
                      ::Type{S},
                      optimizer_constructor=nothing;
                      procs = workers()) where {T <: AbstractFloat, S <: AbstractScenario}

Create a new two-stage stochastic program with stage data given by `first_stage_params` and `second_stage_params`. After construction, scenarios of type `S` can be added through `add_scenario!`. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(first_stage_params::Any,
                           second_stage_params::Any,
                           ::Type{T},
                           ::Type{S},
                           optimizer_constructor = nothing;
                           procs = workers()) where {T <: AbstractFloat, S <: AbstractScenario}
    return StochasticProgram(first_stage_params, second_stage_params, T, S, procs, optimizer_constructor)
end
"""
    StochasticProgram(optimizer_constructor=nothing;
                      procs = workers())

Create a new two-stage stochastic program with scenarios of type `S` and no stage data. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program.
"""
function StochasticProgram(optimizer_constructor = nothing;
                           procs = workers()) where S <: AbstractScenario
    return StochasticProgram(nothing, nothing, Float64, Scenario, optimizer_constructor; procs = procs)
end
"""
    StochasticProgram(::Type{T},
                      ::Type{S},
                      optimizer_constructor=nothing;
                      procs = workers()) where {T <: AbstractFloat, S <: AbstractScenario}

Create a new two-stage stochastic program with scenarios of type `S` and no stage data. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program.
"""
function StochasticProgram(::Type{T},
                           ::Type{S},
                           optimizer_constructor = nothing;
                           procs = workers()) where {T <: AbstractFloat, S <: AbstractScenario}
    return StochasticProgram(nothing, nothing, T, S, optimizer_constructor; procs = procs)
end
"""
    StochasticProgram(first_stage_params::Any,
                      second_stage_params::Any,
                      ::Type{T},
                      scenarios::Vector{<:AbstractScenario},
                      optimizer_constructor = nothing;
                      procs = workers()) where T <: AbstractFloat

Create a new two-stage stochastic program with a given collection of `scenarios`. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(first_stage_params::Any,
                           second_stage_params::Any,
                           ::Type{T},
                           scenarios::Vector{<:AbstractScenario},
                           optimizer_constructor = nothing;
                           procs = workers()) where T <: AbstractFloat
    return StochasticProgram(first_stage_params, second_stage_params, scenarios, procs, optimizer_constructor)
end
"""
    StochasticProgram(::Type{T},
                      scenarios::Vector{<:AbstractScenario},
                      optimizer_constructor = nothing;
                      procs = workers()) where {T <: AbstractFloat}

Create a new two-stage stochastic program with a given collection of `scenarios` and no stage data. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(::Type{T},
                           scenarios::Vector{<:AbstractScenario},
                           optimizer_constructor = nothing;
                           procs = workers()) where T <: AbstractFloat
    return StochasticProgram(nothing, nothing, T, scenarios, optimizer_constructor; procs = procs)
end

# Printing #
# ========================== #
function optimizer_name(stochasticprogram::StochasticProgram)
    if optimizer(stochasticprogram) == nothing
        return "No optimizer attached."
    else
        return JuMP._try_get_solver_name(optimizer(stochasticprogram))
    end
end
JuMP._try_get_solver_name(optimizer::AbstractStructuredOptimizer) = solver_name(optimizer)

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
    if optimizer(stochasticprogram) == nothing
        print(io, "No optimizer attached.")
    else
        print(io, optimizer_name(optimizer(stochasticprogram)))
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
