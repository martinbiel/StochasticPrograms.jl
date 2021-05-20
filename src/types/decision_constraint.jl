"""
    SPConstraintRef

Holds a reference to the stochastic program, the stage the constraint resides in, and the corresponding MOI.ConstraintIndex.
"""
struct SPConstraintRef{C, Shape <: AbstractShape}
    stochasticprogram::StochasticProgram
    stage::Int
    index::C
    shape::Shape
end

function SPConstraintRef(stochasticprogram::StochasticProgram, stage::Integer, cref::ConstraintRef{Model, <:CI{<:DecisionLike}})
    return SPConstraintRef(stochasticprogram, stage, index(cref), cref.shape)
end
function SPConstraintRef(stochasticprogram::StochasticProgram, stage::Integer, cref::ConstraintRef{Model, CI{SingleDecision, S}}) where S
    f = MOI.get(cref.model, MOI.ConstraintFunction(), cref)::SingleDecision
    ci = CI{SingleDecision,S}(f.decision.value)
    return SPConstraintRef(stochasticprogram, stage, ci, cref.shape)
end

"""
    stage(sp_cref::SPConstraintRef)

Return the stage of `sp_cref`.
"""
function stage(sp_cref::SPConstraintRef)
    return sp_cref.stage
end

function JuMP.shape(sp_cref::SPConstraintRef)
    return sp_cref.shape
end

struct SPConstraintNotOwned{C <: SPConstraintRef} <: Exception
    constraint_ref::C
end

# MOI #
# ========================== #
function MOI.get(stochasticprogram::StochasticProgram, attr::MOI.AbstractConstraintAttribute,
                 sp_cref::SPConstraintRef)
    check_belongs_to_model(sp_cref, stochasticprogram)
    if MOI.is_set_by_optimize(attr)
        # Check if there is a cached solution
        cache = solutioncache(stochasticprogram)
        if haskey(cache, :solution)
            # Returned cached solution if possible
            try
                return MOI.get(cache[:solution], attr, index(sp_cref))
            catch
            end
        end
        if haskey(cache, :node_solution_1)
            # Value was possibly only cached in first-stage solution
            try
                return MOI.get(cache[:node_solution_1], attr, index(sp_cref))
            catch
            end
        end
        check_provided_optimizer(stochasticprogram.optimizer)
        if MOI.get(stochasticprogram, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        end
        return MOI.get(optimizer(stochasticprogram), attr, index(sp_cref))
    else
        # Default to proxy for other constraints
        proxy_ = proxy(stochasticprogram, stage(sp_cref))
        if _function_type(index(sp_cref)) <: SingleDecision
            # Need to map SingleDecision constraints
            con_ref = ConstraintRef(proxy_, index(sp_cref))
            return MOI.get(proxy_, attr, con_ref)
        else
            return MOI.get(backend(proxy_), attr, index(sp_cref))
        end
    end
end
function MOI.get(stochasticprogram::StochasticProgram, attr::ScenarioDependentConstraintAttribute,
                 sp_cref::SPConstraintRef)
    check_belongs_to_model(sp_cref, stochasticprogram)
    if MOI.is_set_by_optimize(attr)
        # Check if there is a cached solution
        cache = solutioncache(stochasticprogram)
        key = Symbol(:node_solution_, attr.stage, :_, attr.scenario_index)
        if haskey(cache, key)
            # Returned cached solution
            return MOI.get(cache[key], attr.attr, index(sp_cref))
        end
        check_provided_optimizer(stochasticprogram.optimizer)
        if MOI.get(stochasticprogram, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        end
        try
            # Try to get scenario-dependent value directly
            return MOI.get(optimizer(stochasticprogram), attr, index(sp_cref))
        catch
            # Fallback to resolving scenario-dependence in structure if
            # not supported natively by optimizer
            MOI.get(structure(stochasticprogram), attr, index(sp_cref))
        end
    else
        # Get value from structure if not set by optimizer
        return MOI.get(structure(stochasticprogram), attr, index(sp_cref))
    end
end

function MOI.set(stochasticprogram::StochasticProgram, attr::MOI.AbstractConstraintAttribute,
                 sp_cref::SPConstraintRef, value)
    check_belongs_to_model(sp_cref, stochasticprogram)
    MOI.set(structure(stochasticprogram), attr, index(sp_cref), value)
end

# JuMP constraint interface #
# ========================== #
function JuMP.ConstraintRef(model::AbstractModel, ci::MOI.ConstraintIndex{F,S}) where {F <: SingleDecision, S}
    decisions = get_decisions(model)::Decisions
    inner = mapped_constraint(decisions, ci)
    inner.value == 0 && error("Constraint $ci not properly mapped.")
    return ConstraintRef(model, inner, ScalarShape())
end

JuMP.owner_model(sp_cref::SPConstraintRef) = sp_cref.stochasticprogram

function JuMP.check_belongs_to_model(sp_cref::SPConstraintRef, stochasticprogram::StochasticProgram)
    if owner_model(sp_cref) !== stochasticprogram
        throw(SPConstraintNotOwned(sp_cref))
    end
end
"""
    index(sp_cref::SPConstraintNotOwned)::MOI.ConstraintIndex

Return the index of the decision constraint that corresponds to `sp_cref` in the MOI backend.
"""
index(sp_cref::SPConstraintRef) = sp_cref.index

"""
    optimizer_index(sp_cref::SPConstraintRef)::MOI.VariableIndex

Return the index of the variable that corresponds to `dvar` in the optimizer model.
"""
function JuMP.optimizer_index(sp_cref::SPConstraintRef)
    stage(sp_cref) > 1 && error("$sp_cref is scenario dependent, consider `optimizer_index(sp_cref, scenario_index)`.")
    return JuMP._moi_optimizer_index(structure(owner_model(sp_cref)), index(sp_cref))
end
"""
    optimizer_index(sp_cref::SPConstraintRef, scenario_index)::MOI.VariableIndex

Return the index of the constraint that corresponds to the scenario-dependent `sp_cref` in the optimizer model at `scenario_index`.
"""
function JuMP.optimizer_index(sp_cref::SPConstraintRef, scenario_index::Integer)
    return JuMP._moi_optimizer_index(structure(owner_model(sp_cref)), index(sp_cref), scenario_index)
end

Base.broadcastable(sp_cref::SPConstraintRef) = Ref(sp_cref)

"""
    name(sp_cref::SPConstraintRef)::String

Get the name of the decision constraint `sp_cref`.
"""
function JuMP.name(sp_cref::SPConstraintRef)
    return MOI.get(owner_model(sp_cref), MOI.ConstraintName(), sp_cref)::String
end
"""
    name(sp_cref::SPConstraintRef, scenario_index::Integer)::String

Get the name of the scenario-dependent decision constraint `sp_cref` in scenario `scenario_index`.
"""
function JuMP.name(sp_cref::SPConstraintRef, scenario_index::Integer)
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `name(sp_cref)`.")
    attr = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintName())
    return MOI.get(owner_model(sp_cref), attr, sp_cref)::String
end
"""
    set_name(sp_cref::SPConstraintRef, name::String)

Set the name of the decision constraint `sp_cref` to `name`.
"""
function JuMP.set_name(sp_cref::SPConstraintRef, name::String)
    stage(sp_cref) > 1 && error("$sp_cref is scenario dependent, consider `set_name(sp_cref, scenario_index, name)`.")
    return MOI.set(owner_model(sp_cref), MOI.ConstraintName(), sp_cref, name)
end
"""
    set_name(sp_cref::SPConstraintRef, scenario_index::Integer, name::String)

Set the name of the scenario-dependent decision constraint `sp_cref` in scenario `scenario_index` to `name`.
"""
function JuMP.set_name(sp_cref::SPConstraintRef, scenario_index::Integer, name::String)
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `set_name(sp_cref, name)`.")
    attr = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintName())
    return MOI.set(owner_model(sp_cref), attr, sp_cref, name)
end
"""
    constraint_by_name(stochasticprogram::StochasticProgram,
                       stage::Integer,
                       name::String)::Union{SPConstraintRef, Nothing}

Returns the reference of the constraint with name attribute `name` at `stage` of
`stochasticprogram` or `Nothing` if no constraint has this name attribute. Throws an
error if several constraints have `name` as their name attribute.

    constraint_by_name(stochasticprogram::StochasticProgram,
                       stage::Integer,
                       name::String,
                       F::Type{<:Union{AbstractJuMPScalar,
                                       Vector{<:AbstractJuMPScalar},
                                       MOI.AbstactFunction}},
                       S::Type{<:MOI.AbstractSet})::Union{SPConstraintRef, Nothing}

Similar to the method above, except that it throws an error if the constraint is
not an `F`-in-`S` contraint where `F` is either the JuMP or MOI type of the
function, and `S` is the MOI type of the set.
"""
function JuMP.constraint_by_name(stochasticprogram::StochasticProgram{N}, stage::Integer, name::String) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    index = MOI.get(backend(proxy(stochasticprogram, stage)), MOI.ConstraintIndex, name)
    if index isa Nothing
        return nothing
    else
        if _function_type(index) <: SingleDecision
            f = MOI.get(backend(proxy(stochasticprogram, stage)), MOI.ConstraintFunction(), index)::SingleDecision
            ci = CI{SingleDecision, _set_type(index)}(f.decision.value)
            return constraint_ref_with_index(stochasticprogram, stage, ci)
        else
            return constraint_ref_with_index(stochasticprogram, stage, index)
        end
    end
end
function JuMP.constraint_by_name(stochasticprogram::StochasticProgram{N},
                                 stage::Integer,
                                 name::String,
                                 F::Type{<:MOI.AbstractFunction},
                                 S::Type{<:MOI.AbstractSet}) where N
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    index = MOI.get(backend(proxy(stochasticprogram, stage)), MOI.ConstraintIndex{F, S}, name)
    if index isa Nothing
        return nothing
    else
        if F <: SingleDecision
            f = MOI.get(backend(proxy(stochasticprogram, stage)), MOI.ConstraintFunction(), index)::SingleDecision
            ci = CI{SingleDecision,S}(f.decision.value)
            return constraint_ref_with_index(stochasticprogram, stage, ci)
        else
            return constraint_ref_with_index(stochasticprogram, stage, index)
        end
    end
end
function JuMP.constraint_by_name(stochasticprogram::StochasticProgram,
                                 stage::Integer,
                                 name::String,
                                 F::Type{<:Union{ScalarType,
                                                 Vector{ScalarType}}},
                                 S::Type) where ScalarType <: AbstractJuMPScalar
    return constraint_by_name(stochasticprogram, stage, name, moi_function_type(F), S)
end

function JuMP.constraint_ref_with_index(stochasticprogram::StochasticProgram,
                                        stage::Integer,
                                        index::MOI.ConstraintIndex{<:MOI.AbstractScalarFunction,
                                                                   <:MOI.AbstractScalarSet})
    return SPConstraintRef(stochasticprogram, stage, index, ScalarShape())
end
function JuMP.constraint_ref_with_index(stochasticprogram::StochasticProgram,
                                        stage::Integer,
                                        index::MOI.ConstraintIndex{<:MOI.AbstractVectorFunction,
                                                                   <:MOI.AbstractVectorSet})
    m = proxy(stochasticprogram, stage)
    return SPConstraintRef(stochasticprogram, stage, index, get(m.shapes, index, VectorShape()))
end
"""
    delete(stochasticprogram::StochasticProgram, sp_cref::SPConstraintRef)

Delete the first-stage decision constraint associated with `sp_cref` from the `stochasticprogram`.
"""
function JuMP.delete(stochasticprogram::StochasticProgram, sp_cref::SPConstraintRef)
    stage(sp_cref) > 1 && error("$sp_cref is scenario dependent, consider `delete(stochasticprogram, sp_cref, scenario_index)`.")
    if stochasticprogram !== owner_model(sp_cref)
        error("The constraint reference you are trying to delete does not " *
              "belong to the stochasticprogram.")
    end
    MOI.delete(structure(stochasticprogram), index(sp_cref), stage(sp_cref))
end
"""
    delete(stochasticprogram::StochasticProgram, sp_cref::SPConstraintRef, scenario_index::Integer)

Delete the scenario-dependent decision constraint associated with `sp_cref` from the `stochasticprogram` in scenario `scenario_index`.
"""
function JuMP.delete(stochasticprogram::StochasticProgram, sp_cref::SPConstraintRef, scenario_index::Integer)
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `delete(stochasticprogram, sp_cref)`.")
    if stochasticprogram !== owner_model(sp_cref)
        error("The constraint reference you are trying to delete does not " *
              "belong to the stochasticprogram.")
    end
    MOI.delete(structure(stochasticprogram), index(sp_cref), stage(sp_cref), scenario_index)
end
"""
    delete(stochasticprogram::StochasticProgram, sp_crefs::Vector{<:SPConstraintRef})

Delete the first-stage decision constraints associated with `sp_crefs` from the `stochasticprogram`.
"""
function JuMP.delete(stochasticprogram::StochasticProgram, sp_crefs::Vector{<:SPConstraintRef})
    all(stage.(sp_crefs) .== stage(sp_crefs[1])) || error("$sp_crefs are not all from the same stage")
    stage(sp_crefs[1]) > 1 && error("$sp_crefs are scenario dependent, consider `delete(stochasticprogram, sp_crefs, scenario_index)`.")
    if any(stochasticprogram !== owner_model(sp_cref) for sp_cref in sp_crefs)
        error("A constraint reference you are trying to delete does not " *
              "belong to the stochasticprogram.")
    end
    MOI.delete(structure(stochasticprogram), index.(sp_crefs), stage(sp_crefs[1]))
end
"""
    delete(stochasticprogram::StochasticProgram, sp_crefs::Vector{<:SPConstraintRef}, scenario_index::Integer)

Delete the scenario-dependent decision constraints associated with `sp_crefs` from the `stochasticprogram` at `scenario_index`.
"""
function JuMP.delete(stochasticprogram::StochasticProgram, sp_crefs::Vector{<:SPConstraintRef}, scenario_index::Integer)
    all(stage.(sp_crefs) .== stage(sp_crefs[1])) || error("$sp_crefs are not all from the same stage")
    stage(sp_crefs[1]) == 1 && error("$sp_crefs are not scenario dependent, consider `delete(stochasticprogram, sp_crefs)`.")
    if any(stochasticprogram !== owner_model(sp_cref) for sp_cref in sp_crefs)
        error("A constraint reference you are trying to delete does not " *
              "belong to the stochasticprogram.")
    end
    MOI.delete(structure(stochasticprogram), index.(sp_crefs), stage(sp_crefs[1]), scenario_index)
end
"""
    is_valid(stochasticprogram::StochasticProgram, sp_cref::SPConstraintRef)

Return `true` if `sp_cref` refers to a valid first-stage decision constraint in `stochasticprogram`.
"""
function JuMP.is_valid(stochasticprogram::StochasticProgram, sp_cref::SPConstraintRef)
    stage(sp_cref) > 1 && error("$sp_cref is scenario dependent, consider `is_valid(sp_cref, scenario_index)`.")
    return stochasticprogram === owner_model(sp_cref) &&
        MOI.is_valid(structure(stochasticprogram), index(sp_cref), stage(sp_cref))
end
"""
    is_valid(stochasticprogram::StochasticProgram, sp_cref::SPConstraintRef, scenario_index::Integer)

Return `true` if the scenario-dependent `sp_cref` refers to a valid decision constraint in `stochasticprogram` at `scenario_index`.
"""
function JuMP.is_valid(stochasticprogram::StochasticProgram, sp_cref::SPConstraintRef, scenario_index::Integer)
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `is_valid(sp_cref)`.")
    return stochasticprogram === owner_model(sp_cref) &&
        MOI.is_valid(structure(stochasticprogram), index(sp_cref), stage(sp_cref), scenario_index)
end
"""
    constraint_object(sp_cref::SPConstraintRef)

Return the underlying constraint data for the first-stage decision constraint referenced by `sp_cref`.
"""
function JuMP.constraint_object(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}) where
    {F <: ScalarDecisionLike, S <: MOI.AbstractScalarSet}
    sp = owner_model(sp_cref)
    f = MOI.get(sp, MOI.ConstraintFunction(), sp_cref)::F
    s = MOI.get(sp, MOI.ConstraintSet(), sp_cref)::S
    return ScalarConstraint(jump_function(structure(sp), stage(sp_cref), f), s)
end
function JuMP.constraint_object(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}) where
    {F <: SingleDecision, S <: MOI.AbstractScalarSet}
    sp = owner_model(sp_cref)
    # Check if the constraint was added at creation
    ci = CI{MOI.SingleVariable,SingleDecisionSet{Float64}}(index(sp_cref).value)
    if MOI.is_valid(backend(proxy(sp, stage(sp_cref))), ci)
        s = MOI.get(backend(proxy(sp, stage(sp_cref))), MOI.ConstraintSet(), ci)::SingleDecisionSet
        if s.constraint isa S
            f = MOI.get(backend(proxy(sp, stage(sp_cref))), MOI.ConstraintFunction(), ci)::MOI.SingleVariable
            return ScalarConstraint(jump_function(structure(sp), stage(sp_cef), SingleDecision(f.variable)), s.constraint)
        end
    end
    # Try to get constraint as usual
    f = MOI.get(sp, MOI.ConstraintFunction(), sp_cref)::F
    s = MOI.get(sp, MOI.ConstraintSet(), sp_cref)::S
    return ScalarConstraint(jump_function(structure(sp), stage(sp_cref), f), s)
end
function JuMP.constraint_object(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}) where
    {F <: VectorDecisionLike, S <: MOI.AbstractVectorSet}
    sp = owner_model(sp_cref)
    f = MOI.get(sp, MOI.ConstraintFunction(), sp_cref)::F
    s = MOI.get(sp, MOI.ConstraintSet(), sp_cref)::S
    return VectorConstraint(jump_function(structure(sp), stage(sp_cref), f), s, sp_cref.shape)
end
function JuMP.constraint_object(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}) where
    {F <: VectorOfDecisions, S <: MOI.AbstractVectorSet}
    sp = owner_model(sp_cref)
    # Check if the constraint was added at creation
    ci = CI{MOI.VectorOfVariables,MultipleDecisionSet{Float64}}(index(sp_cref).value)
    if MOI.is_valid(backend(proxy(sp, stage(sp_cref))), ci)
        s = MOI.get(backend(proxy(sp, stage(sp_cref))), MOI.ConstraintSet(), ci)::MultipleDecisionSet
        if s.constraint isa S
            f = MOI.get(backend(proxy(sp, stage(sp_cref))), MOI.ConstraintFunction(), ci)::MOI.VectorOfVariables
            return VectorConstraint(jump_function(structure(sp), stage(sp_cref), VectorOfDecisions(f.variables)), s.constraint, sp_cref.shape)
        end
    end
    # Try to get constraint as usual
    f = MOI.get(sp, MOI.ConstraintFunction(), sp_cref)::F
    s = MOI.get(sp, MOI.ConstraintSet(), sp_cref)::S
    return VectorConstraint(jump_function(structure(sp), stage(sp_cref), f), s, sp_cref.shape)
end
"""
    constraint_object(sp_cref::SPConstraintRef, scenario_index)

Return the underlying constraint data for the scenario-dependent decision constraint
referenced by `sp_cref` in scenario `scenario_index`.
"""
function JuMP.constraint_object(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}, scenario_index::Integer) where
    {F <: ScalarDecisionLike, S <: MOI.AbstractScalarSet}
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `constraint_object(sp_cref)`.")
    sp = owner_model(sp_cref)
    f_attr = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintFunction())
    f = MOI.get(sp, f_attr, sp_cref)::F
    s_attr  = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintSet())
    s = MOI.get(sp, s_attr, sp_cref)::S
    return ScalarConstraint(jump_function(structure(sp), stage(sp_cref), scenario_index, f), s)
end
function JuMP.constraint_object(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}, scenario_index::Integer) where
    {F <: SingleDecision, S <: MOI.AbstractScalarSet}
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `constraint_object(sp_cref)`.")
    sp = owner_model(sp_cref)
    # Check if the constraint was added at creation
    ci = CI{MOI.SingleVariable,SingleDecisionSet{Float64}}(index(sp_cref).value)
    if MOI.is_valid(backend(proxy(sp, stage(sp_cref))), ci)
        s_attr = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintSet())
        s = MOI.get(structure(sp), s_attr, ci)::SingleDecisionSet
        if s.constraint isa S
            return ScalarConstraint(jump_function(structure(sp), stage(sp_cref), scenario_index, SingleDecision(f.variable)), s.constraint)
        end
    end
    # Try to get constraint as usual
    f_attr = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintFunction())
    f = MOI.get(sp, f_attr, sp_cref)::F
    s_attr  = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintSet())
    s = MOI.get(sp, s_attr, sp_cref)::S
    return ScalarConstraint(jump_function(structure(sp), stage(sp_cref), scenario_index, f), s)
end
function JuMP.constraint_object(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}, scenario_index::Integer) where
    {F <: VectorDecisionLike, S <: MOI.AbstractVectorSet}
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `constraint_object(sp_cref)`.")
    sp = sp_cref.stochasticprogram
    f_attr = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintFunction())
    f = MOI.get(sp, f_attr, sp_cref)::F
    s_attr  = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintSet())
    s = MOI.get(sp, s_attr, sp_cref)::S
    return VectorConstraint(jump_function(structure(sp), f), stage(sp_cref), scenario_index, s, sp_cref.shape)
end
function JuMP.constraint_object(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}, scenario_index::Integer) where
    {F <: VectorOfDecisions, S <: MOI.AbstractVectorSet}
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `constraint_object(sp_cref)`.")
    sp = sp_cref.stochasticprogram
    # Check if the constraint was added at creation
    ci = CI{MOI.VectorOfVariables,MultipleDecisionSet{Float64}}(index(sp_cref).value)
    if MOI.is_valid(backend(proxy(sp, stage(sp_cref))), ci)
        s_attr = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintSet())
        s = MOI.get(structure(sp), s_attr, ci)::MultipleDecisionSet
        if s.constraint isa S
            f_attr = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintFunction())
            f = MOI.get(structure(sp), f_attr, ci)::MOI.VectorOfVariables
            return VectorConstraint(jump_function(structure(sp), stage(sp_cref), scenario_index, VectorOfDecisions(f.variables)), s.constraint, sp_cref.shape)
        end
    end
    # Try to get constraint as usual
    f_attr = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintFunction())
    f = MOI.get(sp, f_attr, sp_cref)::F
    s_attr  = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintSet())
    s = MOI.get(sp, s_attr, sp_cref)::S
    return VectorConstraint(jump_function(structure(sp), stage(sp_cref), scenario_index, f), s, sp_cref.shape)
end
"""
    set_normalized_coefficient(sp_cref::SPConstraintRef, dvar::DecisionVariable, value)

Set the coefficient of `dvar` in the first-stage decision constraint `sp_cref` to `value`.
"""
function JuMP.set_normalized_coefficient(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}},
                                         dvar::DecisionVariable,
                                         value) where {T, F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}, S}
    stage(sp_cref) > 1 && error("$sp_cref is scenario dependent, consider `set_normalized_coefficient(sp_cref, dvar, scenario_index, value)`.")
    # Modify proxy
    proxy_ = proxy(owner_model(sp_cref), stage(sp_cref))
    MOI.modify(backend(proxy_), index(sp_cref), DecisionCoefficientChange(index(dvar), convert(T, value)))
    set_normalized_coefficient(structure(owner_model(sp_cref)), index(sp_cref), index(dvar), value)
    return nothing
end
"""
    set_normalized_coefficient(sp_cref::SPConstraintRef, dvar::DecisionVariable, scenario_index::Integer, value)

Set the coefficient of `dvar` in the decision constraint `sp_cref` in scenario `scenario_index` to `value`.
"""
function JuMP.set_normalized_coefficient(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}},
                                         dvar::DecisionVariable,
                                         scenario_index::Integer,
                                         value) where {T, F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}, S}
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `set_normalized_coefficient(sp_cref, dvar, value)`.")
    set_normalized_coefficient(structure(owner_model(sp_cref)), index(sp_cref), index(dvar), stage(dvar), stage(sp_cref), scenario_index, value)
    return nothing
end
"""
    normalized_coefficient(sp_cref::SPConstraintRef, dvar::DecisionVariable)

Return the coefficient associated with `dvar` in the first-stage decision constraint `sp_cref` after JuMP has normalized the constraint into its standard form.
"""
function JuMP.normalized_coefficient(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}},
                                     dvar::DecisionVariable) where {T, F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}, S}
    stage(sp_cref) > 1 && error("$sp_cref is scenario dependent, consider `normalized_coefficient(sp_cref, dvar, scenario_index)`.")
    proxy_ = proxy(owner_model(sp_cref), stage(dvar))
    f = MOI.get(backend(proxy_), MOI.ConstraintFunction(), index(sp_cref))::F
    dref = DecisionRef(proxy_, index(dvar))
    return JuMP._affine_coefficient(jump_function(proxy_, f), dref)
end
"""
    normalized_coefficient(sp_cref::SPConstraintRef, dvar::DecisionVariable, scenario_index::Integer)

Return the coefficient associated with `dvar` in the decision constraint `sp_cref` in scenario `scenario_index` after JuMP has normalized the constraint into its standard form.
"""
function JuMP.normalized_coefficient(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}},
                                     dvar::DecisionVariable,
                                     scenario_index::Integer) where {T, F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}}, S}
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `normalized_coefficient(sp_cref, dvar)`.")
    return normalized_coefficient(structure(owner_model(sp_cref)), index(sp_cref), index(dvar), stage(dvar), stage(sp_cref), scenario_index)
end
"""
    set_normalized_rhs(sp_cref::SPConstraintRef, value)

Set the right-hand side term of the first-stage decision constraint `sp_cref` to `value`.
"""
function JuMP.set_normalized_rhs(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}},
                                 value) where {T,
                                               F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}},
                                               S <: MOIU.ScalarLinearSet{T}}
    stage(sp_cref) > 1 && error("$sp_cref is scenario dependent, consider `set_normalized_rhs(sp_cref, scenario_index, value)`.")
    proxy_ = proxy(owner_model(sp_cref), stage(sp_cref))
    MOI.set(backend(proxy_), MOI.ConstraintSet(), index(sp_cref), S(convert(T, value)))
    set_normalized_rhs(structure(owner_model(sp_cref)), index(sp_cref), value)
    return nothing
end
"""
    set_normalized_rhs(sp_cref::SPConstraintRef, scenario_index::Integer, value)

Set the right-hand side term of the decision constraint `sp_cref` at `scenario_index` to `value`.
"""
function JuMP.set_normalized_rhs(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}},
                                 scenario_index::Integer,
                                 value) where {T,
                                               F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}},
                                               S <: MOIU.ScalarLinearSet{T}}
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `set_normalized_rhs(sp_cref, value)`.")
    set_normalized_rhs(structure(owner_model(sp_cref)), index(sp_cref), stage(sp_cref), scenario_index, value)
    return nothing
end
"""
    normalized_rhs(sp_cref::SPConstraintRef)

Return the right-hand side term of the first-stage decision constraint
`sp_cref` after JuMP has converted the constraint into its normalized form.
"""
function JuMP.normalized_rhs(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}) where {T,
                                           F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}},
                                           S <: MOIU.ScalarLinearSet{T}}
    stage(sp_cref) > 1 && error("$sp_cref is scenario dependent, consider `normalized_rhs(sp_cref, scenario_index)`.")
    con = constraint_object(sp_cref)
    return MOI.constant(con.set)
end
"""
    normalized_rhs(sp_cref::SPConstraintRef, scenario_index::Integer)

Return the right-hand side term of the scenario-dependent decision constraint
`sp_cref` at `scenario_index` after JuMP has converted the constraint into its normalized form.
"""
function JuMP.normalized_rhs(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}},
                             scenario_index::Integer) where {T,
                                                             F <: Union{AffineDecisionFunction{T}, QuadraticDecisionFunction{T}},
                                                             S <: MOIU.ScalarLinearSet{T}}
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `normalized_rhs(sp_cref)`.")
    con = constraint_object(sp_cref, scenario_index)
    return MOI.constant(con.set)
end
"""
    value(sp_cref::SPConstraintRef; result::Int = 1)

Return the primal value of the first-stage decision constraint `sp_cref` associated
with result index `result` of the most-recent solution returned by the solver.
"""
function JuMP.value(sp_cref::SPConstraintRef; result::Int = 1)::Float64
    stage(sp_cref) > 1 && error("$sp_cref is scenario dependent, consider `value(sp_cref, scenario_index)`.")
    values = MOI.get(owner_model(sp_cref), MOI.ConstraintPrimal(result), sp_cref)
    return reshape_vector(values, sp_cref.shape)
end
"""
    value(sp_cref::SPConstraintRef, scenario_index::Integer; result::Int = 1)

Return the primal value of the scenario-dependent decision constraint `sp_cref`
at `scenario_index` associated with result index `result` of the most-recent
solution returned by the solver.
"""
function JuMP.value(sp_cref::SPConstraintRef, scenario_index::Integer; result::Int = 1)::Float64
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `value(sp_cref)`.")
    attr = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintPrimal(result))
    values = MOI.get(owner_model(sp_cref), attr, sp_cref)
    return reshape_vector(values, sp_cref.shape)
end
"""
    value(sp_cref::SPConstraintRef, dvar_value::Function)

Evaluate the primal value of the first-stage decision constraint `sp_cref` using `dvar_value(dvar)`
as the value for each decision variable `dvar`.
"""
function JuMP.value(sp_cref::SPConstraintRef, var_value::Function)::Float64
    stage(sp_cref) > 1 && error("$sp_cref is scenario dependent, consider `value(sp_cref, scenario_index)`.")
    f = jump_function(constraint_object(sp_cref))
    return reshape_vector(value.(f, var_value), sp_cref.shape)
end
"""
    value(sp_cref::SPConstraintRef, dvar_value::Function)

Evaluate the primal value of the scenario-dependent decision constraint `sp_cref`
in scenario `scenario_index` using `dvar_value(dvar)` as the value for each
decision variable `dvar`.
"""
function JuMP.value(sp_cref::SPConstraintRef, scenario_index::Integer, dvar_value::Function)::Float64
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `value(sp_cref, dvar_value)`.")
    f = jump_function(constraint_object(sp_cref, scenario_index))
    return reshape_vector(value.(f, dvar_value), sp_cref.shape)
end
"""
    has_duals(stochasticprogram::StochasticProgram; result::Int = 1)

Return `true` if the solver has a dual solution in the first-stage of
`stochasticprogram` in result index `result` available to query,
otherwise return `false`.
"""
function JuMP.has_duals(stochasticprogram::StochasticProgram; result::Int = 1)
    return dual_status(stochasticprogram; result = result) != MOI.NO_SOLUTION
end
"""
    has_duals(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer; result::Int = 1)

Return `true` if the solver has a dual solution in the node at stage
`stage` and scenario `scenario_index` in result index `result`
available to query, otherwise return `false`.
"""
function JuMP.has_duals(stochasticprogram::StochasticProgram, stage::Integer, scenario_index::Integer; result::Int = 1)
    return dual_status(stochasticprogram, stage, scenario_index; result = result) != MOI.NO_SOLUTION
end
"""
    has_duals(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer; result::Int = 1)

Return `true` if the solver has a dual solution in scenario `scenario_index`
in result index `result` available to query, otherwise return `false`.
"""
function JuMP.has_duals(stochasticprogram::TwoStageStochasticProgram, scenario_index::Integer; result::Int = 1)
    return has_duals(stochasticprogram, 2, scenario_index; result = result)
end
"""
    dual(sp_cref::SPConstraintRef; result::Int = 1)

Return the dual value of the first-stage decision constraint `sp_cref`
associated with result index `result` of the most-recent solution
returned by the solver.
"""
function JuMP.dual(sp_cref::SPConstraintRef; result::Int = 1)
    stage(sp_cref) > 1 && error("$sp_cref is scenario dependent, consider `dual(sp_cref, scenario_index)`.")
    return reshape_vector(_constraint_dual(sp_cref, result), dual_shape(sp_cref.shape))
end
function _constraint_dual(sp_cref::SPConstraintRef{<:JuMP._MOICON{<:MOI.AbstractScalarFunction, <:MOI.AbstractScalarSet}},
                          result::Int)::Float64
    return MOI.get(owner_model(sp_cref), MOI.ConstraintDual(result), sp_cref)
end
function _constraint_dual(sp_cref::SPConstraintRef{<:JuMP._MOICON{<:MOI.AbstractVectorFunction, <:MOI.AbstractVectorSet}},
                          result::Int)::Vector{Float64}
    return MOI.get(owner_model(sp_cref), MOI.ConstraintDual(result), sp_cref)
end
"""
    dual(sp_cref::SPConstraintRef, scenario_index::Integer; result::Int = 1)

Return the dual value of the scenario-dependent decision constraint `sp_cref`
in scenario `scenario_index` associated with result index `result` of the
most-recent solution returned by the solver.
"""
function JuMP.dual(sp_cref::SPConstraintRef, scenario_index::Integer; result::Int = 1)
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `dual(sp_cref)`.")
    return reshape_vector(_constraint_dual(sp_cref, scenario_index, result), dual_shape(sp_cref.shape))
end
function _constraint_dual(sp_cref::SPConstraintRef{<:JuMP._MOICON{<:MOI.AbstractScalarFunction, <:MOI.AbstractScalarSet}},
                          scenario_index::Integer,
                          result::Int)::Float64
    attr = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintDual(result))
    return MOI.get(owner_model(sp_cref), attr, sp_cref)
end
function _constraint_dual(sp_cref::SPConstraintRef{<:JuMP._MOICON{<:MOI.AbstractVectorFunction, <:MOI.AbstractVectorSet}},
                          scenario_index::Integer,
                          result::Int)::Vector{Float64}
    attr = ScenarioDependentConstraintAttribute(stage(sp_cref), scenario_index, MOI.ConstraintDual(result))
    return MOI.get(owner_model(sp_cref), attr, sp_cref)
end

function JuMP.shadow_price(sp_cref::SPConstraintRef{<:JuMP._MOICON})
    error("The shadow price is not defined or not implemented for this type " *
          "of constraint.")
end
function JuMP.shadow_price(sp_cref::SPConstraintRef{<:JuMP._MOICON}, ::Integer)
    error("The shadow price is not defined or not implemented for this type " *
          "of constraint.")
end
"""
    shadow_price(sp_cref::SPConstraintRef)

Return the shadow price of the first-stage decision constraint `sp_cref`
associated with result index `result` of the most-recent solution returned by the solver.
"""
function JuMP.shadow_price(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}) where {F, S <: MOI.LessThan}
    stage(sp_cref) > 1 && error("$sp_cref is scenario dependent, consider `shadow_price(sp_cref, scenario_index)`.")
    sp = owner_model(sp_cref)
    if !has_duals(sp)
        error("The shadow price is not available because no dual result is " *
              "available.")
    end
    return JuMP.shadow_price_less_than_(dual(sp_cref), objective_sense(sp))
end
"""
    shadow_price(sp_cref::SPConstraintRef, scenario_index::Integer)

Return the shadow price of the scenario-dependent decision constraint `sp_cref`
in scenario `scenario_index` associated with result index `result` of the
most-recent solution returned by the solver.
"""
function JuMP.shadow_price(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}, scenario_index::Integer) where {F, S <: MOI.LessThan}
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `shadow_price(sp_cref)`.")
    sp = owner_model(sp_cref)
    if !has_duals(sp, scenario_index)
        error("The shadow price is not available because no dual result is " *
              "available.")
    end
    return JuMP.shadow_price_less_than_(dual(sp_cref, scenario_index), objective_sense(sp, scenario_index))
end

function JuMP.shadow_price(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}) where {F, S <: MOI.GreaterThan}
    stage(sp_cref) > 1 && error("$sp_cref is scenario dependent, consider `shadow_price(sp_cref, scenario_index)`.")
    sp = owner_model(sp_cref)
    if !has_duals(sp)
        error("The shadow price is not available because no dual result is " *
              "available.")
    end
    return JuMP.shadow_price_greater_than_(dual(sp_cref), objective_sense(sp))
end
function JuMP.shadow_price(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}, scenario_index::Integer) where {F, S <: MOI.GreaterThan}
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `shadow_price(sp_cref)`.")
    sp = owner_model(sp_cref)
    if !has_duals(sp, scenario_index)
        error("The shadow price is not available because no dual result is " *
              "available.")
    end
    return JuMP.shadow_price_greater_than_(dual(sp_cref, scenario_index), objective_sense(sp, scenario_index))
end

function JuMP.shadow_price(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}) where {F, S <: MOI.EqualTo}
    stage(sp_cref) > 1 && error("$sp_cref is scenario dependent, consider `shadow_price(sp_cref, scenario_index)`.")
    sp = owner_model(sp_cref)
    if !has_duals(sp)
        error("The shadow price is not available because no dual result is " *
              "available.")
    end
    sense = objective_sense(sp)
    dual_val = dual(sp_cref)
    if dual_val > 0
        return JuMP.shadow_price_greater_than_(dual_val, sense)
    else
        return JuMP.shadow_price_less_than_(dual_val, sense)
    end
end
function JuMP.shadow_price(sp_cref::SPConstraintRef{JuMP._MOICON{F, S}}, scenario_index::Integer) where {F, S <: MOI.EqualTo}
    stage(sp_cref) == 1 && error("$sp_cref is not scenario dependent, consider `shadow_price(sp_cref)`.")
    sp = owner_model(sp_cref)
    if !has_duals(sp, scenario_index)
        error("The shadow price is not available because no dual result is " *
              "available.")
    end
    sense = objective_sense(sp, scenario_index)
    dual_val = dual(sp_cref, scenario_index)
    if dual_val > 0
        return JuMP.shadow_price_greater_than_(dual_val, sense)
    else
        return JuMP.shadow_price_less_than_(dual_val, sense)
    end
end
"""
    num_constraints(stochasticprogram::StochasticProgram{N}, stage::Integer, function_type, set_type)::Int64

Return the number of decision constraints currently in the `stochasticprogram` at `stage` where the function
has type `function_type` and the set has type `set_type`. This errors if regular constraints are queried. If so, either annotate the relevant variables with [`@decision`](@ref) or first query the relevant JuMP subproblem and use the regular `all_constraints` function.
"""
function JuMP.num_constraints(stochasticprogram::StochasticProgram{N},
                              stage::Integer,
                              function_type::Type{<:Union{V,Vector{<:V}}},
                              set_type::Type{<:MOI.AbstractSet})::Int64 where {N, V <: AbstractJuMPScalar}
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    JuMP._error_if_not_concrete_type(function_type)
    JuMP._error_if_not_concrete_type(set_type)
    is_decision_type(V) || error("Only decision constraints can be queried. For regular constraints, either annotate the relevant variable with @decision or first query the relevant JuMP subproblem and use the regular `all_constraints` function.")
    f_type = moi_function_type(function_type)
    m = proxy(stochasticprogram, stage)
    result = MOI.get(m, MOI.NumberOfConstraints{f_type, set_type}())
    # Add any constraints specified at creation
    if f_type <: SingleDecision
        for ci in MOI.get(m, MOI.ListOfConstraintIndices{MOI.SingleVariable, SingleDecisionSet{Float64}}())
            set = MOI.get(backend(m), MOI.ConstraintSet(), ci)
            if set.constraint isa set_type
                result += 1
            end
        end
    end
    if f_type <: VectorOfDecisions
        for ci in MOI.get(m, MOI.ListOfConstraintIndices{MOI.VectorOfVariables, MultipleDecisionSet{Float64}}())
            set = MOI.get(backend(m), MOI.ConstraintSet(), ci)
            if set.constraint isa set_type
                result += 1
            end
        end
    end
    return result
end
"""
    all_constraints(stochasticprogram::StochasticProgram, stage::Integer, function_type, set_type)::Vector{<:SPConstraintRef}

Return a list of all decision constraints currently in the `stochasticprogram` at `stage` where the function has type `function_type` and the set has type `set_type`. The constraints are ordered by creation time. This errors if regular constraints are queried. If so, either annotate the relevant variables with [`@decision`](@ref) or first query the relevant JuMP subproblem and use the regular `all_constraints` function.
"""
function JuMP.all_constraints(stochasticprogram::StochasticProgram{N},
                              stage::Integer,
                              function_type::Type{<:Union{V,Vector{<:V}}},
                              set_type::Type{<:MOI.AbstractSet}) where {N, V <: AbstractJuMPScalar}
    1 <= stage <= N || error("Stage $stage not in range 1 to $N.")
    JuMP._error_if_not_concrete_type(function_type)
    JuMP._error_if_not_concrete_type(set_type)
    is_decision_type(V) || error("Only decision constraints can be queried. For regular constraints, either annotate the relevant variable with @decision or first query the relevant JuMP subproblem and use the regular `all_constraints` function.")
    f_type = moi_function_type(function_type)
    constraint_ref_type = if set_type <: MOI.AbstractScalarSet
        SPConstraintRef{JuMP._MOICON{f_type, set_type},
                        ScalarShape}
    else
        SPConstraintRef{JuMP._MOICON{f_type, set_type}}
    end
    m = proxy(stochasticprogram, stage)
    result = constraint_ref_type[]
    for ci in MOI.get(m, MOI.ListOfConstraintIndices{f_type, set_type}())
        if f_type <: SingleDecision
            # Change to correct index
            f = MOI.get(backend(m), MOI.ConstraintFunction(), ci)::SingleDecision
            ci = CI{SingleDecision, set_type}(f.decision.value)
        end
        push!(result, constraint_ref_with_index(stochasticprogram, stage, ci))
    end
    # Add any constraints specified at creation
    if f_type <: SingleDecision
        for ci in MOI.get(m, MOI.ListOfConstraintIndices{MOI.SingleVariable, SingleDecisionSet{Float64}}())
            set = MOI.get(backend(m), MOI.ConstraintSet(), ci)
            if set.constraint isa set_type
                inner_ci = CI{f_type, set_type}(ci.value)
                push!(result, constraint_ref_with_index(stochasticprogram, stage, inner_ci))
            end
        end
    end
    if f_type <: VectorOfDecisions
        for ci in MOI.get(m, MOI.ListOfConstraintIndices{MOI.VectorOfVariables, MultipleDecisionSet{Float64}}())
            set = MOI.get(backend(m), MOI.ConstraintSet(), ci)
            if set.constraint isa set_type
                inner_ci = CI{f_type, set_type}(ci.value)
                push!(result, constraint_ref_with_index(stochasticprogram, stage, inner_ci))
            end
        end
    end
    return result
end
"""
    list_of_constraint_types(stochasticprogram::Stochasticprogram, stage::Integer)::Vector{Tuple{DataType, DataType}}

Return a list of tuples of the form `(F, S)` where `F` is a JuMP function type and `S` is an MOI set type such that `all_constraints(stochasticprogram, stage, F, S)` returns a nonempty list.
"""
function JuMP.list_of_constraint_types(stochasticprogram::StochasticProgram, stage::Integer)::Vector{Tuple{DataType, DataType}}
    m = proxy(stochasticprogram, stage)
    decision_constraints = Tuple{DataType, DataType}[
        (jump_function_type(m, F), S)
        for (F, S) in filter(t -> is_decision_type(t[1]), MOI.get(m, MOI.ListOfConstraints()))
    ]
    # Add any constraints specified at creation
    for ci in MOI.get(m, MOI.ListOfConstraintIndices{MOI.SingleVariable, SingleDecisionSet{Float64}}())
        set = MOI.get(backend(m), MOI.ConstraintSet(), ci)
        if !(set.constraint isa NoSpecifiedConstraint)
            push!(decision_constraints, (DecisionVariable, typeof(set.constraint)))
        end
    end
    for ci in MOI.get(m, MOI.ListOfConstraintIndices{MOI.VectorOfVariables, MultipleDecisionSet{Float64}}())
        set = MOI.get(backend(m), MOI.ConstraintSet(), ci)
        if !(set.constraint isa NoSpecifiedConstraint)
            push!(decision_constraints, (Vector{DecisionVariable}, typeof(set.constraint)))
        end
    end
    return decision_constraints
end

# Printing #
# ========================== #
function Base.show(io::IO, sp_cref::SPConstraintRef)
    print(io, constraint_string(REPLMode, sp_cref))
end
function Base.show(io::IO, ::MIME"text/latex", sp_cref::SPConstraintRef)
    print(io, constraint_string(IJuliaMode, sp_cref))
end
function JuMP.constraint_string(print_mode, sp_cref::SPConstraintRef; in_math_mode = false)
    return constraint_string(print_mode, name(sp_cref), constraint_object(sp_cref), in_math_mode = in_math_mode)
end
