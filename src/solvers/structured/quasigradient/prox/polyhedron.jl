struct PolyhedronProjection{T <: AbstractFloat, S <: MOI.AbstractOptimizer, PT <: AbstractPenaltyterm} <: AbstractProximal
    projectionsolver::S
    penaltyterm::PT
    decisions::Vector{MOI.VariableIndex}
    projection_targets::Vector{MOI.VariableIndex}
    ξ::Vector{Decision{T}}

    function PolyhedronProjection(model::JuMP.Model, penaltyterm::AbstractPenaltyterm, ξ₀::AbstractVector, ::Type{T}) where T <: AbstractFloat
        optimizer = model.moi_backend
        S = typeof(optimizer)
        PT = typeof(penaltyterm)
        decisions = StochasticPrograms.get_decisions(model, 1)
        projection_targets = Vector{MOI.VariableIndex}(undef, num_decisions(model, 1))
        ξ = map(ξ₀) do val
            Decision(val, T)
        end
        return new{T, S, PT}(optimizer, penaltyterm, decisions.undecided, projection_targets, ξ)
    end
end

function initialize_prox!(quasigradient::AbstractQuasiGradient, polyhedron::PolyhedronProjection)
    # Add projection targets
    ξ = polyhedron.ξ
    decisions = StochasticPrograms.get_decisions(quasigradient.structure.first_stage, 1)
    for i in eachindex(ξ)
        name = add_subscript(:ξ, i)
        var_index, _ = MOI.add_constrained_variable(polyhedron.projectionsolver, SingleKnownSet(1, ξ[i]))
        set_known_decision!(decisions, var_index, ξ[i])
        MOI.set(polyhedron.projectionsolver, MOI.VariableName(), var_index, name)
        polyhedron.projection_targets[i] = var_index
    end
    # Initialize penaltyterm
    F = MOI.ScalarAffineFunction{Float64}
    MOI.set(polyhedron.projectionsolver, MOI.ObjectiveFunction{F}(), zero(F))
    initialize_penaltyterm!(polyhedron.penaltyterm,
                            polyhedron.projectionsolver,
                            1.0,
                            polyhedron.decisions,
                            polyhedron.projection_targets)
    return nothing
end

function restore_proximal_master!(quasigradient::AbstractQuasiGradient, polyhedron::PolyhedronProjection)
    # Delete penalty-term
    remove_penalty!(polyhedron.penaltyterm, quasigradient.structure.first_stage.moi_backend)
    # Delete projection targets
    for var in polyhedron.projection_targets
        MOI.delete(quasigradient.structure.first_stage.moi_backend, var)
    end
    empty!(polyhedron.projection_targets)
    return nothing
end

function prox!(polyhedron::PolyhedronProjection, x::AbstractVector, ∇f::AbstractVector, γ::AbstractFloat)
    # Update projection targets
    for i in eachindex(polyhedron.ξ)
        polyhedron.ξ[i].value = x[i] - γ * ∇f[i]
    end
    # Update penaltyterm
    update_penaltyterm!(polyhedron.penaltyterm,
                        polyhedron.projectionsolver,
                        1.0,
                        polyhedron.decisions,
                        polyhedron.projection_targets)
    # Solve projection problem
    MOI.optimize!(polyhedron.projectionsolver)
    # Get solution
    x .= MOI.get.(polyhedron.projectionsolver, MOI.VariablePrimal(), polyhedron.decisions)
    return nothing
end

# API
# ------------------------------------------------------------
mutable struct Polyhedron <: AbstractProx
    penaltyterm::AbstractPenaltyterm
end
Polyhedron(; penaltyterm = Quadratic()) = Polyhedron(penaltyterm)

function (polyhedron::Polyhedron)(structure::VerticalStructure, x₀::AbstractVector, ::Type{T}) where T <: AbstractFloat
    return PolyhedronProjection(structure.first_stage, polyhedron.penaltyterm, x₀, T)
end

function str(::Polyhedron)
    return ""
end
