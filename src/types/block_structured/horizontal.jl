"""
    HorizontalStructure

Horizontal memory structure. Decomposes stochastic program by scenario.

"""
struct HorizontalStructure{N, M, SP <: NTuple{M, AbstractScenarioProblems}} <: AbstractBlockStructure{N}
    decisions::Decisions{N}
    scenarioproblems::SP
    proxy::NTuple{N,JuMP.Model}

    function HorizontalStructure(decisions::Decisions{N}, scenarioproblems::NTuple{M,AbstractScenarioProblems}) where {N, M}
        M == N - 1 || error("Inconsistent number of stages $N and number of scenario types $M")
        SP = typeof(scenarioproblems)
        proxy = ntuple(Val{N}()) do _
            Model()
        end
        return new{N,M,SP}(decisions, scenarioproblems, proxy)
    end
end

function StochasticStructure(decisions::Decisions{N}, scenario_types::ScenarioTypes{M}, instantiation::Union{Horizontal, DistributedHorizontal}) where {N, M}
    scenarioproblems = ntuple(Val(M)) do i
        ScenarioProblems(scenario_types[i], instantiation)
    end
    return HorizontalStructure(decisions, scenarioproblems)
end

function StochasticStructure(decisions::Decisions{N}, scenarios::NTuple{M, Vector{<:AbstractScenario}}, instantiation::Union{Horizontal, DistributedHorizontal}) where {N, M}
    scenarioproblems = ntuple(Val(M)) do i
        ScenarioProblems(scenarios[i], instantiation)
    end
    return HorizontalStructure(decisions, scenarioproblems)
end

# Base overloads #
# ========================== #
function Base.print(io::IO, structure::HorizontalStructure{2})
    print(io, "Horizontal scenario problems \n")
    print(io, "============== \n")
    for (id, subproblem) in enumerate(subproblems(structure, 2))
        @printf(io, "Subproblem %d (p = %.2f):\n", id, probability(scenario(structure, 2, id)))
        print(io, subproblem)
        print(io, "\n")
    end
end

# MOI #
# ========================== #
function MOI.get(structure::HorizontalStructure, attr::MOI.AbstractModelAttribute)
    if attr isa Union{MOI.ObjectiveFunctionType, MOI.ObjectiveSense}
        # Can defer to proxy here
        return MOI.get(backend(structure.proxy[1]), attr)
    end
    error("The horizontal structure is completely decomposed into subproblems. All model attributes are scenario dependent.")
end
function MOI.get(structure::HorizontalStructure, attr::MOI.AbstractVariableAttribute, index::MOI.VariableIndex)
    error("The horizontal structure is completely decomposed into subproblems. All model attributes are scenario dependent.")
end
function MOI.get(structure::HorizontalStructure, attr::MOI.AbstractConstraintAttribute, ci::MOI.ConstraintIndex)
    error("The horizontal structure is completely decomposed into subproblems. All model attributes are scenario dependent.")
end
function MOI.get(structure::HorizontalStructure, attr::ScenarioDependentModelAttribute)
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    if attr.attr isa MOI.ObjectiveFunction
        return get_from_scenarioproblem(scenarioproblems(structure, attr.stage), attr.scenario_index, attr.stage) do sp, i, stage
            subprob = fetch(sp).problems[i]
            (sense, obj) = get_stage_objective(subprob, stage, 1)
            return obj
        end
    elseif attr.attr isa MOI.ObjectiveFunctionType
        return get_from_scenarioproblem(scenarioproblems(structure, attr.stage), attr.scenario_index, attr.stage) do sp, i, stage
            subprob = fetch(sp).problems[i]
            (sense, obj) = get_stage_objective(subprob, stage, 1)
            return typeof(moi_function(obj))
        end
    elseif attr.attr isa MOI.ObjectiveSense
        return get_from_scenarioproblem(scenarioproblems(structure, attr.stage), attr.scenario_index, attr.stage) do sp, i, stage
            subprob = fetch(sp).problems[i]
            (sense, obj) = get_stage_objective(subprob, stage, 1)
            return sense
        end
    else
        return MOI.get(scenarioproblems(structure, attr.stage), attr)
    end
end
function MOI.get(structure::HorizontalStructure, attr::ScenarioDependentVariableAttribute, index::MOI.VariableIndex)
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, attr.scenario_index)
    return MOI.get(scenarioproblems(structure, attr.stage), attr, mapped_vi)
end
function MOI.get(structure::HorizontalStructure, attr::ScenarioDependentConstraintAttribute, ci::MOI.ConstraintIndex)
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    mapped_ci = mapped_index(structure, ci, attr.scenario_index)
    return MOI.get(scenarioproblems(structure, attr.stage), attr, mapped_ci)
end
function MOI.get(structure::HorizontalStructure, attr::ScenarioDependentConstraintAttribute, ci::CI{F,S}) where {F <: Union{MOI.SingleVariable, SingleDecision}, S}
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, MOI.VariableIndex(ci.value), attr.scenario_index)
    mapped_ci = CI{F,S}(mapped_vi.value)
    return MOI.get(scenarioproblems(structure, attr.stage), attr, mapped_ci)
end

function MOI.set(structure::HorizontalStructure{2}, attr::Union{MOI.AbstractModelAttribute, MOI.Silent}, value)
    if attr isa MOI.ObjectiveFunction
        set_in_scenarioproblems!(scenarioproblems(structure), value) do sp, new_obj
            for (i,subprob) in enumerate(subproblems(fetch(sp)))
                # Get first-stage objective+sense
                (first_stage_sense, first_stage_obj) = get_stage_objective(subprob, 1)
                # Get second_stage objective+sense
                (sense, obj) = get_stage_objective(subprob, 2, 1)
                # Update first-stage objective
                set_stage_objective!(subprob, 1, new_sense, moi_function(new_obj))
                # Update sub objective
                sub_obj = if sense == first_stage_sense
                    sub_obj = new_obj + obj
                else
                    sub_obj = new_obj - obj
                end
                set_objective_function(subprob, sub_obj)
            end
            return nothing
        end
    elseif attr isa MOI.ObjectiveSense
        set_in_scenarioproblems!(scenarioproblems(structure), value) do sp, new_sense
            for (i,subprob) in enumerate(subproblems(fetch(sp)))
                # Get first-stage objective+sense
                (first_stage_sense, first_stage_obj) = get_stage_objective(subprob, 1)
                if first_stage_sense == new_sense
                    # Nothing to do
                    return nothing
                end
                # Get second_stage objective+sense
                (sense, obj) = get_stage_objective(subprob, 2, 1)
                # Update first-stage objective
                set_stage_objective!(subprob, 1, new_sense, moi_function(first_stage_obj))
                # Update sub objective
                sub_obj = if sense == new_sense
                    sub_obj = first_stage_obj + obj
                else
                    sub_obj = first_stage_obj - obj
                end
                set_objective_function(subprob, sub_obj)
            end
            return nothing
        end
    else
        # All subproblems should be updated
        MOI.set(scenarioproblems(structure), attr, value)
    end
end
function MOI.set(structure::HorizontalStructure{2}, attr::ScenarioDependentModelAttribute, value)
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    if attr.attr isa MOI.ObjectiveFunction
        set_in_scenarioproblem!(scenarioproblems(structure, attr.stage), attr.scenario_index, attr.stage, value) do sp, i, stage, value
            subprob = fetch(sp).problems[i]
            # Get first-stage objective+sense
            (sense, obj) = get_stage_objective(subprob, 1)
            # Update subobjective
            (sub_sense, prev_obj) = get_stage_objective(subprob, stage, 1)
            set_stage_objective!(subprob, stage, 1, sub_sense, value)
            new_obj = jump_function(structure.model, value)
            # Update main objective
            sub_obj = if sense == sub_sense
                sub_obj = obj + new_obj
            else
                sub_obj = obj - new_obj
            end
            set_objective_function(subprob, sub_obj)
            return nothing
        end
    elseif attr.attr isa MOI.ObjectiveSense
        set_in_scenarioproblem!(scenarioproblems(structure, attr.stage), attr.scenario_index, attr.stage, value) do sp, i, stage, value
            subprob = fetch(sp).problems[i]
            # Get current objective+sense
            (sense, obj) = get_stage_objective(subprob, stage, 1)
            if sense == value
                # Nothing to do
                return nothing
            end
            # Get first-stage objective+sense
            (first_stage_sense, first_stage_obj) = get_stage_objective(subprob, 1)
            # Update node sense
            set_stage_objective!(subprob, stage, 1, value, moi_function(obj))
            # Update sub objective
            sub_obj = if value == first_stage_sense
                sub_obj = first_stage_obj + obj
            else
                sub_obj = first_stage_obj - obj
            end
            set_objective_function(subprob, sub_obj)
            return nothing
        end
    else
        # Most attributes are set through the scenarioproblems
        MOI.set(scenarioproblems(structure, attr.stage), attr, value)
    end
    return nothing
end
function MOI.set(structure::HorizontalStructure{2}, attr::MOI.AbstractVariableAttribute,
                 index::MOI.VariableIndex, value)
    # All subproblems should be updated
    MOI.set(scenarioproblems(structure), attr, index, value)
    return nothing
end
function MOI.set(structure::HorizontalStructure{2}, attr::ScenarioDependentVariableAttribute,
                 index::MOI.VariableIndex, value)
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, attr.scenario_index)
    MOI.set(scenarioproblems(structure, attr.stage), attr, mapped_vi, value)
    return nothing
end
function MOI.set(structure::HorizontalStructure{2}, attr::MOI.AbstractConstraintAttribute,
                 ci::MOI.ConstraintIndex, value)
    # All subproblems should be updated
    MOI.set(scenarioproblems(structure), attr, ci, value)
    return nothing
end
function MOI.set(structure::HorizontalStructure{2}, attr::ScenarioDependentConstraintAttribute,
                 ci::MOI.ConstraintIndex, value)
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    mapped_ci = mapped_index(structure, ci, attr.scenario_index)
    MOI.set(scenarioproblems(structure, attr.stage), attr, mapped_ci, value)
    return nothing
end
function MOI.set(structure::HorizontalStructure{2}, attr::ScenarioDependentConstraintAttribute,
                 ci::MOI.ConstraintIndex{F,S}, value) where {F <: SingleDecision, S}
    n = num_scenarios(structure, attr.stage)
    1 <= attr.scenario_index <= n || error("Scenario index $attr.scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, MOI.VariableIndex(ci.value), attr.scenario_index)
    mapped_ci = CI{F,S}(mapped_vi.value)
    MOI.set(scenarioproblems(structure, attr.stage), attr, mapped_ci, value)
    return nothing
end

function MOI.is_valid(structure::HorizontalStructure{2}, index::MOI.VariableIndex, stage::Integer)
    stage == 1 || error("No scenario index specified.")
    # First-stage decision should be valid in all subproblems
    return all(MOI.is_valid(scenarioproblems(structure), index, scenario_index) for scenario_index in num_scenarios(structure))
end
function MOI.is_valid(structure::HorizontalStructure{2}, index::MOI.VariableIndex, stage::Integer, scenario_index::Integer)
    stage == 1 && error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, scenario_index)
    return MOI.is_valid(scenarioproblems(structure, stage), mapped_vi, scenario_index)
end
function MOI.is_valid(structure::HorizontalStructure{2}, ci::MOI.ConstraintIndex, stage::Integer)
    stage == 1 || error("No scenario index specified.")
    # First-stage decision constraint should be valid in all subproblems
    return all(MOI.is_valid(scenarioproblems(structure), ci, scenario_index) for scenario_index in num_scenarios(structure))
end
function MOI.is_valid(structure::HorizontalStructure{N}, ci::MOI.ConstraintIndex, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_ci = mapped_index(structure, ci, scenario_index)
    return MOI.is_valid(scenarioproblems(structure, stage), mapped_ci, scenario_index)
end
function MOI.is_valid(structure::HorizontalStructure{N}, ci::MOI.ConstraintIndex{F,S}, stage::Integer, scenario_index::Integer) where {N, F <: SingleDecision, S}
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    return MOI.is_valid(scenarioproblems(structure, stage), ci, scenario_index)
end

function MOI.delete(structure::HorizontalStructure{2}, indices::Vector{MOI.VariableIndex}, stage::Integer)
    stage == 1 || error("No scenario index specified.")
    # First-stage decision should be removed from every subproblem
    for scenario_index in 1:num_scenarios(structure)
        MOI.delete(scenarioproblems(structure), indices, scenario_index)
    end
    return nothing
end
function MOI.delete(structure::HorizontalStructure{N}, indices::Vector{MOI.VariableIndex}, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_indices = map(indices) do index
        return mapped_index(structure, index, scenario_index)
    end
    MOI.delete(scenarioproblems(structure, stage), mapped_indices, scenario_index)
    return nothing
end
function MOI.delete(structure::HorizontalStructure{2}, ci::MOI.ConstraintIndex, stage::Integer)
    stage == 1 || error("No scenario index specified.")
    # First-stage decision constraints should be removed from every subproblem
    for scenario_index in 1:num_scenarios(structure)
        MOI.delete(scenarioproblems(structure), ci, scenario_index)
    end
    return nothing
end
function MOI.delete(structure::HorizontalStructure{2}, cis::Vector{<:MOI.ConstraintIndex}, stage::Integer)
    stage == 1 || error("No scenario index specified.")
    # First-stage decision constraints should be removed from every subproblem
    for scenario_index in 1:num_scenarios(structure)
        MOI.delete(scenarioproblems(structure), cis, scenario_index)
    end
    return nothing
end
function MOI.delete(structure::HorizontalStructure{N}, ci::MOI.ConstraintIndex, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_ci = mapped_index(structure, ci, scenario_index)
    MOI.delete(scenarioproblems(structure, stage), mapped_ci, scenario_index)
    return nothing
end
function MOI.delete(structure::HorizontalStructure{N}, cis::Vector{<:MOI.ConstraintIndex}, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_cis = map(cis) do ci
        mapped_index(structure, ci, scenario_index)
    end
    MOI.delete(scenarioproblems(structure, stage), mapped_cis, scenario_index)
    return nothing
end

# JuMP #
# ========================== #
function decision_dispatch(decision_function::Function,
                           structure::HorizontalStructure{N},
                           index::MOI.VariableIndex,
                           stage::Integer,
                           args...) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    proxy_ = structure.proxy[stage]
    dref = DecisionRef(proxy_, index)
    return decision_function(dref, args...)
end
function decision_dispatch!(decision_function!::Function,
                            structure::HorizontalStructure{2},
                            index::MOI.VariableIndex,
                            stage::Integer,
                            args...)
    # First-stage decision mutators should be dispatched to every subproblem
    for scenario_index in 1:num_scenarios(structure)
        scenario_decision_dispatch!(decision_function!,
                                    scenarioproblems(structure),
                                    index,
                                    scenario_index,
                                    args...)
    end
    return nothing
end
function scenario_decision_dispatch(decision_function::Function,
                                    structure::HorizontalStructure{N},
                                    index::MOI.VariableIndex,
                                    stage::Integer,
                                    scenario_index::Integer,
                                    args...) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, scenario_index)
    return scenario_decision_dispatch(decision_function,
                                      scenarioproblems(structure, stage),
                                      mapped_vi,
                                      scenario_index,
                                      args...)
end
function scenario_decision_dispatch!(decision_function!::Function,
                                     structure::HorizontalStructure{N},
                                     index::MOI.VariableIndex,
                                     stage::Integer,
                                     scenario_index::Integer,
                                     args...) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, scenario_index)
    scenario_decision_dispatch!(decision_function!,
                                scenarioproblems(structure, stage),
                                mapped_vi,
                                scenario_index,
                                args...)
    return nothing
end
function JuMP.fix(structure::HorizontalStructure{2}, index::MOI.VariableIndex, stage::Integer, val::Number)
    d = decision(structure, index, stage)
    if state(d) == NotTaken
        # Update state
        d.state = Taken
        # Update value
        d.value = val
    else
        # Just update value
        d.value = val
    end
    update_decision_state!(scenarioproblems(structure), index, Taken)
    return nothing
end
function JuMP.fix(structure::HorizontalStructure{N}, index::MOI.VariableIndex, stage::Integer, scenario_index::Integer, val::Number) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, scenario_index)
    fix(scenarioproblems(structure, stage), mapped_vi, scenario_index, val)
    return nothing
end
function JuMP.unfix(structure::HorizontalStructure{2}, index::MOI.VariableIndex, stage::Integer)
    d = decision(structure, index, stage)
    if state(d) == NotTaken
        # Nothing to do, just return
        return nothing
    end
    # Update state
    d.state = NotTaken
    update_decision_state!(scenarioproblems(structure), index, NotTaken)
    return nothing
end
function JuMP.unfix(structure::HorizontalStructure{N}, index::MOI.VariableIndex, stage::Integer, scenario_index::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, scenario_index)
    unfix(scenarioproblems(structure, stage), mapped_vi, scenario_index)
    return nothing
end

function JuMP.set_objective_sense(structure::HorizontalStructure, stage::Integer, sense::MOI.OptimizationSense)
    if stage == 1
        MOI.set(structure, MOI.ObjectiveSense(), sense)
    else
        set_in_scenarioproblems!(scenarioproblems(structure), sense) do sp, new_sense
            for (i,subprob) in enumerate(subproblems(fetch(sp)))
                # Get first-stage objective+sense
                (first_stage_sense, first_stage_obj) = get_stage_objective(subprob, 1)
                # Get current objective+sense
                (sense, obj) = get_stage_objective(subprob, 2, 1)
                if sense == new_sense
                    # Nothing to do
                    return nothing
                end
                # Update node sense
                set_stage_objective!(subprob, 2, 1, new_sense, moi_function(obj))
                # Update sub objective
                sub_obj = if new_sense == first_stage_sense
                    sub_obj = first_stage_obj + obj
                else
                    sub_obj = first_stage_obj - obj
                end
                set_objective_function(subprob, sub_obj)
            end
            return nothing
        end
    end
    return nothing
end
function JuMP.objective_function_type(structure::HorizontalStructure)
    error("The horizontal structure is completely decomposed into subproblems. All model attributes are scenario dependent.")
end

function JuMP.objective_function(structure::HorizontalStructure, FunType::Type{<:AbstractJuMPScalar})
    error("The horizontal structure is completely decomposed into subproblems. All model attributes are scenario dependent.")
end

function JuMP.objective_function(structure::HorizontalStructure, stage::Integer, FunType::Type{<:AbstractJuMPScalar})
    return objective_function(structure.proxy[stage], FunType)
end

function JuMP._moi_optimizer_index(structure::HorizontalStructure, ci::CI)
    return decision_index(backend(structure.proxy[1]), ci)
end
function JuMP._moi_optimizer_index(structure::HorizontalStructure, ci::CI{F,S}) where {F <: SingleDecision, S}
    inner = mapped_constraint(structure.decisions, ci)
    inner.value == 0 && error("Constraint $ci not properly mapped.")
    return decision_index(backend(structure.proxy[1]), inner)
end
function JuMP._moi_optimizer_index(structure::HorizontalStructure, index::VI, scenario_index::Integer)
    mapped_vi = mapped_index(structure, index, scenario_index)
    return JuMP._moi_optimizer_index(scenarioproblems(structure), mapped_vi, scenario_index)
end
function JuMP._moi_optimizer_index(structure::HorizontalStructure, ci::CI{F,S}, scenario_index::Integer) where {F <: SingleDecision, S}
    num_first_stage_decisions = MOI.get(structure.proxy[1], MOI.NumberOfConstraints{MOI.SingleVariable,SingleDecisionSet{Float64}}())
    if ci.value <= num_first_stage_decisions
        return JuMP._moi_optimizer_index(scenarioproblems(structure), ci, scenario_index)
    else
        mapped_vi = mapped_index(structure, MOI.VariableIndex(ci.value), scenario_index)
        mapped_ci = CI{F,S}(mapped_vi.value)
        return JuMP._moi_optimizer_index(scenarioproblems(structure), mapped_ci, scenario_index)
    end
end

function JuMP.set_objective_coefficient(structure::HorizontalStructure{2}, index::VI, var_stage::Integer, stage::Integer, coeff::Real)
    if var_stage == 1
        if stage == 1
            # Modification should be applied in every subproblem
            for scenario_index in 1:num_scenarios(structure)
                set_objective_coefficient(scenarioproblems(structure), index, scenario_index, coeff)
            end
        else
            error("The horizontal structure is completely decomposed into subproblems. Can only modify first-stage part of objective for first-stage.")
        end
    else
        error("Decision is scenario dependent, consider `set_objective_coefficient(sp, dvar, stage, scenario_index, coeff)`.")
    end
    return nothing
end
function JuMP.set_objective_coefficient(structure::HorizontalStructure{N}, index::VI, var_stage::Integer, stage::Integer, scenario_index::Integer, coeff::Real) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = if var_stage == 1
        mapped_vi = index
    else
        mapped_vi = mapped_index(structure, index, scenario_index)
    end
    set_objective_coefficient(scenarioproblems(structure, stage), mapped_vi, scenario_index, coeff)
    return nothing
end

function JuMP.set_normalized_coefficient(structure::HorizontalStructure,
                                         ci::CI{F,S},
                                         index::VI,
                                         value) where {T, F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}, S}
    # Modification should be applied in every subproblem
    for scenario_index in 1:num_scenarios(structure)
        set_normalized_coefficient(scenarioproblems(structure), ci, index, scenario_index, value)
    end
    return nothing
end
function JuMP.set_normalized_coefficient(structure::HorizontalStructure{N},
                                         ci::CI{F,S},
                                         index::VI,
                                         var_stage::Integer,
                                         stage::Integer,
                                         scenario_index::Integer,
                                         value) where {N, T, F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}, S}
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, scenario_index)
    mapped_ci = mapped_index(structure, ci, scenario_index)
    set_normalized_coefficient(scenarioproblems(structure, stage), mapped_ci, mapped_vi, scenario_index, value)
    return nothing
end


function JuMP.normalized_coefficient(structure::HorizontalStructure{N},
                                     ci::CI{F,S},
                                     index::VI,
                                     var_stage::Integer,
                                     stage::Integer,
                                     scenario_index::Integer) where {N, T, F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}, S}
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, scenario_index)
    mapped_ci = mapped_index(structure, ci, scenario_index)
    return normalized_coefficient(scenarioproblems(structure, stage), mapped_ci, mapped_vi, scenario_index)
end

function JuMP.set_normalized_rhs(structure::HorizontalStructure,
                                 ci::CI{F,S},
                                 value) where {T,
                                               F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}},
                                               S <: MOIU.ScalarLinearSet{T}}
    # Modification should be applied in every subproblem
    for scenario_index in 1:num_scenarios(structure)
        set_normalized_rhs(scenarioproblems(structure), ci, scenario_index, value)
    end
    return nothing
end
function JuMP.set_normalized_rhs(structure::HorizontalStructure{N},
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
    set_normalized_rhs(scenarioproblems(structure, stage), mapped_ci, scenario_index, value)
    return nothing
end

function DecisionRef(structure::HorizontalStructure, index::VI)
    return DecisionRef(structure.proxy[1], index)
end

function JuMP.jump_function(structure::HorizontalStructure{N},
                            stage::Integer,
                            f::MOI.AbstractFunction) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    return JuMP.jump_function(structure.proxy[stage], f)
end
function JuMP.jump_function(structure::HorizontalStructure{N},
                            stage::Integer,
                            scenario_index::Integer,
                            f::MOI.AbstractFunction) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    # Remap to proxy indices
    num_first_stage_decisions = MOI.get(structure.proxy[1], MOI.NumberOfConstraints{MOI.SingleVariable,SingleDecisionSet{Float64}}())
    first_stage_offset = MOI.get(structure.proxy[1], MOI.NumberOfVariables()) - num_first_stage_decisions
    f = MOIU.map_indices(f) do vi
        if vi.value <= num_first_stage_decisions
            return vi
        else
            return MOI.VariableIndex(vi.value - first_stage_offset)
        end
    end
    return JuMP.jump_function(structure.proxy[stage], f)
end

# Getters #
# ========================== #
function structure_name(structure::HorizontalStructure)
    return "Horizontal"
end

function decision(structure::HorizontalStructure{N}, index::MOI.VariableIndex, stage::Integer) where N
    stage == 1 || error("No scenario index specified.")
    return decision(structure.decisions, stage, index)
end
function decision(structure::HorizontalStructure{N}, index::MOI.VariableIndex, stage::Integer, scenario_index::Integer) where N
    stage > 1 || error("There are no scenarios in the first stage.")
    n = num_scenarios(structure, stage)
    1 <= scenario_index <= n || error("Scenario index $scenario_index not in range 1 to $n.")
    mapped_vi = mapped_index(structure, index, scenario_index)
    return decision(scenarioproblems(structure, stage), mapped_vi, scenario_index)
end

# Setters #
# ========================== #
function update_known_decisions!(structure::HorizontalStructure{2})
    # Modification should be applied in every subproblem
    for scenario_index in 1:num_scenarios(structure)
        update_known_decisions!(scenarioproblems(structure), scenario_index)
    end
    return nothing
end

function untake_decisions!(structure::HorizontalStructure{2,1,NTuple{1,SP}}) where SP <: ScenarioProblems
    if untake_decisions!(structure.decisions[1])
        update_decisions!(scenarioproblems(structure), DecisionsStateChange())
    end
    return nothing
end
function untake_decisions!(structure::HorizontalStructure{2,1,NTuple{1,SP}}) where SP <: DistributedScenarioProblems
    sp = scenarioproblems(structure)
    @sync begin
        for (i,w) in enumerate(workers())
            @async remotecall_fetch(
                w, sp[w-1], sp.decisions[w-1]) do sp, d
                    if untake_decisions!(fetch(d))
                        update_decisions!(fetch(sp), DecisionsStateChange())
                    end
                end
        end
    end
    return nothing
end

# Indices
# ========================== #
function mapped_index(structure::HorizontalStructure{2}, index::MOI.VariableIndex, scenario_index::Integer)
    # The initial number of first-stage decisions is always given by
    num_first_stage_decisions = MOI.get(structure.proxy[1], MOI.NumberOfConstraints{MOI.SingleVariable,SingleDecisionSet{Float64}}())
    # Calculate offset from first-stage auxilliary variables (first-stage decisions are included in second-stage proxy, so deduct them)
    first_stage_offset = MOI.get(structure.proxy[1], MOI.NumberOfVariables()) - num_first_stage_decisions
    return MOI.VariableIndex(index.value + first_stage_offset)
end
function mapped_index(structure::HorizontalStructure{2}, ci::CI{F,S}, scenario_index::Integer) where {F,S}
    first_stage_offset = MOI.get(structure.proxy[1], MOI.NumberOfConstraints{F,S}())
    return CI{F,S}(ci.value + first_stage_offset)
end
