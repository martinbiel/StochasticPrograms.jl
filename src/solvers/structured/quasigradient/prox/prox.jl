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
    ProxPenaltyTerm

An optimizer attribute used to set the proximal term in the prox step. Options are:

- [`Quadratic`](@ref) (default)
- [`InfNorm`](@ref)
- [`ManhattanNorm`](@ref)
"""
struct ProxPenaltyTerm <: ProxParameter end

include("common.jl")
include("no_prox.jl")
include("polyhedron.jl")
include("anderson.jl")
include("nesterov.jl")
include("dry_friction.jl")
