abstract type AbstractLShaped end

StochasticPrograms.num_subproblems(lshaped::AbstractLShaped) = StochasticPrograms.num_subproblems(lshaped.structure)
num_cuts(lshaped::AbstractLShaped) = lshaped.data.num_cuts
num_iterations(lshaped::AbstractLShaped) = lshaped.data.iterations
tolerance(lshaped::AbstractLShaped) = lshaped.parameters.τ

# Initialization #
# ======================================================================== #
function initialize!(lshaped::AbstractLShaped)
    # Initialize progress meter
    lshaped.progress.thresh = lshaped.parameters.τ
    # Initialize subproblems
    initialize_subproblems!(lshaped, scenarioproblems(lshaped.structure), tolerance(lshaped))
    # Prepare the master optimization problem
    prepare_master!(lshaped)
    # Initialize regularization policy
    initialize_regularization!(lshaped)
    # Finish initialization
    finish_initilization!(lshaped)
    return nothing
end
# ======================================================================== #

# Functions #
# ======================================================================== #
function set_params!(lshaped::AbstractLShaped; kwargs...)
    for (k,v) in kwargs
        setfield!(lshaped.parameters, k, v)
    end
    return nothing
end

function prepare_master!(lshaped::AbstractLShaped)
    # Cache the objective function
    F = MOI.get(lshaped.master, MOI.ObjectiveFunctionType())
    lshaped.data.master_objective = MOI.get(lshaped.master, MOI.ObjectiveFunction{F}())
    # Initialize the required number of master variables. Use
    # MOI.VariableIndex(0) as an undef value
    append!(lshaped.master_variables, fill(MOI.VariableIndex(0), num_thetas(lshaped)))
end

function add_master_variable!(lshaped::AbstractLShaped, index::Integer)
    F = MOI.get(lshaped.master, MOI.ObjectiveFunctionType())
    master_variable = MOI.add_variable(lshaped.master)
    # Set name
    MOI.set(lshaped.master, MOI.VariableName(), master_variable,
            add_subscript("θ", index))
    # Get sense
    sense = MOI.get(lshaped.master, MOI.ObjectiveSense())
    coeff = sense == MOI.MIN_SENSE ? 1.0 : -1.0
    # Add to objective
    MOI.modify(lshaped.master, MOI.ObjectiveFunction{F}(), MOI.ScalarCoefficientChange(master_variable, coeff))
    lshaped.master_variables[index] = master_variable
    return nothing
end

function remove_cut_constraints!(lshaped::AbstractLShaped)
    # Decrease count
    lshaped.data.num_cuts -= length(lshaped.cut_constraints)
    # Remove cuts
    for ci in lshaped.cut_constraints
        if !iszero(ci.value)
            MOI.delete(lshaped.master, ci)
        end
    end
    empty!(lshaped.cut_constraints)
    return nothing
end

function restore_master!(lshaped::AbstractLShaped)
    # Remove cut constraints
    remove_cut_constraints!(lshaped)
    # Remove master variables
    for var in lshaped.master_variables
        if !iszero(var.value)
            MOI.delete(lshaped.master, var)
        end
    end
    empty!(lshaped.master_variables)
    # Remove any regularization terms
    restore_regularized_master!(lshaped)
    # Re-add original objective
    @unpack master_objective = lshaped.data
    F = typeof(master_objective)
    MOI.set(lshaped.master, MOI.ObjectiveFunction{F}(), master_objective)
    return nothing
end

function active_model_objectives(lshaped::AbstractLShaped)
    return map(lshaped.master_variables) do var
        var.value != 0
    end
end

function update_solution!(lshaped::AbstractLShaped)
    ncols = num_decisions(lshaped.structure)
    nb = num_thetas(lshaped)
    lshaped.x .= MOI.get.(lshaped.master, MOI.VariablePrimal(), lshaped.decisions.undecided)
    θs = map(lshaped.master_variables) do vi
        if vi.value == 0
            -1e10
        else
            MOI.get(lshaped.master, MOI.VariablePrimal(), vi)
        end
    end
    set_model_objectives(lshaped, θs)
    return nothing
end

function decision(lshaped::AbstractLShaped, index::MOI.VariableIndex)
    i = something(findfirst(i -> i == index, lshaped.decisions.undecided), 0)
    if iszero(i)
        throw(MOI.InvalidIndex(index))
    end
    return decision(lshaped)[i]
end

function evaluate_first_stage(lshaped::AbstractLShaped, x::AbstractVector)
    model = lshaped.master
    # Get objective
    @unpack master_objective = lshaped.data
    # Evaluate objective
    obj_val = MOIU.eval_variables(master_objective) do vi
        if vi in lshaped.decisions.undecided
            # Only evaluate decision
            x[vi.value]
        else
            0.0
        end
    end
    # Return value
    return obj_val
end

function current_objective_value(lshaped::AbstractLShaped)
    # Get sense
    sense = MOI.get(lshaped.master, MOI.ObjectiveSense())
    correction = sense == MOI.MIN_SENSE ? 1.0 : -1.0
    # Return sense-corrected value
    return evaluate_first_stage(lshaped, current_decision(lshaped)) +
        correction * sum(subobjectives(lshaped))
end

function calculate_estimate(lshaped::AbstractLShaped)
    # Get sense
    sense = MOI.get(lshaped.master, MOI.ObjectiveSense())
    correction = sense == MOI.MIN_SENSE ? 1.0 : -1.0
    # Return sense-corrected value
    return evaluate_first_stage(lshaped, lshaped.x) +
        correction * sum(model_objectives(lshaped))
end

function log!(lshaped::AbstractLShaped; optimal = false, status = nothing)
    @unpack Q, θ, iterations = lshaped.data
    @unpack keep, offset, indent = lshaped.parameters
    # Early termination log
    if status != nothing && lshaped.parameters.log
        lshaped.progress.thresh = Inf
        lshaped.progress.printed = true
        val = if status == MOI.INFEASIBLE
            Inf
        elseif status == MOI.DUAL_INFEASIBLE
            -Inf
        else
            0.0
        end
        ProgressMeter.update!(lshaped.progress, val,
                              showvalues = [
                                  ("$(indentstr(indent))Objective", val),
                                  ("$(indentstr(indent))Early termination", status),
                                  ("$(indentstr(indent))Number of cuts", num_cuts(lshaped)),
                                  ("$(indentstr(indent))Iterations", iterations)
                              ], keep = keep, offset = offset)
        return nothing
    end
    # Value update
    push!(lshaped.Q_history, Q)
    push!(lshaped.θ_history, θ)
    lshaped.data.iterations += 1
    # Log
    log_regularization!(lshaped)
    if lshaped.parameters.log
        current_gap = optimal ? 0.0 : gap(lshaped)
        ProgressMeter.update!(lshaped.progress, current_gap,
                              showvalues = [
                                  ("$(indentstr(indent))Objective", objective_value(lshaped)),
                                  ("$(indentstr(indent))Gap", current_gap),
                                  ("$(indentstr(indent))Number of cuts", num_cuts(lshaped)),
                                  ("$(indentstr(indent))Iterations", iterations)
                              ], keep = keep, offset = offset)
    end
    return nothing
end

function log!(lshaped::AbstractLShaped, t::Integer; optimal = false, status = nothing)
    @unpack Q,θ,iterations = lshaped.data
    @unpack keep, offset, indent = lshaped.parameters
    lshaped.Q_history[t] = Q
    lshaped.θ_history[t] = θ
    if status != nothing && lshaped.parameters.log
        lshaped.progress.thresh = Inf
        lshaped.progress.printed = true
        val = if status == MOI.INFEASIBLE
            Inf
        elseif status == MOI.DUAL_INFEASIBLE
            -Inf
        else
            0.0
        end
        ProgressMeter.update!(lshaped.progress, val,
                              showvalues = [
                                  ("$(indentstr(indent))Objective", val),
                                  ("$(indentstr(indent))Early termination", status),
                                  ("$(indentstr(indent))Number of cuts", num_cuts(lshaped)),
                                  ("$(indentstr(indent))Iterations", iterations)
                              ], keep = keep, offset = offset)
        return nothing
    end
    log_regularization!(lshaped,t)
    if lshaped.parameters.log
        current_gap = optimal ? 0.0 : gap(lshaped)
        ProgressMeter.update!(lshaped.progress, current_gap,
                              showvalues = [
                                  ("$(indentstr(indent))Objective", objective_value(lshaped)),
                                  ("$(indentstr(indent))Gap", current_gap),
                                  ("$(indentstr(indent))Number of cuts", num_cuts(lshaped)),
                                  ("$(indentstr(indent))Iterations", iterations)
                              ], keep = keep, offset = offset)
    end
    return nothing
end

function indentstr(n::Integer)
    return repeat(" ", n)
end

function check_optimality(lshaped::AbstractLShaped)
    @unpack τ = lshaped.parameters
    @unpack θ = lshaped.data
    return θ > -Inf && gap(lshaped) <= τ
end
# ======================================================================== #

# Cut functions #
# ======================================================================== #
active(lshaped::AbstractLShaped, hyperplane::AbstractHyperPlane) = active(hyperplane, decision(lshaped), tolerance(lshaped))
active(lshaped::AbstractLShaped, cut::HyperPlane{OptimalityCut}) = optimal(cut, decision(lshaped), model_objectives(lshaped)[cut.id], tolerance(lshaped))
active(lshaped::AbstractLShaped, cut::AggregatedOptimalityCut) = optimal(cut, decision(lshaped), sum(model_objectives(lshaped)[cut.ids]), tolerance(lshaped))
satisfied(lshaped::AbstractLShaped, hyperplane::AbstractHyperPlane) = satisfied(hyperplane, decision(lshaped), tolerance(lshaped))
satisfied(lshaped::AbstractLShaped, cut::HyperPlane{OptimalityCut}) = satisfied(cut, decision(lshaped), model_objectives(lshaped)[cut.id], tolerance(lshaped))
satisfied(lshaped::AbstractLShaped, cut::AggregatedOptimalityCut) = satisfied(cut, decision(lshaped), sum(model_objectives(lshaped)[cut.ids]), tolerance(lshaped))
violated(lshaped::AbstractLShaped, hyperplane::AbstractHyperPlane) = !satisfied(lshaped, hyperplane)
gap(lshaped::AbstractLShaped, hyperplane::AbstractHyperPlane) = gap(hyperplane, decision(lshaped))
gap(lshaped::AbstractLShaped, cut::HyperPlane{OptimalityCut}) = gap(cut, decision(lshaped), model_objectives(lshaped)[cut.id])
gap(lshaped::AbstractLShaped, cut::AggregatedOptimalityCut) = gap(cut, decision(lshaped), sum(model_objectives(lshaped)[cut.ids]))

function add_cut!(lshaped::AbstractLShaped, cut::AbstractHyperPlane; consider_consolidation = true, check = true)
    added = add_cut!(lshaped, cut, model_objectives(lshaped), subobjectives(lshaped), check = check)
    if consider_consolidation
        added && add_cut!(lshaped, lshaped.consolidation, cut)
    end
    return added
end

function add_cut!(lshaped::AbstractLShaped, cut::HyperPlane{OptimalityCut}, θs::AbstractVector, subobjectives::AbstractVector, Q::AbstractFloat; check = true)
    if lshaped.master_variables[cut.id].value == 0
        # Add master variable if cut is encountered for the first time
        add_master_variable!(lshaped, cut.id)
    end
    # Get the model value
    θ = θs[cut.id]
    @unpack τ, cut_scaling = lshaped.parameters
    # Update objective
    subobjectives[cut.id] = Q
    # Check if cut gives new information
    if check && θ > -Inf && (θ + τ >= Q || θ + τ >= cut(lshaped.x))
        # Optimal with respect to this subproblem
        return false
    end
    # Add optimality cut
    process_cut!(lshaped, cut)
    f, set = moi_constraint(cut, lshaped.master_variables, cut_scaling)
    push!(lshaped.cut_constraints, MOI.add_constraint(lshaped.master, f, set))
    lshaped.data.num_cuts += 1
    if lshaped.parameters.debug
        push!(lshaped.cuts, cut)
    end
    return true
end
function add_cut!(lshaped::AbstractLShaped, cut::AggregatedOptimalityCut, θs::AbstractVector, subobjectives::AbstractVector, Q::AbstractFloat; check = true)
    for id in cut.ids
        if lshaped.master_variables[id].value == 0
            # Add master variable if cut is encountered for the first time
            add_master_variable!(lshaped, id)
        end
    end
    θs = θs[cut.ids]
    θ = sum(θs)
    @unpack τ, cut_scaling = lshaped.parameters
    # Update objective
    subobjectives[cut.ids] .= Q/length(cut.ids)
    # Check if cut gives new information
    if check && θ > -Inf && (θ + τ >= Q || θ + τ >= cut(lshaped.x))
        # Optimal with respect to these subproblems
        return false
    end
    # Add optimality cut
    process_cut!(lshaped, cut)
    f, set = moi_constraint(cut, lshaped.master_variables, cut_scaling)
    push!(lshaped.cut_constraints, MOI.add_constraint(lshaped.master, f, set))
    lshaped.data.num_cuts += 1
    if lshaped.parameters.debug
        push!(lshaped.cuts, cut)
    end
    return true
end
add_cut!(lshaped::AbstractLShaped, cut::AnyOptimalityCut, θs::AbstractVector, subobjectives::AbstractVector, x::AbstractVector; check = true) = add_cut!(lshaped, cut, θs, subobjectives, cut(x); check = check)
add_cut!(lshaped::AbstractLShaped, cut::AnyOptimalityCut, θs::AbstractVector, subobjectives::AbstractVector; check = true) = add_cut!(lshaped, cut, θs, subobjectives, current_decision(lshaped); check = check)

function add_cut!(lshaped::AbstractLShaped, cut::HyperPlane{FeasibilityCut}, ::AbstractVector, subobjectives::AbstractVector, Q::AbstractFloat; check = true)
    # Ensure that there is no false convergence
    subobjectives[cut.id] = Q
    # Add feasibility cut
    process_cut!(lshaped, cut)
    f, set = moi_constraint(cut, lshaped.master_variables, 1.0)
    push!(lshaped.cut_constraints, MOI.add_constraint(lshaped.master, f, set))
    lshaped.data.num_cuts += 1
    if lshaped.parameters.debug
        push!(lshaped.feasibility.cuts, cut)
    end
    return true
end
add_cut!(lshaped::AbstractLShaped, cut::HyperPlane{FeasibilityCut}, θs::AbstractVector, subobjectives::AbstractVector; check = true) = add_cut!(lshaped, cut, θs, subobjectives, Inf)

function add_cut!(lshaped::AbstractLShaped, cut::HyperPlane{Infeasible}, ::AbstractVector, subobjectives::AbstractVector; check = true)
    subobjectives[cut.id] = Inf
    return true
end

function add_cut!(lshaped::AbstractLShaped, cut::HyperPlane{Unbounded}, ::AbstractVector, subobjectives::AbstractVector; check = true)
    subobjectives[cut.id] = -Inf
    return true
end
