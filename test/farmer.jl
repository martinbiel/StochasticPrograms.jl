using StochasticPrograms
using JuMP

CROPS = [:wheat,:corn,:beets]
PURCHASE = [:wheat,:corn]
SELL = [:wheat,:corn,:beets_quota,:beets_extra]

C = Dict(:wheat=>150,:corn=>230,:beets=>260)
REQ = Dict(:wheat=>200,:corn=>240,:beets=>0)
P = Dict(:wheat=>238,:corn=>210)
S = Dict(:wheat=>170,:corn=>150,:beets_quota=>36,:beets_extra=>10)
B = 500

struct FarmerScenario <: AbstractScenarioData
    Y::Dict{Symbol,Float64}
end
StochasticPrograms.probability(::FarmerScenario) = 1/3

function StochasticPrograms.expected(sds::Vector{FarmerScenario})
    sd = FarmerScenario(Dict(:wheat=>sum([probability(s)*s.Y[:wheat] for s in sds]),
                             :corn=>sum([probability(s)*s.Y[:corn] for s in sds]),
                             :beets=>sum([probability(s)*s.Y[:beets] for s in sds])))
end

s1 = FarmerScenario(Dict(:wheat=>3.0,:corn=>3.6,:beets=>24.0))
s2 = FarmerScenario(Dict(:wheat=>2.5,:corn=>3.0,:beets=>20.0))
s3 = FarmerScenario(Dict(:wheat=>2.0,:corn=>2.4,:beets=>16.0))

sp = StochasticProgram([s1,s2,s3],solver=ClpSolver())

@first_stage sp = begin
    @variable(model, x[c = CROPS] >= 0)
    @objective(model, Min, sum(C[c]*x[c] for c in CROPS))
    @constraint(model, sum(x[c] for c in CROPS) <= B)
end

@second_stage sp = begin
    @decision x
    s = scenario
    @variable(model, y[p = PURCHASE] >= 0)
    @variable(model, w[s = SELL] >= 0)
    @objective(model, Min, sum( P[p] * y[p] for p = PURCHASE) - sum( S[s] * w[s] for s in SELL))

    @constraint(model, const_minreq[p=PURCHASE],
                   s.Y[p] * x[p] + y[p] - w[p] >= REQ[p])
    @constraint(model, const_minreq_beets,
                   s.Y[:beets] * x[:beets] - w[:beets_quota] - w[:beets_extra] >= REQ[:beets])
    @constraint(model, const_aux, w[:beets_quota] <= 6000)
end

res = SPResult([170,80,250],-108390,7015.56,1150,-118600,-107240)
push!(problems,(sp,res,"Farmer"))
