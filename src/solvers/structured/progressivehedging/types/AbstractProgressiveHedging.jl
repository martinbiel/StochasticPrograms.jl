abstract type AbstractProgressiveHedgingSolver <: AbstractStructuredModel end

nscenarios(ph::AbstractProgressiveHedgingSolver) = ph.nscenarios

# Initialization #
# ======================================================================== #
function init!(ph::AbstractProgressiveHedgingSolver, subsolver::QPSolver)
    # Initialize progress meter
    ph.progress.thresh = ph.parameters.τ
    # Finish initialization based on solver traits
    init_subproblems!(ph, subsolver)
    # Initialize penalty parameter (if applicable)
    ph.data.δ₁ = 1.0
    init_penalty!(ph)
end
# ======================================================================== #

# Functions #
# ======================================================================== #
function set_params!(ph::AbstractProgressiveHedgingSolver; kwargs...)
    for (k,v) in kwargs
        setfield!(ph.parameters, k, v)
    end
end

function current_objective_value(ph::AbstractProgressiveHedgingSolver, Qs::AbstractVector)
    return sum(Qs)
end
current_objective_value(ph) = current_objective_value(ph, ph.subobjectives)

function get_objective_value(ph::AbstractProgressiveHedgingSolver)
    if !isempty(ph.Q_history)
        return ph.Q_history[end]
    else
        return calculate_objective_value(ph)
    end
end

function iterate_nominal!(ph::AbstractProgressiveHedgingSolver)
    # Resolve all subproblems at the current optimal solution
    Q = resolve_subproblems!(ph)
    if Q == Inf
        return :Infeasible
    elseif Q == -Inf
        return :Unbounded
    end
    ph.data.Q = Q
    # Update iterate
    update_iterate!(ph)
    # Update subproblems
    update_subproblems!(ph)
    # Get dual gap
    update_dual_gap!(ph)
    # Update penalty (if applicable)
    update_penalty!(ph)
    # Update progress
    @unpack δ₁, δ₂ = ph.data
    ph.data.δ = sqrt(δ₁ + δ₂)/(1e-10+norm(ph.ξ,2))
    # Log progress
    log!(ph)
    # Check optimality
    if check_optimality(ph)
        # Optimal
        return :Optimal
    end
    # Just return a valid status for this iteration
    return :Valid
end

function log!(ph::AbstractProgressiveHedgingSolver)
    @unpack Q, δ, δ₂ = ph.data
    @unpack keep, offset, indent = ph.parameters
    push!(ph.Q_history, Q)
    push!(ph.dual_gaps, δ₂)
    ph.data.iterations += 1
    if ph.parameters.log
        ProgressMeter.update!(ph.progress,δ,
                              showvalues = [
                                  ("$(indentstr(indent))Objective",Q),
                                  ("$(indentstr(indent))δ",δ)
                              ], keep = keep, offset = offset)
    end
end

function indentstr(n::Integer)
    return repeat(" ", n)
end

function check_optimality(ph::AbstractProgressiveHedgingSolver)
    @unpack τ = ph.parameters
    @unpack δ = ph.data
    return δ <= τ
end
# ======================================================================== #
function show(io::IO, ph::AbstractProgressiveHedgingSolver)
    println(io, typeof(ph).name.name)
    println(io, "State:")
    show(io, ph.data)
    println(io, "Parameters:")
    show(io, ph.parameters)
end

function show(io::IO, ::MIME"text/plain", ph::AbstractProgressiveHedgingSolver)
    show(io, ph)
end
