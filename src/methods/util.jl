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
        if @capture(x, var_Symbol)
            if var == :Bin
                set = MOI.ZeroOne()
                found = true
                return :()
            elseif var == :Int
                set = MOI.Integer()
                found = true
                return :()
            end
        elseif @capture(x, var_Symbol = true)
            if var == :binary
                set = MOI.ZeroOne()
                found = true
                return :()
            elseif var == :integer
                set = MOI.Integer()
                found = true
                return :()
            end
        elseif @capture(x, var_Symbol in constrset_) && !found && !quit
            set = constrset
            found = true
            return :($var)
        elseif @capture(x, var_Symbol[ids__] in constrset_) && !found && !quit
            set = constrset
            found = true
            return :($var[$ids])
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
# ========================== #
