# Mean/variance calculations #
# ========================== #
function outcome_mean(subproblems::Vector{JuMP.Model}, probabilities::AbstractVector, sense::Union{MOI.OptimizationSense, Nothing} = nothing)
    # Sanity check
    length(subproblems) == length(probabilities) || error("Inconsistent number of subproblems and probabilities")
    N = length(subproblems)
    N == 0 && return 0.0
    if sense === nothing || sense == MOI.FEASIBILITY_SENSE
        sense = objective_sense(subproblems[1])
    end
    return mapreduce(+, 1:N) do k
        outcome = subproblems[k]
        val = try
            optimize!(outcome)
            status = termination_status(outcome)
            if status != MOI.OPTIMAL
                if status == MOI.INFEASIBLE
                    objective_sense(outcome) == MOI.MAX_SENSE ? -Inf : Inf
                elseif status == MOI.DUAL_INFEASIBLE
                    objective_sense(outcome) == MOI.MAX_SENSE ? Inf : -Inf
                else
                    error("Outcome model could not be solved, returned status: $status")
                end
            else
                probabilities[k]*objective_value(outcome)
            end
        catch error
            if isa(error, NoOptimizer)
                @warn "No optimizer set, cannot solve outcome model."
                rethrow(NoOptimizer())
            else
                @warn "Outcome model could not be solved."
                rethrow(error)
            end
        end
        val = sense == objective_sense(outcome) ? val : -val
    end
end
function welford(subproblems::Vector{JuMP.Model}, probabilities::AbstractVector, sense::Union{MOI.OptimizationSense, Nothing} = nothing)
    # Sanity check
    length(subproblems) == length(probabilities) || error("Inconsistent number of subproblems and probabilities")
    N = length(subproblems)
    N == 0 && return 0.0, 0.0, 0.0, N
    if sense === nothing || sense == MOI.FEASIBILITY_SENSE
        sense = objective_sense(subproblems[1])
    end
    Q̄ₖ = Sₖ = wₖ = w²ₖ = 0
    for k = 1:N
        π = probabilities[k]
        wₖ = wₖ + π
        Q̄ₖ₋₁ = Q̄ₖ
        problem = subproblems[k]
        try
            optimize!(problem)
            status = termination_status(problem)
            Q = if status != MOI.OPTIMAL
                Q = if status == MOI.INFEASIBLE
                    objective_sense(problem) == MOI.MAX_SENSE ? -Inf : Inf
                elseif status == MOI.DUAL_INFEASIBLE
                    objective_sense(problem) == MOI.MAX_SENSE ? Inf : -Inf
                else
                    error("Subproblem could not be solved during welford algorithm, returned status: $status")
                end
            else
                Q = objective_value(problem)
            end
            Q = sense == objective_sense(problem) ? Q : -Q
            Q̄ₖ = Q̄ₖ + (π / wₖ) * (Q - Q̄ₖ)
            Sₖ = Sₖ + π * (Q - Q̄ₖ) * (Q - Q̄ₖ₋₁)
        catch error
            if isa(error, NoOptimizer)
                @warn "No optimizer set, cannot solve subproblem during welford algorithm."
                rethrow(NoOptimizer())
            else
                @warn "Subproblem could not be solved during welford algorithm."
                rethrow(error)
            end
        end
    end
    correction = N / ((N - 1) * wₖ)
    if isinf(Q̄ₖ)
        correction = 0.0
    end
    return Q̄ₖ, correction * Sₖ, wₖ, N
end
function aggregate_welford(left::Tuple, right::Tuple)
    x̄ₗ, σₗ², wₗ, nₗ = left
    x̄ᵣ, σᵣ², wᵣ, nᵣ = right
    δ = x̄ᵣ - x̄ₗ
    w = wₗ + wᵣ
    n = nₗ + nᵣ
    x̄ = (wₗ * x̄ₗ + wᵣ * x̄ᵣ) / w
    Sₗ = σₗ² * ((nₗ - 1) * wₗ) / nₗ
    Sᵣ = σᵣ² * ((nᵣ - 1) * wᵣ) / nᵣ
    S = Sₗ + Sᵣ + (wₗ * wᵣ / w) * δ * δ
    correction = n / ((n - 1) * w)
    return x̄, correction * S, w, n
end
