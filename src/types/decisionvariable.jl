const MOIB = MOI.Bridges

struct Decision end

struct DecisionRef <: JuMP.AbstractVariableRef
    model::JuMP.Model
    index::MOI.VariableIndex
end

const GAE{C,V} = JuMP.GenericAffExpr{C,V}
const GAEV{C} = JuMP.GenericAffExpr{C,JuMP.VariableRef}
const GAEDV{C} = JuMP.GenericAffExpr{C,DecisionRef}

mutable struct DecisionVariableAffExpr{C} <: JuMP.AbstractJuMPScalar
    v::JuMP.GenericAffExpr{C, JuMP.VariableRef}
    dv::JuMP.GenericAffExpr{C, DecisionRef}
end
const DVAE{C} = DecisionVariableAffExpr{C}

function JuMP.value(aff::DecisionVariableAffExpr, value::Function)
    return JuMP.value(aff.v, value) + JuMP.value(aff.dv, value)
end

function JuMP.constant(aff::DVAE)
    return aff.v.constant
end

function JuMP.function_string(mode, aff::DecisionVariableAffExpr, show_constant=true)
    variable_terms = JuMP.function_string(mode, aff.v, false)
    decision_terms = JuMP.function_string(mode, aff.dv, false)
    first_decision_term_coef = first(linear_terms(aff.dv))[1]
    ret = string(variable_terms, JuMP._sign_string(first_decision_term_coef), decision_terms)
    if !JuMP._is_zero_for_printing(aff.v.constant) && show_constant
        ret = string(ret, JuMP._sign_string(aff.v.constant),

                     JuMP._string_round(abs(aff.v.constant)))
    end
    return ret
end

function JuMP._assert_isfinite(aff::DecisionVariableAffExpr)
    JuMP._assert_isfinite(aff.v)
    for (coef, dv) in linear_terms(aff.dv)
        isfinite(coef) || error("Invalid coefficient $coef on decision variable $dv.")
    end
end

function JuMP.check_belongs_to_model(aff::DecisionVariableAffExpr, model::AbstractModel)
    JuMP.check_belongs_to_model(aff.v, model)
    JuMP.check_belongs_to_model(aff.dv, model)
end

struct DecisionVariableSet{C, S <: Union{MOI.LessThan,MOI.GreaterThan,MOI.EqualTo}} <: MOI.AbstractScalarSet
    decision_variables::JuMP.GenericAffExpr{C, DecisionRef}
    set::S
end

function JuMP.constraint_string(print_mode, constraint_object::ScalarConstraint{F, <:DecisionVariableSet}) where F
    f = constraint_object.func - constraint_object.set.decision_variables
    s = constraint_object.set.set
    return JuMP.constraint_string(print_mode, ScalarConstraint(f, s))
end

struct DecisionVariableBridge{T, S} <: MOIB.Constraint.AbstractBridge
    constraint::MOI.ConstraintIndex{MOI.ScalarAffineFunction{T}, S}
end

function MOIB.Constraint.bridge_constraint(::Type{DecisionVariableBridge{T, S}},
                                           model,
                                           f::MOI.ScalarAffineFunction{T},
                                           dvar_set::DecisionVariableSet{T,S}) where {T, S}
    dvar_value = JuMP.value(dvar_set.decision_variables, JuMP.value)
    set = MOIU.shift_constant(dvar_set.set, convert(T, -dvar_value))
    constraint = MOI.add_constraint(model, f, set)
    return DecisionVariableBridge{T, S}(constraint)
end

function MOI.supports_constraint(::Type{<:DecisionVariableBridge{T}},
                                 ::Type{<:MOI.ScalarAffineFunction},
                                 ::Type{<:DecisionVariableSet}) where {T}
    return true
end
function MOIB.added_constrained_variable_types(::Type{<:DecisionVariableBridge})
    return Tuple{DataType}[]
end
function MOIB.added_constraint_types(::Type{<:DecisionVariableBridge{T, S}}) where {T, S}
    return [(MOI.ScalarAffineFunction{T}, S)]
end
function MOIB.Constraint.concrete_bridge_type(::Type{<:DecisionVariableBridge},
                              ::Type{<:MOI.ScalarAffineFunction},
                              ::Type{<:DecisionVariableSet{T,S}}) where {T,S}
    return DecisionVariableBridge{T, S}
end

MOI.get(b::DecisionVariableBridge{T, S}, ::MOI.NumberOfConstraints{MOI.ScalarAffineFunction{T}, S}) where {T, S} = 1
MOI.get(b::DecisionVariableBridge{T, S}, ::MOI.ListOfConstraintIndices{MOI.ScalarAffineFunction{T}, S}) where {T, S} = [b.constraint]

function MOI.set(model::MOI.ModelLike, ::MOI.ConstraintSet,
                 bridge::DecisionVariableBridge{T, S}, change::S) where {T, S}
    MOI.set(model, MOI.ConstraintSet(), bridge.constraint, change)
end

function MOI.delete(model::MOI.ModelLike, c::DecisionVariableBridge)
    MOI.delete(model, c.constraint)
    return
end

function JuMP.build_constraint(_error::Function, aff::DecisionVariableAffExpr, set::S) where S <: Union{MOI.LessThan,MOI.GreaterThan,MOI.EqualTo}
    offset = constant(aff.v)
    add_to_expression!(aff.v, -offset)
    shifted_set = MOIU.shift_constant(set, -offset)
    parameterized_set = DecisionVariableSet(-aff.dv, shifted_set)
    constraint = JuMP.ScalarConstraint(aff.v, parameterized_set)
    return JuMP.BridgeableConstraint(constraint, DecisionVariableBridge)
end

function JuMP.build_constraint(_error::Function, aff::DecisionVariableAffExpr, lb, ub)
    JuMP.build_constraint(_error, aff, MOI.Interval(lb, ub))
end

mutable struct DecisionVariable{T} <: JuMP.AbstractVariable
    value::T

    function DecisionVariable(val::T) where T
        return new{T}(val)
    end
end

function value(dv::DecisionVariable)
    return dv.value
end

struct DecisionVariables{T}
    parent_model::JuMP.Model
    data::Dict{Int, DecisionVariable{T}}

    function DecisionVariables(::Type{T}) where T <: AbstractFloat
        return new{T}(Model(), Dict{Int, DecisionVariable{T}}())
    end
end

function _update_decision_variables(decision_variables::DecisionVariables, x::AbstractVector)
    for (i, dv) in decision_variables.data
        i > length(x) && error("Given decision of length $(length(x)) not compatible with defined decision variable $((i, dv)).")
        dv.value = x[i]
    end
    return
end

function _parent_model(decision_variables::DecisionVariables)
    return decision_variables.parent_model
end

function _getdecisionvariables(model::JuMP.Model)
    !haskey(model.ext, :decisionvariables) && error("No decision variables in model")
    return model.ext[:decisionvariables]
end

function _getdecisionvariables(decision::DecisionRef)
    return _getdecisionvariables(decision.model)
end

function add_decision_variable(model::JuMP.Model, name::String, dv::DecisionVariable)
    decision_variables = _getdecisionvariables(model)
    parent_variable = variable_by_name(decision_variables.parent_model, name)
    parent_variable == nothing && error("No matching decision variable with name $name in parent model.")
    _index = index(parent_variable)
    if !haskey(decision_variables.data, _index.value)
        decision_variables.data[_index.value] = dv
    end
    dref = DecisionRef(model, _index)
    return dref
end

function update_decision_variable_constraints(model::JuMP.Model)
    F = GAEV{Float64}
    for set_type in [MOI.EqualTo{Float64}, MOI.LessThan{Float64}, MOI.GreaterThan{Float64}]
        S = DecisionVariableSet{Float64, set_type}
        for cref in all_constraints(model, F, S)
            _update_decision_variables_constraint(cref)
        end
    end
end

function _update_decision_variables_constraint(cref::ConstraintRef)
    _update_decision_variables_constraint(backend(owner_model(cref)), cref.index)
end

function _update_decision_variables_constraint(model::MOI.ModelLike, ci::MOI.ConstraintIndex{MOI.ScalarAffineFunction{T}, DecisionVariableSet{T,S}}) where {T,S}
    dvar_set = MOI.get(model, MOI.ConstraintSet(), ci)
    dvar_value = JuMP.value(dvar_set.decision_variables, JuMP.value)
    set = MOIU.shift_constant(dvar_set.set, convert(T, dvar_value))
    MOI.set(model, MOI.ConstraintSet(), ci, set)
    return
end

function JuMP.name(dref::DecisionRef)
    decision_variables = _getdecisionvariables(dref)
    parent_model = _parent_model(decision_variables)
    parent_variable = VariableRef(parent_model, dref.index)
    return MOI.get(parent_model, MOI.VariableName(), parent_variable)::String
end

JuMP.index(dref::DecisionRef) = dref.index

function JuMP.value(dref::DecisionRef)
    decision_variables = _getdecisionvariables(dref)
    return value(decision_variables.data[dref.index.value])
end

_invalid_init_error(msg) = error("Invalid initialization of decision. " * msg * " not supported.")


function JuMP.build_variable(_error::Function, info::JuMP.VariableInfo, ::Decision)
    if info.has_fix
        return DecisionVariable(info.fixed_value)
    end
    return DecisionVariable(0.0)
end

function JuMP.add_variable(model::JuMP.Model, dv::DecisionVariable, name::String="")
    isempty(name) && error("Name must be provided for decision variables.")
    dref = add_decision_variable(model, name, dv)
    return dref
end


Base.one(::Type{DecisionRef}) = one(GAEDV{Float64})

Base.iszero(aff::DVAE) = iszero(aff.v) && iszero(aff.dv)
Base.zero(::Type{DVAE{C}}) where {C} = DVAE{C}(zero(GAEV{C}), zero(GAEDV{C}))
Base.one(::Type{DVAE{C}}) where {C} = DVAE{C}(one(GAEV{C}), zero(GAEDV{C}))
Base.zero(aff::DVAE) = zero(typeof(aff))
Base.one(aff::DVAE) =  one(typeof(aff))
Base.copy(aff::DVAE{C}) where {C}  = DVAE{C}(copy(aff.v), copy(aff.dv))
Base.broadcastable(expr::DVAE) = Ref(expr)

DVAE{C}() where {C} = zero(DVAE{C})

Base.convert(::Type{DVAE{C}}, aff::GAEV{C}) where {C} = DVAE{C}(aff, GAEDV{C}(zero(C)))

# Number--DecisionRef
Base.:(+)(lhs::C, rhs::DecisionRef) where C<:Number = DVAE{C}(GAEV{C}(convert(C, lhs)), GAEDV{C}(zero(C), rhs => +one(C)))
Base.:(-)(lhs::C, rhs::DecisionRef) where C<:Number = DVAE{C}(GAEV{C}(convert(C, lhs)), GAEDV{C}(zero(C), rhs => -one(C)))
Base.:(*)(lhs::C, rhs::DecisionRef) where C<:Number = DVAE{C}(GAEV{C}(zero(C)), GAEDV{C}(zero(C), rhs => lhs))

# Number--DVAE
Base.:(+)(lhs::Number, rhs::DVAE{C}) where C<:Number = DVAE{C}(lhs+rhs.v, copy(rhs.dv))
Base.:(-)(lhs::Number, rhs::DVAE{C}) where C<:Number = DVAE{C}(lhs-rhs.v, -rhs.dv)
Base.:(*)(lhs::Number, rhs::DVAE{C}) where C<:Number = DVAE{C}(lhs*rhs.v, lhs*rhs.dv)

#=
    DecisionRef
=#

# AbstractJuMPScalar
Base.:(-)(lhs::DecisionRef) = DVAE{Float64}(GAEV{Float64}(0.0), GAEDV{Float64}(0.0, lhs => -1.0))

# DecisionRef--Number
Base.:(+)(lhs::DecisionRef, rhs::Number) = (+)(rhs, lhs)
Base.:(-)(lhs::DecisionRef, rhs::Number) = (+)(-rhs, lhs)
Base.:(*)(lhs::DecisionRef, rhs::Number) = (*)(rhs, lhs)
Base.:(/)(lhs::DecisionRef, rhs::Number) = (*)(1.0 / rhs, lhs)

# DecisionRef--VariableRef
Base.:(+)(lhs::DecisionRef, rhs::JuMP.VariableRef) = DVAE{Float64}(GAEV{Float64}(0.0, rhs => +1.0), GAEDV{Float64}(0.0, lhs => 1.0))
Base.:(-)(lhs::DecisionRef, rhs::JuMP.VariableRef) = DVAE{Float64}(GAEV{Float64}(0.0, rhs => -1.0), GAEDV{Float64}(0.0, lhs => 1.0))

# DecisionRef--DecisionRef
Base.:(+)(lhs::DecisionRef, rhs::DecisionRef) = DVAE{Float64}(GAEV{Float64}(0.0), GAEDV{Float64}(0.0, lhs => 1.0, rhs => +1.0))
Base.:(-)(lhs::DecisionRef, rhs::DecisionRef) = DVAE{Float64}(GAEV{Float64}(0.0), GAEDV{Float64}(0.0, lhs => 1.0, rhs => -1.0))

# DecisionRef--GAEDV
Base.:(+)(lhs::DecisionRef, rhs::GAEDV{C}) where C = (+)(GAEDV{C}(zero(C), lhs => 1.0),  rhs)
Base.:(-)(lhs::DecisionRef, rhs::GAEDV{C}) where C = (+)(GAEDV{C}(zero(C), lhs => 1.0), -rhs)

# DecisionRef--GAEV/GenericAffExpr{C,VariableRef}
Base.:(+)(lhs::DecisionRef, rhs::GAEV{C}) where {C} = DVAE{C}(copy(rhs),GAEDV{C}(zero(C), lhs => 1.))
Base.:(-)(lhs::DecisionRef, rhs::GAEV{C}) where {C} = DVAE{C}(-rhs,GAEDV{C}(zero(C), lhs => 1.))

# DecisionRef--DVAE{C}
Base.:(+)(lhs::DecisionRef, rhs::DVAE{C}) where {C} = DVAE{C}(copy(rhs.v),lhs+rhs.dv)
Base.:(-)(lhs::DecisionRef, rhs::DVAE{C}) where {C} = DVAE{C}(-rhs.v,lhs-rhs.dv)

#=
    VariableRef
=#

# VariableRef--DecisionRef
Base.:(+)(lhs::JuMP.VariableRef, rhs::DecisionRef) = DVAE{Float64}(GAEV{Float64}(zero(Float64), lhs => 1.0),GAEDV{Float64}(zero(Float64), rhs =>  1.0))
Base.:(-)(lhs::JuMP.VariableRef, rhs::DecisionRef) = DVAE{Float64}(GAEV{Float64}(zero(Float64), lhs => 1.0),GAEDV{Float64}(zero(Float64), rhs => -1.0))

# VariableRef--GenericAffExpr{C,DecisionRef}
Base.:(+)(lhs::JuMP.VariableRef, rhs::GAEDV{C}) where {C} = DVAE{C}(GAEV{C}(zero(C), lhs => 1.),copy(rhs))
Base.:(-)(lhs::JuMP.VariableRef, rhs::GAEDV{C}) where {C} = DVAE{C}(GAEV{C}(zero(C), lhs => 1.),-rhs)

# VariableRef--DVAE{C}
Base.:(+)(lhs::JuMP.VariableRef, rhs::DVAE{C}) where {C} = DVAE{C}(lhs + rhs.v, copy(rhs.dv))
Base.:(-)(lhs::JuMP.VariableRef, rhs::DVAE{C}) where {C} = DVAE{C}(lhs - rhs.v, -rhs.dv)

#=
    GenericAffExpr{C,VariableRef}
=#

# GenericAffExpr{C,VariableRef}--DecisionRef
Base.:(+)(lhs::GAEV{C}, rhs::DecisionRef) where {C} = (+)(rhs,lhs)
Base.:(-)(lhs::GAEV{C}, rhs::DecisionRef) where {C} = (+)(-rhs,lhs)

# GenericAffExpr{C,VariableRef}--GenericAffExpr{C,DecisionRef}
Base.:(+)(lhs::GAEV{C}, rhs::GAEDV{C}) where {C} = DVAE{C}(copy(lhs),copy(rhs))
Base.:(-)(lhs::GAEV{C}, rhs::GAEDV{C}) where {C} = DVAE{C}(copy(lhs),-rhs)

# GenericAffExpr{C,VariableRef}--DVAE{C}
Base.:(+)(lhs::GAEV{C}, rhs::DVAE{C}) where {C} = DVAE{C}(lhs+rhs.v,copy(rhs.dv))
Base.:(-)(lhs::GAEV{C}, rhs::DVAE{C}) where {C} = DVAE{C}(lhs-rhs.v,-rhs.dv)

#=
    GenericAffExpr{C,DecisionRef}/GAEDV
=#

# GenericAffExpr{C,DecisionRef}--VariableRef
Base.:(+)(lhs::GAEDV{C}, rhs::JuMP.VariableRef) where {C} = (+)(rhs,lhs)
Base.:(-)(lhs::GAEDV{C}, rhs::JuMP.VariableRef) where {C} = (+)(-rhs,lhs)

# GenericAffExpr{C,DecisionRef}--GenericAffExpr{C,VariableRef}
Base.:(+)(lhs::GAEDV{C}, rhs::GAEV{C}) where {C} = (+)(rhs,lhs)
Base.:(-)(lhs::GAEDV{C}, rhs::GAEV{C}) where {C} = (+)(-rhs,lhs)

#=
    DVAE{C}
=#

Base.:(-)(lhs::DVAE{C}) where C = DVAE{C}(-lhs.v, -lhs.dv)

# Number--DVAE
Base.:(+)(lhs::DVAE, rhs::Number) = (+)(rhs,lhs)
Base.:(-)(lhs::DVAE, rhs::Number) = (+)(-rhs,lhs)
Base.:(*)(lhs::DVAE, rhs::Number) = (*)(rhs,lhs)

# DVAE{C}--DecisionRef
Base.:(+)(lhs::DVAE{C}, rhs::DecisionRef) where {C} = (+)(rhs,lhs)
Base.:(-)(lhs::DVAE{C}, rhs::DecisionRef) where {C} = (+)(-rhs,lhs)

# VariableRef--DVAE{C}
Base.:(+)(lhs::DVAE{C}, rhs::JuMP.VariableRef) where {C} = (+)(rhs,lhs)
Base.:(-)(lhs::DVAE{C}, rhs::JuMP.VariableRef) where {C} = (+)(-rhs,lhs)

# DVAE{C}--GenericAffExpr{C,VariableRef}
# DVAE{C}--GenericAffExpr{C,DecisionRef}
Base.:(+)(lhs::DVAE{C}, rhs::GAE{C,V}) where {C,V} = (+)(rhs,lhs)
Base.:(-)(lhs::DVAE{C}, rhs::GAE{C,V}) where {C,V} = (+)(-rhs,lhs)

# DVAE{C}--DVAE{C}
Base.:(+)(lhs::DVAE{C}, rhs::DVAE{C}) where {C} = DVAE{C}(lhs.v+rhs.v,lhs.dv+rhs.dv)
Base.:(-)(lhs::DVAE{C}, rhs::DVAE{C}) where {C} = DVAE{C}(lhs.v-rhs.v,lhs.dv-rhs.dv)
