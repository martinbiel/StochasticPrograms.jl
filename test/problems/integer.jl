simple = @stochastic_model begin
    @stage 1 begin
        @decision(model, x₁, Bin)
        @decision(model, x₂, Bin)
        @objective(model, Max, 6*x₁ + 4*x₂)
    end
    @stage 2 begin
        @uncertain T₁ T₂ h
        @recourse(model, y₁, Bin)
        @recourse(model, y₂, Bin)
        @recourse(model, y₃, Bin)
        @recourse(model, y₄, Bin)
        @objective(model, Max, 3*y₁ + 7*y₂ + 9*y₃ + 6*y₄)
        @constraint(model, 2*y₁ + 4*y₂ + 5*y₃ + 3*y₄ <= h - T₁*x₁ - T₂*x₂)
    end
end

ξ₁ = @scenario T₁ = 2. T₂ = 4. h = 10. probability = 0.25
ξ₂ = @scenario T₁ = 4. T₂ = 3. h = 15. probability = 0.75
