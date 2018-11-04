Crops = [:wheat,:corn,:beets]
Purchased = [:wheat,:corn]
Sold = [:wheat,:corn,:beets_quota,:beets_extra]

Cost = Dict(:wheat=>150,:corn=>230,:beets=>260)
Required = Dict(:wheat=>200,:corn=>240,:beets=>0)
PurchasePrice = Dict(:wheat=>238,:corn=>210)
SellPrice = Dict(:wheat=>170,:corn=>150,:beets_quota=>36,:beets_extra=>10)
Budget = 500

@scenario Farmer = begin
    Yield::Dict{Symbol, Float64}

    @zero begin
        return FarmerScenario(Dict(:wheat=>0.,:corn=>0.,:beets=>0.))
    end

    @expectation begin
        return FarmerScenario(Dict(:wheat=>sum([probability(s)*s.Yield[:wheat] for s in scenarios]),
                                   :corn=>sum([probability(s)*s.Yield[:corn] for s in scenarios]),
                                   :beets=>sum([probability(s)*s.Yield[:beets] for s in scenarios])))
    end
end

s₁ = FarmerScenario(Dict(:wheat=>3.0,:corn=>3.6,:beets=>24.0), probability = 1/3)
s₂ = FarmerScenario(Dict(:wheat=>2.5,:corn=>3.0,:beets=>20.0), probability = 1/3)
s₃ = FarmerScenario(Dict(:wheat=>2.0,:corn=>2.4,:beets=>16.0), probability = 1/3)

farmer = StochasticProgram((Crops,Cost,Budget), (Required,PurchasePrice,SellPrice), [s₁,s₂,s₃], solver=GLPKSolverLP())

@first_stage farmer = begin
    (Crops,Cost,Budget) = stage
    @variable(model, x[c = Crops] >= 0)
    @objective(model, Min, sum(Cost[c]*x[c] for c in Crops))
    @constraint(model, sum(x[c] for c in Crops) <= Budget)
end

@second_stage farmer = begin
    @decision x
    (Required, PurchasePrice, SellPrice) = stage
    @variable(model, y[p = Purchased] >= 0)
    @variable(model, w[s = Sold] >= 0)
    @objective(model, Min, sum( PurchasePrice[p] * y[p] for p = Purchased) - sum( SellPrice[s] * w[s] for s in Sold))

    @constraint(model, const_minreq[p=Purchased],
                   scenario.Yield[p] * x[p] + y[p] - w[p] >= Required[p])
    @constraint(model, const_minreq_beets,
                   scenario.Yield[:beets] * x[:beets] - w[:beets_quota] - w[:beets_extra] >= Required[:beets])
    @constraint(model, const_aux, w[:beets_quota] <= 6000)
end

farmer_res = SPResult([170,80,250], -108390, -115405.56, 7015.56, 1150, -118600, -107240)
push!(problems, (farmer,farmer_res,"Farmer"))
