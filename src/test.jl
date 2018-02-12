using StochasticPrograms
using JuMP

struct SData <: StochasticPrograms.AbstractScenarioData
    π::Float64
    d::Float64
end

function expected(sds::Vector{SData})
    sd = SData(1,sum([s.π*s.d for s in sds]))
end

s1 = SData(0.25,3)
s2 = SData(0.25,2)
s3 = SData(0.25,6)
s4 = SData(0.25,8)

sds = [s1,s2,s3,s4]

sp = StochasticProgram(sds)

@define_subproblem sp = begin
    @variable(model, y)
    @constraint(model, y <= scenario.d)
end
