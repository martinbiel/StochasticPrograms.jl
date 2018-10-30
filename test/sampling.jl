@everywhere begin
    struct SimpleSampler <: AbstractSampler{SimpleScenario} end

    function (sampler::SimpleSampler)()
        return SimpleScenario(rand(), [500.0,100]+(2*rand()-1)*[50.,50], [-24.0,-28].+(2*rand()-1))
    end
end

sampled_sp = StochasticProgram(SimpleSampler(), solver=GLPKSolverLP())

@first_stage sampled_sp = begin
    @variable(model, x₁ >= 40)
    @variable(model, x₂ >= 20)
    @objective(model, Min, 100*x₁ + 150*x₂)
    @constraint(model, x₁+x₂ <= 120)
end

@second_stage sampled_sp = begin
    @decision x₁ x₂
    s = scenario
    @variable(model, 0 <= y₁ <= s.d[1])
    @variable(model, 0 <= y₂ <= s.d[2])
    @objective(model, Min, s.q[1]*y₁ + s.q[2]*y₂)
    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
end
