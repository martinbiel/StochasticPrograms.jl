simple_model = @stochastic_model begin
    @stage 1 begin
        @decision(model, x₁ >= 40)
        @decision(model, x₂ >= 20)
        @objective(model, Min, 100*x₁ + 150*x₂)
        @constraint(model, x₁ + x₂ <= 120)
    end
    @stage 2 begin
        @uncertain q₁ q₂ d₁ d₂
        @decision(model, y₁ >= 0)
        @decision(model, y₂ >= 0)
        @objective(model, Min, q₁*y₁ + q₂*y₂)
        @constraint(model, y₁ <= d₁)
        @constraint(model, y₂ <= d₂)
        @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
        @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
    end
end

ξ₁ = Scenario(q₁ = -24.0, q₂ = -28.0, d₁ = 500.0, d₂ = 100.0, probability = 0.4)
ξ₂ = Scenario(q₁ = -28.0, q₂ = -32.0, d₁ = 300.0, d₂ = 300.0, probability = 0.6)
simple = instantiate(simple_model, [ξ₁,ξ₂], optimizer = GLPK.Optimizer)

simple_res = SPResult([46.67,36.25], -855.83, -1518.75, 662.92, 286.92, -1445.92, -568.92)
push!(problems, (simple, simple_res, "Simple"))
