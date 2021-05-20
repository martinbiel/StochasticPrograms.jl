function restore!(model::MOI.ModelLike, ::AbstractIntegerAlgorithm)
    return nothing
end

function check_optimality(lshaped::AbstractLShaped, ::AbstractIntegerAlgorithm)
    return all(1:num_subproblems(lshaped)) do idx
        if has_metadata(lshaped.execution.metadata, idx, :integral_solution)
            return get_metadata(lshaped.execution.metadata, idx, :integral_solution)
        else
            error("Worker $idx has not reported if latest solution satisfies integral restrictions.")
        end
    end
end

function is_approx_integer(val::AbstractFloat)
    return ceil(val) - val <= sqrt(eps()) || val - floor(val) <= sqrt(eps())
end

function gather_integer_variables(subproblem::SubProblem)
    model = subproblem.model
    N = num_stages(model.ext[:decisions])
    all_known = mapreduce(vcat, 1:N-1) do s
        index.(all_known_decision_variables(model, s))
    end
    all_decisions = index.(all_decision_variables(model, N))
    indices = Vector{MOI.VariableIndex}()
    for var in all_variables(model)
        vi = index(var)
        if vi in all_known
            # Known decision, skip
            continue
        end
        if vi in all_decisions
            # Decision variable
            dref = DecisionRef(model, vi)
            if is_integer(dref) || is_binary(dref)
                push!(indices, vi)
            else
                continue
            end
        else
            if is_integer(var) || is_binary(var)
                push!(indices, vi)
            else
                continue
            end
        end
    end
    return indices
end

function check_integrality_restrictions(subproblem::SubProblem, fractional = Vector{MOI.VariableIndex}())
    satisfies_integer = map(integer_variables(subproblem.integer_algorithm)) do vi
        val = MOI.get(subproblem.optimizer, MOI.VariablePrimal(), vi)
        if is_approx_integer(MOI.get(subproblem.optimizer, MOI.VariablePrimal(), vi))
            return true
        else
            push!(fractional, vi)
            return false
        end
    end
    return all(satisfies_integer)
end

mutable struct SecondStageLP{T_ <: AbstractFloat}
    T::SparseMatrixCSC{T_,Int}
    W::SparseMatrixCSC{T_,Int}
    h::Vector{T_}
    lb::Vector{T_}
    ub::Vector{T_}
end

function SecondStageLP(subproblem::SubProblem{T_}; standard_form = false) where T_ <: AbstractFloat
    model = subproblem.model
    nx = StochasticPrograms.num_known_decisions(model)
    ny = num_variables(model) - nx
    # Prepare data
    Tᵢ = Vector{Int}()
    Tⱼ = Vector{Int}()
    Tᵥ = Vector{T_}()
    Wᵢ = Vector{Int}()
    Wⱼ = Vector{Int}()
    Wᵥ = Vector{T_}()
    lhs = Vector{T_}()
    rhs = Vector{T_}()
    lb = fill(-Inf, ny)
    ub = fill(Inf, ny)
    i = 0
    slack = 0
    # Loop over constraints
    for (F,S) in list_of_constraint_types(model)
        for cref in all_constraints(model, F, S)
            if S <: StochasticPrograms.SingleDecisionSet ||
                S <: StochasticPrograms.MultipleDecisionSet
                continue
            elseif F <: VariableRef || F <: DecisionRef
                f = MOI.get(model, MOI.ConstraintFunction(), cref)
                if f isa MOI.SingleVariable
                    idx = f.variable.value - nx
                elseif f isa SingleDecision
                    idx = f.decision.value - nx
                end
                set = MOI.get(model, MOI.ConstraintSet(), cref)
                if set isa MOI.LessThan
                    ub[idx] = set.upper
                    if standard_form
                        i += 1
                        slack += 1
                        push!(Wᵢ, i)
                        push!(Wⱼ, idx)
                        push!(Wᵥ, 1.0)
                        push!(Wᵢ, i)
                        push!(Wⱼ, ny + slack)
                        push!(Wᵥ, 1.0)
                        push!(lhs, -Inf)
                        push!(rhs, set.upper)
                    end
                elseif set isa MOI.GreaterThan
                    lb[idx] = set.lower
                elseif set isa MOI.EqualTo
                    lb[idx] = set.value
                    ub[idx] = set.value
                end
            elseif F <: AffExpr
                i += 1
                f = MOI.get(model, MOI.ConstraintFunction(), cref)
                for term in f.terms
                    push!(Wᵢ, i)
                    push!(Wⱼ, term.variable_index.value - nx)
                    push!(Wᵥ, term.coefficient)
                end
                set = MOI.get(model, MOI.ConstraintSet(), cref)
                if set isa MOI.LessThan
                    push!(lhs, -Inf)
                    push!(rhs, set.upper)
                    if standard_form
                        slack += 1
                        push!(Wᵢ, i)
                        push!(Wⱼ, ny + slack)
                        push!(Wᵥ, 1.0)
                    end
                elseif set isa MOI.GreaterThan
                    push!(lhs, set.lower)
                    push!(rhs, Inf)
                    if standard_form
                        slack += 1
                        push!(Wᵢ, i)
                        push!(Wⱼ, ny + slack)
                        push!(Wᵥ, -1.0)
                    end
                elseif set isa MOI.EqualTo
                    push!(lhs, set.value)
                    push!(rhs, set.value)
                    if standard_form
                        slack += 1
                        push!(Wᵢ, i)
                        push!(Wⱼ, ny + slack)
                        push!(Wᵥ, 1.0)
                    end
                end
            elseif F <: Vector{<:AffExpr}
                f = MOI.get(model, MOI.ConstraintFunction(), cref)
                set = MOI.get(model, MOI.ConstraintSet(), cref)
                for (j,fⱼ) in enumerate(MOIU.eachscalar(f))
                    i += 1
                    for term in fⱼ.terms
                        push!(Wᵢ, i)
                        push!(Wⱼ, term.variable_index.value - nx)
                        push!(Wᵥ, term.coefficient)
                    end
                    if set isa MOI.Nonpositives
                        push!(lhs, -Inf)
                        push!(rhs, -f.constants[j])
                        if standard_form
                            slack += 1
                            push!(Wᵢ, i)
                            push!(Wⱼ, ny + slack)
                            push!(Wᵥ, 1.0)
                        end
                    elseif set isa MOI.Nonnegatives
                        push!(lhs, -f.constants[j])
                        push!(rhs, Inf)
                        if standard_form
                            slack += 1
                            push!(Wᵢ, i)
                            push!(Wⱼ, ny + slack)
                            push!(Wᵥ, -1.0)
                        end
                    elseif set isa MOI.Zeros
                        push!(lhs, -f.constants[j])
                        push!(rhs, -f.constants[j])
                        if standard_form
                            slack += 1
                            push!(Wᵢ, i)
                            push!(Wⱼ, ny + slack)
                            push!(Wᵥ, 1.0)
                        end
                    end
                end
            elseif F <: DecisionAffExpr
                i += 1
                aff = jump_function(model, MOI.get(model, MOI.ConstraintFunction(), cref))
                for (coeff, var) in linear_terms(aff.variables)
                    push!(Wᵢ, i)
                    push!(Wⱼ, index(var).value - nx)
                    push!(Wᵥ, coeff)
                end
                for (coeff, dvar) in linear_terms(aff.decisions)
                    if state(dvar) == Known
                        push!(Tᵢ, i)
                        push!(Tⱼ, index(dvar).value)
                        push!(Tᵥ, coeff)
                    else
                        push!(Wᵢ, i)
                        push!(Wⱼ, index(dvar).value - nx)
                        push!(Wᵥ, coeff)
                    end
                end
                set = MOI.get(model, MOI.ConstraintSet(), cref)
                if set isa MOI.LessThan
                    push!(lhs, -Inf)
                    push!(rhs, set.upper)
                    if standard_form
                        slack += 1
                        push!(Wᵢ, i)
                        push!(Wⱼ, ny + slack)
                        push!(Wᵥ, 1.0)
                    end
                elseif set isa MOI.GreaterThan
                    push!(lhs, set.lower)
                    push!(rhs, Inf)
                    if standard_form
                        slack += 1
                        push!(Wᵢ, i)
                        push!(Wⱼ, ny + slack)
                        push!(Wᵥ, -1.0)
                    end
                elseif set isa MOI.EqualTo
                    push!(lhs, set.value)
                    push!(rhs, set.value)
                    if standard_form
                        slack += 1
                        push!(Wᵢ, i)
                        push!(Wⱼ, ny + slack)
                        push!(Wᵥ, 1.0)
                    end
                end
            elseif F <: Vector{<:DecisionAffExpr}
                f = MOI.get(model, MOI.ConstraintFunction(), cref)
                set = MOI.get(model, MOI.ConstraintSet(), cref)
                for (j,fⱼ) in enumerate(MOIU.eachscalar(f))
                    i += 1
                    aff = jump_function(model, fⱼ)
                    for (coeff, var) in linear_terms(aff.variables)
                        push!(Wᵢ, i)
                        push!(Wⱼ, index(var).value - nx)
                        push!(Wᵥ, coeff)
                    end
                    for (coeff, dvar) in linear_terms(aff.decisions)
                        if state(dvar) == Known
                            push!(Tᵢ, i)
                            push!(Tⱼ, index(dvar).value)
                            push!(Tᵥ, coeff)
                        else
                            push!(Wᵢ, i)
                            push!(Wⱼ, index(dvar).value - nx)
                            push!(Wᵥ, coeff)
                        end
                    end
                    if set isa MOI.Nonpositives
                        push!(lhs, -Inf)
                        push!(rhs, -f.variable_part.constants[j])
                        if standard_form
                            slack += 1
                            push!(Wᵢ, i)
                            push!(Wⱼ, ny + slack)
                            push!(Wᵥ, 1.0)
                        end
                    elseif set isa MOI.Nonnegatives
                        push!(lhs, -f.variable_part.constants[j])
                        push!(rhs, Inf)
                        if standard_form
                            slack += 1
                            push!(Wᵢ, i)
                            push!(Wⱼ, ny + slack)
                            push!(Wᵥ, -1.0)
                        end
                    elseif set isa MOI.Zeros
                        push!(lhs, -f.variable_part.constants[j])
                        push!(rhs, -f.variable_part.constants[j])
                        if standard_form
                            slack += 1
                            push!(Wᵢ, i)
                            push!(Wⱼ, ny + slack)
                            push!(Wᵥ, 1.0)
                        end
                    end
                end
            else
                error("Cannot extract linear representation from $F-$S constraint.")
            end
        end
    end
    T̃ = sparse(Tᵢ, Tⱼ, Tᵥ, i, nx)
    W̃ = sparse(Wᵢ, Wⱼ, Wᵥ, i, ny + slack)
    if standard_form
        h = lhs
        i = .!isfinite.(h)
        h[i] .= rhs[i]
        return SecondStageLP(T̃, W̃, h, lb, ub)
    else
        T, h = StochasticPrograms.canonical(T̃, lhs, rhs)
        W, h = StochasticPrograms.canonical(W̃, lhs, rhs)
        return SecondStageLP(-T, -W, -h, lb, ub)
    end
end

function optimal_basis(subproblem::SubProblem)
    model = subproblem.model
    nx = StochasticPrograms.num_known_decisions(model)
    ny = num_variables(model) - nx
    variable_basis = Int[]
    slack_basis = Int[]
    slack = 0
    # Loop over constraints
    for (F,S) in list_of_constraint_types(model)
        for cref in all_constraints(model, F, S)
            if S <: StochasticPrograms.SingleDecisionSet ||
                S <: StochasticPrograms.MultipleDecisionSet
                continue
            elseif F <: VariableRef || F <: DecisionRef
                f = MOI.get(model, MOI.ConstraintFunction(), cref)
                set = MOI.get(model, MOI.ConstraintSet(), cref)
                if f isa MOI.SingleVariable
                    idx = f.variable.value - nx
                elseif f isa SingleDecision
                    idx = f.decision.value - nx
                end
                if set isa MOI.LessThan || set isa MOI.EqualTo
                    slack += 1
                    if MOI.get(model, MOI.ConstraintBasisStatus(), cref) == MOI.BASIC
                        push!(slack_basis, ny + slack)
                    end
                elseif set isa MOI.GreaterThan
                    if MOI.get(model, MOI.ConstraintBasisStatus(), cref) == MOI.BASIC
                        push!(variable_basis, idx)
                    end
                end
            elseif F <: AffExpr || F <: DecisionAffExpr
                slack += 1
                if MOI.get(model, MOI.ConstraintBasisStatus(), cref) == MOI.BASIC
                    push!(slack_basis, ny + slack)
                end
            else
                error("Cannot extract basis from $F-$S constraint.")
            end
        end
    end
    return vcat(variable_basis, slack_basis)
end

function add_row!(lp::SecondStageLP, T̄::AbstractVector, W̄::AbstractVector, h̄::AbstractFloat; standard_form = false)
    # Get current size
    m = size(lp.W, 1)
    nx = size(lp.T, 2)
    ny = size(lp.W, 2)
    if standard_form
        # Prepare to add new slack variable
        ny += 1
    end
    # Get current matrix structure
    Tᵢ, Tⱼ, Tᵥ = findnz(lp.T)
    Wᵢ, Wⱼ, Wᵥ = findnz(lp.W)
    # Add T row
    for (j, coeff) in enumerate(T̄)
        if abs(coeff) >= sqrt(eps())
            push!(Tᵢ, m + 1)
            push!(Tⱼ, j)
            push!(Tᵥ, coeff)
        end
    end
    lp.T = sparse(Tᵢ, Tⱼ, Tᵥ, m + 1, nx)
    # Add W row
    for (j, coeff) in enumerate(W̄)
        if abs(coeff) >= sqrt(eps())
            push!(Wᵢ, m + 1)
            push!(Wⱼ, j)
            push!(Wᵥ, coeff)
        end
    end
    if standard_form
        # Add slack term
        push!(Wᵢ, m + 1)
        push!(Wⱼ, ny)
        push!(Wᵥ, -1.0)
    end
    lp.W = sparse(Wᵢ, Wⱼ, Wᵥ, m + 1, ny)
    # Add new rhs
    push!(lp.h, h̄)
    return nothing
end
