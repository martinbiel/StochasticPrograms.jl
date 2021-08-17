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

abstract type AbstractTerminationCriterion end
abstract type AbstractTermination end

terminate(quasigradient::AbstractQuasiGradient, k::Integer, f::Float64, x::AbstractVector, ∇f::AbstractVector) = terminate(quasigradient.criterion, k, f, x, ∇f)

"""
    RawTerminationParameter

An optimizer attribute used for raw parameters of the termination criterion. Defers to `RawParameter`.
"""
struct RawTerminationParameter <: TerminationParameter
    name::Any
end

function MOI.get(termination::AbstractTermination, param::RawTerminationParameter)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(termination.parameters)))
        error("Unrecognized parameter name: $(name) for termination $(typeof(termination)).")
    end
    return getfield(termination.parameters, name)
end

function MOI.set(termination::AbstractTermination, param::RawTerminationParameter, value)
    name = Symbol(param.name)
    if !(name in fieldnames(typeof(termination.parameters)))
        error("Unrecognized parameter name: $(name) for termination $(typeof(termination)).")
    end
    setfield!(termination.parameters, name, value)
    return nothing
end

include("iteration.jl")
include("objective.jl")
include("gradient.jl")
