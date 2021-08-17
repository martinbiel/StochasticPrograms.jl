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

@with_kw mutable struct DryFrictionParameters{T}
    γ::T = 0.9
    r::T = 1e-3
end

"""
    DryFrictionProximal

Functor object for using dry-friction acceleration in the prox step of a quasigradient algorithm. Create by supplying a [`DryFriction`](@ref) object through `prox ` to `QuasiGradient.Optimizer` or by setting the [`Prox`](@ref) attribute.

...
# Parameters
- `prox::AbstractProx = Polyhedron`: Inner prox step
- `γ::AbstractFloat = 0.9`: Heavy-ball parameter
- `r::AbstractFloat = 1e-3`: Dry-friction parameter
...
"""
struct DryFrictionProximal{T <: AbstractFloat, P <: AbstractProximal} <: AbstractProximal
    parameters::DryFrictionParameters{T}

    prox::P
    xprev::Vector{T}

    function DryFrictionProximal(proximal::AbstractProximal, ::Type{T}; kw...) where T <: AbstractFloat
        P = typeof(proximal)
        return new{T,P}(DryFrictionParameters{T}(; kw...),
                        proximal,
                        Vector{T}())
    end
end

function initialize_prox!(quasigradient::AbstractQuasiGradient, dryfriction::DryFrictionProximal)
    # Initialize inner
    initialize_prox!(quasigradient, dryfriction.prox)
    return nothing
end

function restore_proximal_master!(quasigradient::AbstractQuasiGradient, dryfriction::DryFrictionProximal)
    # Restore inner
    restore_proximal_master!(quasigradient, dryfriction.prox)
    return nothing
end

function prox!(quasigradient::AbstractQuasiGradient, dryfriction::DryFrictionProximal, x::AbstractVector, ∇f::AbstractVector, h::AbstractFloat)
    if length(dryfriction.xprev) == 0
        # First iteration standard prox
        resize!(dryfriction.xprev, length(x))
        dryfriction.xprev .= x
        prox!(quasigradient, dryfriction.prox, x, ∇f, h)
        return nothing
    end
    @unpack γ, r = dryfriction.parameters
    λ = h / (1 + h * γ)
    z = (1 / (1 + h * γ)) * (x - dryfriction.xprev) / h - λ * ∇f
    proj_z = (1 - λ*r / max(λ*r, norm(z))) * z
    # Check for restart
    if norm(proj_z) <= sqrt(eps())
        dryfriction.parameters.r = 0.1 * r
        proj_z .= -∇f
    end
    dryfriction.xprev .= x
    # Regular prox step
    prox!(quasigradient, dryfriction.prox, x, -proj_z, h)
    return nothing
end

# API
# ------------------------------------------------------------
"""
    DryFriction

Factory object for [`DryFrictionProximal`](@ref). Pass to `prox` in `Quasigradient.Optimizer` or set the [`Prox`](@ref) attribute. See ?DryFrictionProximal for parameter descriptions.

"""
mutable struct DryFriction <: AbstractProx
    prox::AbstractProx
    parameters::DryFrictionParameters
end
DryFriction(; prox::AbstractProx = Polyhedron(), kw...) = DryFriction(prox, DryFrictionParameters(; kw...))

function (dryfriction::DryFriction)(structure::StageDecompositionStructure, x₀::AbstractVector, ::Type{T}) where T <: AbstractFloat
    proximal = dryfriction.prox(structure, x₀, T)
    return DryFrictionProximal(proximal, T; type2dict(dryfriction.parameters)...)
end

function str(::DryFriction)
    return ""
end
