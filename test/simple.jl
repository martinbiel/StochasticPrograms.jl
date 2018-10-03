@everywhere begin
    struct SimpleScenario <: AbstractScenarioData
        π::Probability
        d::Vector{Float64}
        q::Vector{Float64}
    end

    function StochasticPrograms.expected(scenarios::Vector{SimpleScenario})
        isempty(scenarios) && return SimpleScenario(1.,zeros(2),zeros(2))
        return SimpleScenario(1.,sum([s.π*s.d for s in scenarios]),sum([s.π*s.q for s in scenarios]))
    end
end

s1 = SimpleScenario(0.4,[500.0,100],[-24.0,-28])
s2 = SimpleScenario(0.6,[300.0,300],[-28.0,-32])

sds = [s1,s2]

simple = StochasticProgram(sds,solver=GLPKSolverLP())

@first_stage simple = begin
    @variable(model, x₁ >= 40)
    @variable(model, x₂ >= 20)
    @objective(model, Min, 100*x₁ + 150*x₂)
    @constraint(model, x₁+x₂ <= 120)
end

@second_stage simple = begin
    @decision x₁ x₂
    s = scenario
    @variable(model, 0 <= y₁ <= s.d[1])
    @variable(model, 0 <= y₂ <= s.d[2])
    @objective(model, Min, s.q[1]*y₁ + s.q[2]*y₂)
    @constraint(model, 6*y₁ + 10*y₂ <= 60*x₁)
    @constraint(model, 8*y₁ + 5*y₂ <= 80*x₂)
end

simple_res = SPResult([46.67,36.25],-855.83,-1518.75,662.92,286.92,-1445.92,-568.92)
push!(problems,(simple,simple_res,"Simple"))
