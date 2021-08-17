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

struct SPResult
    x̄::Vector{Float64}
    ȳ::Dict{Int, Vector{Float64}}
    VRP::Float64
    EWS::Float64
    EVPI::Float64
    VSS::Float64
    EV::Float64
    EEV::Float64
end

problems = Vector{Tuple{StochasticModel,Vector{<:AbstractScenario},SPResult,String}}()
@info "Loading test problems..."
@info "Loading simple..."
include("simple.jl")
@info "Loading instant simple..."
include("instant_simple.jl")
@info "Loading vectorized simple..."
include("vectorized_simple.jl")
@info "Loading infeasible..."
include("infeasible.jl")
@info "Loading vectorized infeasible..."
include("vectorized_infeasible.jl")
@info "Loading farmer..."
include("farmer.jl")
@info "Loading sampler..."
include("sampler.jl")
@info "Test problems loaded. Starting test sequence."
