# JuMP Objectives/constraints #
# ========================== #
function JuMP.set_objective_coefficient(model::Model, decision_or_known::Union{DecisionRef, KnownRef}, coeff::Real)
    if model.nlp_data !== nothing && _nlp_objective_function(model) !== nothing
        error("A nonlinear objective is already set in the model")
    end

    obj_fct_type = objective_function_type(model)
    if obj_fct_type == VariableRef
        # Nothing to do
        return nothing
    elseif obj_fct_type == typeof(decision_or_known)
        current_obj = objective_function(model)
        if index(current_obj) == index(decision_or_known)
            set_objective_function(model, coeff * decision_or_known)
        else
            set_objective_function(model, add_to_expression!(coeff * decision_or_known, current_obj))
        end
    elseif obj_fct_type == AffExpr || obj_fct_type == QuadExpr
        # Nothing to do
        return nothing
    elseif obj_fct_type == CombinedAffExpr{Float64} && decision_or_known isa DecisionRef
        MOI.modify(backend(model),
                   MOI.ObjectiveFunction{moi_function_type(obj_fct_type)}(),
                   MOI.DecisionCoefficientChange(index(decision_or_known), coeff)
                   )
    elseif obj_fct_type == CombinedAffExpr{Float64} && decision_or_known isa KnownRef
        MOI.modify(backend(model),
                   MOI.ObjectiveFunction{moi_function_type(obj_fct_type)}(),
                   MOI.KnownCoefficientChange(index(decision_or_known), coeff, value(decision_or_known))
                   )
    else
        error("Objective function type not supported: $(obj_fct_type)")
    end
    return nothing
end

function JuMP.set_normalized_coefficient(
    con_ref::ConstraintRef{Model, JuMP._MOICON{F, S}}, decision::DecisionRef, coeff
    ) where {S, T, F <: AffineDecisionFunction{T}}
    MOI.modify(backend(owner_model(con_ref)), index(con_ref),
               DecisionCoefficientChange(index(decision), convert(T, coeff)))
    return nothing
end

function JuMP.set_normalized_coefficient(
    con_ref::ConstraintRef{Model, JuMP._MOICON{F, S}}, known::KnownRef, coeff
    ) where {S, T, F <: AffineDecisionFunction{T}}
    MOI.modify(backend(owner_model(con_ref)), index(con_ref),
               KnownCoefficientChange(index(known), convert(T, coeff), convert(T, value(known))))
    return nothing
end

# Internal update functions #
# ========================== #
function update_decisions!(model::JuMP.Model, change::DecisionModification)
    update_decision_objective!(model, change)
    update_decision_constraints!(model, change)
end

function update_decision_objective!(model::JuMP.Model, change::DecisionModification)
    func_type = objective_function_type(model)
    if func_type <: CombinedAffExpr
        # Only need to update if there are decision variables in objective
        MOI.modify(backend(model),
                   MOI.ObjectiveFunction{JuMP.moi_function_type(func_type)}(),
                   change)
    end
    return nothing
end

function update_decision_constraints!(model::JuMP.Model, change::DecisionModification)
    for F in [CombinedAffExpr{Float64}, DecisionRef]
        for S in [MOI.EqualTo{Float64}, MOI.LessThan{Float64}, MOI.GreaterThan{Float64}]
            for cref in all_constraints(model, F, S)
                update_decision_constraint!(cref, change)
            end
        end
    end
end

function update_decision_constraint!(cref::ConstraintRef, change::DecisionModification)
    update_decision_constraint!(backend(owner_model(cref)), cref.index, change)
    return nothing
end

function update_decision_constraint!(model::MOI.ModelLike, ci::MOI.ConstraintIndex{SingleDecision, S}, change::DecisionModification) where {T,S}
    MOI.modify(model, ci, change)
    return nothing
end

function update_decision_constraint!(model::MOI.ModelLike, ci::MOI.ConstraintIndex{AffineDecisionFunction{T}, S}, change::DecisionModification) where {T,S}
    MOI.modify(model, ci, change)
    return nothing
end
