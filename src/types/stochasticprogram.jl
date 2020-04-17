struct StochasticProgram{N, T <: AbstractFloat, S <: NTuple{N, Stage}, ST <: AbstractStochasticStructure{N,T}}
    stages::S
    structure::ST
    generator::Dict{Symbol, Function}
    problemcache::Dict{Symbol, JuMP.Model}
    optimizer::StochasticProgramOptimizer

    function StochasticProgram(first_stage_params::Any,
                               second_stage_params::Any,
                               ::Type{T},
                               ::Type{S},
                               instantiation::StochasticInstantiation,
                               optimizer_constructor) where {T <: AbstractFloat, S <: AbstractScenario}
        stages = (Stage(first_stage_params), Stage(second_stage_params))
        optimizer = StochasticProgramOptimizer(optimizer_constructor)
        structure = StochasticStructure(T, S, default_structure(stochastic_structure, optimizer.optimizer))
        ST = typeof(structure)
        return new{2, 1, T, typeof(stages), ST}(stages,
                                                structure,
                                                Dict{Symbol, Function}(),
                                                Dict{Symbol, JuMP.Model}(),
                                                optimizer)
    end

    function StochasticProgram(first_stage_params::Any,
                               second_stage_params::Any,
                               ::Type{T},
                               scenarios::Vector{<:AbstractScenario},
                               instantiation::StochasticInstantiation,
                               optimizer_constructor) where T <: AbstractFloat
        stages = (Stage(first_stage_params), Stage(second_stage_params))
        S = typeof(stages)
        optimizer = StochasticProgramOptimizer(optimizer_constructor)
        structure = StochasticStructure(T, scenarios, default_structure(stochastic_structure, optimizer.optimizer))
        ST = typeof(structure)
        return new{2, 1, T, S, ST}(stages,
                                   structure,
                                   Dict{Symbol, Function}(),
                                   Dict{Symbol, JuMP.Model}(),
                                   optimizer)
    end

    function StochasticProgram(::Type{T},
                               stage_params::NTuple{N, Any},
                               scenario_types::NTuple{M, DataType},
                               instantiation::StochasticInstantiation,
                               optimizer_constructor) where {N, M, T <: AbstractFloat}
        N >= 2 || error("Stochastic program needs at least two stages.")
        M == N - 1 || error("Inconsistent number of stages $N and number of scenario types $M")
        stages = ntuple(Val(N)) do i
            Stage(stage_params[i])
        end
        S = typeof(stages)
        optimizer = StochasticProgramOptimizer(optimizer_constructor)
        structure = StochasticStructure(T, scenario_types, default_structure(instantiation, optimizer.optimizer))
        ST = typeof(structure)
        return new{N, M, T, S, ST}(stages,
                                   structure,
                                   Dict{Symbol, Function}(),
                                   Dict{Symbol, JuMP.Model}(),
                                   optimizer)
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
        optimizer = StochasticProgramOptimizer(optimizer_constructor)
        structure = StochasticStructure(T, scenario_types, default_structure(instantiation, optimizer.optimizer))
        ST = typeof(structure)
        return new{N, M, T, S, ST}(stages,
                                   structure,
                                   Dict{Symbol, Function}(),
                                   Dict{Symbol, JuMP.Model}(),
                                   optimizer)
    end
end
TwoStageStochasticProgram{T, S <: Tuple{Stage, Stage}, ST <: AbstractStochasticStructure{2,T}} = StochasticProgram{2, 1, T, S, ST}

# Constructors #
# ========================== #
# Two-stage
# ========================== #
"""
    StochasticProgram(first_stage_params::Any,
                      second_stage_params::Any,
                      ::Type{T},
                      instantiation::StochasticInstantiation,
                      optimizer_constructor=nothing) where T <: AbstractFloat

Create a new two-stage stochastic program with stage data given by `first_stage_params` and `second_stage_params`. After construction, scenarios of type `Scenario` can be added through `add_scenario!`. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(first_stage_params::Any,
                           second_stage_params::Any,
                           ::Type{T},
                           instantiation::StochasticInstantiation,
                           optimizer_constructor = nothing) where T <: AbstractFloat
    return StochasticProgram(first_stage_params, second_stage_params, T, Scenario, instantiation, optimizer_constructor)
end
"""
    StochasticProgram(first_stage_params::Any,
                      second_stage_params::Any,
                      ::Type{T},
                      ::Type{S},
                      instantiation::StochasticInstantiation,
                      optimizer_constructor=nothing) where {T <: AbstractFloat, S <: AbstractScenario}

Create a new two-stage stochastic program with stage data given by `first_stage_params` and `second_stage_params`. After construction, scenarios of type `S` can be added through `add_scenario!`. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(first_stage_params::Any,
                           second_stage_params::Any,
                           ::Type{T},
                           ::Type{S},
                           instantiation::StochasticInstantiation,
                           optimizer_constructor = nothing) where {T <: AbstractFloat, S <: AbstractScenario}
    return StochasticProgram(first_stage_params, second_stage_params, T, S, instantiation, optimizer_constructor)
end
"""
    StochasticProgram(instantiation::StochasticInstantiation, optimizer_constructor=nothing)

Create a new two-stage stochastic program with scenarios of type `S` and no stage data. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program.
"""
function StochasticProgram(instantiation::StochasticInstantiation, optimizer_constructor = nothing) where S <: AbstractScenario
    return StochasticProgram(nothing, nothing, Float64, Scenario, instantiation, optimizer_constructor; procs = procs)
end
"""
    StochasticProgram(::Type{T},
                      ::Type{S},
                      instantiation::StochasticInstantiation,
                      optimizer_constructor=nothing;
                      procs = workers()) where {T <: AbstractFloat, S <: AbstractScenario}

Create a new two-stage stochastic program with scenarios of type `S` and no stage data. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program.
"""
function StochasticProgram(::Type{T},
                           ::Type{S},
                           instantiation::StochasticInstantiation,
                           optimizer_constructor = nothing) where {T <: AbstractFloat, S <: AbstractScenario}
    return StochasticProgram(nothing, nothing, T, S, instantiation, optimizer_constructor; procs = procs)
end
"""
    StochasticProgram(first_stage_params::Any,
                      second_stage_params::Any,
                      ::Type{T},
                      scenarios::Vector{<:AbstractScenario},
                      instantiation::StochasticInstantiation,
                      optimizer_constructor = nothing) where T <: AbstractFloat

Create a new two-stage stochastic program with a given collection of `scenarios`. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(first_stage_params::Any,
                           second_stage_params::Any,
                           ::Type{T},
                           scenarios::Vector{<:AbstractScenario},
                           instantiation::StochasticInstantiation,
                           optimizer_constructor = nothing) where T <: AbstractFloat
    return StochasticProgram(first_stage_params, second_stage_params, T, scenarios, instantiation, optimizer_constructor)
end
"""
    StochasticProgram(::Type{T},
                      scenarios::Vector{<:AbstractScenario},
                      instantiation::StochasticInstantiation,
                      optimizer_constructor = nothing) where {T <: AbstractFloat}

Create a new two-stage stochastic program with a given collection of `scenarios` and no stage data. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(::Type{T},
                           scenarios::Vector{<:AbstractScenario},
                           instantiation::StochasticInstantiation,
                           optimizer_constructor = nothing) where T <: AbstractFloat
    return StochasticProgram(nothing, nothing, T, scenarios, instantiation, optimizer_constructor)
end
"""
    StochasticProgram(scenarios::Vector{<:AbstractScenario},
                      instantiation::StochasticInstantiation,
                      optimizer_constructor = nothing) where {T <: AbstractFloat}

Create a new two-stage stochastic program with a given collection of `scenarios` and no stage data. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(scenarios::Vector{<:AbstractScenario},
                           instantiation::StochasticInstantiation,
                           optimizer_constructor = nothing) where T <: AbstractFloat
    return StochasticProgram(nothing, nothing, Float64, scenarios, instantiation, optimizer_constructor)
end

# Printing #
# ========================== #
function Base.show(io::IO, stochasticprogram::StochasticProgram{N}) where N
    plural(n) = (n == 1 ? "" : "s")
    stage(sp, s) = begin
        stage_key = Symbol(:stage_,s)
        if has_generator(sp, stage_key)
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
        else
            " * undefined stage $s"
        end
    end
    if initialized(stochasticprogram)
        if N == 2 && distributed(stochasticprogram)
            println(io, "Distributed stochastic program with:")
        else
            println(io, "Stochastic program with:")
        end
    else
        println(io, "Uninitialized stochastic program with:")
    end
    print(io, stage(stochasticprogram, 1))
    for s = 2:N
        println(io,"")
        print(io, stage(stochasticprogram, s))
    end
    if initialized(stochasticprogram)
        println(io,"")
        print(io, "Solver name: ")
        print(io, optimizer_name(stochasticprogram))
    end
end
function Base.print(io::IO, stochasticprogram::StochasticProgram)
    if initialized(stochasticprogram)
        # Delegate printing according to stochastic structure
        print(io, structure(stochasticprogram))
    else
        # Just give summary if the stochastic program has not been initialized yet
        show(io, stochasticprogram)
    end
    print(io, "Solver name: ")
    print(io, optimizer_name(stochasticprogram))
end
function _print(io::IO, stochasticprogram::StochasticProgram, ::AbstractProvidedOptimizer)
    # Just give summary if no optimizer has been provided
    show(io, stochasticprogram)
end
# ========================== #
