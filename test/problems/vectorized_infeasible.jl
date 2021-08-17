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

@stochastic_model vec_infeasible begin
    @stage 1 begin
        @parameters begin
            lb = zeros(2)
            c  = [3., 2.]
        end
        @decision(vec_infeasible, x[i in 1:2] >= lb[i])
        @objective(vec_infeasible, Min, dot(c, x))
    end
    @stage 2 begin
        @parameters begin
            q = [-15., -12.]
            T = [-1. 0;
                  0  -1.]
            W = [3. 2.;
                 2. 5.]
        end
        @uncertain ξ[1:2]
        @recourse(vec_infeasible, 0.8 * ξ[i] <= y[i in 1:2] <= ξ[i])
        @objective(vec_infeasible, Min, dot(q, y))
        @constraint(vec_infeasible, T * x + W * y in MOI.Nonpositives(2))
    end
end

ξ₁ = @scenario ξ[1:2] = [6., 8.] probability = 0.5
ξ₂ = @scenario ξ[1:2] = [4., 4.] probability = 0.5

vec_infeasible_res = SPResult([27.2,41.6], Dict(1 => [4.8, 6.4], 2 => [4., 4.]), 36.4, 9.2, 27.2, Inf, 9.2, Inf)
push!(problems, (vec_infeasible, [ξ₁,ξ₂], vec_infeasible_res, "Vectorized Infeasible"))
