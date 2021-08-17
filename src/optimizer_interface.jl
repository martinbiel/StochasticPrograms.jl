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

# Structured optimizer interface
# ========================== #
"""
    supports_structure(optimizer::StochasticProgramOptimizerType, structure::AbstractStochasticStructure)

Return a `Bool` indicating whether `optimizer` supports the stochastic `structure`. That is, `load_structure!(optimizer, structure)` will not throw `UnsupportedStructure`
"""
function supports_structure(optimizer::StochasticProgramOptimizerType, structure::AbstractStochasticStructure)
    return false
end
"""
    check_loadable(optimizer::AbstractStructuredOptimizer, structure::AbstractStochasticStructure)

Throws an `UnloadableStructure` exception if `structure` is not loadable by `optimizer`.

    See also: [`load_structure!`](@ref)
"""
function check_loadable end
"""
    load_structure!(optimizer::AbstractStructuredOptimizer, structure::AbstractStochasticStructure, x₀::AbstractVector)

Instantiate the `optimizer` with the stochastic program represented in memory by the given `structure` and initial decision `x₀`.

See also: [`optimize!`](@ref)
"""
function load_structure! end
"""
    restore_structure!(optimizer::AbstractStructuredOptimizer)

Restore the stochastic program to the state it was in before a call to `optimize!`

See also: [`load_structure!`](@ref)
"""
function restore_structure! end
"""
    optimize!(optimizer::AbstractStructuredOptimizer)

Start the solution procedure for `optimizer` after a call to [`load_structure!`](@ref).

See also: [`load_structure!`](@ref)
"""
function optimize! end
"""
    optimizer_name(optimizer::AbstractStructuredOptimizer)

Optionally, return a string identifier of `AbstractStructuredOptimizer`.
"""
function optimizer_name(::AbstractStructuredOptimizer)
    return "SolverName() attribute not implemented by the optimizer."
end
"""
    master_optimizer(optimizer::AbstractStructuredOptimizer)

Return a MOI optimizer constructor
"""
function master_optimizer end
"""
   subproblem_optimizer(optimizer::AbstractStructuredOptimizer)

Return a MOI optimizer constructor for solving subproblems
"""
function subproblem_optimizer end
"""
    num_iterations(optimizer::AbstractStructuredOptimizer)

Return the number of iterations ran by the structured optimizer

See also: [`optimize!`](@ref)
"""
function num_iterations end
# Sample-based solver interface
# ========================== #
"""
    load_model!(optimizer::AbstractSampledOptimizer, model::StochasticModel, x₀::AbstractVector)

Instantiate the `optimizer` with the stochastic model and initial decision `x₀`.

See also: [`optimize!`](@ref)
"""
function load_model! end
"""
    optimizer_name(optimizer::AbstractSampledOptimizer)

Optionally, return a string identifier of `AbstractSampledOptimizer`.
"""
function optimizer_name(::AbstractSampledOptimizer)
    return "SolverName() attribute not implemented by the optimizer."
end
"""
    optimal_instance(optimizer::AbstractSampledOptimizer)

Return a stochastic programming instance of the stochastic model after a call to [`optimize!`](@ref).
"""
function optimal_instance end
