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

"""
    NoProximal

Empty functor object for running a quasi-gradient algorithm without a prox step.

"""
struct NoProximal <: AbstractProximal end

function initialize_prox!(::AbstractQuasiGradient, ::NoProximal)
    return nothing
end

function restore_proximal_master!(::AbstractQuasiGradient, ::NoProximal)
    return nothing
end

function prox!(::AbstractQuasiGradient, ::NoProximal, x::AbstractVector, ∇f::AbstractVector, γ::AbstractFloat)
    x .= x - γ*∇f
    return nothing
end

# API
# ------------------------------------------------------------
"""
    NoProx

Factory object for [`NoProximal`](@ref). Passed by default to `prox` in `QuasiGradient.Optimizer`.

"""
struct NoProx <: AbstractProx end

function (::NoProx)(::StageDecompositionStructure, ::AbstractVector, ::Type{T}) where T <: AbstractFloat
    return NoProximal()
end

function str(::NoProx)
    return ""
end
