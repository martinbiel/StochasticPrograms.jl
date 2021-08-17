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

@define_scenario SimpleScenario = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end

ξ₁ = SimpleScenario(24.0, 28.0, 500.0, 100.0, probability = 0.4)
ξ₂ = SimpleScenario(28.0, 32.0, 300.0, 300.0, probability = 0.6)

simple_sp = StochasticProgram([ξ₁, ξ₂], Deterministic(), GLPK.Optimizer)

@first_stage simple_sp = begin
    @decision(simple_sp, x₁ >= 40)
    @decision(simple_sp, x₂ >= 20)
    @objective(simple_sp, Min, 100*x₁ + 150*x₂)
    @constraint(simple_sp, x₁ + x₂ <= 120)
end

@second_stage simple_sp = begin
    @known(simple_sp, x₁, x₂)
    @uncertain q₁ q₂ d₁ d₂ from SimpleScenario
    @recourse(simple_sp, 0 <= y₁ <= d₁)
    @recourse(simple_sp, 0 <= y₂ <= d₂)
    @objective(simple_sp, Max, q₁*y₁ + q₂*y₂)
    @constraint(simple_sp, 6*y₁ + 10*y₂ <= 60*x₁)
    @constraint(simple_sp, 8*y₁ + 5*y₂ <= 80*x₂)
end
