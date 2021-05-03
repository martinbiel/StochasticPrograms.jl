"""
    DeterministicEquivalent

Deterministic equivalent memory structure. Stochastic program is stored as one large optimization problem. Supported by any standard `AbstractOptimizer`.

"""
struct DeterministicEquivalent{N, M, S <: NTuple{M, Scenarios}} <: AbstractStochasticStructure{N}
    decisions::NTuple{N, Decisions}
    scenarios::S
    sub_objectives::NTuple{N, Vector{Tuple{MOI.OptimizationSense, MOI.AbstractScalarFunction}}}
    model::JuMP.Model
    proxy::NTuple{N,JuMP.Model}

    function DeterministicEquivalent(decisions::NTuple{N, Decisions}, scenarios::NTuple{M, Scenarios}) where {N, M}
        M == N - 1 || error("Inconsistent number of stages $N and number of scenario types $M")
        sub_objectives = ntuple(Val(N)) do i
            Vector{Tuple{MOI.ObjectiveSense, MOI.AbstractScalarFunction}}()
        end
        proxy = ntuple(Val{N}()) do _
            Model()
        end
        S = typeof(scenarios)
        return new{N,M,S}(decisions, scenarios, sub_objectives, Model(), proxy)
    end
end

function StochasticStructure(decisions::NTuple{N, Decisions}, scenario_types::ScenarioTypes{M}, ::Deterministic) where {N, M}
    scenarios = ntuple(Val(M)) do i
        Vector{scenario_types[i]}()
    end
    return DeterministicEquivalent(decisions, scenarios)
end

function StochasticStructure(decisions::NTuple{N, Decisions}, scenarios::NTuple{M, Vector{<:AbstractScenario}}, ::Deterministic) where {N, M}
    return DeterministicEquivalent(decisions, scenarios)
end

# Base overloads #
# ========================== #
function Base.print(io::IO, structure::DeterministicEquivalent)
    print(io, "Deterministic equivalent problem\n")
    print(io, structure.model)
end
# ========================== #

# MOI #
# ========================== #
function MOI.get(structure::DeterministicEquivalent, attr::MOI.AbstractModelAttribute)
    return MOI.get(backend(structure.model), attr)
end
function MOI.get(structure::DeterministicEquivalent, attr::ScenarioDependentModelAttribute)
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    if attr.attr isa MOI.ObjectiveFunction
        return structure.sub_objectives[attr.stage][attr.scenario_index][2]
    elseif attr.attr isa MOI.ObjectiveFunctionType
        return typeof(structure.sub_objectives[attr.stage][attr.scenario_index][2])
    elseif attr.attr isa MOI.ObjectiveSense
        return structure.sub_objectives[attr.stage][attr.scenario_index][1]
    elseif attr.attr isa MOI.ObjectiveValue || attr.attr isa MOI.DualObjectiveValue
        return MOIU.eval_variables(structure.sub_objectives[attr.stage][attr.scenario_index][2]) do idx
            return MOI.get(backend(structure.model), MOI.VariablePrimal(), idx)
        end
    else
        # Most attributes are shared with the deterministic equivalent
        return MOI.get(backend(structure.model), attr.attr)
    end
end
function MOI.get(structure::DeterministicEquivalent, attr::MOI.AbstractVariableAttribute, index::MOI.VariableIndex)
    return MOI.get(backend(structure.model), attr, index)
end
function MOI.get(structure::DeterministicEquivalent, attr::ScenarioDependentVariableAttribute, index::MOI.VariableIndex)
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, attr.scenario_index)
    return MOI.get(backend(structure.model), attr.attr, mapped_vi)
end
function MOI.get(structure::DeterministicEquivalent, attr::MOI.AbstractConstraintAttribute, cindex::MOI.ConstraintIndex)
    return MOI.get(backend(structure.model), attr, cindex)
end
function MOI.get(structure::DeterministicEquivalent, attr::ScenarioDependentConstraintAttribute, ci::CI{F,S}) where {F,S}
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    mapped_ci = mapped_index(structure, ci, attr.scenario_index)
    return MOI.get(backend(structure.model), attr.attr, mapped_ci)
end
function MOI.get(structure::DeterministicEquivalent, attr::ScenarioDependentConstraintAttribute, ci::CI{F,S}) where {F <: Union{MOI.SingleVariable, SingleDecision}, S}
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, MOI.VariableIndex(ci.value), attr.scenario_index)
    mapped_ci = CI{F,S}(mapped_vi.value)
    return MOI.get(backend(structure.model), attr.attr, mapped_ci)
end

function MOI.set(structure::DeterministicEquivalent, attr::MOI.Silent, flag)
    MOI.set(backend(structure.model), attr, flag)
    return nothing
end
function MOI.set(structure::DeterministicEquivalent, attr::MOI.AbstractModelAttribute, value)
    if attr isa MOI.ObjectiveFunction
        # Get full objective+sense
        dep_obj = copy(value)
        obj_sense = objective_sense(structure.model)
        # Update first-stage objective
        structure.sub_objectives[1][1] = (obj_sense, value)
        # Update main objective
        for (i, sub_objective) in enumerate(structure.sub_objectives[2])
            (sense, func) = sub_objective
            if obj_sense == sense
                dep_obj += probability(structure, 2, i) * func
            else
                dep_obj -= probability(structure, 2, i) * func
            end
        end
        MOI.set(backend(structure.model), attr, dep_obj)
    elseif attr isa MOI.ObjectiveSense
        # Get full objective+sense
        prev_sense, dep_obj = structure.sub_objectives[1][1]
        # Update first-stage objective
        structure.sub_objectives[1][1] = (value, dep_obj)
        # Update main objective (if necessary)
        if value != prev_sense
            for (i, sub_objective) in enumerate(structure.sub_objectives[2])
                (sense, func) = sub_objective
                if value == sense
                    dep_obj += probability(structure, 2, i) * func
                else
                    dep_obj -= probability(structure, 2, i) * func
                end
            end
            MOI.set(backend(structure.model), MOI.ObjectiveFunction{typeof(dep_obj)}(), dep_obj)
        end
        MOI.set(backend(structure.model), MOI.ObjectiveSense(), value)
    else
        # Most attributes are shared with the deterministic equivalent
        MOI.set(backend(structure.model), attr, value)
    end
    return nothing
end
function MOI.set(structure::DeterministicEquivalent, attr::ScenarioDependentModelAttribute, value)
    if attr.attr isa MOI.ObjectiveFunction
        # Get full objective+sense
        obj_sense = objective_sense(structure.model)
        dep_obj = objective_function(structure.model)
        # Update subobjective
        (sub_sense, prev_func) = structure.sub_objectives[attr.stage][attr.scenario_index]
        structure.sub_objectives[attr.stage][attr.scenario_index] = (sub_sense, value)
        prev_sub_obj = jump_function(structure.model, prev_func)
        sub_obj = jump_function(structure.model, value)
        # Update main objective
        if obj_sense == sub_sense
            dep_obj += probability(structure, attr.stage, attr.scenario_index) * (sub_obj - prev_sub_obj)
        else
            dep_obj -= probability(structure, attr.stage, attr.scenario_index) * (sub_obj - prev_sub_obj)
        end
        MOI.set(backend(structure.model), attr.attr, moi_function(dep_obj))
    elseif attr.attr isa MOI.ObjectiveSense
        # Get full objective+sense
        obj_sense = objective_sense(structure.model)
        dep_obj = moi_function(objective_function(structure.model))
        # Update subobjective sense
        (prev_sense, func) = structure.sub_objectives[attr.stage][attr.scenario_index]
        structure.sub_objectives[attr.stage][attr.scenario_index] = (value, func)
        # Update main objective (if necessary)
        if value != prev_sense
            if value == obj_sense
                dep_obj += 2 * probability(structure, attr.stage, attr.scenario_index) * func
            else
                dep_obj -= 2 * probability(structure, attr.stage, attr.scenario_index) * func
            end
            MOI.set(backend(structure.model), MOI.ObjectiveFunction{typeof(dep_obj)}(), dep_obj)
        end
    else
        # Most attributes are shared with the deterministic equivalent
        MOI.set(backend(structure.model), attr.attr, value)
    end
    return nothing
end
function MOI.set(structure::DeterministicEquivalent, attr::MOI.AbstractVariableAttribute,
                 index::MOI.VariableIndex, value)
    MOI.set(backend(structure.model), attr, index, value)
    return nothing
end
function MOI.set(structure::DeterministicEquivalent, attr::ScenarioDependentVariableAttribute,
                 index::MOI.VariableIndex, value)
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, attr.scenario_index)
    MOI.set(backend(structure.model), attr.attr, mapped_vi, value)
    return nothing
end
function MOI.set(structure::DeterministicEquivalent, attr::MOI.AbstractConstraintAttribute,
                 ci::MOI.ConstraintIndex, value)
    MOI.set(backend(structure.model), attr, ci, value)
    return nothing
end
function MOI.set(structure::DeterministicEquivalent, attr::ScenarioDependentConstraintAttribute,
                 ci::CI{F,S}, value) where {F, S}
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    mapped_ci = mapped_index(structure, ci, attr.scenario_index)
    MOI.set(backend(structure.model), attr.attr, mapped_ci, value)
    return nothing
end
function MOI.set(structure::DeterministicEquivalent, attr::ScenarioDependentConstraintAttribute,
                 ci::CI{F,S}, value) where {F <: SingleDecision, S}
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, MOI.VariableIndex(ci.value), attr.scenario_index)
    mapped_ci = CI{F,S}(mapped_vi.value)
    MOI.set(backend(structure.model), attr.attr, mapped_ci, value)
    return nothing
end

function MOI.is_valid(structure::DeterministicEquivalent, index::MOI.VariableIndex, stage::Integer)
    stage == 1 || error("No scenario index specified.")
    return MOI.is_valid(backend(structure.model), index)
end
function MOI.is_valid(structure::DeterministicEquivalent, index::MOI.VariableIndex, stage::Integer, scenario_index::Integer)
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, scenario_index)
    return MOI.is_valid(backend(structure.model), mapped_vi)
end

function MOI.is_valid(structure::DeterministicEquivalent, ci::MOI.ConstraintIndex{F,S}, stage::Integer) where {F, S}
    stage == 1 || error("No scenario index specified.")
    return MOI.is_valid(backend(structure.model), ci)
end
function MOI.is_valid(structure::DeterministicEquivalent, ci::MOI.ConstraintIndex{F,S}, stage::Integer, scenario_index::Integer) where {F, S}
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_ci = mapped_index(structure, ci, scenario_index)
    return MOI.is_valid(backend(structure.model), mapped_ci)
end
function MOI.is_valid(structure::DeterministicEquivalent, ci::MOI.ConstraintIndex{F,S}, stage::Integer, scenario_index::Integer) where {F <: SingleDecision, S}
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, MOI.VariableIndex(ci.value), scenario_index)
    mapped_ci = CI{F,S}(mapped_vi.value)
    return MOI.is_valid(backend(structure.model), mapped_ci)
end

function MOI.add_constraint(structure::DeterministicEquivalent, f::SingleDecision, s::MOI.AbstractSet)
    return MOI.add_constraint(backend(structure.model), f, s)
end
function MOI.add_constraint(structure::DeterministicEquivalent, f::SingleDecision, s::MOI.AbstractSet, stage::Integer, scenario_index::Integer)
    stage == 1 && error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    g = MOIU.map_indices(f) do index
        return mapped_index(structure, index, scenario_index)
    end
    return MOI.add_constraint(backend(structure.model), g, s)
end

function MOI.delete(structure::DeterministicEquivalent, index::MOI.VariableIndex, stage::Integer)
    stage == 1 || error("No scenario index specified.")
    JuMP.delete(structure.model, DecisionRef(structure.model, index))
    return nothing
end
function MOI.delete(structure::DeterministicEquivalent{N}, index::MOI.VariableIndex, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, scenario_index)
    JuMP.delete(structure.model, DecisionRef(structure.model, mapped_vi))
    return nothing
end
function MOI.delete(structure::DeterministicEquivalent, indices::Vector{MOI.VariableIndex}, stage::Integer)
    stage == 1 || error("No scenario index specified.")
    JuMP.delete(structure.model, DecisionRef.(structure.model, indices))
    return nothing
end
function MOI.delete(structure::DeterministicEquivalent{N}, indices::Vector{MOI.VariableIndex}, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_indices = map(indices) do index
        return mapped_index(structure, index, scenario_index)
    end
    JuMP.delete(structure.model, DecisionRef.(structure.model, mapped_indices))
    return nothing
end
function MOI.delete(structure::DeterministicEquivalent, ci::MOI.ConstraintIndex, stage::Integer)
    stage == 1 || error("No scenario index specified.")
    MOI.delete(backend(structure.model), ci)
    return nothing
end
function MOI.delete(structure::DeterministicEquivalent, cis::Vector{<:MOI.ConstraintIndex}, stage::Integer)
    stage == 1 || error("No scenario index specified.")
    MOI.delete(backend(structure.model), cis)
    return nothing
end
function MOI.delete(structure::DeterministicEquivalent{N}, ci::MOI.ConstraintIndex{F,S}, stage::Integer, scenario_index::Integer) where {N, F, S}
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_ci = mapped_index(structure, ci, scenario_index)
    MOI.delete(backend(structure.model), mapped_ci)
    return nothing
end
function MOI.delete(structure::DeterministicEquivalent{N}, ci::MOI.ConstraintIndex{F,S}, stage::Integer, scenario_index::Integer) where {N, F <: SingleDecision, S}
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, MOI.VariableIndex(ci.value), scenario_index)
    mapped_ci = CI{F,S}(mapped_vi.value)
    MOI.delete(backend(structure.model), mapped_ci)
    return nothing
end
function MOI.delete(structure::DeterministicEquivalent{N}, cis::Vector{<:MOI.ConstraintIndex}, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_cis = map(cis) do ci
        return mapped_index(structure, ci, scenario_index)
    end
    MOI.delete(backend(structure.model), mapped_cis)
    return nothing
end
function MOI.delete(structure::DeterministicEquivalent{N}, cis::Vector{MOI.ConstraintIndex{F,S}}, stage::Integer, scenario_index::Integer) where {N, F <: SingleDecision, S}
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_cis = map(cis) do ci
        mapped_vi = mapped_index(structure, MOI.VariableIndex(ci.value), scenario_index)
        return CI{F,S}(mapped_vi.value)
    end
    MOI.delete(backend(structure.model), mapped_cis)
    return nothing
end

# JuMP #
# ========================== #
function JuMP.fix(structure::DeterministicEquivalent{N}, index::MOI.VariableIndex, stage::Integer, val::Number) where N
    dref = DecisionRef(structure.model, index)
    fix(dref, val)
    return nothing
end
function JuMP.fix(structure::DeterministicEquivalent{N}, index::MOI.VariableIndex, stage::Integer, scenario_index::Integer, val::Number) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    # Fix mapped decision
    mapped_vi = mapped_index(structure, index, scenario_index)
    dref = DecisionRef(structure.model, mapped_vi)
    fix(dref, val)
    return nothing
end
function JuMP.unfix(structure::DeterministicEquivalent{N}, index::MOI.VariableIndex, stage::Integer) where N
    dref = DecisionRef(structure.model, index)
    unfix(dref)
    return nothing
end
function JuMP.unfix(structure::DeterministicEquivalent{N}, index::MOI.VariableIndex, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    # Unfix mapped decision
    mapped_vi = mapped_index(structure, index, scenario_index)
    dref = DecisionRef(structure.model, mapped_vi)
    unfix(dref)
    return nothing
end

function JuMP.set_objective_sense(structure::DeterministicEquivalent, stage::Integer, sense::MOI.OptimizationSense)
    if stage == 1
        # Changes the first-stage sense modifies the whole objective as usual
        MOI.set(structure, MOI.ObjectiveSense(), sense)
    else
        # Every sub-objective in the given stage should be changed
        for scenario_index in 1:num_scenarios(structure, stage)
            # Use temporary model to apply modification
            attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.ObjectiveSense())
            MOI.set(structure, attr, sense)
        end
    end
    return nothing
end

function JuMP.objective_function_type(structure::DeterministicEquivalent)
    return jump_function_type(structure.model,
                              MOI.get(structure, MOI.ObjectiveFunctionType()))
end
function JuMP.objective_function_type(structure::DeterministicEquivalent{N}, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.ObjectiveFunctionType())
    return jump_function_type(structure.model,
                              MOI.get(structure, attr))
end

function JuMP.objective_function(structure::DeterministicEquivalent, FunType::Type{<:AbstractJuMPScalar})
    MOIFunType = moi_function_type(FunType)
    func = MOI.get(structure,
                   MOI.ObjectiveFunction{MOIFunType}())::MOIFunType
    return jump_function(structure.model, func)
end
function JuMP.objective_function(structure::DeterministicEquivalent, stage::Integer, FunType::Type{<:AbstractJuMPScalar})
    if stage == 1
        obj::FunType = jump_function(structure.model, structure.sub_objectives[stage][1][2])
        return obj
    else
        return objective_function(structure.proxy, FunType)
    end
end
function JuMP.objective_function(structure::DeterministicEquivalent{N},
                                 stage::Integer,
                                 scenario_index::Integer,
                                 FunType::Type{<:AbstractJuMPScalar}) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    MOIFunType = moi_function_type(FunType)
    attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.ObjectiveFunction{MOIFunType}())
    func = MOI.get(structure, attr)::MOIFunType
    return jump_function(structure.model, func)
end

function JuMP._moi_optimizer_index(structure::DeterministicEquivalent, index::VI)
    return decision_index(backend(structure.model), index)
end
function JuMP._moi_optimizer_index(structure::DeterministicEquivalent, index::VI, scenario_index::Integer)
    mapped_vi = mapped_index(structure, index, scenario_index)
    return decision_index(backend(structure.model), mapped_vi)
end
function JuMP._moi_optimizer_index(structure::DeterministicEquivalent, ci::CI)
    return decision_index(backend(structure.model), ci)
end
function JuMP._moi_optimizer_index(structure::DeterministicEquivalent, ci::CI, scenario_index::Integer)
    mapped_ci = mapped_index(structure, ci, scenario_index)
    return decision_index(backend(structure.model), mapped_ci)
end
function JuMP._moi_optimizer_index(structure::DeterministicEquivalent, ci::CI{F,S}, scenario_index::Integer) where {F <: SingleDecision, S}
    mapped_vi = mapped_index(structure, MOI.VariableIndex(ci.value), scenario_index)
    mapped_ci = CI{F,S}(mapped_vi.value)
    return decision_index(backend(structure.model), mapped_ci)
end

function JuMP.set_objective_coefficient(structure::DeterministicEquivalent{N}, index::VI, var_stage::Integer, stage::Integer, coeff::Real) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    var_stage <= stage || error("Can only modify coefficient in current stage of decision or subsequent stages from where decision is taken.")
    if var_stage == 1 && stage == 1
        # Use temporary model to apply modification
        obj = structure.sub_objectives[1][1][2]
        m = Model()
        MOI.set(backend(m), MOI.ObjectiveFunction{typeof(obj)}(), obj)
        dref = DecisionRef(m, index)
        set_objective_coefficient(m, dref, coeff)
        obj = objective_function(m)
        F = moi_function_type(typeof(obj))
        # Modify full objective
        MOI.set(structure, MOI.ObjectiveFunction{F}(), moi_function(obj))
    elseif (var_stage == 1 && stage > 1) || var_stage > 1
        for scenario_index in 1:num_scenarios(structure, stage)
            # Use temporary model to apply modification
            obj = structure.sub_objectives[stage][scenario_index][2]
            m = Model()
            F = moi_function_type(typeof(obj))
            MOI.set(backend(m), MOI.ObjectiveFunction{F}(), obj)
            dref = DecisionRef(m, index)
            set_objective_coefficient(m, dref, coeff)
            obj = objective_function(m)
            attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.ObjectiveFunction{typeof(obj)}())
            MOI.set(structure, attr, obj)
        end
    end
    return nothing
end
function JuMP.set_objective_coefficient(structure::DeterministicEquivalent{N}, index::VI, var_stage::Integer, stage::Integer, scenario_index::Integer, coeff::Real) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    if var_stage == 1
        # Use temporary model to apply modification
        obj = structure.sub_objectives[stage][scenario_index][2]
        m = Model()
        MOI.set(backend(m), MOI.ObjectiveFunction{typeof(obj)}(), obj)
        dref = DecisionRef(m, index)
        set_objective_coefficient(m, dref, coeff)
        obj = objective_function(m)
        F = moi_function_type(typeof(obj))
        attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.ObjectiveFunction{F}())
        MOI.set(structure, attr, moi_function(obj))
    else
        # Use temporary model to apply modification
        sense, obj = structure.sub_objectives[stage][scenario_index]
        m = Model()
        F = typeof(obj)
        MOI.set(backend(m), MOI.ObjectiveFunction{F}(), obj)
        mapped_vi = mapped_index(structure, index, scenario_index)
        dref = DecisionRef(m, mapped_vi)
        set_objective_coefficient(m, dref, coeff)
        obj = objective_function(m)
        structure.sub_objectives[stage][scenario_index] = (sense, moi_function(obj))
        # Set coefficient of mapped second-stage variable
        dref = DecisionRef(structure.model, mapped_vi)
        set_objective_coefficient(structure.model, dref, probability(structure, stage, scenario_index) * coeff)
    end
    return nothing
end

function JuMP.set_normalized_coefficient(structure::DeterministicEquivalent,
                                         ci::CI{F,S},
                                         index::VI,
                                         value) where {T, F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}, S}
    MOI.modify(backend(structure.model), ci,
               DecisionCoefficientChange(index, convert(T, value)))
    return nothing
end
function JuMP.set_normalized_coefficient(structure::DeterministicEquivalent{N},
                                         ci::CI{F,S},
                                         index::VI,
                                         stage::Integer,
                                         scenario_index::Integer,
                                         value) where {N, T, F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}, S}
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, scenario_index)
    mapped_ci = mapped_index(structure, ci, scenario_index)
    MOI.modify(backend(structure.model), mapped_ci,
               DecisionCoefficientChange(mapped_vi, convert(T, value)))
    return nothing
end

function JuMP.normalized_coefficient(structure::DeterministicEquivalent{N},
                                     ci::CI{F,S},
                                     index::VI,
                                     stage::Integer,
                                     scenario_index::Integer) where {N, T, F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}, S}
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_ci = mapped_index(structure, ci, scenario_index)
    f = MOI.get(structure, MOI.ConstraintFunction(), mapped_ci)::F
    mapped_vi = mapped_index(structure, index, scenario_index)
    dref = DecisionRef(structure.model, mapped_vi)
    return JuMP._affine_coefficient(jump_function(structure.model, f), dref)
end

function JuMP.set_normalized_rhs(structure::DeterministicEquivalent,
                                 ci::CI{F,S},
                                 value) where {T,
                                               F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}},
                                               S <: MOIU.ScalarLinearSet{T}}
    MOI.set(backend(structure.model), MOI.ConstraintSet(), ci,
            S(convert(T, value)))
    return nothing
end
function JuMP.set_normalized_rhs(structure::DeterministicEquivalent{N},
                                 ci::CI{F,S},
                                 stage::Integer,
                                 scenario_index::Integer,
                                 value) where {N,
                                               T,
                                               F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}},
                                               S <: MOIU.ScalarLinearSet{T}}
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_ci = mapped_index(structure, ci, scenario_index)
    MOI.set(backend(structure.model), MOI.ConstraintSet(), mapped_ci,
            S(convert(T, value)))
    return nothing
end

function DecisionRef(structure::DeterministicEquivalent, index::VI)
    return DecisionRef(structure.model, index)
end
function DecisionRef(structure::DeterministicEquivalent, index::VI, stage::Integer, scenario_index::Integer)
    mapped_vi = mapped_index(structure, index, scenario_index)
    return DecisionRef(structure.model, mapped_vi)
end
function DecisionRef(structure::DeterministicEquivalent{N}, index::VI, at_stage::Integer, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    return DecisionRef(structure.model, index)
end

function JuMP.jump_function(structure::DeterministicEquivalent{N},
                            stage::Integer,
                            f::MOI.AbstractFunction) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    return JuMP.jump_function(structure.model, f)
end

function JuMP.relax_integrality(structure::DeterministicEquivalent)
    unrelax = relax_decision_integrality(structure.model)
    return unrelax
end

# Getters #
# ========================== #
function structure_name(structure::DeterministicEquivalent)
    return "Deterministic equivalent"
end
function scenario_types(structure::DeterministicEquivalent{N}) where N
    return ntuple(Val{N-1}()) do i
        eltype(structure.scenarios[i])
    end
end
function proxy(structure::DeterministicEquivalent{N}, stage::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    return structure.proxy[stage]
end
function decision(structure::DeterministicEquivalent{N}, index::MOI.VariableIndex, stage::Integer) where N
    stage == 1 || error("No scenario index specified.")
    return decision(structure.decisions[stage], index)
end
function decision(structure::DeterministicEquivalent{N}, index::MOI.VariableIndex, stage::Integer, scenario_index::Integer) where N
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, scenario_index)
    return decision(structure.decisions[stage], mapped_vi)
end
function scenario(structure::DeterministicEquivalent{N}, stage::Integer, scenario_index::Integer) where N
    return structure.scenarios[stage-1][scenario_index]
end
function scenarios(structure::DeterministicEquivalent{N}, stage::Integer) where N
    return structure.scenarios[stage-1]
end
function subproblem(structure::DeterministicEquivalent, stage::Integer, scenario_index::Integer)
    error("The determinstic equivalent is not decomposed into subproblems.")
end
function subproblems(structure::DeterministicEquivalent, stage::Integer)
    error("The determinstic equivalent is not decomposed into subproblems.")
end
function num_subproblems(structure::DeterministicEquivalent, stage::Integer)
    return 0
end
function deferred(structure::DeterministicEquivalent)
    return num_variables(structure.model) == 0
end
# ========================== #

# Setters
# ========================== #
function update_known_decisions!(structure::DeterministicEquivalent)
    update_known_decisions!(structure.model)
    return nothing
end
function update_known_decisions!(structure::DeterministicEquivalent, stage::Integer, scenario_index::Integer)
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    update_known_decisions!(structure.model)
    return nothing
end

function add_scenario!(structure::DeterministicEquivalent, stage::Integer, scenario::AbstractScenario)
    push!(scenarios(structure, stage), scenario)
    return nothing
end
function add_worker_scenario!(structure::DeterministicEquivalent, stage::Integer, scenario::AbstractScenario, w::Integer)
    add_scenario!(structure, scenario, stage)
    return nothing
end
function add_scenario!(scenariogenerator::Function, structure::DeterministicEquivalent, stage::Integer)
    add_scenario!(structure, stage, scenariogenerator())
    return nothing
end
function add_worker_scenario!(scenariogenerator::Function, structure::DeterministicEquivalent, stage::Integer, w::Integer)
    add_scenario!(scenariogenerator, structure, stage)
    return nothing
end
function add_scenarios!(structure::DeterministicEquivalent, stage::Integer, _scenarios::Vector{<:AbstractScenario})
    append!(scenarios(structure, stage), _scenarios)
    return nothing
end
function add_worker_scenarios!(structure::DeterministicEquivalent, stage::Integer, scenarios::Vector{<:AbstractScenario}, w::Integer)
    add_scenarios!(structure, scenarios, stasge)
    return nothing
end
function add_scenarios!(scenariogenerator::Function, structure::DeterministicEquivalent, stage::Integer, n::Integer)
    for i = 1:n
        add_scenario!(structure, stage) do
            return scenariogenerator()
        end
    end
    return nothing
end
function add_worker_scenarios!(scenariogenerator::Function, structure::DeterministicEquivalent, stage::Integer, n::Integer, w::Integer)
    add_scenarios!(scenariogenerator, structure, n, stage)
    return nothing
end
function sample!(structure::DeterministicEquivalent, stage::Integer, sampler::AbstractSampler, n::Integer)
    sample!(scenarios(structure, stage), sampler, n)
    return nothing
end
# ========================== #

# Indices
# ========================== #
function mapped_index(structure::DeterministicEquivalent{2}, index::MOI.VariableIndex, scenario_index::Integer)
    first_stage_offset = -(scenario_index - 1) * MOI.get(structure.proxy[1], MOI.NumberOfVariables())
    scenario_offset = (scenario_index - 1) * MOI.get(structure.proxy[2], MOI.NumberOfVariables())
    return MOI.VariableIndex(index.value + first_stage_offset + scenario_offset)
end
function mapped_index(structure::DeterministicEquivalent{2}, ci::CI{F,S}, scenario_index::Integer) where {F,S}
    first_stage_offset = MOI.get(structure.proxy[1], MOI.NumberOfConstraints{F,S}())
    scenario_offset = (scenario_index - 1) * MOI.get(structure.proxy[2], MOI.NumberOfConstraints{F,S}())
    return CI{F,S}(ci.value + first_stage_offset + scenario_offset)
end
