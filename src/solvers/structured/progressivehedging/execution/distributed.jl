SubWorker{T,A,S} = RemoteChannel{Channel{Vector{SubProblem{T,A,S}}}}
ScenarioProblemChannel{S} = RemoteChannel{Channel{StochasticPrograms.ScenarioProblems{S}}}

Work = RemoteChannel{Channel{Int}}
Progress{T <: AbstractFloat} = Tuple{Int,Int,T}
ProgressQueue{T <: AbstractFloat} = RemoteChannel{Channel{Progress{T}}}

function init_subproblems!(ph::AbstractProgressiveHedgingSolver, subsolver::QPSolver, subworkers::Vector{SubWorker{T,A,S}}) where {T <: AbstractFloat, A <: AbstractVector, S <: LQSolver}
    # Create subproblems on worker processes
    m = ph.stochasticprogram
    @sync begin
        for w in workers()
            subworkers[w-1] = RemoteChannel(() -> Channel{Vector{SubProblem{T,A,S}}}(1), w)
            @async load_worker!(scenarioproblems(m), m, w, subworkers[w-1], subsolver)
        end
        # Prepare memory
        log_val = ph.parameters.log
        ph.parameters.log = false
        log!(ph)
        ph.parameters.log = log_val
    end
    update_iterate!(ph)
    return ph
end

function update_dual_gap!(ph::AbstractProgressiveHedgingSolver, subworkers::Vector{SubWorker{T,A,S}}) where {T <: AbstractFloat, A <: AbstractVector, S <: LQSolver}
    # Update δ₂
    partial_δs = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_δs[i] = remotecall_fetch((sw,ξ)->begin
                subproblems = fetch(sw)
                if length(subproblems) > 0
                    return sum([s.π*norm(s.x-ξ,2)^2 for s in subproblems])
                else
                    return zero(T)
                end
            end,
            w,
            subworkers[w-1],
            ph.ξ)
        end
    end
    ph.data.δ₂ = sum(partial_δs)
    return nothing
end

function calculate_objective_value(ph::AbstractProgressiveHedgingSolver, subworkers::Vector{<:SubWorker{T}}) where T <: AbstractFloat
    partial_objectives = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_objectives[i] = remotecall_fetch((sw)->begin
                subproblems = fetch(sw)
                if length(subproblems) > 0
                    return sum([get_objective_value(s) for s in subproblems])
                else
                    return zero(T)
                end
            end,
            w,
            subworkers[w-1])
        end
    end
    return sum(partial_objectives)
end


function fill_submodels!(ph::AbstractProgressiveHedgingSolver, scenarioproblems::StochasticPrograms.ScenarioProblems, subworkers::Vector{<:SubWorker})
    j = 0
    @sync begin
        for w in workers()
            n = remotecall_fetch((sw)->length(fetch(sw)), w, subworkers[w-1])
            for i = 1:n
                k = i+j
                @async fill_submodel!(scenarioproblems.problems[k],remotecall_fetch((sw,i,x)->begin
                    sp = fetch(sw)[i]
                    get_solution(sp)
                end,
                w,
                subworkers[w-1],
                i,
                ph.ξ)...)
            end
            j += n
        end
    end
end

function fill_submodels!(ph::AbstractProgressiveHedgingSolver, scenarioproblems::StochasticPrograms.DScenarioProblems, subworkers::Vector{<:SubWorker})
    @sync begin
        for w in workers()
            @async remotecall(fill_submodels!,
                              w,
                              subworkers[w-1],
                              ph.ξ,
                              scenarioproblems[w-1])
        end
    end
end

function load_subproblems!(ph::AbstractProgressiveHedgingSolver, subsolver::MPB.AbstractMathProgSolver)
    for i = 1:ph.nscenarios
        push!(ph.subproblems,SubProblem(WS(ph.stochasticprogram, scenario(ph.stochasticprogram,i); solver = subsolver),
                                        i,
                                        probability(ph.stochasticprogram,i),
                                        decision_length(ph.stochasticprogram),
                                        subsolver))
    end
    return ph
end

function load_worker!(scenarioproblems::StochasticPrograms.ScenarioProblems,
                      sp::StochasticProgram,
                      w::Integer,
                      worker::SubWorker,
                      subsolver::QPSolver)
    n = StochasticPrograms.nscenarios(scenarioproblems)
    (nscen, extra) = divrem(n, nworkers())
    prev = [nscen + (extra + 2 - p > 0) for p in 2:(w-1)]
    start = isempty(prev) ? 1 : sum(prev) + 1
    stop = min(start + nscen + (extra + 2 - w > 0) - 1, n)
    return remotecall_fetch(init_subworker!,
                            w,
                            worker,
                            generator(sp, :stage_1),
                            generator(sp, :stage_2),
                            stage_parameters(sp, 1),
                            stage_parameters(sp, 2),
                            scenarios(sp)[start:stop],
                            decision_length(sp),
                            subsolver,
                            start)
end

function load_worker!(scenarioproblems::StochasticPrograms.DScenarioProblems,
                      sp::StochasticProgram,
                      w::Integer,
                      worker::SubWorker,
                      subsolver::QPSolver)
    leading_scen = [scenarioproblems.scenario_distribution[p-1] for p in 2:(w-1)]
    start_id = isempty(leading_scen) ? 1 : sum(leading_scen)+1
    return remotecall_fetch(init_subworker!,
                            w,
                            worker,
                            generator(sp, :stage_1),
                            generator(sp, :stage_2),
                            stage_parameters(sp, 1),
                            stage_parameters(sp, 2),
                            scenarioproblems[w-1],
                            decision_length(sp),
                            subsolver,
                            start_id)
end

function init_subworker!(subworker::SubWorker{T,A,S},
                         stage_one_generator::Function,
                         stage_two_generator::Function,
                         stage_one_params::Any,
                         stage_two_params::Any,
                         scenarios::Vector{<:AbstractScenario},
                         xdim::Integer,
                         subsolver::QPSolver,
                         start_id::Integer) where {T <: AbstractFloat, A <: AbstractArray, S <: LQSolver}
    subproblems = Vector{SubProblem{T,A,S}}(undef, length(scenarios))
    id = start_id
    solver = get_solver(subsolver)
    for (i,scenario) = enumerate(scenarios)
        subproblems[i] = SubProblem(_WS(stage_one_generator, stage_two_generator, stage_one_params, stage_two_params, scenario, solver),
                                    id,
                                    probability(scenario),
                                    xdim,
                                    solver)
        id += 1
    end
    put!(subworker, subproblems)
end

function init_subworker!(subworker::SubWorker{T,A,S},
                         stage_one_generator::Function,
                         stage_two_generator::Function,
                         stage_one_params::Any,
                         stage_two_params::Any,
                         scenarioproblems::ScenarioProblemChannel,
                         xdim::Integer,
                         subsolver::QPSolver,
                         start_id::Integer) where {T <: AbstractFloat, A <: AbstractArray, S <: LQSolver}
    sp = fetch(scenarioproblems)
    subproblems = Vector{SubProblem{T,A,S}}(undef, StochasticPrograms.nscenarios(sp))
    id = start_id
    solver = get_solver(subsolver)
    for (i,scenario) = enumerate(scenarios(sp))
        subproblems[i] = SubProblem(_WS(stage_one_generator, stage_two_generator, stage_one_params, stage_two_params, scenario, solver),
                                    id,
                                    probability(scenario),
                                    xdim,
                                    solver)
        id += 1
    end
    put!(subworker, subproblems)
end

function fill_submodels!(subworker::SubWorker{T,A,S},
                         x::A,
                         scenarioproblems::ScenarioProblemChannel) where {T <: AbstractFloat, A <: AbstractArray, S <: LQSolver}
    sp = fetch(scenarioproblems)
    subproblems::Vector{SubProblem{T,A,S}} = fetch(subworker)
    for (i, submodel) in enumerate(sp.problems)
        fill_submodel!(submodel, subproblems[i])
    end
end

function fill_submodel!(submodel::JuMP.Model, subproblem::SubProblem)
    fill_submodel!(submodel, get_solution(subproblem)...)
end

function fill_submodel!(submodel::JuMP.Model, x::AbstractVector, μ::AbstractVector, λ::AbstractVector)
    submodel.colVal = x
    submodel.redCosts = μ
    submodel.linconstrDuals = λ
    submodel.objVal = JuMP.prepAffObjective(submodel)⋅x
end

function resolve_subproblems!(subworker::SubWorker{T,A,S}, ξ::AbstractVector, r::AbstractFloat) where {T <: AbstractFloat, A <: AbstractArray, S <: LQSolver}
    subproblems::Vector{SubProblem{T,A,S}} = fetch(subworker)
    Qs = A(undef, length(subproblems))
    for (i,subproblem) ∈ enumerate(subproblems)
        reformulate_subproblem!(subproblem, ξ, r)
        Qs[i] = subproblem()
    end
    return sum(Qs)
end

function collect_primals(subworker::SubWorker{T,A,S}, n::Integer) where {T <: AbstractFloat, A <: AbstractArray, S <: LQSolver}
    subproblems::Vector{SubProblem{T,A,S}} = fetch(subworker)
    if length(subproblems) > 0
        return sum([subproblem.π*subproblem.x for subproblem in subproblems])
    else
        return zeros(T,n)
    end
end
