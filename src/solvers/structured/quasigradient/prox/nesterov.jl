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

@with_kw mutable struct NesterovData{T}
    t::T = 1.0
end

@with_kw mutable struct NesterovParameters
    stabilizing_projection::Bool = false
end

"""
    NesterovProximal

Functor object for using nesterov accleration, with FISTA updates, in the prox step of a quasigradient algorithm. Create by supplying a [`Nesterov`](@ref) object through `prox ` to `QuasiGradient.Optimizer` or by setting the [`Prox`](@ref) attribute.

...
# Parameters
- `prox::AbstractProx = Polyhedron`: Inner prox step
- `stabilizing_projection::Bool = false`: Specify if an extra guarding projection should be performed to ensure first-stage feasibility
...
"""
struct NesterovProximal{T <: AbstractFloat, P <: AbstractProximal} <: AbstractProximal
    data::NesterovData{T}
    parameters::NesterovParameters

    prox::P
    xprev::Vector{T}

    function NesterovProximal(proximal::AbstractProximal, ::Type{T}; kw...) where T <: AbstractFloat
        P = typeof(proximal)
        return new{T,P}(NesterovData{T}(),
                        NesterovParameters(; kw...),
                        proximal,
                        Vector{T}())
    end
end

function initialize_prox!(quasigradient::AbstractQuasiGradient, nesterov::NesterovProximal)
    # Initialize inner
    initialize_prox!(quasigradient, nesterov.prox)
    return nothing
end

function restore_proximal_master!(quasigradient::AbstractQuasiGradient, nesterov::NesterovProximal)
    # Restore inner
    restore_proximal_master!(quasigradient, nesterov.prox)
    return nothing
end

function prox!(quasigradient::AbstractQuasiGradient, nesterov::NesterovProximal, x::AbstractVector, ∇f::AbstractVector, h::AbstractFloat)
    if length(nesterov.xprev) == 0
        resize!(nesterov.xprev, length(x))
        nesterov.xprev .= x
        return nothing
    end
    @unpack t = nesterov.data
    # Prox step
    prox!(quasigradient, nesterov.prox, x, ∇f, h)
    # Update incumbent xₖ
    quasigradient.ξ .= x
    # Update t
    tnext = (1 + sqrt(1 + 4*t^2)) / 2
    # Look-ahead
    x .= x + ((t - 1) / tnext) * (x - nesterov.xprev)
    # Possibly stabilize the iterate
    if nesterov.parameters.stabilizing_projection
        prox!(quasigradient, nesterov.prox, x, ∇f, 0.0)
    end
    # Update memory
    nesterov.xprev .= quasigradient.ξ
    nesterov.data.t = tnext
    return nothing
end

# API
# ------------------------------------------------------------
"""
    Nesterov

Factory object for [`NesterovProximal`](@ref). Pass to `prox` in `Quasigradient.Optimizer` or set the [`Prox`](@ref) attribute. See ?NesterovProximal for parameter descriptions.

"""
mutable struct Nesterov <: AbstractProx
    prox::AbstractProx
    parameters::NesterovParameters
end
Nesterov(; prox::AbstractProx = Polyhedron(), kw...) = Nesterov(prox, NesterovParameters(; kw...))

function (nesterov::Nesterov)(structure::StageDecompositionStructure, x₀::AbstractVector, ::Type{T}) where T <: AbstractFloat
    proximal = nesterov.prox(structure, x₀, T)
    return NesterovProximal(proximal, T; type2dict(nesterov.parameters)...)
end

function str(::Nesterov)
    return ""
end
