@sampler Simple = begin
    @sample begin
        return SimpleScenario(-24.0 + randn(), -28.0 + randn(), 500.0 + randn(), 100 + randn(), probability = rand())
    end
end

sampled_sp = StochasticProgram(SimpleScenario, solver=GLPKSolverLP())

@first_stage sampled_sp = begin
    @variable(model, x₁ >= 40)
    @variable(model, x₂ >= 20)
    @objective(model, Min, 100*x₁ + 150*x₂)
    @constraint(model, x₁ + x₂ <= 120)
end

@second_stage sampled_sp = begin
    @decision x₁ x₂
    ξ = scenario
    @variable(model, 0 <= y₁ <= ξ.d₁)
    @variable(model, 0 <= y₂ <= ξ.d₂)
    @objective(model, Min, ξ.q₁*y₁ + ξ.q₂*y₂)
    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
end
