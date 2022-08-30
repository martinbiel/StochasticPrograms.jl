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

abstract type AbstractRegularization end
abstract type AbstractRegularizer end
# Regularization API #
# ------------------------------------------------------------
initialize_regularization!(lshaped::AbstractLShaped) = initialize_regularization!(lshaped, lshaped.regularization)
restore_regularized_master!(lshaped::AbstractLShaped) = restore_regularized_master!(lshaped, lshaped.regularization)
filter_variables!(lshaped::AbstractLShaped, list) = filter_variables!(lshaped.regularization, list)
filter_constraints!(lshaped::AbstractLShaped, list) = filter_constraints!(lshaped.regularization, list)
log_regularization!(lshaped::AbstractLShaped) = log_regularization!(lshaped, lshaped.regularization)
log_regularization!(lshaped::AbstractLShaped, t::Integer) = log_regularization!(lshaped, t, lshaped.regularization)
take_step!(lshaped::AbstractLShaped) = take_step!(lshaped, lshaped.regularization)
decision(lshaped::AbstractLShaped) = decision(lshaped, lshaped.regularization)
objective_value(lshaped::AbstractLShaped) = objective_value(lshaped, lshaped.regularization)
gap(lshaped::AbstractLShaped) = gap(lshaped, lshaped.regularization)
process_cut!(lshaped::AbstractLShaped, cut::AbstractHyperPlane) = process_cut!(lshaped, cut, lshaped.regularization)
# ------------------------------------------------------------
# Attributes #
# ------------------------------------------------------------
"""
    RawRegularizationParameter

An optimizer attribute used for raw parameters of the regularizer. Defers to `RawOptimizerAttribute`.
"""
struct RawRegularizationParameter <: RegularizationParameter
    name::Any
end
"""
    RegularizationPenaltyTerm

An optimizer attribute used to set the proximal term in regulariztion procedures (RD/LV). Options are:

- [`Quadratic`](@ref) (default)
- [`Linearized`](@ref)
- [`InfNorm`](@ref)
- [`ManhattanNorm`](@ref)
"""
struct RegularizationPenaltyTerm <: RegularizationParameter end

include("common.jl")
include("no_regularization.jl")
include("rd.jl")
include("tr.jl")
include("lv.jl")
