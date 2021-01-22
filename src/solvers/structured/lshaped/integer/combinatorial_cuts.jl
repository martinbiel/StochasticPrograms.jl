@with_kw mutable struct CombinatorialCutsData{T <: AbstractFloat}
    L::T = -1e10
    solve_relaxed::Bool = false
end

@with_kw mutable struct CombinatorialCutsParameters{T <: AbstractFloat}
    lower_bound::T = -1e10
    alternate::Bool = false
    update_L_every::Int = 0
end
"""
    CombinatorialCutsMaster

Master functor object for using weak optimality cuts in an integer L-shaped algorithm. Requires all first-stage decisions to be binary. Create by supplying a [`CombinatorialCuts`](@ref) object through `integer_strategy` in `LShaped.Optimizer` or set the [`IntegerStrategy`](@ref) attribute.

"""
struct CombinatorialCutsMaster{T <: AbstractFloat} <: AbstractIntegerAlgorithm
    parameters::CombinatorialCutsParameters{T}

    function CombinatorialCutsMaster(::Type{T}; kw...) where T <: AbstractFloat
        T_ = promote_type(T, Float32)
        return new{T_}(CombinatorialCutsParameters{T}(; kw...))
    end
end

function initialize_integer_algorithm!(master::CombinatorialCutsMaster, first_stage::JuMP.Model)
    # Sanity check
    if !all(is_binary, all_decision_variables(first_stage, 1))
        error("Combinatorial cuts require all first-stage decisions to be binary.")
    end
    return nothing
end

function handle_integrality!(lshaped::AbstractLShaped, master::CombinatorialCutsMaster)
    if count(active_model_objectives(lshaped)) != num_thetas(lshaped)
        # Only update lower bound if all master variables have been added
        return nothing
    end
    if master.parameters.lower_bound <= -1e10 ||
        (master.parameters.update_L_every != 0 &&
         rem(lshaped.data.iterations, master.parameters.update_L_every) == 0)
        # Check if lower bound should be calculated
        if evaluate_first_stage(lshaped, current_decision(lshaped)) > sqrt(eps())
            # Get sense
            sense = MOI.get(lshaped.master, MOI.ObjectiveSense())
            coeff = sense == MOI.MIN_SENSE ? 1.0 : -1.0
            # Cache current objective
            F = MOI.get(lshaped.master, MOI.ObjectiveFunctionType())
            objective = MOI.get(lshaped.master, MOI.ObjectiveFunction{F}())
            # Replace objective with only model objectives
            F = MOI.ScalarAffineFunction{Float64}
            MOI.set(lshaped.master, MOI.ObjectiveFunction{F}(), zero(F))
            for var in lshaped.master_variables
                MOI.modify(lshaped.master,
                           MOI.ObjectiveFunction{F}(),
                           MOI.ScalarCoefficientChange(var, coeff))
            end
            MOI.optimize!(lshaped.master)
            θs = map(lshaped.master_variables) do vi
                if vi.value == 0
                    -1e10
                else
                    MOI.get(lshaped.master, MOI.VariablePrimal(), vi)
                end
            end
            # Re-add objective
            F = typeof(objective)
            MOI.set(lshaped.master, MOI.ObjectiveFunction{F}(), objective)
        else
            θs = model_objectives(lshaped)
        end
        master.parameters.lower_bound = sum(θs)
        for subproblem in lshaped.execution.subproblems
            update_lower_bound!(subproblem.integer_algorithm, θs[subproblem.id])
        end
    end
    return nothing
end
"""
    CombinatorialCutsWorker

Worker functor object for using weak optimality cuts in an integer L-shaped algorithm. Create by supplying a [`CombinatorialCuts`](@ref) object through `integer_strategy` in `LShaped.Optimizer` or set the [`IntegerStrategy`](@ref) attribute.

"""
struct CombinatorialCutsWorker{T <: AbstractFloat} <: AbstractIntegerAlgorithm
    data::CombinatorialCutsData{T}
    parameters::CombinatorialCutsParameters{T}
    integer_variables::Vector{MOI.VariableIndex}

    function CombinatorialCutsWorker(::Type{T}; kw...) where T <: AbstractFloat
        T_ = promote_type(T, Float32)
        worker = new{T_}(CombinatorialCutsData{T_}(),
                         CombinatorialCutsParameters{T}(; kw...),
                         Vector{MOI.VariableIndex}())
        worker.data.L = worker.parameters.lower_bound
        return worker
    end
end

function initialize_integer_algorithm!(worker::CombinatorialCutsWorker, subproblem::SubProblem)
    # Gather integer variables
    append!(worker.integer_variables, gather_integer_variables(subproblem))
    # Sanity check
    if isempty(worker.integer_variables)
        @warn "No integer variables in subproblem $(subproblem.id). Integer strategy is superfluous."
    end
    return nothing
end

function integer_variables(worker::CombinatorialCutsWorker)
    return worker.integer_variables
end

function update_lower_bound!(worker::CombinatorialCutsWorker, L::AbstractFloat)
    worker.data.L = L
    return nothing
end

function solve_subproblem(subproblem::SubProblem,
                          metadata,
                          ::NoFeasibilityAlgorithm,
                          worker::CombinatorialCutsWorker,
                          x::AbstractVector)
    # Check if lower bound has been set
    if worker.data.L <= -1e10 || worker.data.solve_relaxed
        # Relax integrality and compute regular optimality cuts
        unrelax = relax_decision_integrality(subproblem.model)
        cut = solve_subproblem(subproblem, x)
        # Unrelax integrality restrictions again
        unrelax()
        # Check if integer restrictions are satisfied
        set_metadata!(metadata,
                      subproblem.id,
                      :integral_solution,
                      check_integrality_restrictions(subproblem))
        # Solve integer problem next iteration
        worker.data.solve_relaxed = false
        # Return standard optimality cut (if successful)
        return cut
    end
    # Solve relaxed problem next iteration if alternating
    worker.data.solve_relaxed = worker.parameters.alternate
    # Solve subproblem with integer restrictions
    MOI.optimize!(subproblem.optimizer)
    status = MOI.get(subproblem.optimizer, MOI.TerminationStatus())
    if status ∈ AcceptableTermination
        # Integer restrictions are satisfied if optimal
        set_metadata!(metadata,
                      subproblem.id,
                      :integral_solution,
                      true)
        return CombinatorialOptimalityCut(subproblem, x, worker.data.L)
    elseif status == MOI.INFEASIBLE
        return Infeasible(subproblem)
    elseif status == MOI.DUAL_INFEASIBLE
        return Unbounded(subproblem)
    else
        error("Subproblem $(subproblem.id) was not solved properly, returned status code: $status")
    end
end

function solve_subproblem(subproblem::SubProblem,
                          metadata,
                          feasibility_algorithm::FeasibilityCutsWorker,
                          worker::CombinatorialCutsWorker,
                          x::AbstractVector)
    # Prepare auxiliary problem
    model = subproblem.optimizer
    if !prepared(feasibility_algorithm)
        prepare!(model, feasibility_algorithm)
    end
    # Relax integrality
    unrelax = relax_decision_integrality(subproblem.model)
    # Optimize auxiliary problem
    MOI.optimize!(model)
    # Sanity check that aux problem could be solved
    status = MOI.get(subproblem.optimizer, MOI.TerminationStatus())
    if !(status ∈ AcceptableTermination)
        error("Subproblem $(subproblem.id) was not solved properly during feasibility check, returned status code: $status")
    end
    # check objective
    sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    w = correction * MOI.get(model, MOI.ObjectiveValue())
    # Ensure correction is available in master
    set_metadata!(metadata, subproblem.id, :correction, correction)
    # Check feasibility
    if w > sqrt(eps())
        # Subproblem is infeasible, create feasibility cut
        cut = FeasibilityCut(subproblem, x)
        # Unrelax integrality restrictions again
        unrelax()
        return cut
    end
    # Unrelax integrality restrictions again
    unrelax()
    # Restore subproblem and solve as usual
    restore_subproblem!(subproblem)
    return solve_subproblem(subproblem, metadata, NoFeasibilityAlgorithm(), worker, x)
end

function CombinatorialOptimalityCut(subproblem::SubProblem{T}, x::AbstractVector, L::T) where T <: AbstractFloat
    π = subproblem.probability
    cols = collect(1:length(x))
    vals = zeros(T, length(x))
    S = 0
    for (i,val) in enumerate(x)
        if isapprox(val, 0., rtol = 1e-6)
            vals[i] = -1.
        else
            # Assume x == 1
            S += 1
            vals[i] = 1.
        end
    end
    # Get sense
    sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
    correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
    # Get sense-corrected optimal value
    Q = correction * π * MOI.get(subproblem.optimizer, MOI.ObjectiveValue())
    G = -(Q - L) * sparsevec(cols, vals, length(x))
    q = -(Q - L) * (S - 1) + L
    return OptimalityCut(G, q, subproblem.id)
end

# API
# ------------------------------------------------------------
"""
    CombinatorialCuts

Factory object for [`CombinatorialCuts`](@ref). Pass to `integer_strategy` in `LShaped.Optimizer` or set the [`IntegerStrategy`](@ref) attribute.

"""
struct CombinatorialCuts <: AbstractIntegerStrategy
    parameters::CombinatorialCutsParameters{Float64}
end
CombinatorialCuts(; kw...) = CombinatorialCuts(CombinatorialCutsParameters(; kw...))

function master(wc::CombinatorialCuts, ::Type{T}) where T <: AbstractFloat
    return CombinatorialCutsMaster(T; type2dict(wc.parameters)...)
end

function worker(wc::CombinatorialCuts, ::Type{T}) where T <: AbstractFloat
    return CombinatorialCutsWorker(T; type2dict(wc.parameters)...)
end
function worker_type(::CombinatorialCuts)
    return CombinatorialCutsWorker{Float64}
end
