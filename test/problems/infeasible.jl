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

@stochastic_model infeasible begin
    @stage 1 begin
        @decision(infeasible, x₁ >= 0)
        @decision(infeasible, x₂ >= 0)
        @objective(infeasible, Min, 3*x₁ + 2*x₂)
    end
    @stage 2 begin
        @uncertain ξ₁ ξ₂
        @recourse(infeasible, 0.8*ξ₁ <= y₁ <= ξ₁)
        @recourse(infeasible, 0.8*ξ₂ <= y₂ <= ξ₂)
        @objective(infeasible, Min, -15*y₁ - 12*y₂)
        @constraint(infeasible, 3*y₁ + 2*y₂ <= x₁)
        @constraint(infeasible, 2*y₁ + 5*y₂ <= x₂)
    end
end

ξ₁ = @scenario ξ₁ = 6. ξ₂ = 8. probability = 0.5
ξ₂ = @scenario ξ₁ = 4. ξ₂ = 4. probability = 0.5

infeasible_res = SPResult([27.2,41.6], Dict(1 => [4.8, 6.4], 2 => [4., 4.]), 36.4, 9.2, 27.2, Inf, 9.2, Inf)
push!(problems, (infeasible, [ξ₁,ξ₂], infeasible_res, "Infeasible"))
