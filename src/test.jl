using StochasticPrograms
using JuMP

struct SData <: AbstractScenarioData
    π::Float64
    d::Vector{Float64}
    q::Vector{Float64}
end

function StochasticPrograms.expected(sds::Vector{SData})
    sd = SData(1,sum([s.π*s.d for s in sds]),sum([s.π*s.q for s in sds]))
end

s1 = SData(0.4,[500.0,100],[-24.0,-28])
s2 = SData(0.6,[300.0,300],[-28.0,-32])

sds = [s1,s2]

sp = StochasticProgram(sds)

@first_stage sp = begin
    @variable(model, x1 >= 40)
    @variable(model, x2 >= 20)
    @objective(model, Min, 100*x1 + 150*x2)
    @constraint(model, x1+x2 <= 120)
end

@second_stage sp = begin
    @decision x1 x2
    s = scenario
    @variable(model, 0 <= y1 <= s.d[1])
    @variable(model, 0 <= y2 <= s.d[2])
    @objective(model, Min, s.q[1]*y1 + s.q[2]*y2)
    @constraint(model, 6*y1 + 10*y2 <= 60*x1)
    @constraint(model, 8*y1 + 5*y2 <= 80*x2)
end
