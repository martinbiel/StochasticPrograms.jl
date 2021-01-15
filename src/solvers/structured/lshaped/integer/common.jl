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

function check_integrality_restrictions(subproblem::SubProblem)
    model = subproblem.model
    N = length(model.ext[:decisions])
    all_known = mapreduce(vcat, 1:N-1) do s
        index.(all_known_decision_variables(model, s))
    end
    all_decisions = index.(all_decision_variables(model, N))
    return all(all_variables(model)) do var
        vi = index(var)
        if vi in all_known
            # Known decision, skip
            return true
        end
        if vi in all_decisions
            # Decision variable
            dref = DecisionRef(model, vi)
            if is_integer(dref) || is_binary(dref)
                return is_approx_integer(value(dref))
            else
                return true
            end
        else
            if is_integer(var) || is_binary(var)
                return is_approx_integer(value(var))
            else
                return true
            end
        end
    end
end
