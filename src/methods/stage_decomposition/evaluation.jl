# Stage-decomposition evaluation #
# ============================== #
function evaluate_decision(structure::StageDecompositionStructure, decision::AbstractVector)
    # Evalaute decision stage-wise
    cᵀx = _eval_first_stage(structure, decision)
    𝔼Q = _eval_second_stages(structure, decision, objective_sense(structure.first_stage))
    # Return evaluation result
    return cᵀx + 𝔼Q
end

function statistically_evaluate_decision(structure::StageDecompositionStructure, decision::AbstractVector)
    # Evalaute decision stage-wise
    cᵀx = _eval_first_stage(structure, decision)
    𝔼Q, σ² = _stat_eval_second_stages(structure, decision, objective_sense(structure.first_stage))
    return cᵀx + 𝔼Q, sqrt(σ²)
end

function _eval_first_stage(structure::StageDecompositionStructure, decision::AbstractVector)
    # Update decisions (checks handled by first-stage model)
    take_decisions!(structure.first_stage,
                    all_decision_variables(structure.first_stage, 1),
                    decision)
    # Optimize first_stage model
    optimize!(structure.first_stage)
    # Switch on return status
    status = termination_status(structure.first_stage)
    result = if status in AcceptableTermination
        result = objective_value(structure.first_stage)
    else
        result = if status == MOI.INFEASIBLE
            result = objective_sense(structure.first_stage) == MOI.MAX_SENSE ? -Inf : Inf
        elseif status == MOI.DUAL_INFEASIBLE
            result = objective_sense(structure.first_stage) == MOI.MAX_SENSE ? Inf : -Inf
        else
            error("First-stage model could not be solved, returned status: $status")
        end
    end
    # Revert back to untaken decisions
    untake_decisions!(structure.first_stage, all_decision_variables(structure.first_stage, 1))
    # Return evaluation result
    return result
end

function _eval_second_stages(structure::StageDecompositionStructure{2,1,Tuple{SP}},
                             decision::AbstractVector,
                             sense::MOI.OptimizationSense) where SP <: ScenarioProblems
    update_known_decisions!(structure.decisions[2], decision)
    map(subprob -> update_known_decisions!(subprob), subproblems(structure))
    return outcome_mean(subproblems(structure), probability.(scenarios(structure)), sense)
end
function _eval_second_stages(structure::StageDecompositionStructure{2,1,Tuple{SP}},
                             decision::AbstractVector,
                             sense::MOI.OptimizationSense) where SP <: DistributedScenarioProblems
    Qs = Vector{Float64}(undef, nworkers())
    sp = scenarioproblems(structure)
    @sync begin
        for (i,w) in enumerate(workers())
            @async Qs[i] = remotecall_fetch(
                w,
                sp[w-1],
                sp.decisions[w-1],
                decision,
                sense) do sp, d, x, sense
                    scenarioproblems = fetch(sp)
                    decisions = fetch(d)
                    num_scenarios(scenarioproblems) == 0 && return 0.0
                    update_known_decisions!(decisions, x)
                    map(subprob -> update_known_decisions!(subprob), subproblems(scenarioproblems))
                    return outcome_mean(subproblems(scenarioproblems),
                                        probability.(scenarios(scenarioproblems)),
                                        sense)
                end
        end
    end
    return sum(Qs)
end

function _stat_eval_second_stages(structure::StageDecompositionStructure{2,1,Tuple{SP}},
                                  decision::AbstractVector,
                                  sense::MOI.OptimizationSense) where SP <: ScenarioProblems
    update_known_decisions!(structure.decisions[2], decision)
    map(subprob -> update_known_decisions!(subprob), subproblems(structure))
    return welford(subproblems(structure), probability.(scenarios(structure)), sense)
end
function _stat_eval_second_stages(structure::StageDecompositionStructure{2,1,Tuple{SP}},
                                  decision::AbstractVector,
                                  sense::MOI.OptimizationSense) where SP <: DistributedScenarioProblems
    partial_welfords = Vector{Tuple{Float64,Float64,Float64,Int}}(undef, nworkers())
    sp = scenarioproblems(structure)
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_welfords[i] = remotecall_fetch(
                w,
                sp[w-1],
                sp.decisions[w-1],
                decision,
                sense) do sp, d, x, sense
                    scenarioproblems = fetch(sp)
                    decisions = fetch(d)
                    num_scenarios(scenarioproblems) == 0 && return zero(eltype(x)), zero(eltype(x)), zero(eltype(x)), zero(Int)
                    update_known_decisions!(decisions, x)
                    map(subprob -> update_known_decisions!(subprob), subproblems(scenarioproblems))
                    return welford(subproblems(scenarioproblems), probability.(scenarios(scenarioproblems)), sense)
                end
        end
    end
    𝔼Q, σ², _ = reduce(aggregate_welford, partial_welfords)
    return 𝔼Q, σ²
end
