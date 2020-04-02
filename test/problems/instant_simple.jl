@scenario SimpleScenario = begin
    q₁::Float64
    q₂::Float64
    d₁::Float64
    d₂::Float64
end

ξ₁ = SimpleScenario(-24.0, -28.0, 500.0, 100.0, probability = 0.4)
ξ₂ = SimpleScenario(-28.0, -32.0, 300.0, 300.0, probability = 0.6)

sp = StochasticProgram([ξ₁, ξ₂], optimizer = GLPK.Optimizer)

@first_stage sp = begin
    @variable(model, x₁ >= 40)
    @variable(model, x₂ >= 20)
    @objective(model, Min, 100*x₁ + 150*x₂)
    @constraint(model, x₁ + x₂ <= 120)
end

@second_stage sp = begin
    @decision x₁ x₂
    @uncertain q₁ q₂ d₁ d₂ from SimpleScenario
    @variable(model, 0 <= y₁ <= d₁)
    @variable(model, 0 <= y₂ <= d₂)
    @objective(model, Min, q₁*y₁ + q₂*y₂)
    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
end

#simple_res = SPResult([46.67,36.25], -855.83, -1518.75, 662.92, 286.92, -1445.92, -568.92)
#push!(problems, (simple, simple_res, "Instant simple"))
