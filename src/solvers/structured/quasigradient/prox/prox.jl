abstract type AbstractProximal end
abstract type AbstractProx end

initialize_prox!(quasigradient::AbstractQuasiGradient) = initialize_prox!(quasigradient, quasigradient.prox)
restore_proximal_master!(quasigradient::AbstractQuasiGradient) = restore_proximal_master!(quasigradient, quasigradient.prox)
prox!(quasigradient::AbstractQuasiGradient, x::AbstractVector, ∇f::AbstractVector, γ::AbstractFloat) = prox!(quasigradient, quasigradient.prox, x, ∇f, γ)

"""
    RawProxParameter

An optimizer attribute used for raw parameters of the proximal step. Defers to `RawParameter`.
"""
struct RawProxParameter <: ProxParameter
    name::Any
end
"""
    ProxPenaltyterm

An optimizer attribute used to set the proximal term in the prox step. Options are:

- [`Quadratic`](@ref) (default)
- [`InfNorm`](@ref)
- [`ManhattanNorm`](@ref)
"""
struct ProxPenaltyterm <: ProxParameter end

include("common.jl")
include("no_prox.jl")
include("polyhedron.jl")
include("anderson.jl")
include("nesterov.jl")
include("dry_friction.jl")
