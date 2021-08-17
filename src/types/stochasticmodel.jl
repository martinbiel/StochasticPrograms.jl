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
    StochasticModel

A mathematical model of a stochastic optimization problem.
"""
struct StochasticModel{N, P <: NTuple{N, StageParameters}}
    parameters::P
    generator::Function
    optimizer::StochasticProgramOptimizer

    function StochasticModel(generator::Function,
                             parameters::Vararg{StageParameters,N}) where N
        return new{N,typeof(parameters)}(parameters, generator, StochasticProgramOptimizer(nothing))
    end
end
num_stages(::StochasticModel{N}) where N = N

# Printing #
# ========================== #
function Base.show(io::IO, stochasticmodel::StochasticModel)
    println(io, "Multi-stage Stochastic Model")
end
function Base.show(io::IO, stochasticmodel::StochasticModel{2})
    modelstr = "minimize f₀(x) + 𝔼[f(x,ξ)]
  x∈𝒳

where

f(x,ξ) = min  f(y; x, ξ)
              y ∈ 𝒴 (x, ξ)"
    print(io, "Two-Stage Stochastic Model\n\n")
    println(io, modelstr)
end

# Getters #
# ========================== #
"""
    optimal_instance(stochasticmodel::StochasticModel)

Return a stochastic programming instance of the stochastic model after a call to [`optimize!`](@ref).
"""
function optimal_instance(stochasticmodel::StochasticModel)
    # Sanity checks
    check_provided_optimizer(stochasticmodel.optimizer)
    if MOI.get(stochasticmodel, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
        throw(OptimizeNotCalled())
    end
    return optimal_instance(optimizer(stochasticmodel))
end

# MOI #
# ========================== #
function MOI.get(stochasticmodel::StochasticModel, attr::Union{MOI.TerminationStatus, MOI.PrimalStatus, MOI.DualStatus})
    return MOI.get(optimizer(stochasticmodel), attr)
end
function MOI.get(stochasticmodel::StochasticModel, attr::MOI.AbstractModelAttribute)
    if MOI.is_set_by_optimize(attr)
        check_provided_optimizer(stochasticmodel.optimizer)
        if MOI.get(stochasticmodel, MOI.TerminationStatus()) == MOI.OPTIMIZE_NOT_CALLED
            throw(OptimizeNotCalled())
        end
    end
    return MOI.get(optimizer(stochasticmodel), attr)
end
function MOI.get(stochasticmodel::StochasticModel, attr::MOI.AbstractOptimizerAttribute)
    MOI.get(optimizer(stochasticmodel), attr)
end

MOI.set(sp::StochasticModel, attr::MOI.AbstractOptimizerAttribute, value) = MOI.set(optimizer(sp), attr, value)
MOI.set(sp::StochasticModel, attr::MOI.AbstractModelAttribute, value) = MOI.set(optimizer(sp), attr, value)
