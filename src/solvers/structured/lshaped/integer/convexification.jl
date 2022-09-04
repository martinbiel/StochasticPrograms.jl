# MIT License
#
# Copyright (c) 2018 Martin Biel
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

abstract type ConvexificationStrategy end

struct Gomory <: ConvexificationStrategy end
struct LiftAndProject <: ConvexificationStrategy end
struct CuttingPlaneTree <: ConvexificationStrategy end

@with_kw mutable struct ConvexificationData{T <: AbstractFloat}
    relaxation::Union{Nothing, SecondStageLP{T}} = nothing
    cglp::Union{Nothing, JuMP.Model} = nothing
    unrelax::Function = () -> nothing
end

@with_kw mutable struct ConvexificationParameters
    maximum_iterations::Int = 1
    optimizer = nothing
    strategy::ConvexificationStrategy = Gomory()
end
"""
    ConvexificationMaster

Master functor object for using weak optimality cuts in an integer L-shaped algorithm. Requires all first-stage decisions to be binary. Create by supplying a [`Convexification`](@ref) object through `integer_strategy` in `LShaped.Optimizer` or set the [`IntegerStrategy`](@ref) attribute.

"""
struct ConvexificationMaster <: AbstractIntegerAlgorithm end

function initialize_integer_algorithm!(::ConvexificationMaster, first_stage::JuMP.Model)
    # Sanity check
    if !all(is_binary, all_decision_variables(first_stage, 1))
        error("Convexification requires all first-stage decisions to be binary.")
    end
    return nothing
end

function handle_integrality!(lshaped::AbstractLShaped, ::ConvexificationMaster)
    @unpack τ = lshaped.parameters
    if gap(lshaped) <= τ
        set_metadata!(lshaped.execution.metadata, :converged, true)
    end
    # Ensure all binary decisions are rounded
    for (i,dvar) in enumerate(all_decision_variables(lshaped.structure.first_stage, 1))
        lshaped.x[i] = round(lshaped.x[i])
    end
    return nothing
end
"""
    ConvexificationWorker

Worker functor object for using weak optimality cuts in an integer L-shaped algorithm. Create by supplying a [`Convexification`](@ref) object through `integer_strategy` in `LShaped.Optimizer` or set the [`IntegerStrategy`](@ref) attribute.

"""
struct ConvexificationWorker{T <: AbstractFloat} <: AbstractIntegerAlgorithm
    data::ConvexificationData{T}
    parameters::ConvexificationParameters
    integer_variables::Vector{MOI.VariableIndex}
    cutting_planes::Vector{MOI.ConstraintIndex}

    function ConvexificationWorker(::Type{T}; kw...) where T <: AbstractFloat
        T_ = promote_type(T, Float32)
        worker = new{T_}(ConvexificationData{T_}(),
                         ConvexificationParameters(; kw...),
                         Vector{MOI.VariableIndex}(),
                         Vector{MOI.ConstraintIndex}())
        return worker
    end
end

function initialize_integer_algorithm!(worker::ConvexificationWorker, subproblem::SubProblem)
    # Sanity check
    if any(is_integer, all_decision_variables(subproblem.model, StochasticPrograms.stage(subproblem.model))) ||
       any(is_integer, all_auxiliary_variables(subproblem.model))
        if !(worker.parameters.strategy isa Gomory)
            if subproblem.id == 1
                @warn "Switching convexification strategy to Gomory to handle integer variables."
            end
            worker.parameters.strategy = Gomory()
        end
    end
    # Gather integer variables
    append!(worker.integer_variables, gather_integer_variables(subproblem))
    # Sanity check
    if isempty(worker.integer_variables)
        @warn "No integer variables in subproblem $(subproblem.id). Integer strategy is superfluous."
    end
    # Relax integer restrictions
    worker.data.unrelax = relax_decision_integrality(subproblem.model)
    # Extract model information
    standard_form = worker.parameters.strategy isa Gomory
    worker.data.relaxation = SecondStageLP(subproblem; standard_form = standard_form)
    return nothing
end

function restore!(model::MOI.ModelLike, worker::ConvexificationWorker)
    # Delete any added cutting planes
    if !isempty(worker.cutting_planes)
        MOI.delete(model, worker.cutting_planes)
    end
    # Restore integral restrictions
    worker.data.unrelax()
    worker.data.unrelax = () -> nothing
    return nothing
end

function integer_variables(worker::ConvexificationWorker)
    return worker.integer_variables
end

function solve_subproblem(subproblem::SubProblem{T},
                          metadata,
                          ::NoFeasibilityAlgorithm,
                          worker::ConvexificationWorker,
                          x::AbstractVector) where T <: AbstractFloat
    # Initial solve
    cut = solve_subproblem(subproblem, x)
    # Check if integer restrictions are satisfied
    # and collect any fractional variables
    fractional = MOI.VariableIndex[]
    set_metadata!(metadata,
                  subproblem.id,
                  :integral_solution,
                  check_integrality_restrictions(subproblem, fractional))
    # Check if solution satisfies integer requirements
    if isempty(fractional)
        # No cutting planes needed, just return cut
        return cut
    end
    # Check if L-shaped has converged
    if has_metadata(metadata, :converged)
        # Solve subproblem with integer restrictions
        return solve_unrelaxed(subproblem, metadata, worker, x)
    end
    # Otherwise, add cutting planes until solution is integer
    # or user-limit is reached
    num_iterations = 1
    while true
        inds = MOI.get(subproblem.optimizer, MOI.ListOfVariableIndices())
        ȳ = MOI.get.(subproblem.optimizer, MOI.VariablePrimal(), inds[length(x)+1:end])
        try
            # Generate and add cutting plane
            πx, πy, g = cutting_plane(worker,
                                      worker.parameters.strategy,
                                      subproblem,
                                      x,
                                      ȳ,
                                      fractional)
            f, set, coeffs = moi_constraint(subproblem, πx, πy, g)
            # Add cutting plane to subproblem
            ci = MOI.add_constraint(subproblem.optimizer, f, set)
            push!(worker.cutting_planes, ci)
            # Update subproblem
            if !isempty(coeffs)
                push!(subproblem.linking_constraints, ci)
                push!(subproblem.masterterms, coeffs)
            end
        catch
            @warn "Cutting plane could not be generated in subproblem $(subproblem.id)"
            # If cutting plane could not be generated,
            # return latest working cut and try again next iteration
            return cut
        end
        # Re-solve subproblem
        cut = solve_subproblem(subproblem, x)
        fractional = MOI.VariableIndex[]
        set_metadata!(metadata,
                      subproblem.id,
                      :integral_solution,
                      check_integrality_restrictions(subproblem, fractional))
        if isempty(fractional) || num_iterations >= worker.parameters.maximum_iterations
            # Return cut
            return cut
        end
        # Increment iteration count
        num_iterations += 1
    end
end

function solve_subproblem(subproblem::SubProblem,
                          metadata,
                          feasibility_algorithm::FeasibilityCutsWorker,
                          worker::ConvexificationWorker,
                          x::AbstractVector)
    # Prepare auxiliary problem
    model = subproblem.optimizer
    if !prepared(feasibility_algorithm)
        prepare!(model, feasibility_algorithm)
    else
        activate!(model, feasibility_algorithm)
    end
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
        return cut
    end
    # Restore subproblem and solve as usual
    deactivate!(model, feasibility_algorithm)
    return solve_subproblem(subproblem, metadata, NoFeasibilityAlgorithm(), worker, x)
end

function solve_unrelaxed(subproblem::SubProblem, metadata, worker::ConvexificationWorker, x::AbstractVector)
    # Delete any added cutting planes
    if !isempty(worker.cutting_planes)
        MOI.delete(subproblem.optimizer, worker.cutting_planes)
    end
    empty!(worker.cutting_planes)
    # Restore integral restrictions
    worker.data.unrelax()
    worker.data.unrelax = () -> nothing
    # Solve subproblem with integer restrictions
    MOI.optimize!(subproblem.optimizer)
    status = MOI.get(subproblem.optimizer, MOI.TerminationStatus())
    cut = if status ∈ AcceptableTermination
        # Integer restrictions are satisfied if optimal
        set_metadata!(metadata,
                      subproblem.id,
                      :integral_solution,
                      true)
        # Get sense
        sense = MOI.get(subproblem.optimizer, MOI.ObjectiveSense())
        correction = (sense == MOI.MIN_SENSE || sense == MOI.FEASIBILITY_SENSE) ? 1.0 : -1.0
        # Create sense-corrected optimality cut
        π = subproblem.probability
        Q = correction * π * MOI.get(subproblem.optimizer, MOI.ObjectiveValue())
        cut = OptimalityCut(spzeros(length(x)), Q, subproblem.id)
    elseif status == MOI.INFEASIBLE
        cut = Infeasible(subproblem)
    elseif status == MOI.DUAL_INFEASIBLE
        cut = Unbounded(subproblem)
    else
        error("Subproblem $(subproblem.id) was not solved properly, returned status code: $status")
    end
    # Relax integer restrictions again
    worker.data.unrelax = relax_decision_integrality(subproblem.model)
    # Return resulting cut
    return cut
end

function moi_constraint(subproblem::SubProblem{T}, πx::AbstractVector, πy::AbstractVector, g::AbstractFloat) where T <: AbstractFloat
    # Create cutting plane
    f = zero(AffineDecisionFunction{T})
    coeffs = Vector{Tuple{Int, Int, T}}()
    N = StochasticPrograms.stage(subproblem.model)
    all_known = mapreduce(vcat, 1:N-1) do s
        index.(all_known_decision_variables(subproblem.model, s))
    end
    all_decisions = index.(all_decision_variables(subproblem.model, N))
    ix = 0
    iy = 0
    for vi in MOI.get(subproblem.optimizer, MOI.ListOfVariableIndices())
        if vi in all_known
            ix += 1
            coeff = T(πx[ix])
            if abs(coeff) >= sqrt(eps())
                push!(f.decision_part.terms, MOI.ScalarAffineTerm(coeff, vi))
                push!(coeffs, (1, vi.value, coeff))
            else
                πx[ix] = zero(T)
            end
        elseif vi in all_decisions
            iy += 1
            coeff = T(πy[iy])
            if abs(coeff) >= sqrt(eps())
                push!(f.decision_part.terms, MOI.ScalarAffineTerm(coeff, vi))
            else
                πy[iy] = zero(T)
            end
        else
            iy += 1
            coeff = T(πy[iy])
            if abs(coeff) >= sqrt(eps())
                push!(f.variable_part.terms, MOI.ScalarAffineTerm(coeff, vi))
            else
                πy[iy] = zero(T)
            end
        end
    end
    set = MOI.GreaterThan{Float64}(g)
    return f, set, coeffs
end

function cutting_plane(worker::ConvexificationWorker,
                       ::Gomory,
                       subproblem::SubProblem,
                       x̄::AbstractVector,
                       ȳ::AbstractVector,
                       fractional::Vector{MOI.VariableIndex})
    # Pick smallest fractional index
    fractional_index = fractional[1].value - length(x̄)
    # Get matrices
    T = worker.data.relaxation.T
    W = worker.data.relaxation.W
    h = worker.data.relaxation.h
    ny = length(ȳ)
    # Get current optimal basis
    basis = optimal_basis(subproblem)
    nonbasis = setdiff(1:size(W,2),basis)
    # Compute row of basis inverse corresponding
    # to fractional index
    i = something(findfirst(j -> j == fractional_index, basis), 0)
    if i == 0
        error("Fractional variable not in basis.")
    end
    ei = zeros(size(W, 1))
    ei[i] = 1.0
    Bᵢ⁻¹ = W[:,basis]' \ ei
    # Get source rows
    nonbasic = setdiff(1:ny, basis)
    nonbasic_slack = setdiff(ny+1:size(W,2), basis)
    w = (Bᵢ⁻¹'*W[:,nonbasis])
    γ = (Bᵢ⁻¹'*T)[:]
    ρ = Bᵢ⁻¹'*h
    # Translate x to the origin
    for (j,x) in enumerate(x̄)
        if x == 1.
            ρ -= γ[j]
            γ[j] *= -1
        end
    end
    # Calculate Gomory coefficients
    ϕ(x) = x - floor(x)
    ϕγ = ϕ.(γ)
    ϕw = ϕ.(w)
    ρ  = ϕ(ρ)
    πx = min.(ϕγ, (ρ .* (1 .- ϕγ) ./ (1 .- ρ)))
    w  = min.(ϕw, (ρ .* (1 .- ϕw) ./ (1 .- ρ)))
    # Translate back
    for (j,x) in enumerate(x̄)
        if x == 1.
            ρ -= πx[j]
            πx[j] *= -1
        end
    end
    πy = zero(ȳ)
    πy[nonbasic] .= w[nonbasic]
    # Map slacks to rows
    for (coeff,slack) in zip(w[length(nonbasic)+1:end], nonbasic_slack)
        row = slack - ny
        πx .-= W[row,slack] * coeff * T[row,:]
        πy .-= W[row,slack] * coeff * W[row,1:ny]
        ρ -= W[row,slack] * coeff * h[row]
    end
    # Extend standard form LP with new cuts
    add_row!(worker.data.relaxation, πx, πy, ρ; standard_form = true)
    # Return cutting plane
    return πx, πy, ρ
end

function cutting_plane(worker::ConvexificationWorker,
                       ::LiftAndProject,
                       subproblem::SubProblem{T},
                       x̄::AbstractVector,
                       ȳ::AbstractVector,
                       fractional::Vector{MOI.VariableIndex}) where T <: AbstractFloat
    # Check optimizer
    if worker.parameters.optimizer === nothing
        error("Cannot generate CGLP without optimizer.")
    end
    # Largest fractional index
    fractional_index = fractional[end].value - length(x̄)
    model = subproblem.model
    nx = length(x̄)
    ny = length(ȳ)
    nw = nx + ny - 1
    # Prepare data
    Gᵢ = Vector{Int}()
    Gⱼ = Vector{Int}()
    Gᵥ = Vector{T}()
    Hᵢ = Vector{Int}()
    Hⱼ = Vector{Int}()
    Hᵥ = Vector{T}()
    Fᵢ = Vector{Int}()
    Fⱼ = Vector{Int}()
    Fᵥ = Vector{T}()
    lhs = Vector{T}()
    rhs = Vector{T}()
    i = 0
    # Loop over constraints
    for (F,S) in list_of_constraint_types(model)
        for cref in all_constraints(model, F, S)
            if S <: StochasticPrograms.SingleDecisionSet ||
                S <: StochasticPrograms.MultipleDecisionSet
                continue
            elseif F <: VariableRef || F <: DecisionRef
                continue
            elseif F <: AffExpr
                i += 1
                f = MOI.get(model, MOI.ConstraintFunction(), cref)
                for term in f.terms
                    idx = term.variable.value - nx
                    if idx == fractional_index
                        # yⱼ
                        push!(Hᵢ, i)
                        push!(Hᵥ, term.coefficient)
                        push!(Hⱼ, idx)
                    else
                        # yⱼ
                        push!(Fᵢ, i)
                        push!(Fᵥ, term.coefficient)
                        push!(Fⱼ, nx + ny + nx + idx)
                        # 1-yⱼ
                        push!(Hᵢ, i+1)
                        push!(Hᵥ, term.coefficient)
                        push!(Hⱼ, idx)
                        push!(Fᵢ, i+1)
                        push!(Fᵥ, -term.coefficient)
                        push!(Fⱼ, nx + ny + nx + idx)
                    end
                end
                set = MOI.get(model, MOI.ConstraintSet(), cref)
                if set isa MOI.LessThan
                    # yⱼ
                    push!(lhs, -Inf)
                    push!(rhs, zero(T))
                    push!(Hᵢ, i)
                    push!(Hᵥ, -set.upper)
                    push!(Hⱼ, fractional_index)
                    # 1-yⱼ
                    push!(lhs, -Inf)
                    push!(rhs, set.upper)
                    push!(Hᵢ, i+1)
                    push!(Hᵥ, set.upper)
                    push!(Hⱼ, fractional_index)
                elseif set isa MOI.GreaterThan
                    # yⱼ
                    push!(lhs, zero(T))
                    push!(rhs, Inf)
                    push!(Hᵢ, i)
                    push!(Hᵥ, -set.lower)
                    push!(Hⱼ, fractional_index)
                    # 1-yⱼ
                    push!(lhs, set.lower)
                    push!(rhs, Inf)
                    push!(Hᵢ, i+1)
                    push!(Hᵥ, set.lower)
                    push!(Hⱼ, fractional_index)
                elseif set isa MOI.EqualTo
                    # yⱼ
                    push!(lhs, zero(T))
                    push!(rhs, zero(T))
                    push!(Hᵢ, i)
                    push!(Hᵥ, -set.value)
                    push!(Hⱼ, fractional_index)
                    # 1-yⱼ
                    push!(lhs, set.value)
                    push!(rhs, set.value)
                    push!(Hᵢ, i+1)
                    push!(Hᵥ, set.value)
                    push!(Hⱼ, fractional_index)
                end
                i += 1
            elseif F <: DecisionAffExpr
                i += 1
                aff = jump_function(model, MOI.get(model, MOI.ConstraintFunction(), cref))
                for (coeff, var) in linear_terms(aff.variables)
                    idx = index(var).value - nx
                    if idx == fractional_index
                        # yⱼ
                        push!(Hᵢ, i)
                        push!(Hᵥ, coefff)
                        push!(Hⱼ, idx)
                    else
                        # yⱼ
                        push!(Fᵢ, i)
                        push!(Fᵥ, coeff)
                        push!(Fⱼ, nx + idx - 1)
                        # 1-yⱼ
                        push!(Hᵢ, i+1)
                        push!(Hᵥ, coeff)
                        push!(Hⱼ, idx)
                        push!(Fᵢ, i+1)
                        push!(Fᵥ, -coeff)
                        push!(Fⱼ, nx + idx - 1)
                    end
                end
                for (coeff, dvar) in linear_terms(aff.decisions)
                    if state(dvar) == Known
                        idx = index(dvar).value
                        # yⱼ
                        push!(Fᵢ, i)
                        push!(Fᵥ, coeff)
                        push!(Fⱼ, idx)
                        # 1-yⱼ
                        push!(Gᵢ, i+1)
                        push!(Gᵥ, coeff)
                        push!(Gⱼ, idx)
                        push!(Fᵢ, i+1)
                        push!(Fᵥ, -coeff)
                        push!(Fⱼ, idx)
                    else
                        idx = index(dvar).value - nx
                        if idx == fractional_index
                            # yⱼ
                            push!(Hᵢ, i)
                            push!(Hᵥ, coeff)
                            push!(Hⱼ, idx)
                        else
                            # yⱼ
                            push!(Fᵢ, i)
                            push!(Fᵥ, coeff)
                            push!(Fⱼ, nx + idx - 1)
                            # 1-yⱼ
                            push!(Hᵢ, i+1)
                            push!(Hᵥ, coeff)
                            push!(Hⱼ, idx)
                            push!(Fᵢ, i+1)
                            push!(Fᵥ, -coeff)
                            push!(Fⱼ, nx + idx - 1)
                        end
                    end
                end
                set = MOI.get(model, MOI.ConstraintSet(), cref)
                if set isa MOI.LessThan
                    # yⱼ
                    push!(lhs, -Inf)
                    push!(rhs, zero(T))
                    push!(Hᵢ, i)
                    push!(Hᵥ, -set.upper)
                    push!(Hⱼ, fractional_index)
                    # 1-yⱼ
                    push!(lhs, -Inf)
                    push!(rhs, set.upper)
                    push!(Hᵢ, i+1)
                    push!(Hᵥ, set.upper)
                    push!(Hⱼ, fractional_index)
                elseif set isa MOI.GreaterThan
                    # yⱼ
                    push!(lhs, zero(T))
                    push!(rhs, Inf)
                    push!(Hᵢ, i)
                    push!(Hᵥ, -set.lower)
                    push!(Hⱼ, fractional_index)
                    # 1-yⱼ
                    push!(lhs, set.lower)
                    push!(rhs, Inf)
                    push!(Hᵢ, i+1)
                    push!(Hᵥ, set.lower)
                    push!(Hⱼ, fractional_index)
                elseif set isa MOI.EqualTo
                    # yⱼ
                    push!(lhs, zero(T))
                    push!(rhs, zero(T))
                    push!(Hᵢ, i)
                    push!(Hᵥ, -set.value)
                    push!(Hⱼ, fractional_index)
                    # 1-yⱼ
                    push!(lhs, set.value)
                    push!(rhs, set.value)
                    push!(Hᵢ, i+1)
                    push!(Hᵥ, set.value)
                    push!(Hⱼ, fractional_index)
                end
                i += 1
            else
                error("Cannot extract linear representation from $F-$S constraint.")
            end
        end
    end
    # x ≥ 0
    for j in 1:length(x̄)
        i += 1
        # yⱼ
        push!(Fᵢ, i)
        push!(Fᵥ, 1.)
        push!(Fⱼ, j)
        push!(lhs, zero(T))
        push!(rhs, Inf)
        # 1-yⱼ
        push!(Gᵢ, i+1)
        push!(Gᵥ, 1.)
        push!(Gⱼ, j)
        push!(Fᵢ, i+1)
        push!(Fᵥ, -1.)
        push!(Fⱼ, j)
        push!(lhs, zero(T))
        push!(rhs, Inf)
        i += 1
    end
    # x ≤ 1
    for j in 1:length(x̄)
        i += 1
        # yⱼ
        push!(Fᵢ, i)
        push!(Fᵥ, 1.)
        push!(Fⱼ, j)
        push!(Hᵢ, i)
        push!(Hᵥ, -1.)
        push!(Hⱼ, fractional_index)
        push!(lhs, -Inf)
        push!(rhs, zero(T))
        # 1-yⱼ
        push!(Gᵢ, i+1)
        push!(Gᵥ, 1.)
        push!(Gⱼ, j)
        push!(Fᵢ, i+1)
        push!(Fᵥ, -1.)
        push!(Fⱼ, j)
        push!(Hᵢ, i+1)
        push!(Hᵥ, 1.)
        push!(Hⱼ, fractional_index)
        push!(lhs, -Inf)
        push!(rhs, 1.)
        i += 1
    end
    # y ≥ 0
    for j in 1:length(ȳ)
        i += 1
        if j == fractional_index
            # yⱼ
            push!(Hᵢ, i)
            push!(Hᵥ, 1.)
            push!(Hⱼ, j)
            push!(lhs, zero(T))
            push!(rhs, Inf)
        else
            # yⱼ
            push!(Fᵢ, i)
            push!(Fᵥ, 1.)
            push!(Fⱼ, nx + j - 1)
            push!(lhs, zero(T))
            push!(rhs, Inf)
            # 1-yⱼ
            push!(Hᵢ, i+1)
            push!(Hᵥ, 1.)
            push!(Hⱼ, j)
            push!(Fᵢ, i+1)
            push!(Fᵥ, -1.)
            push!(Fⱼ, nx + j - 1)
            push!(lhs, zero(T))
            push!(rhs, Inf)
            i += 1
        end
    end
    # y ≤ 1
    for j in 1:length(ȳ)
        i += 1
        if j == fractional_index
            # 1-yⱼ
            push!(Hᵢ, i)
            push!(Hᵥ, 1.)
            push!(Hⱼ, j)
            push!(lhs, -Inf)
            push!(rhs, 1.)
        else
            # yⱼ
            push!(Fᵢ, i)
            push!(Fᵥ, 1.)
            push!(Fⱼ, nx + j - 1)
            push!(Hᵢ, i)
            push!(Hᵥ, -1.)
            push!(Hⱼ, fractional_index)
            push!(lhs, -Inf)
            push!(rhs, zero(T))
            # 1-yⱼ
            push!(Hᵢ, i+1)
            push!(Hᵥ, 1.)
            push!(Hⱼ, j)
            push!(Fᵢ, i+1)
            push!(Fᵥ, -1.)
            push!(Fⱼ, nx + j - 1)
            push!(Hᵢ, i+1)
            push!(Hᵥ, 1.)
            push!(Hⱼ, fractional_index)
            push!(lhs, -Inf)
            push!(rhs, 1.)
            i += 1
        end
    end
    G̃ = sparse(Gᵢ, Gⱼ, Gᵥ, i, nx)
    H̃ = sparse(Hᵢ, Hⱼ, Hᵥ, i, ny)
    F̃ = sparse(Fᵢ, Fⱼ, Fᵥ, i, nw)
    G, f = StochasticPrograms.canonical(G̃, lhs, rhs; direction = :geq)
    H, f = StochasticPrograms.canonical(H̃, lhs, rhs; direction = :geq)
    F, f = StochasticPrograms.canonical(F̃, lhs, rhs; direction = :geq)
    # Generate CGLP
    CGLP = Model(worker.parameters.optimizer)
    n = size(F, 1)
    @variable(CGLP, π[1:n] >= 0)
    @objective(CGLP, Min, π⋅(H*ȳ) - π⋅(f - G*x̄))
    @constraint(CGLP, F'*π .== 0)
    @constraint(CGLP, sum(π) == 1)
    # Solve CGLP
    optimize!(CGLP)
    if termination_status(CGLP) == MOI.OPTIMAL
        π = value.(π)
        πx = G'*π
        πy = H'*π
        g = π⋅f
        # Extend standard form LP with new cuts
        add_row!(worker.data.relaxation, πx, πy, g)
        # Return cutting plane
        return πx, πy, g
    else
        error("CGLP could not be solved.")
    end
end

function cutting_plane(worker::ConvexificationWorker,
                       ::CuttingPlaneTree,
                       subproblem::SubProblem,
                       x̄::AbstractVector,
                       ȳ::AbstractVector,
                       fractional::Vector{MOI.VariableIndex})
    # Check optimizer
    if worker.parameters.optimizer === nothing
        error("Cannot generate CGLP without optimizer.")
    end
    # Largest fractional index
    fractional_index = fractional[end].value - length(x̄)
    # Dimensions
    lp = worker.data.relaxation
    m  = size(lp.T, 1)
    nx = size(lp.T, 2)
    ny = size(lp.W, 2)
    length(x̄) == nx || error("Given first-stage decision $x̄ does not match second-stage problem dimensions.")
    length(ȳ) == ny || error("Given second-stage decision $ȳ does not match second-stage problem dimensions.")
    ȳ[abs.(ȳ) .<= sqrt(eps())] .= 0.0
    x_lb = fill(0., nx)
    x_ub = fill(1., nx)
    lb_finite = isfinite.(lp.lb)
    ub_finite = isfinite.(lp.ub)
    # Generate CGLP
    CGLP = Model(worker.parameters.optimizer)
    @variable(CGLP, πx[1:nx])
    @variable(CGLP, πy[1:ny])
    @variable(CGLP, tx >= 0)
    @variable(CGLP, ty >= 0)
    @variable(CGLP, λ₂₁[1:m] >= 0)
    @variable(CGLP, λ₂₂[1:m] >= 0)
    @variable(CGLP, ν₁₁[1:nx] >= 0)
    @variable(CGLP, ν₁₂[1:nx] >= 0)
    @variable(CGLP, ν₂₁[1:ny] >= 0)
    @variable(CGLP, ν₂₂[1:ny] >= 0)
    @variable(CGLP, μ₁₁[1:nx] >= 0)
    @variable(CGLP, μ₁₂[1:nx] >= 0)
    @variable(CGLP, μ₂₁[1:ny] >= 0)
    @variable(CGLP, μ₂₂[1:ny] >= 0)
    @objective(CGLP, Min, tx + ty)
    @constraint(CGLP, vcat(tx, πx) in MOI.NormOneCone(nx+1))
    @constraint(CGLP, vcat(ty, πy) in MOI.NormOneCone(ny+1))
    @constraint(CGLP, πx .== lp.T'*λ₂₁ + μ₁₁ - ν₁₁)
    @constraint(CGLP, πx .== lp.T'*λ₂₂ + μ₁₂ - ν₁₂)
    @constraint(CGLP, πy .== lp.W'*λ₂₁ + μ₂₁ - ν₂₁)
    @constraint(CGLP, πy .== lp.W'*λ₂₂ + μ₂₂ - ν₂₂)
    lp.ub[fractional_index] = 0.
    @constraint(CGLP, lp.h⋅λ₂₁ + x_lb⋅μ₁₁ + lp.lb[lb_finite]⋅μ₂₁[lb_finite] - x_ub⋅ν₁₁ - lp.ub[ub_finite]⋅ν₂₁[ub_finite] >= πx⋅x̄ + πy⋅ȳ + 1)
    lp.ub[fractional_index] = 1.
    lp.lb[fractional_index] = 1.
    @constraint(CGLP, lp.h⋅λ₂₂ + x_lb⋅μ₁₂ + lp.lb[lb_finite]⋅μ₂₂[lb_finite] - x_ub⋅ν₁₂ - lp.ub[ub_finite]⋅ν₂₂[ub_finite] >= πx⋅x̄ + πy⋅ȳ + 1)
    lp.lb[fractional_index] = 0.
    # Solve CGLP
    optimize!(CGLP)
    if termination_status(CGLP) == MOI.OPTIMAL
        # Extract cutting plane parameters
        πx = value.(CGLP[:πx])
        πy = value.(CGLP[:πy])
        g  = πx⋅x̄ + πy⋅ȳ + 1.
        # Extend standard form LP with new cuts
        add_row!(worker.data.relaxation, πx, πy, g)
        # Return cutting plane
        return πx, πy, g
    else
        error("CGLP could not be solved to optimality.")
    end
end

# API
# ------------------------------------------------------------
"""
    Convexification

Factory object for using convexification to handle integer recourse. Pass to `integer_strategy` in `LShaped.Optimizer` or set the [`IntegerStrategy`](@ref) attribute.

...
# Parameters
- `maximum_iterations::Integer = 1`: Determines the number of iterations spent generating cutting-planes each time a subproblem is solved.
- `strategy::ConvexificationStrategy = Gomory()`: Specify convexification strategy (`Gomory`, `LiftAndProject`, `CuttingPlaneTree`)
- `optimizer = nothing`: Optionally specify an optimizer used to solve auxilliary problems in the `LiftAndProject` or `CuttingPlaneTree` strategies.
...

"""
struct Convexification <: AbstractIntegerStrategy
    parameters::ConvexificationParameters
end
Convexification(; kw...) = Convexification(ConvexificationParameters(; kw...))

function master(wc::Convexification, ::Type{T}) where T <: AbstractFloat
    return ConvexificationMaster()
end

function worker(wc::Convexification, ::Type{T}) where T <: AbstractFloat
    return ConvexificationWorker(T; type2dict(wc.parameters)...)
end
function worker_type(::Convexification)
    return ConvexificationWorker{Float64}
end
