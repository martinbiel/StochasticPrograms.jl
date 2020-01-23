abstract type AbstractLShapedSolver <: AbstractStructuredModel end

nscenarios(lshaped::AbstractLShapedSolver) = lshaped.nscenarios
ncuts(lshaped::AbstractLShapedSolver) = lshaped.data.ncuts
niterations(lshaped::AbstractLShapedSolver) = lshaped.data.iterations
tolerance(lshaped::AbstractLShapedSolver) = lshaped.parameters.τ

# Initialization #
# ======================================================================== #
function initialize!(lshaped::AbstractLShapedSolver, subsolver::SubSolver)
    # Initialize progress meter
    lshaped.progress.thresh = lshaped.parameters.τ
    # Initialize subproblems
    initialize_subproblems!(lshaped, scenarioproblems(lshaped.stochasticprogram), decision(lshaped), subsolver)
    # Prepare the master optimization problem
    prepare_master!(lshaped)
    # Initialize regularization policy
    initialize_regularization!(lshaped)
    # Initialize feasibility handler
    initialize_feasibility!(lshaped)
    # Finish initialization
    finish_initilization!(lshaped)
    return nothing
end
# ======================================================================== #

# Functions #
# ======================================================================== #
function set_params!(lshaped::AbstractLShapedSolver; kwargs...)
    for (k,v) in kwargs
        setfield!(lshaped.parameters,k,v)
    end
    return nothing
end

function prepare_master!(lshaped::AbstractLShapedSolver)
    # θs
    for i = 1:nthetas(lshaped)
        MPB.addvar!(lshaped.mastersolver.lqmodel ,-1e10, Inf, initial_theta_coefficient(lshaped.feasibility))
        push!(lshaped.mastervector, -1e10)
    end
    return nothing
end

function update_solution!(lshaped::AbstractLShapedSolver, solver::LQSolver)
    ncols = decision_length(lshaped.stochasticprogram)
    nb = nthetas(lshaped)
    x = copy(getsolution(solver))
    lshaped.mastervector .= x[1:ncols+nb]
    lshaped.x[1:ncols] .= x[1:ncols]
    set_model_objectives(lshaped, x[ncols+1:ncols+nb])
    return nothing
end

function current_objective_value(lshaped::AbstractLShapedSolver)
    return lshaped.c⋅current_decision(lshaped) + sum(subobjectives(lshaped))
end

function calculate_estimate(lshaped::AbstractLShapedSolver)
    return lshaped.c⋅lshaped.x + sum(model_objectives(lshaped))
end

function solve_master!(lshaped::AbstractLShapedSolver)
    try
        solve_regularized_master!(lshaped, lshaped.regularization)
    catch
        # Master problem could not be solved for some reason.
        @unpack Q,θ = lshaped.data
        gap = abs(θ-Q)/(abs(Q)+1e-10)
        @warn "Master problem could not be solved, solver returned status $(status(lshaped.mastersolver)). The following relative tolerance was reached: $(@sprintf("%.1e",gap)). Aborting procedure."
        return :StoppedPrematurely
    end
    if status(lshaped.mastersolver) == :Infeasible
        @warn "Master is infeasible. Aborting procedure."
        return :Infeasible
    end
    if status(lshaped.mastersolver) == :Unbounded
        @warn "Master is unbounded. Aborting procedure."
        return :Unbounded
    end
    return :Optimal
end

function log!(lshaped::AbstractLShapedSolver; optimal = false)
    @unpack Q,θ,iterations = lshaped.data
    @unpack keep, offset, indent = lshaped.parameters
    push!(lshaped.Q_history, Q)
    push!(lshaped.θ_history, θ)
    lshaped.data.iterations += 1

    log_regularization!(lshaped)
    if lshaped.parameters.log
        current_gap = optimal ? 0.0 : gap(lshaped)
        ProgressMeter.update!(lshaped.progress,current_gap,
                              showvalues = [
                                  ("$(indentstr(indent))Objective", objective(lshaped)),
                                  ("$(indentstr(indent))Gap", current_gap),
                                  ("$(indentstr(indent))Number of cuts", ncuts(lshaped)),
                                  ("$(indentstr(indent))Iterations", iterations)
                              ], keep = keep, offset = offset)
    end
    return nothing
end

function log!(lshaped::AbstractLShapedSolver, t::Integer; optimal = false)
    @unpack Q,θ,iterations = lshaped.data
    @unpack keep, offset, indent = lshaped.parameters
    lshaped.Q_history[t] = Q
    lshaped.θ_history[t] = θ

    log_regularization!(lshaped,t)

    if lshaped.parameters.log
        current_gap = optimal ? 0.0 : gap(lshaped)
        ProgressMeter.update!(lshaped.progress, current_gap,
                              showvalues = [
                                  ("$(indentstr(indent))Objective", objective(lshaped)),
                                  ("$(indentstr(indent))Gap", current_gap),
                                  ("$(indentstr(indent))Number of cuts", ncuts(lshaped)),
                                  ("$(indentstr(indent))Iterations", iterations)
                              ], keep = keep, offset = offset)
    end
    return nothing
end

function indentstr(n::Integer)
    return repeat(" ", n)
end

function check_optimality(lshaped::AbstractLShapedSolver)
    @unpack τ = lshaped.parameters
    @unpack θ = lshaped.data
    return θ > -Inf && gap(lshaped) <= τ
end
# ======================================================================== #

# Cut functions #
# ======================================================================== #
active(lshaped::AbstractLShapedSolver, hyperplane::AbstractHyperPlane) = active(hyperplane, decision(lshaped), tolerance(lshaped))
active(lshaped::AbstractLShapedSolver, cut::HyperPlane{OptimalityCut}) = optimal(cut, decision(lshaped), model_objectives(lshaped)[cut.id], tolerance(lshaped))
active(lshaped::AbstractLShapedSolver, cut::AggregatedOptimalityCut) = optimal(cut, decision(lshaped), sum(model_objectives(lshaped)[cut.ids]), tolerance(lshaped))
satisfied(lshaped::AbstractLShapedSolver, hyperplane::AbstractHyperPlane) = satisfied(hyperplane, decision(lshaped), tolerance(lshaped))
satisfied(lshaped::AbstractLShapedSolver, cut::HyperPlane{OptimalityCut}) = satisfied(cut, decision(lshaped), model_objectives(lshaped)[cut.id], tolerance(lshaped))
satisfied(lshaped::AbstractLShapedSolver, cut::AggregatedOptimalityCut) = satisfied(cut, decision(lshaped), sum(model_objectives(lshaped)[cut.ids]), tolerance(lshaped))
violated(lshaped::AbstractLShapedSolver, hyperplane::AbstractHyperPlane) = !satisfied(lshaped, hyperplane)
gap(lshaped::AbstractLShapedSolver, hyperplane::AbstractHyperPlane) = gap(hyperplane, decision(lshaped))
gap(lshaped::AbstractLShapedSolver, cut::HyperPlane{OptimalityCut}) = gap(cut, decision(lshaped), model_objectives(lshaped)[cut.id])
gap(lshaped::AbstractLShapedSolver, cut::AggregatedOptimalityCut) = gap(cut, decision(lshaped), sum(model_objectives(lshaped)[cut.ids]))

function add_cut!(lshaped::AbstractLShapedSolver, cut::AbstractHyperPlane; consider_consolidation = true, check = true)
    added = add_cut!(lshaped, cut, model_objectives(lshaped), subobjectives(lshaped), check = check)
    added && update_objective!(lshaped, cut)
    if consider_consolidation
        added && add_cut!(lshaped, lshaped.consolidation, cut)
    end
    return added
end

function add_cut!(lshaped::AbstractLShapedSolver, cut::HyperPlane{OptimalityCut}, θs::AbstractVector, subobjectives::AbstractVector, Q::AbstractFloat; check = true)
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
    MPB.addconstr!(lshaped.mastersolver.lqmodel, lowlevel(cut, cut_scaling)...)
    lshaped.data.ncuts += 1
    if lshaped.parameters.debug
        push!(lshaped.cuts, cut)
    end
    return true
end
function add_cut!(lshaped::AbstractLShapedSolver, cut::AggregatedOptimalityCut, θs::AbstractVector, subobjectives::AbstractVector, Q::AbstractFloat; check = true)
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
    MPB.addconstr!(lshaped.mastersolver.lqmodel, lowlevel(cut, cut_scaling)...)
    lshaped.data.ncuts += 1
    if lshaped.parameters.debug
        push!(lshaped.cuts, cut)
    end
    return true
end
add_cut!(lshaped::AbstractLShapedSolver, cut::AnyOptimalityCut, θs::AbstractVector, subobjectives::AbstractVector, x::AbstractVector; check = true) = add_cut!(lshaped, cut, θs, subobjectives, cut(x); check = check)
add_cut!(lshaped::AbstractLShapedSolver, cut::AnyOptimalityCut, θs::AbstractVector, subobjectives::AbstractVector; check = true) = add_cut!(lshaped, cut, θs, subobjectives, current_decision(lshaped); check = check)

function add_cut!(lshaped::AbstractLShapedSolver, cut::HyperPlane{FeasibilityCut}, ::AbstractVector, subobjectives::AbstractVector, Q::AbstractFloat; check = true)
    # Ensure that there is no false convergence
    subobjectives[cut.id] = Q
    # Add feasibility cut
    process_cut!(lshaped, cut)
    MPB.addconstr!(lshaped.mastersolver.lqmodel, lowlevel(cut)...)
    lshaped.data.ncuts += 1
    if lshaped.parameters.debug
        push!(lshaped.feasibility.cuts, cut)
    end
    return true
end
add_cut!(lshaped::AbstractLShapedSolver, cut::HyperPlane{FeasibilityCut}, θs::AbstractVector, subobjectives::AbstractVector; check = true) = add_cut!(lshaped, cut, θs, subobjectives, Inf)

function add_cut!(lshaped::AbstractLShapedSolver, cut::HyperPlane{Infeasible}, ::AbstractVector, subobjectives::AbstractVector; check = true)
    subobjectives[cut.id] = Inf
    return true
end

function add_cut!(lshaped::AbstractLShapedSolver, cut::HyperPlane{Unbounded}, ::AbstractVector, subobjectives::AbstractVector; check = true)
    subobjectives[cut.id] = -Inf
    return true
end
