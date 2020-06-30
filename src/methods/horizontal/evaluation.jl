function evaluate_decision(structure::HorizontalBlockStructure, decision::AbstractVector)
    return _eval_subproblems(structure, decision)
end

function statistically_evaluate_decision(structure::HorizontalBlockStructure, decision::AbstractVector)
    𝔼Q, σ² = _stat_eval_subproblems(structure, decision)
    return 𝔼Q, sqrt(σ²)
end

function _eval_subproblems(structure::HorizontalBlockStructure{2,1,Tuple{SP}},
                           decision::AbstractVector) where SP <: ScenarioProblems
    # Update decisions
    take_decisions!(structure.decisions[1], decision)
    map(subprob -> update_decisions!(subprob), subproblems(structure))
    return outcome_mean(subproblems(structure), probability.(scenarios(structure)))
end
function _eval_subproblems(structure::HorizontalBlockStructure{2,1,Tuple{SP}},
                           decision::AbstractVector) where SP <: DistributedScenarioProblems
    Qs = Vector{Float64}(undef, nworkers())
    sp = scenarioproblems(structure)
    @sync begin
        for (i,w) in enumerate(workers())
            @async Qs[i] = remotecall_fetch(
                w,
                sp[w-1],
                sp.decisions[w-1],
                decision) do sp, d, x
                    scenarioproblems = fetch(sp)
                    num_scenarios(scenarioproblems) == 0 && return 0.0
                    take_decisions!(fetch(d), x)
                    map(subprob -> update_decisions!(subprob), subproblems(scenarioproblems))
                    return outcome_mean(subproblems(scenarioproblems),
                                        probability.(scenarios(scenarioproblems)))
                end
        end
    end
    return sum(Qs)
end

function _stat_eval_subproblems(structure::HorizontalBlockStructure{2,1,Tuple{SP}},
                                decision::AbstractVector) where SP <: ScenarioProblems
    # Update decisions
    take_decisions!(structure.decisions[1], decision)
    map(subprob -> update_decisions!(subprob), subproblems(structure))
    return welford(subproblems(structure), probability.(scenarios(structure)))
end
function _stat_eval_subproblems(structure::HorizontalBlockStructure{2,1,Tuple{SP}},
                                decision::AbstractVector) where SP <: DistributedScenarioProblems
    partial_welfords = Vector{Tuple{Float64,Float64,Float64,Int}}(undef, nworkers())
    sp = scenarioproblems(structure)
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_welfords[i] = remotecall_fetch(
                w,
                sp[w-1],
                sp.decisions[w-1],
                x) do sp, d, x
                    scenarioproblems = fetch(sp)
                    num_scenarios(scenarioproblems) == 0 && return 0.0, 0.0, 0.0, 0
                    take_decisions!(fetch(d), x)
                    map(subprob -> update_decisions!(subprob), subproblems(scenarioproblems))
                    return welford(subproblems(scenarioproblems),
                                   probability.(scenarios(scenarioproblems)))
                end
        end
    end
    𝔼Q, σ², _ = reduce(aggregate_welford, partial_welfords)
    return 𝔼Q, σ²
end
