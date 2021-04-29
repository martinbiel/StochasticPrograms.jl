struct StochasticProgram{N, S <: NTuple{N, Stage}, ST <: AbstractStochasticStructure{N}}
    stages::S
    decisions::NTuple{N, Decisions}
    structure::ST
    generator::Dict{Symbol, Function}
    problemcache::Dict{Symbol, JuMP.Model}
    solutioncache::Dict{Symbol, SolutionCache}
    optimizer::StochasticProgramOptimizer

    function StochasticProgram(stages::NTuple{N, Stage},
                               scenario_types::ScenarioTypes{M},
                               instantiation::StochasticInstantiation,
                               optimizer_constructor) where {N, M}
        N >= 2 || error("Stochastic program needs at least two stages.")
        M == N - 1 || error("Inconsistent number of stages $N and number of scenario types $M")
        S = typeof(stages)
        decisions = ntuple(Val(N)) do i
            Decisions()
        end
        optimizer = StochasticProgramOptimizer(optimizer_constructor)
        structure = StochasticStructure(decisions, scenario_types, default_structure(instantiation, optimizer.optimizer))
        ST = typeof(structure)
        return new{N, S, ST}(stages,
                             decisions,
                             structure,
                             Dict{Symbol, Function}(),
                             Dict{Symbol, JuMP.Model}(),
                             Dict{Symbol, SolutionCache}(),
                             optimizer)
    end

    function StochasticProgram(stages::NTuple{N, Stage},
                               scenarios::NTuple{M, Vector{<:AbstractScenario}},
                               instantiation::StochasticInstantiation,
                               optimizer_constructor) where {N, M}
        N >= 2 || error("Stochastic program needs at least two stages.")
        M == N - 1 || error("Inconsistent number of stages $N and number of scenario types $M")
        S = typeof(stages)
        decisions = ntuple(Val(N)) do i
            Decisions()
        end
        optimizer = StochasticProgramOptimizer(optimizer_constructor)
        structure = StochasticStructure(decisions, scenarios, default_structure(instantiation, optimizer.optimizer))
        ST = typeof(structure)
        return new{N, S, ST}(stages,
                             decisions,
                             structure,
                             Dict{Symbol, Function}(),
                             Dict{Symbol, JuMP.Model}(),
                             Dict{Symbol, SolutionCache}(),
                             optimizer)
    end
end
TwoStageStochasticProgram{S <: Tuple{Stage, Stage}, ST <: AbstractStochasticStructure{2}} = StochasticProgram{2, S, ST}

# Constructors #
# ========================== #
# Two-stage
# ========================== #
"""
    StochasticProgram(first_stage_params::Any,
                      second_stage_params::Any,
                      instantiation::StochasticInstantiation,
                      optimizer_constructor=nothing) where T <: AbstractFloat

Create a new two-stage stochastic program with stage data given by `first_stage_params` and `second_stage_params`. After construction, scenarios of type `Scenario` can be added through `add_scenario!`. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(first_stage_params::Any,
                           second_stage_params::Any,
                           instantiation::StochasticInstantiation,
                           optimizer_constructor = nothing)
    stages = (Stage(first_stage_params), Stage(second_stage_params))
    return StochasticProgram(stages, (Scenario,), instantiation, optimizer_constructor)
end
"""
    StochasticProgram(first_stage_params::Any,
                      second_stage_params::Any,
                      ::Type{Scenario},
                      instantiation::StochasticInstantiation,
                      optimizer_constructor=nothing) where Scenario <: AbstractScenario

Create a new two-stage stochastic program with stage data given by `first_stage_params` and `second_stage_params`. After construction, scenarios of type `S` can be added through `add_scenario!`. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(first_stage_params::Any,
                           second_stage_params::Any,
                           ::Type{Scenario},
                           instantiation::StochasticInstantiation,
                           optimizer_constructor = nothing) where Scenario <: AbstractScenario
    stages = (Stage(first_stage_params), Stage(second_stage_params))
    return StochasticProgram(stages, (Scenario,), instantiation, optimizer_constructor)
end
"""
    StochasticProgram(::Type{Scenario},
                      instantiation::StochasticInstantiation,
                      optimizer_constructor=nothing) where Scenario <: AbstractScenario

Create a new two-stage stochastic program with scenarios of type `Scenario` and no stage data. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program.
"""
function StochasticProgram(::Type{Scenario},
                           instantiation::StochasticInstantiation,
                           optimizer_constructor = nothing) where Scenario <: AbstractScenario
    stages = (Stage(nothing), Stage(nothing))
    return StochasticProgram(stages, (Scenario,), instantiation, optimizer_constructor; procs = procs)
end
"""
    StochasticProgram(first_stage_params::Any,
                      second_stage_params::Any,
                      scenarios::Vector{<:AbstractScenario},
                      instantiation::StochasticInstantiation,
                      optimizer_constructor = nothing)

Create a new two-stage stochastic program with a given collection of `scenarios`. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(first_stage_params::Any,
                           second_stage_params::Any,
                           scenarios::Vector{<:AbstractScenario},
                           instantiation::StochasticInstantiation,
                           optimizer_constructor = nothing)
    stages = (Stage(first_stage_params), Stage(second_stage_params))
    return StochasticProgram(stages, (scenarios,), instantiation, optimizer_constructor)
end
"""
    StochasticProgram(scenarios::Vector{<:AbstractScenario},
                      instantiation::StochasticInstantiation,
                      optimizer_constructor = nothing)

Create a new two-stage stochastic program with a given collection of `scenarios` and no stage data. Optionally, a capable `optimizer_constructor` can be supplied to later optimize the stochastic program. If multiple Julia processes are available, the resulting stochastic program will automatically be memory-distributed on these processes. This can be avoided by setting `procs = [1]`.
"""
function StochasticProgram(scenarios::Vector{<:AbstractScenario},
                           instantiation::StochasticInstantiation,
                           optimizer_constructor = nothing)
    stages = (Stage(nothing), Stage(nothing))
    return StochasticProgram(stages, (scenarios,), instantiation, optimizer_constructor)
end

function Base.copy(src::StochasticProgram{N}; instantiation = UnspecifiedInstantiation(), optimizer = nothing) where N
    stages = ntuple(Val(N)) do i
        Stage(stage_parameters(src, i))
    end
    scenario_types = ntuple(Val(N-1)) do i
        scenario_type(src, i+1)
    end
    dest = StochasticProgram(stages, scenario_types, instantiation, optimizer)
    merge!(dest.generator, src.generator)
    return dest
end

# Printing #
# ========================== #
function Base.show(io::IO, stochasticprogram::StochasticProgram{N}) where N
    plural(n) = (n == 1 ? "" : "s")
    stage(sp, s) = begin
        stage_key = Symbol(:stage_,s)
        ndecisions = num_decisions(sp, s)
        nscenarios = num_scenarios(sp, s)
        if s == 1
            if N == 2
                return " * $(ndecisions) decision variable$(plural(ndecisions))"
            else
                return " * Stage $s:\n   * $(ndecisions) decision variable$(plural(ndecisions))"
            end
        elseif s == 2 && N == 2
            stype = typename(scenario_type(stochasticprogram))
            return " * $(ndecisions) recourse variables\n * $(nscenarios) scenario$(plural(nscenarios)) of type $stype"
        else
            stype = typename(scenario_type(stochasticprogram, s))
            if distributed(stochasticprogram, s)
                if s == N
                    return " * Distributed stage $s:\n   * $(ndecisions) recourse variables\n * $(nscenarios) scenario$(plural(nscenarios)) of type $stype"
                else
                    return " * Distributed stage $s:\n   * $(ndecisions) decision variable$(plural(ndecisions))\n   * $(nscenarios) scenario$(plural(nscenarios)) of type $stype"
                end
            else
                if s == N
                    return " * Stage $s:\n   * $(ndecisions) recourse variables\n   * $(nscenarios) scenario$(plural(nscenarios)) of type $stype"
                else
                    return " * Stage $s:\n   * $(ndecisions) decision variable$(plural(ndecisions))\n   * $(nscenarios) scenario$(plural(nscenarios)) of type $stype"
                end
            end
        end
    end
    if deferred(stochasticprogram)
        n = num_scenarios(stochasticprogram)
        if n == 0
            return print(io, "Deferred stochastic program")
        else
            return print(io, "Deferred stochastic program with $n scenario$(plural(n))")
        end
    end
    if N == 2 && distributed(stochasticprogram)
        println(io, "Distributed stochastic program with:")
    else
        println(io, "Stochastic program with:")
    end
    print(io, stage(stochasticprogram, 1))
    for s = 2:N
        println(io,"")
        print(io, stage(stochasticprogram, s))
    end
    println(io,"")
    print(io, "Structure: ")
    print(io, structure_name(stochasticprogram))
    println(io,"")
    print(io, "Solver name: ")
    print(io, optimizer_name(stochasticprogram))
end
function Base.print(io::IO, stochasticprogram::StochasticProgram)
    if !deferred(stochasticprogram)
        # Delegate printing according to stochastic structure
        print(io, structure(stochasticprogram))
        print(io, "Solver name: ")
        print(io, optimizer_name(stochasticprogram))
    else
        # Just give summary if the stochastic program has not been initialized yet
        show(io, stochasticprogram)
    end
end
# ========================== #

# MOI #
# ========================== #
function MOI.get(stochasticprogram::StochasticProgram, attr::Union{MOI.TerminationStatus, MOI.PrimalStatus, MOI.DualStatus})
    # Check if there is a cached solution
    cache = solutioncache(stochasticprogram)
    if haskey(cache, :solution)
        # Returned cached solution if possible
        try
            return MOI.get(cache[:solution], attr)
        catch
        end
    end
    if haskey(cache, :node_solution_1)
        # Value was possibly only cached in first-stage solution
        try
            return MOI.get(cache[:node_solution_1], attr)
        catch
        end
    end
    return MOI.get(optimizer(stochasticprogram), attr)
end
function MOI.get(stochasticprogram::StochasticProgram, attr::MOI.AbstractModelAttribute)
    if MOI.is_set_by_optimize(attr)
        # Check if there is a cached solution
        cache = solutioncache(stochasticprogram)
        if haskey(cache, :solution)
            # Returned cached solution if possible
            try
                return MOI.get(cache[:solution], attr)
            catch
            end
        end
        if haskey(cache, :node_solution_1)
            # Value was possibly only cached in first-stage solution
            try
                return MOI.get(cache[:node_solution_1], attr)
            catch
            end
        end
        check_provided_optimizer(stochasticprogram.optimizer)
        if MOI.get(stochasticprogram, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        end
        return MOI.get(optimizer(stochasticprogram), attr)
    else
        if is_structure_independent(attr)
            # Get attribute from first stage of proxy if structure independent
            return MOI.get(proxy(stochasticprogram, 1), attr)
        else
            # Handle in structure otherwise
            return MOI.get(structure(stochasticprogram), attr)
        end
    end
end
function MOI.get(stochasticprogram::StochasticProgram, attr::ScenarioDependentModelAttribute)
    if MOI.is_set_by_optimize(attr)
        # Check if there is a cached solution
        cache = solutioncache(stochasticprogram)
        key = Symbol(:node_solution_, attr.stage, :_, attr.scenario_index)
        if haskey(cache, key)
            try
                return MOI.get(cache[key], attr.attr)
            catch
            end
        end
        check_provided_optimizer(stochasticprogram.optimizer)
        # Return statuses without checks
        if typeof(attr.attr) <: Union{MOI.TerminationStatus, MOI.PrimalStatus, MOI.DualStatus}
            try
                # Try to get scenario-dependent value directly
                return MOI.get(optimizer(stochasticprogram), attr)
            catch
                # Fallback to resolving scenario-dependence in structure if
                # not supported natively by optimizer
                return MOI.get(structure(stochasticprogram), attr)
            end
        end
        if MOI.get(stochasticprogram, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        end
        try
            # Try to get scenario-dependent value directly
            return MOI.get(optimizer(stochasticprogram), attr)
        catch
            # Fallback to resolving scenario-dependence in structure if
            # not supported natively by optimizer
            MOI.get(structure(stochasticprogram), attr)
        end
    else
        if is_structure_independent(attr)
            # Get attribute from first stage of proxy if structure independent
            return MOI.get(proxy(stochasticprogram, 1), attr)
        else
            # Handle in structure otherwise
            return MOI.get(structure(stochasticprogram), attr)
        end
    end
end
function MOI.get(stochasticprogram::StochasticProgram, attr::MOI.AbstractOptimizerAttribute)
    MOI.get(optimizer(stochasticprogram), attr)
end

function MOI.set(sp::StochasticProgram, attr::MOI.AbstractOptimizerAttribute, value)
    MOI.set(optimizer(sp), attr, value)
    return nothing
end
function MOI.set(sp::StochasticProgram, attr::MOI.AbstractModelAttribute, value)
    if is_structure_independent(attr)
        MOI.set(proxy(sp, attr.stage), attr, value)
    end
    MOI.set(structure(sp), attr, value)
    return nothing
end
function MOI.set(sp::StochasticProgram, attr::ScenarioDependentModelAttribute, value)
    if is_structure_independent(attr)
        MOI.set(proxy(sp, attr.stage), attr, value)
    end
    MOI.set(structure(sp), attr, value)
    return nothing
end

function MOI.set(sp::StochasticProgram, attr::MOI.Silent, flag)
    # Ensure that Silent is always passed
    MOI.set(structure(sp), attr, flag)
    # Pass to optimizer anyway
    MOI.set(optimizer(sp), attr, flag)
    return nothing
end

function JuMP.check_belongs_to_model(con_ref::ConstraintRef{<:StochasticProgram}, stochasticprogram::StochasticProgram)
    if owner_model(con_ref) !== model
        throw(ConstraintNotOwned(con_ref))
    end
end

Base.broadcastable(sp::StochasticProgram) = Ref(sp)
