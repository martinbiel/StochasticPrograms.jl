abstract type AbstractQuasiGradient end

StochasticPrograms.num_subproblems(quasigradient::AbstractQuasiGradient) = quasigradient.num_subproblems
num_iterations(quasigradient::AbstractQuasiGradient) = quasigradient.data.iterations
tolerance(quasigradient::AbstractQuasiGradient) = quasigradient.parameters.τ

# Initialization #
# ======================================================================== #
function initialize!(quasigradient::AbstractQuasiGradient)
    # Initialize subproblems
    initialize_subproblems!(quasigradient, scenarioproblems(quasigradient.structure, 2))
    # Prepare the master optimization problem
    prepare_master_objective!(quasigradient)
    # # Initialize prox policy
    initialize_prox!(quasigradient)
    # # Initialize step policy
    # initialize_step!(quasigradient)
    return nothing
end
# ======================================================================== #

# Functions #
# ======================================================================== #
function prepare_master_objective!(quasigradient::AbstractQuasiGradient)
    # Check sense first
    sense = MOI.get(quasigradient.master, MOI.ObjectiveSense())
    if sense == MOI.FEASIBILITY_SENSE
        quasigradient.data.no_objective = true
        # Use min-sense during quasi-gradient procedure
        MOI.set(quasigradient.master, MOI.ObjectiveSense(), MOI.MIN_SENSE)
        F = AffineDecisionFunction{Float64}
        MOI.set(quasigradient.master, MOI.ObjectiveFunction{F}(), zero(F))
    else
        # Cache the objective function
        obj = objective_function(quasigradient.structure.first_stage)
        x = all_decision_variables(quasigradient.structure.first_stage, 1)
        quasigradient.data.master_objective = moi_function(obj)
        quasigradient.c .= JuMP._affine_coefficient.(obj, x)
    end
    return nothing
end

function restore_master!(quasigradient::AbstractQuasiGradient)
    # Remove any prox terms
    restore_proximal_master!(quasigradient)
    if quasigradient.data.no_objective
        # Re-set FEASIBILITY_SENSE
        MOI.set(quasigradient.master, MOI.ObjectiveSense(), MOI.FEASIBILITY_SENSE)
    else
        # Re-add original objective
        @unpack master_objective = quasigradient.data
        F = typeof(master_objective)
        MOI.set(quasigradient.master, MOI.ObjectiveFunction{F}(), master_objective)
    end
    return nothing
end

function decision(quasigradient::AbstractQuasiGradient, index::MOI.VariableIndex)
    i = something(findfirst(i -> i == index, all_decisions(quasigradient.decisions)), 0)
    if iszero(i)
        throw(MOI.InvalidIndex(index))
    end
    return quasigradient.x[i]
end

function evaluate_first_stage(quasigradient::AbstractQuasiGradient, x::AbstractVector)
    # Get objective
    @unpack master_objective = quasigradient.data
    # Evaluate objective
    obj_val = MOIU.eval_variables(master_objective) do vi
        if vi in all_decisions(quasigradient.decisions)
            # Only evaluate decision
            x[vi.value]
        else
            0.0
        end
    end
    # Return value
    return obj_val
end

function current_objective_value(quasigradient::AbstractQuasiGradient, Q::AbstractFloat)
    # Get sense
    sense = MOI.get(quasigradient.master, MOI.ObjectiveSense())
    correction = sense == MOI.MIN_SENSE ? 1.0 : -1.0
    # Return sense-corrected value
    return evaluate_first_stage(quasigradient, current_decision(quasigradient)) + correction * Q
end

function log!(quasigradient::AbstractQuasiGradient; optimal = false, status = nothing)
    @unpack Q, iterations = quasigradient.data
    @unpack keep, offset, indent = quasigradient.parameters
    # Early termination log
    if status != nothing && quasigradient.parameters.log
        quasigradient.progress.thresh = Inf
        quasigradient.progress.printed = true
        val = if status == MOI.INFEASIBLE
            Inf
        elseif status == MOI.DUAL_INFEASIBLE
            -Inf
        else
            0.0
        end
        ProgressMeter.update!(quasigradient.progress, iterations,
                              showvalues = [
                                  ("$(indentstr(indent))Objective", val),
                                  ("$(indentstr(indent))Early termination", status)
                              ], keep = keep, offset = offset)
        return nothing
    end
    # Value update
    push!(quasigradient.Q_history, Q)
    quasigradient.data.iterations += 1
    # Log
    if quasigradient.parameters.log
        ProgressMeter.update!(quasigradient.progress, iterations,
                              showvalues = [
                                  ("$(indentstr(indent))Objective", Q),
                                  ("$(indentstr(indent))||∇Q||:", norm(quasigradient.subgradient))
                              ], keep = keep, offset = offset)
    end
    return nothing
end

function log!(quasigradient::AbstractQuasiGradient, t::Integer; optimal = false, status = nothing)
    @unpack Q,θ,iterations = quasigradient.data
    @unpack keep, offset, indent = quasigradient.parameters
    quasigradient.Q_history[t] = Q
    if status != nothing && quasigradient.parameters.log
        val = if status == MOI.INFEASIBLE
            Inf
        elseif status == MOI.DUAL_INFEASIBLE
            -Inf
        else
            0.0
        end
        ProgressMeter.update!(quasigradient.progress, iterations,
                              showvalues = [
                                  ("$(indentstr(indent))Objective", val),
                                  ("$(indentstr(indent))Early termination", status)
                              ], keep = keep, offset = offset)
        return nothing
    end
    if quasigradient.parameters.log
        ProgressMeter.update!(quasigradient.progress, iterations,
                              showvalues = [
                                  ("$(indentstr(indent))Objective", Q),
                                  ("$(indentstr(indent))||∇Q||:", norm(quasigradient.subgradient))
                              ], keep = keep, offset = offset)
    end
    return nothing
end

function indentstr(n::Integer)
    return repeat(" ", n)
end

function terminate(quasigradient::AbstractQuasiGradient)
    @unpack τ, maximum_iterations = quasigradient.parameters
    return quasigradient.data.iterations >= maximum_iterations || norm(quasigradient.subgradient) <= τ
end
# ======================================================================== #
