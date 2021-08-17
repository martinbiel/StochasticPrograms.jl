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

@with_kw mutable struct PolyakStepData{T <: AbstractFloat}
    f̄::T = Inf
end

@with_kw mutable struct PolyakStepParameters{T <: AbstractFloat}
    γ₀::T = 0.1
    η::T = 1.0
end

"""
    PolyakStep

Functor object for using the Polyak step size in a quasigradient algorithm. Create by supplying a [`Polyak`](@ref) object through `step` to `QuasiGradient.Optimizer` or by setting the [`Prox`](@ref) attribute.

...
# Parameters
- `γ₀::AbstractFloat = 0.1`: Nominal step
- `η::AbstractFloat = 1.0`: Diminishing factor
...
"""
struct PolyakStep{T <: AbstractFloat} <: AbstractStep
    data::PolyakStepData{T}
    parameters::PolyakStepParameters{T}

    function PolyakStep(::Type{T}; kw...) where T <: AbstractFloat
        return new{T}(PolyakStepData{T}(), PolyakStepParameters{T}(; kw...))
    end
end
function step(step::PolyakStep, k::Integer, fval::Float64, x::AbstractVector, g::AbstractVector)
    if k == 1
        step.data.f̄ = fval
    end
    @unpack γ₀, η = step.parameters
    @unpack f̄ = step.data
    α = γ₀ / (1 + η * k)
    γ = (fval - f̄ + αₖ)/norm(g)^2
    if fval <= step.data.f̄
        step.data.f̄ = fval
    end
    return γ
end


# API
# ------------------------------------------------------------
"""
    Polyak

Factory object for [`PolyakStep`](@ref). Pass to `step` in `Quasigradient.Optimizer` or set the [`StepSize`](@ref) attribute. See ?PolyakStep for parameter descriptions.

"""
struct Polyak <: AbstractStepSize
    parameters::PolyakStepParameters{Float64}
end
PolyakStepParame(γ::AbstractFloat) = Constant(PolyakStepParameters(; γ = Float64(γ)))
Polyak(; kw...) = Polyak(PolyakStepParameters(; kw...))

function (stepsize::Polyak)(::Type{T}) where T <: AbstractFloat
    return PolyakStep(T; type2dict(stepsize.parameters)...)
end

function str(::Polyak)
    return "Polyak step size"
end
