farmer_model = @stochastic_model begin
    @stage 1 begin
        @parameters begin
            Crops = [:wheat, :corn, :beets]
            Cost = Dict(:wheat=>150, :corn=>230, :beets=>260)
            Budget = 500
        end
        @variable(model, x[c = Crops] >= 0)
        @objective(model, Min, sum(Cost[c]*x[c] for c in Crops))
        @constraint(model, sum(x[c] for c in Crops) <= Budget)
    end
    @stage 2 begin
        @decision x
        @parameters begin
            Purchased  = [:wheat, :corn]
            Sold = [:wheat, :corn, :bquota, :bextra]
            Required = Dict(:wheat=>200, :corn=>240, :beets=>0)
            PurchasePrice = Dict(:wheat=>238, :corn=>210)
            SellPrice = Dict(:wheat=>170, :corn=>150, :bquota=>36, :bextra=>10)
        end
        @uncertain ξ::YieldScenario = begin
            wheat::Float64
            corn::Float64
            beets::Float64
        end
        @variable(model, y[p = Purchased] >= 0)
        @variable(model, w[s = Sold] >= 0)
        @objective(model, Min, sum( PurchasePrice[p] * y[p] for p = Purchased) - sum( SellPrice[s] * w[s] for s in Sold))

        @constraint(model, const_minreq[p=Purchased],
            ξ[p] * x[p] + y[p] - w[p] >= Required[p])
        @constraint(model, const_minreq_beets,
            ξ[:beets] * x[:beets] - w[:bquota] - w[:bextra] >= Required[:beets])
        @constraint(model, const_aux, w[:bquota] <= 6000)
    end
end

ξ₁ = YieldScenario(3.0, 3.6, 24.0, probability = 1/3)
ξ₂ = YieldScenario(2.5, 3.0, 20.0, probability = 1/3)
ξ₃ = YieldScenario(2.0, 2.4, 16.0, probability = 1/3)

farmer = instantiate(farmer_model, [ξ₁,ξ₂,ξ₃], solver=GLPKSolverLP())

farmer_res = SPResult([170,80,250], -108390, -115405.56, 7015.56, 1150, -118600, -107240)
push!(problems, (farmer,farmer_res,"Farmer"))
