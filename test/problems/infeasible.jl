s₁ = Scenario(ξ₁ = 6., ξ₂ = 8., probability = 0.5)
s₂ = Scenario(ξ₁ = 4., ξ₂ = 4., probability = 0.5)

infeasible = StochasticProgram([s₁,s₂], optimizer = GLPK.Optimizer)

@first_stage infeasible = begin
    @variable(model, x₁ >= 0)
    @variable(model, x₂ >= 0)
    @objective(model, Min, 3*x₁ + 2*x₂)
end

@second_stage infeasible = begin
    @decision x₁ x₂
    @uncertain ξ₁ ξ₂
    @variable(model, 0.8*ξ₁ <= y₁ <= ξ₁)
    @variable(model, 0.8*ξ₂ <= y₂ <= ξ₂)
    @objective(model, Min, -15*y₁ - 12*y₂)
    @constraint(model, 3*y₁ + 2*y₂ <= x₁)
    @constraint(model, 2*y₁ + 5*y₂ <= x₂)
end

infeasible_res = SPResult([27.2,41.6], 36.4, 9.2, 27.2, Inf, 9.2, Inf)
push!(problems, (infeasible, infeasible_res, "Infeasible"))
