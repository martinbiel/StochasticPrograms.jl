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
