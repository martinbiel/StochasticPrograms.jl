# MIT License
#
# Copyright (c) 2018 Martin Biel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

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

function copy_decision_objective!(src::JuMP.Model, dest::JuMP.Model, vars::Vector{DecisionRef})
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

typename(dtype::UnionAll) = dtype.body.body.name.name
typename(dtype::DataType) = dtype.name.name

function run_manual_gc()
    @everywhere GC.gc()
    @everywhere ccall(:malloc_trim, Cvoid, (Cint,), 0)
    @everywhere sleep(1)
    @everywhere GC.gc()
    @everywhere ccall(:malloc_trim, Cvoid, (Cint,), 0)
    @everywhere sleep(1)
    @everywhere GC.gc()
    @everywhere ccall(:malloc_trim, Cvoid, (Cint,), 0)
    @everywhere sleep(1)
    @everywhere GC.gc()
    @everywhere ccall(:malloc_trim, Cvoid, (Cint,), 0)
    @everywhere sleep(10)
end

function _function_type(ci::CI{F,S}) where {F,S}
    return F
end
function _set_type(ci::CI{F,S}) where {F,S}
    return S
end

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

function canonical(C::AbstractMatrix{T}, d₁::AbstractVector{T}, d₂::AbstractVector{T}; direction = :leq) where T <: AbstractFloat
    i₁      = isfinite.(d₁)
    i₂      = isfinite.(d₂)
    m₁, m₂  = sum(i₁), sum(i₂)
    m       = m₁ + m₂
    m == 0 && return zero(C), zero(d₁)
    C̃       = zeros(T, m, size(C, 2))
    d̃       = zeros(T, m)
    C̃[1:m₁,:]        = -C[i₁, :]
    d̃[1:m₁]          = -d₁[i₁]
    C̃[(m₁+1):end,:]  = C[i₂,:]
    d̃[(m₁+1):end]    = d₂[i₂]
    if direction == :leq
        return C̃, d̃
    elseif direction == :geq
        return -C̃, -d̃
    else
        error("unknown direction.")
    end
end

function canonical(C::AbstractSparseMatrix{T}, d₁::AbstractVector{T}, d₂::AbstractVector{T}; direction = :leq) where T <: AbstractFloat
    # Convert to canonical form
    i₁     = isfinite.(d₁)
    i₂     = isfinite.(d₂)
    m₁, m₂ = sum(i₁), sum(i₂)
    m      = m₁ + m₂
    m == 0 && return zero(C), zero(d₁)
    C̃ᵢ     = Vector{Int}()
    C̃ⱼ     = Vector{Int}()
    C̃ᵥ     = Vector{T}()
    d̃      = zeros(T, m)
    d̃[1:m₁] = -d₁[i₁]
    d̃[(m₁+1):end]    = d₂[i₂]
    rows   = rowvals(C)
    vals   = nonzeros(C)
    for col in 1:size(C, 2)
        for j in nzrange(C, col)
            row = rows[j]
            if i₁[row]
                idx = count(i -> i, i₁[1:row])
                push!(C̃ᵢ, idx)
                push!(C̃ⱼ, col)
                push!(C̃ᵥ, -vals[j])
            end
            if i₂[row]
                idx = count(i -> i, i₂[1:row])
                push!(C̃ᵢ, m₁ + idx)
                push!(C̃ⱼ, col)
                push!(C̃ᵥ, vals[j])
            end
        end
    end
    C̃ = sparse(C̃ᵢ, C̃ⱼ, C̃ᵥ, m, size(C, 2))
    if direction == :leq
        return C̃, d̃
    elseif direction == :geq
        return -C̃, -d̃
    else
        error("unknown direction.")
    end
end

function decision_variables_at_stage(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    return all_decisions(get_decisions(proxy(stochasticprogram, s)), s)
end

function decision_constraints_at_stage(stochasticprogram::StochasticProgram{N}, s::Integer) where N
    1 <= s <= N || error("Stage $s not in range 1 to $N.")
    proxy_ = proxy(stochasticprogram, s)
    return mapreduce(vcat, MOI.get(proxy_, MOI.ListOfConstraints())) do (F, S)
        if F <: SingleDecision
            return map(MOI.get(proxy_, MOI.ListOfConstraintIndices{F,S}())) do ci
                # Change to correct index
                f = MOI.get(backend(proxy_), MOI.ConstraintFunction(), ci)::SingleDecision
                return ci = CI{SingleDecision, S}(f.decision.value)
            end
        elseif F <: AffineDecisionFunction || F <: QuadraticDecisionFunction
            return MOI.get(proxy_, MOI.ListOfConstraintIndices{F,S}())
        else
            return CI[]
        end
    end
end

function attach_mocks!(structure::DeterministicEquivalent)
    MOIU.attach_optimizer(structure.model)
    return nothing
end

function attach_mocks!(structure::StageDecompositionStructure)
    MOIU.attach_optimizer(structure.first_stage)
    for s in subproblems(structure, 2)
        MOIU.attach_optimizer(s)
    end
    return nothing
end

function attach_mocks!(structure::ScenarioDecompositionStructure)
    return nothing
end

function decision_index(model::MOI.ModelLike, index::MOI.VariableIndex)
    ci = CI{MOI.SingleVariable,SingleDecisionSet{Float64}}(index.value)
    if MOI.is_valid(model, ci)
        return MOI.get(model, DecisionIndex(), ci)
    end
    # Locate multiple decision set
    F = MOI.VectorOfVariables
    S = MultipleDecisionSet{Float64}
    for ci in MOI.get(model, MOI.ListOfConstraintIndices{F,S}())
        f = MOI.get(model, MOI.ConstraintFunction(), ci)
        i = something(findfirst(vi -> vi == index, f.variables), 0)
        if i != 0
            return MOI.get(model, DecisionIndex(), ci)
        end
    end
end

function decision_index(model::MOI.ModelLike, ci::MOI.ConstraintIndex)
    return MOI.get(model, DecisionIndex(), ci)
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
