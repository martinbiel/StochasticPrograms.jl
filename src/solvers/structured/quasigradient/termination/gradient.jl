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

@with_kw mutable struct GradientThresholdParameters{T <: AbstractFloat}
    τ::T = 1e-6
end

"""
    ObjectiveThreshold

Functor object for using a zero gradient threshold as termination criterion in a quasigradient algorithm. Create by supplying a [`AtGradientThreshold`](@ref) object through `terminate` to `QuasiGradient.Optimizer` or by setting the [`Termination`](@ref) attribute.

...
# Parameters
- `τ::AbstractFloat = 1e-6`: Numerical tolerance for zero gradient
...
"""
struct GradientThreshold{T <: AbstractFloat} <: AbstractTerminationCriterion
    parameters::GradientThresholdParameters{T}

    function GradientThreshold(::Type{T}; kw...) where T <: AbstractFloat
        return new{T}(GradientThresholdParameters{T}(; kw...))
    end
end

function Progress(termination::GradientThreshold, str::AbstractString)
    @unpack τ = termination.parameters
    return ProgressThresh(τ, 0.0, str)
end

function progress_value(::GradientThreshold, k::Integer, f::AbstractFloat, ∇f_norm::AbstractFloat)
    return ∇f_norm
end

function terminate(termination::GradientThreshold, k::Integer, f::Float64, x::AbstractVector, ∇f::AbstractVector)
    return norm(∇f) <= termination.τ
end

# API
# ------------------------------------------------------------
"""
    AtGradientThreshold

Factory object for [`GradientThreshold`](@ref). Pass to `terminate` in `Quasigradient.Optimizer` or set the [`Termination`](@ref) attribute. See ?GradientThreshold for parameter descriptions.

"""
mutable struct AtGradientThreshold <: AbstractTermination
    parameters::GradientThresholdParameters{Float64}
end
AtGradientThreshold(τ::AbstractFloat) = AtGradientThreshold(GradientThresholdParameters(; τ = Float64(τ)))
AtGradientThreshold(; kw...) = AtGradientThreshold(GradientThresholdParameters(; kw...))

function (criteria::AtGradientThreshold)(::Type{T}) where T <: AbstractFloat
    return GradientThreshold(T; type2dict(criteria.parameters)...)
end
