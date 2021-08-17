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

@stochastic_model integer begin
    @stage 1 begin
        @decision(integer, x₁, Bin)
        @decision(integer, x₂, Bin)
        @objective(integer, Max, 6*x₁ + 4*x₂)
    end
    @stage 2 begin
        @uncertain T₁ T₂ h
        @recourse(integer, y₁, Bin)
        @recourse(integer, y₂, Bin)
        @recourse(integer, y₃, Bin)
        @recourse(integer, y₄, Bin)
        @objective(integer, Max, 3*y₁ + 7*y₂ + 9*y₃ + 6*y₄)
        @constraint(integer, 2*y₁ + 4*y₂ + 5*y₃ + 3*y₄ <= h - T₁*x₁ - T₂*x₂)
    end
end

ξ₁ = @scenario T₁ = 2. T₂ = 4. h = 10. probability = 0.25
ξ₂ = @scenario T₁ = 4. T₂ = 3. h = 15. probability = 0.75
