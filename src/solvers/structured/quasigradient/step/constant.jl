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

@with_kw mutable struct ConstantStepParameters{T <: AbstractFloat}
    γ::T = 0.01
end

"""
    ConstantStep

Functor object for using a constant step size in a quasigradient algorithm. Create by supplying a [`Constant`](@ref) object through `step` to `QuasiGradient.Optimizer` or by setting the [`StepSize`](@ref) attribute.

...
# Parameters
- `γ::AbstractFloat = 0.01`: Step length
...
"""
struct ConstantStep{T <: AbstractFloat} <: AbstractStep
    parameters::ConstantStepParameters{T}

    function ConstantStep(::Type{T}; kw...) where T <: AbstractFloat
        return new{T}(ConstantStepParameters{T}(; kw...))
    end
end
step(step::ConstantStep, ::Integer, ::Float64, ::AbstractVector, ::AbstractVector) = step.parameters.γ


# API
# ------------------------------------------------------------
"""
    Constant

Factory object for [`ConstantStep`](@ref). Pass to `step` in `Quasigradient.Optimizer` or set the [`StepSize`](@ref) attribute. See ?ConstantStep for parameter descriptions.

"""
struct Constant <: AbstractStepSize
    parameters::ConstantStepParameters{Float64}
end
Constant(γ::AbstractFloat) = Constant(ConstantStepParameters(; γ = Float64(γ)))
Constant(; kw...) = Constant(ConstantStepParameters(; kw...))

function (stepsize::Constant)(::Type{T}) where T <: AbstractFloat
    return ConstantStep(T; type2dict(stepsize.parameters)...)
end

function str(::Constant)
    return "constant step size"
end
