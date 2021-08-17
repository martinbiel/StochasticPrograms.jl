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

@with_kw mutable struct BBParameters{T <: AbstractFloat}
    γ₀::T = 0.1
end

"""
    BBStep

Functor object for using the Barzilai-Borwein step size in a quasigradient algorithm. Create by supplying a [`BB`](@ref) object through `step` to `QuasiGradient.Optimizer` or by setting the [`StepSize`](@ref) attribute.

...
# Parameters
- `γ₀::AbstractFloat = 0.1`: Initial step-size and fallback if BB is numerically unstable
...
"""
struct BBStep{T <: AbstractFloat} <: AbstractStep
    parameters::BBParameters{T}
    xprev::Vector{T}
    gprev::Vector{T}

    function BBStep(::Type{T}; kw...) where T <: AbstractFloat
        return new{T}(BBParameters{T}(; kw...), Vector{T}(), Vector{T}())
    end
end

function step(step::BBStep, k::Integer, fval::Float64, x::AbstractVector, g::AbstractVector)
    if k == 1
        resize!(step.xprev, length(x))
        resize!(step.gprev, length(x))
        step.xprev .= x
        step.gprev .= g
        return step.parameters.γ₀
    end
    s = x - step.xprev
    y = g - step.gprev
    sy = (s⋅y)
    if abs(sy) <= sqrt(eps())
        return step.parameters.γ₀
    end
    η = (norm(s,2) ^ 2) / sy
    step.xprev .= x
    step.gprev .= g
    return η
end


# API
# ------------------------------------------------------------
"""
    BB

Factory object for [`BBStep`](@ref). Pass to `step` in `Quasigradient.Optimizer` or set the [`StepSize`](@ref) attribute. See ?BBStep for parameter descriptions.

"""
struct BB <: AbstractStepSize
    parameters::BBParameters{Float64}
end
BB(γ₀::AbstractFloat) = BB(BBParameters(; γ₀ = Float64(γ₀)))
BB(; kw...) = BB(BBParameters(; kw...))

function (stepsize::BB)(::Type{T}) where T <: AbstractFloat
    return BBStep(T; type2dict(stepsize.parameters)...)
end

function str(::BB)
    return "BB step size"
end
