"""
    relative_gap(model::StochasticProgram)

Return the final relative optimality gap after a call to `optimize!(stochasticprogram)`.
"""
function JuMP.relative_gap(stochasticprogram::StochasticProgram)::Float64
    return MOI.get(stochasticprogram, MOI.RelativeGap())
end
"""
    relative_gap(model::StochasticProgram, stage::Integer, scenario_index::Integer)

Return the final relative optimality gap in the node at stage `stage` and
scenario `scenario_index` after a call to `optimize!(stochasticprogram)`.
"""
function JuMP.relative_gap(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)::Float64
    attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.RelativeGap())
    return MOI.get(stochasticprogram, attr)
end
"""
    objective_bound(stochasticprogram::StochasticProgram)

Return the best known bound on the optimal objective value after a call to `optimize!(stochasticprogram)`.
"""
function JuMP.objective_bound(stochasticprogram::StochasticProgram)::Float64
    return MOI.get(stochasticprogram, MOI.ObjectiveBound())
end
"""
    objective_bound(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)

Return the best known bound on the optimal objective value in the node at
stage `stage` and scenario `scenario_index` after a call to `optimize!(stochasticprogram)`.
"""
function JuMP.objective_bound(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)::Float64
    attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.ObjectiveBound())
    return MOI.get(stochasticprogram, attr)
end
"""
    objective_value(stochasticprogram::StochasticProgram; result::Int = 1)

Return the objective value associated with result index `result` of the most-recent solution after a call to `optimize!(stochasticprogram)`.
"""
function JuMP.objective_value(stochasticprogram::StochasticProgram; result::Int = 1)::Float64
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Switch on termination status
    status = JuMP.termination_status(stochasticprogram)
    if status in AcceptableTermination
        return MOI.get(stochasticprogram, MOI.ObjectiveValue(result))
    else
        if status == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        elseif status == MOI.INFEASIBLE
            @warn "Stochastic program is infeasible"
            return objective_sense(stochasticprogram) == MOI.MAX_SENSE ? -Inf : Inf
        elseif status == MOI.DUAL_INFEASIBLE
            @warn "Stochastic program is unbounded"
            return objective_sense(stochasticprogram) == MOI.MAX_SENSE ? Inf : -Inf
        else
            @warn("Stochastic program could not be solved, returned status: $status")
            return NaN
        end
    end
end
"""
    objective_value(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer; result::Int = 1)

Return the objective value of the node at stage `stage` and scenario `scenario_index` associated
with result index `result` of the most-recent solution after a call to `optimize!(stochasticprogram)`.
"""
function JuMP.objective_value(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer; result::Int = 1)::Float64
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Switch on termination status
    status = JuMP.termination_status(stochasticprogram, stage, scenario_index)
    if status in AcceptableTermination
        attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.ObjectiveValue(result))
        return MOI.get(stochasticprogram, attr)
    else
        if status == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        elseif status == MOI.INFEASIBLE
            @warn "Stochastic program is infeasible in node at ($stage,$scenario_index)"
            return objective_sense(stochasticprogram, stage, scenario_index) == MOI.MAX_SENSE ? -Inf : Inf
        elseif status == MOI.DUAL_INFEASIBLE
            @warn "Stochastic program is unbounded in node at ($stage,$scenario_index)"
            return objective_sense(stochasticprogram, stage, scenario_index) == MOI.MAX_SENSE ? Inf : -Inf
        else
            @warn("Stochastic program node at ($stage,$scenario_index) could not be solved, returned status: $status")
            return NaN
        end
    end
end
"""
    objective_value(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer; result::Int = 1)

Return the objective value of scenario `scenario_index` associated with result index `result`
of the most-recent solution after a call to `optimize!(stochasticprogram)`.
"""
function JuMP.objective_value(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer; result::Int = 1)::Float64
    return objective_value(stochasticprogram, 2, scenario_index; result = result)
end
"""
    dual_objective_value(stochasticprogram::StochasticProgram; result::Int = 1)

Return the objective value of the dual problem associated with result index `result`
of the most-recent solution after a call to `optimize!(stochasticprogram)`.
"""
function JuMP.dual_objective_value(stochasticprogram::StochasticProgram; result::Int = 1)::Float64
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Switch on termination status
    status = JuMP.termination_status(stochasticprogram)
    if status in AcceptableTermination
        return MOI.get(stochasticprogram, MOI.DualObjectiveValue(result))
    else
        if status == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        elseif status == MOI.INFEASIBLE
            @warn "Stochastic program is infeasible"
            return objective_sense(stochasticprogram) == MOI.MAX_SENSE ? Inf : -Inf
        elseif status == MOI.DUAL_INFEASIBLE
            @warn "Stochastic program is unbounded"
            return objective_sense(stochasticprogram) == MOI.MAX_SENSE ? -Inf : Inf
        else
            @warn("Stochastic program could not be solved, returned status: $status")
            return NaN
        end
    end
end
"""
    dual_objective_value(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer; result::Int = 1)

Return the objective value of the dual problem of the node at stage `stage` and scenario `scenario_index` associated
with result index `result` of the most-recent solution after a call to `optimize!(stochasticprogram)`.
"""
function JuMP.dual_objective_value(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer; result::Int = 1)::Float64
    # Throw NoOptimizer error if no recognized optimizer has been provided
    check_provided_optimizer(stochasticprogram.optimizer)
    # Switch on termination status
    status = JuMP.termination_status(stochasticprogram, stage, scenario_index)
    if status in AcceptableTermination
        attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.DualObjectiveValue(result))
        return MOI.get(stochasticprogram, attr)
    else
        if status == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        elseif status == MOI.INFEASIBLE
            @warn "Stochastic program is infeasible in node at ($stage,$scenario_index)"
            return objective_sense(stochasticprogram, stage, scenario_index) == MOI.MAX_SENSE ? Inf : -Inf
        elseif status == MOI.DUAL_INFEASIBLE
            @warn "Stochastic program is unbounded in node at ($stage,$scenario_index)"
            return objective_sense(stochasticprogram, stage, scenario_index) == MOI.MAX_SENSE ? -Inf : Inf
        else
            @warn("Stochastic program node at ($stage,$scenario_index) could not be solved, returned status: $status")
            return NaN
        end
    end
end
"""
    dual_objective_value(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer; result::Int = 1)

Return the objective value of the dual problem of scenario `scenario_index` associated with result index `result`
of the most-recent solution after a call to `optimize!(stochasticprogram)`.
"""
function JuMP.dual_objective_value(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer; result::Int = 1)::Float64
    return dual_objective_value(stochasticprogram, 2, scenario_index; result = result)
end
"""
    objective_sense(stochasticprogram::StochasticProgram)::MathOptInterface.OptimizationSense

Return the objective sense of the `stochasticprogram`.
"""
function JuMP.objective_sense(stochasticprogram::StochasticProgram)
    return MOI.get(stochasticprogram, MOI.ObjectiveSense())::MOI.OptimizationSense
end
"""
    objective_sense(stochasticprogram::StochasticProgram, stage::Integer)::MathOptInterface.OptimizationSense

Return the objective sense of the `stochasticprogram` stage `stage`.
"""
function JuMP.objective_sense(stochasticprogram::StochasticProgram{N}, stage::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    return objective_sense(proxy(stochasticprogram, stage))
end
"""
    objective_sense(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)::MathOptInterface.OptimizationSense

Return the objective sense in the node at stage `stage` and scenario `scenario_index`.
"""
function JuMP.objective_sense(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)
    attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.ObjectiveSense())
    return MOI.get(stochasticprogram, attr)::MOI.OptimizationSense
end
"""
    set_objective_sense(stochasticprogram::StochasticProgram, sense::MathOptInterface.OptimizationSense)

Sets the objective sense of the `stochasticprogram` to `sense`.
"""
function JuMP.set_objective_sense(stochasticprogram::StochasticProgram, sense::MOI.OptimizationSense)
    MOI.set(structure(stochasticprogram), MOI.ObjectiveSense(), sense)
    return nothing
end
"""
    set_objective_sense(stochasticprogram::StochasticProgram, stage::Integer, sense::MathOptInterface.OptimizationSense)

Sets the objective sense of the `stochasticprogram` at stage `stage` to `sense`.
"""
function JuMP.set_objective_sense(stochasticprogram::StochasticProgram{N}, stage::Integer, sense::MOI.OptimizationSense) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    # Modify proxy
    set_objective_sense(proxy(stochasticprogram, stage), sense)
    # Modify through structure
    MOI.set(structure(stochasticprogram), MOI.ObjectiveSense(), stage, sense)
    return nothing
end
"""
    set_objective_sense(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer, sense::MathOptInterface.OptimizationSense)

Sets the objective sense of the stochasticprogram node at stage `stage`
and scenario `scenario_index` to the given `sense`.
"""
function JuMP.set_objective_sense(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer, sense::MOI.OptimizationSense)
    attr = ScenarioDependentModelAttribute(stage, scenario_index, MOI.ObjectiveSense())
    MOI.set(structure(stochasticprogram), attr, sense)
    return nothing
end
"""
    objective_function_type(stochasticprogram::Stochasticprogram)::AbstractJuMPScalar

Return the type of the objective function of `stochasticprogram`.
"""
function JuMP.objective_function_type(stochasticprogram::StochasticProgram)
    return objective_function_type(structure(stochasticprogram))
end
"""
    objective_function_type(stochasticprogram::Stochasticprogram, stage::Integer)::AbstractJuMPScalar

Return the type of the objective function at stage `stage` of `stochasticprogram`.
"""
function JuMP.objective_function_type(stochasticprogram::StochasticProgram{N}, stage::Integer) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    return objective_function_type(proxy(stochasticprogram, stage))
end
"""
    objective_function_type(stochasticprogram::Stochasticprogram, stage::Integer, scenario_index::Integer)::AbstractJuMPScalar

Return the type of the objective function in the node at stage `stage` and scenario `scenario_index`.
"""
function JuMP.objective_function_type(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer)
    return objective_function_type(structure(stochasticprogram), stage, scenario_index)
end
"""
    objective_function(stochasticprogram::StochasticProgram,
                       T::Type{<:AbstractJuMPScalar}=objective_function_type(model))

Return an object of type `T` representing the full objective function of the `stochasticprogram`. Error if the objective is not convertible to type `T`.
"""
function JuMP.objective_function(stochasticprogram::StochasticProgram, FunType::Type{<:AbstractJuMPScalar} = objective_function_type(stochasticprogram))
    return objective_function(structure(stochasticprogram), FunType)
end
"""
    objective_function(stochasticprogram::StochasticProgram,
                       stage::Integer,
                       T::Type{<:AbstractJuMPScalar}=objective_function_type(model))

Return an object of type `T` representing the objective function at stage `stage` of the `stochasticprogram`. Error if the objective is not convertible to type `T`.
"""
function JuMP.objective_function(stochasticprogram::StochasticProgram{N},
                                 stage::Integer,
                                 FunType::Type{<:AbstractJuMPScalar} = objective_function_type(stochasticprogram, stage)) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    return objective_function(structure(stochasticprogram), stage, FunType)
end
"""
    objective_function(stochasticprogram::StochasticProgram,
                       stage::Integer,
                       scenario_index::Integer,
                       T::Type{<:AbstractJuMPScalar}=objective_function_type(model))

Return an object of type `T` representing the objective function in the node at
stage `stage` and scenario `scenario_index`. Error if the objective is not convertible to type `T`.
"""
function JuMP.objective_function(stochasticprogram::StochasticProgram,
                                 stage::Integer,
                                 scenario_index::Integer,
                                 FunType::Type{<:AbstractJuMPScalar} = objective_function_type(stochasticprogram, stage, scenario_index))
    return objective_function(structure(stochasticprogram), stage, scenario_index, FunType)
end
"""
    set_objective_coefficient(stochasticprogram::StochasticProgram, dvar::DecisionVariable, stage::Integer, coefficient::Real)

Set the linear objective coefficient associated with `dvar` to `coefficient` in stage `stage`.
"""
function JuMP.set_objective_coefficient(stochasticprogram::StochasticProgram, dvar::DecisionVariable, stage::Integer, coeff::Real)
    # Modify proxy
    proxy_ = proxy(stochasticprogram, stage)
    dref = DecisionRef(proxy_, index(dvar))
    set_objective_coefficient(proxy_, dref, coeff)
    # Modify objective through structure
    set_objective_coefficient(structure(stochasticprogram), index(dvar), StochasticPrograms.stage(dvar), stage, coeff)
end
"""
    set_objective_coefficient(stochasticprogram::StochasticProgram, dvar::DecisionVariable, stage::Integer, scenario_index::Integer, coefficient::Real)

Set the scenario-dependent linear objective coefficient at `scenario_index` associated with `dvar` to `coefficient` in stage `stage`.
"""
function JuMP.set_objective_coefficient(stochasticprogram::StochasticProgram, dvar::DecisionVariable, stage::Integer, scenario_index::Integer, coeff::Real)
    # Modify objective through structure
    set_objective_coefficient(structure(stochasticprogram), index(dvar), StochasticPrograms.stage(dvar), stage, scenario_index, coeff)
end
