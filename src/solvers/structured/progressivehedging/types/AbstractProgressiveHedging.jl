abstract type AbstractProgressiveHedging end

StochasticPrograms.num_subproblems(ph::AbstractProgressiveHedging) = StochasticPrograms.num_subproblems(ph.structure, 2)
num_iterations(ph::AbstractProgressiveHedging) = ph.data.iterations

# Initialization #
# ======================================================================== #
function initialize!(ph::AbstractProgressiveHedging, penaltyterm::AbstractPenaltyterm)
    # Initialize progress meter
    ph.progress.thresh = sqrt(ph.parameters.ϵ₁ ^ 2 + ph.parameters.ϵ₂ ^ 2)
    # Initialize subproblems
    initialize_subproblems!(ph, scenarioproblems(ph.structure), penaltyterm)
    # Initialize penalty parameter (if applicable)
    ph.data.δ₁ = 1.0
    initialize_penalty!(ph)
    # Finish initialization
    finish_initilization!(ph, penalty(ph))
end
# ======================================================================== #

# Functions #
# ======================================================================== #
function decision(ph::AbstractProgressiveHedging)
    return ph.ξ
end

function decision(ph::AbstractProgressiveHedging, index::MOI.VariableIndex)
    i = something(findfirst(i -> i == index, all_decisions(ph.decisions)), 0)
    if iszero(i)
        throw(MOI.InvalidIndex(index))
    end
    return decision(ph)[i]
end

function current_objective_value(ph::AbstractProgressiveHedging, Qs::AbstractVector)
    return sum(Qs)
end
current_objective_value(ph) = current_objective_value(ph, ph.subobjectives)

function get_objective_value(ph::AbstractProgressiveHedging)
    if !isempty(ph.Q_history)
        return ph.Q_history[end]
    else
        return calculate_objective_value(ph)
    end
end

function objective_value(ph::AbstractProgressiveHedging)
    return ph.data.Q
end

function log!(ph::AbstractProgressiveHedging; optimal = false, status = nothing)
    @unpack Q, δ₁, δ₂, iterations = ph.data
    @unpack ϵ₁, ϵ₂, keep, offset, indent = ph.parameters
    # Early termination log
    if status != nothing && ph.parameters.log
        ph.progress.thresh = Inf
        ph.progress.printed = true
        val = if status == MOI.INFEASIBLE
            Inf
        elseif status == MOI.DUAL_INFEASIBLE
            -Inf
        else
            0.0
        end
        ProgressMeter.update!(ph.progress, val,
                              showvalues = [
                                  ("$(indentstr(indent))Objective", val),
                                  ("$(indentstr(indent))Early termination", status),
                                  ("$(indentstr(indent))Iterations", iterations)
                              ], keep = keep, offset = offset)
        return nothing
    end
    push!(ph.Q_history, Q)
    push!(ph.primal_gaps, δ₁)
    push!(ph.dual_gaps, δ₂)
    ph.data.iterations += 1
    if ph.parameters.log
        δ = sqrt(δ₁ ^ 2 + δ₂ ^ 2)
        if δ <= ph.progress.thresh && !(δ₁ <= ϵ₁ && δ₂ <= ϵ₂)
            δ = 1.01 * ph.progress.thresh
        end
        δ = optimal ? 0.0 : δ
        ProgressMeter.update!(ph.progress, δ,
                              showvalues = [
                                  ("$(indentstr(indent))Objective",Q),
                                  ("$(indentstr(indent))Primal gap", δ₁),
                                  ("$(indentstr(indent))Dual gap", δ₂),
                                  ("$(indentstr(indent))Iterations", iterations)
                              ], keep = keep, offset = offset)
    end
end

function indentstr(n::Integer)
    return repeat(" ", n)
end

function check_optimality(ph::AbstractProgressiveHedging)
    @unpack ϵ₁, ϵ₂ = ph.parameters
    @unpack δ₁, δ₂ = ph.data
    return δ₁ <= ϵ₁ && δ₂ <= ϵ₂
end
# ======================================================================== #
function show(io::IO, ph::AbstractProgressiveHedging)
    println(io, typeof(ph).name.name)
    println(io, "State:")
    show(io, ph.data)
    println(io, "Parameters:")
    show(io, ph.parameters)
end

function show(io::IO, ::MIME"text/plain", ph::AbstractProgressiveHedging)
    show(io, ph)
end
