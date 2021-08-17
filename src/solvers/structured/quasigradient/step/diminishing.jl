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

@with_kw mutable struct DiminishingStepParameters{T <: AbstractFloat}
    γ₀::T = 0.1
    η::T = 1.0
end

"""
    DiminishingStep

Functor object for using a constant step size in a quasigradient algorithm. Create by supplying a [`Constant`](@ref) object through `step` to `QuasiGradient.Optimizer` or by setting the [`StepSize`](@ref) attribute.

...
# Parameters
- `γ₀::AbstractFloat = 0.1`: Nominal step
- `η::AbstractFloat = 1.0`: Diminishing factor
...
"""
struct DiminishingStep{T <: AbstractFloat} <: AbstractStep
    parameters::DiminishingStepParameters{T}

    function DiminishingStep(::Type{T}; kw...) where T <: AbstractFloat
        return new{T}(DiminishingStepParameters{T}(; kw...))
    end
end
function step(step::DiminishingStep, k::Integer, ::Float64, ::AbstractVector, ::AbstractVector)
    @unpack γ₀, η = step.parameters
    return γ₀ / (1 + η * k)
end


# API
# ------------------------------------------------------------
"""
    Diminishing

Factory object for [`DiminishingStep`](@ref). Pass to `step` in `Quasigradient.Optimizer` or set the [`StepSize`](@ref) attribute. See ?DiminishingStep for parameter descriptions.

"""
struct Diminishing <: AbstractStepSize
    parameters::DiminishingStepParameters{Float64}
end
DiminishingStepParame(γ::AbstractFloat) = Constant(DiminishingStepParameters(; γ = Float64(γ)))
Diminishing(; kw...) = Diminishing(DiminishingStepParameters(; kw...))

function (stepsize::Diminishing)(::Type{T}) where T <: AbstractFloat
    return DiminishingStep(T; type2dict(stepsize.parameters)...)
end

function str(::Diminishing)
    return "diminishing step size"
end
