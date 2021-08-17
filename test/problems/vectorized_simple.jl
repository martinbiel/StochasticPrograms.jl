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

@stochastic_model vec_simple begin
    @stage 1 begin
        @parameters begin
            lb = [40.0, 20.0]
            c  = [100., 150.]
            A  = [1. 1.]
            b  = [120.]
        end
        @decision(vec_simple, x[i in 1:2] >= lb[i])
        @objective(vec_simple, Min, dot(c, x))
        @constraint(vec_simple, A * x - b in MOI.Nonpositives(1))
    end
    @stage 2 begin
        @parameters begin
            lb = [0., 0.]
            T  = [-60. 0.;
                  0.  -80.]
            W  = [6. 10.;
                  8. 5.]
        end
        @uncertain ξ[1:4]
        q  = [ξ[1], ξ[2]]
        ub = [ξ[3], ξ[4]]
        @recourse(vec_simple, lb[i] <= y[i in 1:2] <= ub[i])
        @objective(vec_simple, Max, dot(q, y))
        @constraint(vec_simple, T * x + W * y in MOI.Nonpositives(2))
    end
end

ξ₁ = @scenario ξ[1:4] = [24.0, 28.0, 500.0, 100.0] probability = 0.4
ξ₂ = @scenario ξ[1:4] = [28.0, 32.0, 300.0, 300.0] probability = 0.6

vec_simple_res = SPResult([46.67, 36.25], Dict(1 => [300., 100.], 2 => [300., 100.]), -855.83, -1518.75, 662.92, 286.92, -1445.92, -568.92)
push!(problems, (vec_simple, [ξ₁,ξ₂], vec_simple_res, "Vectorized Simple"))
