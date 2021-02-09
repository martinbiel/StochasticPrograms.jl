# JuMP Objectives/constraints #
# ========================== #
function JuMP.normalized_coefficient(
    con_ref::ConstraintRef{Model, JuMP._MOICON{F, S}}, dref::DecisionRef
    ) where {S, T, F <: AffineDecisionFunction{T}}
    con = JuMP.constraint_object(con_ref)
    return JuMP._affine_coefficient(con.func, dref)
end

function JuMP.set_objective_coefficient(model::Model, dref::DecisionRef, coeff::Real)
    if model.nlp_data !== nothing && _nlp_objective_function(model) !== nothing
        error("A nonlinear objective is already set in the model")
    end
    obj_fct_type = objective_function_type(model)
    if obj_fct_type == VariableRef || obj_fct_type == AffExpr || obj_fct_type == QuadExpr
        current_obj = objective_function(model)
        set_objective_function(model, add_to_expression!(coeff * dref, current_obj))
    elseif obj_fct_type == typeof(dref)
        current_obj = objective_function(model)
        if index(current_obj) == index(dref)
            set_objective_function(model, coeff * dref)
        else
            set_objective_function(model, add_to_expression!(coeff * dref, current_obj))
        end
    elseif obj_fct_type <: Union{DecisionAffExpr, DecisionQuadExpr} && dref isa DecisionRef
        MOI.modify(
            backend(model),
            MOI.ObjectiveFunction{moi_function_type(obj_fct_type)}(),
            DecisionCoefficientChange(index(dref), coeff))
    else
        error("Objective function type not supported: $(obj_fct_type)")
    end
    return nothing
end

function JuMP.normalized_rhs(con_ref::ConstraintRef{Model, JuMP._MOICON{F, S}}) where {
        T, S <: Union{MOI.LessThan{T}, MOI.GreaterThan{T}, MOI.EqualTo{T}},
        F <: AffineDecisionFunction{T}}
    con = constraint_object(con_ref)
    return MOI.constant(con.set)
end

function JuMP.set_normalized_coefficient(
    con_ref::ConstraintRef{Model, JuMP._MOICON{F, S}}, variable::VariableRef, coeff
    ) where {S, T, F <: AffineDecisionFunction{T}}
    MOI.modify(backend(owner_model(con_ref)), index(con_ref),
               MOI.ScalarCoefficientChange(index(variable), convert(T, coeff)))
    return nothing
end

function JuMP.set_normalized_coefficient(
    con_ref::ConstraintRef{Model, JuMP._MOICON{F, S}}, decision::DecisionRef, coeff
    ) where {S, T, F <: AffineDecisionFunction{T}}
    MOI.modify(backend(owner_model(con_ref)), index(con_ref),
               DecisionCoefficientChange(index(decision), convert(T, coeff)))
    return nothing
end

# Internal update functions #
# ========================== #
function update_known_decisions!(model::JuMP.Model)
    update_known_decisions!(backend(model))
    return nothing
end

function update_known_decisions!(model::MOI.ModelLike)
    change = KnownValuesChange()
    F = MOI.SingleVariable
    S = SingleDecisionSet{Float64}
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        MOI.modify(model, ci, change)
    end
    F = MOI.VectorOfVariables
    S = MultipleDecisionSet{Float64}
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        MOI.modify(model, ci, change)
    end
    return nothing
end

function update_decision_state!(dref::DecisionRef, state::DecisionState)
    model = backend(owner_model(dref))
    ci = CI{MOI.SingleVariable,SingleDecisionSet{Float64}}(index(dref).value)
    if MOI.is_valid(model, ci)
        MOI.modify(model, ci, DecisionStateChange(1, state))
        return nothing
    end
    # Locate multiple decision set
    F = MOI.VectorOfVariables
    S = MultipleDecisionSet{Float64}
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        f = MOI.get(model, MOI.ConstraintFunction(), ci)
        i = something(findfirst(vi -> vi == index(dref), f.variables), 0)
        if i != 0
            MOI.modify(model, ci, DecisionStateChange(i, state))
            return nothing
        end
    end
    return nothing
end
