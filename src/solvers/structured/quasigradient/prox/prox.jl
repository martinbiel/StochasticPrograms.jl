abstract type AbstractProximal end
abstract type AbstractProx end

initialize_prox!(quasigradient::AbstractQuasiGradient) = initialize_prox!(quasigradient, quasigradient.prox)
restore_proximal_master!(quasigradient::AbstractQuasiGradient) = restore_proximal_master!(quasigradient, quasigradient.prox)
prox!(quasigradient::AbstractQuasiGradient, x::AbstractVector, ∇f::AbstractVector, γ::AbstractFloat) = prox!(quasigradient, quasigradient.prox, x, ∇f, γ)

include("no_prox.jl")
include("polyhedron.jl")
include("anderson.jl")
