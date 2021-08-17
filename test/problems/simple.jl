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

@stochastic_model simple begin
    @stage 1 begin
        @decision(simple, x₁ >= 40)
        @decision(simple, x₂ >= 20)
        objective = @expression(simple, 100*x₁ + 150*x₂)
        @objective(simple, Min, objective)
        @constraint(simple, x₁ + x₂ <= 120)
    end
    @stage 2 begin
        @uncertain q₁ q₂ d₁ d₂
        @recourse(simple, 0 <= y₁ <= d₁)
        @recourse(simple, 0 <= y₂ <= d₂)
        @objective(simple, Max, q₁*y₁ + q₂*y₂)
        @constraint(simple, 6*y₁ + 10*y₂ <= 60*x₁)
        @constraint(simple, 8*y₁ + 5*y₂ <= 80*x₂)
    end
end

ξ₁ = @scenario q₁ = 24.0 q₂ = 28.0 d₁ = 500.0 d₂ = 100.0 probability = 0.4
ξ₂ = @scenario q₁ = 28.0 q₂ = 32.0 d₁ = 300.0 d₂ = 300.0 probability = 0.6

simple_res = SPResult([46.67, 36.25], Dict(1 => [300., 100.], 2 => [300., 100.]), -855.83, -1518.75, 662.92, 286.92, -1445.92, -568.92)
push!(problems, (simple, [ξ₁,ξ₂], simple_res, "Simple"))
