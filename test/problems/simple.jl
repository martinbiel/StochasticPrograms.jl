simple = @stochastic_model begin
    @stage 1 begin
        @decision(model, x₁ >= 40)
        @decision(model, x₂ >= 20)
        objective = @expression(model, 100*x₁ + 150*x₂)
        @objective(model, Min, objective)
        @constraint(model, x₁ + x₂ <= 120)
    end
    @stage 2 begin
        @uncertain q₁ q₂ d₁ d₂
        @recourse(model, 0 <= y₁ <= d₁)
        @recourse(model, 0 <= y₂ <= d₂)
        @objective(model, Max, q₁*y₁ + q₂*y₂)
        @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
        @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
    end
end

ξ₁ = @scenario q₁ = 24.0 q₂ = 28.0 d₁ = 500.0 d₂ = 100.0 probability = 0.4
ξ₂ = @scenario q₁ = 28.0 q₂ = 32.0 d₁ = 300.0 d₂ = 300.0 probability = 0.6

simple_res = SPResult([46.67, 36.25], Dict(1 => [300., 100.], 2 => [300., 100.]), -855.83, -1518.75, 662.92, 286.92, -1445.92, -568.92)
push!(problems, (simple, [ξ₁,ξ₂], simple_res, "Simple"))
