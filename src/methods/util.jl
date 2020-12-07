# Utility #
# ========================== #
function evaluate_objective(objective::JuMP.GenericAffExpr, x::AbstractVector)
    val = objective.constant
    for (var, coeff) in objective.terms
        val += coeff*x[index(var).value]
    end
    return val
end

function invalidate_cache!(stochasticprogram::StochasticProgram)
    cache = problemcache(stochasticprogram)
    delete!(cache, :evp)
    delete!(cache, :dep)
    delete!(cache, :stage_1)
    cache = solutioncache(stochasticprogram)
    delete!(cache, :solution)
    return nothing
end

function remove_scenarios!(stochasticprogram::StochasticProgram, s::Integer = 2)
    remove_scenarios!(scenarioproblems(stochasticprogram, s))
    return nothing
end

function remove_decision_variables!(stochasticprogram::StochasticProgram, s::Integer)
    remove_decision_variables!(scenarioproblems(stochasticprogram, s))
    return nothing
end

function remove_subproblems!(stochasticprogram::StochasticProgram, s::Integer = 2)
    remove_subproblems!(scenarioproblems(stochasticprogram, s))
    return nothing
end

function transfer_model!(dest::StochasticProgram, src::StochasticProgram)
    empty!(dest.generator)
    merge!(dest.generator, src.generator)
    return dest
end

function copy_decision_objective!(src::JuMP.Model, dest::JuMP.Model, vars::Vector{<:Union{DecisionRef, KnownRef}})
    src_obj = objective_function(src)
    src_obj_sense = objective_sense(src)
    dest_obj_sense = objective_sense(dest)
    for var in vars
        src_var = decision_by_name(src, name(var))
        src_var === nothing && error("Cannot copy objective function. Variable $var not in src model.")
        coeff = JuMP._affine_coefficient(src_obj, src_var)
        if dest_obj_sense == src_obj_sense
            set_objective_coefficient(dest, var, coeff)
        else
            set_objective_coefficient(dest, var, -coeff)
        end
    end
    dest_obj = objective_function(dest)
    if dest_obj_sense == src_obj_sense
        set_objective_function(dest, dest_obj + constant(src_obj))
    else
        set_objective_function(dest, -dest_obj + constant(src_obj))
        set_objective_sense(dest, src_obj_sense)
    end
    return nothing
end

function supports_zero(types::Vector, provided_def::Bool)
    for vartype in types
        if !hasmethod(zero, (Type{vartype}, ))
            !provided_def && @warn "Zero not defined for $vartype. Cannot generate zero function."
            return false
        end
    end
    return true
end

function supports_expected(types::Vector, provided_def::Bool)
    for vartype in types
        if !hasmethod(+, (vartype, vartype))
            !provided_def && @warn "Addition not defined for $vartype. Cannot generate expectation function."
            return false
        end
        if !hasmethod(*, (Float64, vartype)) || Base.code_typed(*, (Float64, vartype))[1].second != vartype
            !provided_def && @warn "Scalar multiplication with Float64 not defined for $vartype. Cannot generate expectation function."
            return false
        end
    end
    return true
end

problemcache(stochasticprogram::StochasticProgram) = stochasticprogram.problemcache
solutioncache(stochasticprogram::StochasticProgram) = stochasticprogram.solutioncache
function get_problem(stochasticprogram::StochasticProgram, key::Symbol)
    haskey(stochasticprogram.problemcache, key)|| error("No $key in problem cache")
    return stochasticprogram.problemcache[key]
end

typename(dtype::UnionAll) = dtype.body.name.name
typename(dtype::DataType) = dtype.name.name

function add_subscript(src::AbstractString, subscript::Integer)
    return @sprintf("%s%s", src, unicode_subscript(subscript))
end
add_subscript(src::Symbol, subscript::Integer) = add_subscript(String(src), subscript)

function unicode_subscript(subscript::Integer)
    if subscript < 0
        error("$subscript is negative")
    end
    return join('₀'+d for d in reverse(digits(subscript)))
end

function extract_set(expr)
    set = NoSpecifiedConstraint()
    found = false
    quit = false
    new_expr = prewalk(expr) do x
        if @capture(x, var_Symbol in constrset_) && !found && !quit
            set = constrset
            found = true
            return :($var)
        elseif @capture(x, var_Symbol[ids__] in constrset_) && !found && !quit
            set = constrset
            found = true
            return :($(x.args[2]))
        elseif @capture(x, [ids__] in constrset_) && !found && !quit
            set = constrset
            found = true
            return :($(x.args[2]))
        elseif @capture(x, set = constrset_) && !found && !quit
            set = constrset
            found = true
            return :()
        elseif @capture(x, var_Symbol[ids__])
            # Break here to prevent indices from being filtered
            quit = true
            return x
        else
            return x
        end
    end
    return set, new_expr, found
end

function decision_variables_at_stage(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    return get_decisions(proxy(stochasticprogram, s), s).undecided
end

function decision_constraints_at_stage(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    return mapreduce(vcat, MOI.get(proxy(stochasticprogram, s), MOI.ListOfConstraints())) do (F, S)
        if F <: SingleDecision || F <: AffineDecisionFunction || F <: QuadraticDecisionFunction
            return MOI.get(proxy(stochasticprogram, s), MOI.ListOfConstraintIndices{F,S}())
        end
        return CI[]
    end
end

function attach_mocks!(structure::DeterministicEquivalent)
    MOIU.attach_optimizer(structure.model)
    return nothing
end

function attach_mocks!(structure::VerticalStructure)
    MOIU.attach_optimizer(structure.first_stage)
    for s in subproblems(structure, 2)
        MOIU.attach_optimizer(s)
    end
    return nothing
end

function attach_mocks!(structure::HorizontalStructure)
    return nothing
end

function mock_index(dvar::DecisionVariable)
    return MOIU.xor_index(optimizer_index(dvar))
end
function mock_index(dvar::DecisionVariable, scenario_index::Integer)
    return MOIU.xor_index(optimizer_index(dvar, scenario_index))
end
function mock_index(sp_cref::SPConstraintRef{CI{AffineDecisionFunction{Float64},S}}) where S
    idx = optimizer_index(sp_cref)
    return MOIU.xor_index(CI{MOI.ScalarAffineFunction{Float64},S}(idx.value))
end
function mock_index(sp_cref::SPConstraintRef{CI{AffineDecisionFunction{Float64},S}}, scenario_index::Integer) where S
    idx = optimizer_index(sp_cref, scenario_index)
    return MOIU.xor_index(CI{MOI.ScalarAffineFunction{Float64},S}(idx.value))
end
function mock_index(sp_cref::SPConstraintRef{CI{SingleDecision,S}}) where S
    idx = optimizer_index(sp_cref)
    return MOIU.xor_index(CI{MOI.SingleVariable,S}(idx.value))
end
function mock_index(sp_cref::SPConstraintRef{CI{SingleDecision,S}}, scenario_index::Integer) where S
    idx = optimizer_index(sp_cref, scenario_index)
    return MOIU.xor_index(CI{MOI.SingleVariable,S}(idx.value))
end

function MOI.get(src::MOIU.MockOptimizer, attr::ScenarioDependentModelAttribute)
    return MOI.get(src, attr.attr)
end

function MOI.get(src::MOIU.MockOptimizer, attr::ScenarioDependentVariableAttribute, index::MOI.VariableIndex)
    return MOI.get(src, attr.attr, index)
end

function MOI.get(src::MOIU.MockOptimizer, attr::ScenarioDependentConstraintAttribute, ci::MOI.ConstraintIndex)
    return MOI.get(src, attr.attr, ci)
end

function MOI.set(src::MOIU.MockOptimizer, attr::ScenarioDependentModelAttribute, value)
    return MOI.set(src, attr.attr, value)
end

function MOI.set(src::MOIU.MockOptimizer, attr::ScenarioDependentVariableAttribute, index::MOI.VariableIndex, value)
    return MOI.set(src, attr.attr, index, value)
end

function MOI.set(src::MOIU.MockOptimizer, attr::ScenarioDependentConstraintAttribute, ci::MOI.ConstraintIndex, value)
    return MOI.set(src, attr.attr, ci, value)
end
# ========================== #
