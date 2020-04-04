sm = @stochastic_model begin
    @stage 1 begin
        @decision(model, x¹ <= 2)
        @decision(model, w¹)
        @decision(model, y¹)
        @objective(model, Min, 100*x¹ + 3*w¹ + 0.5*y¹)
        @constraint(model, x¹ + w¹ - y¹ == 1)
    end
    @stage 2 begin
        @uncertain d
        @variable(model, x² <= 2)
        @variable(model, w²)
        @decision(model, y²)
        @objective(model, Min, x² + 3*w² + 0.5*y²)
        @constraint(model, y¹ + x² + w² - y² == d)
    end
    @stage 3 begin
        @uncertain d
        @variable(model, x³ <= 2)
        @variable(model, w³)
        @variable(model, y³)
        @objective(model, Min, x³ + 3*w³)
        @constraint(model, y² + x³ + w³ - y³ == d)
    end
end
s₂₁ = Scenario(d = 1.0, probability = 0.5)
s₂₂ = Scenario(d = 3.0, probability = 0.5)

s₃₁ = Scenario(d = 1.0, probability = 0.25)
s₃₂ = Scenario(d = 3.0, probability = 0.25)
s₃₃ = Scenario(d = 1.0, probability = 0.25)
s₃₄ = Scenario(d = 3.0, probability = 0.25)

sp = instantiate(sm, ([s₂₁,s₂₂], [s₃₁,s₃₂,s₃₃,s₃₄]))
