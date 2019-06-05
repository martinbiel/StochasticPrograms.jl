# Examples

## Farmer problem

The following defines the well-known "Farmer problem", first outlined in [Introduction to Stochastic Programming](https://link.springer.com/book/10.1007%2F978-1-4614-0237-4), in StochasticPrograms. The problem revolves around a farmer who needs to decide how to partition his land to sow three different crops. The uncertainty comes from not knowing what the future yield of each crop will be. Recourse decisions involve purchasing/selling crops at the market.

```@example farmer
using StochasticPrograms
using GLPKMathProgInterface
```
We begin by introducing some variable indices:
```@example farmer
Crops = [:wheat, :corn, :beets];
Purchased = [:wheat, :corn];
Sold = [:wheat, :corn, :beets_quota, :beets_extra];
```
The price of beets drops after a certain quantity (6000), so we introduce an extra variable to handle the excess beets. Using the variable indices, we define the deterministic problem parameters:
```@example farmer
Cost = Dict(:wheat=>150, :corn=>230, :beets=>260);
Required = Dict(:wheat=>200, :corn=>240, :beets=>0);
PurchasePrice = Dict(:wheat=>238, :corn=>210);
SellPrice = Dict(:wheat=>170, :corn=>150, :beets_quota=>36, :beets_extra=>10);
Budget = 500;
```
In the first stage, the farmer needs to know what crops to plant, the cost of planting them, and the available land. Therefore, we introduce the first stage data:
```@example farmer
first_stage_data = (Crops, Cost, Budget)
```
In the second stage, the farmer needs to know the required quantity of each crop, the purchase price, and the sell price:
```@example farmer
second_stage_data = (Required, PurchasePrice, SellPrice)
```
The uncertainty lies in the future yield of each crop. We define a scenario type to capture this:
```julia
@scenario Yield = begin
    wheat::Float64
    corn::Float64
    beets::Float64
end
```
All of the above definitions can be included directly in the definition of the stochastic model of the farmer problem. Consider
```@example farmer
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
```
The three predicted outcomes can be defined through:
```@example farmer
ξ₁ = YieldScenario(3.0, 3.6, 24.0, probability = 1/3)
ξ₂ = YieldScenario(2.5, 3.0, 20.0, probability = 1/3)
ξ₃ = YieldScenario(2.0, 2.4, 16.0, probability = 1/3)
```
We can now instantiate the farmer problem using the defined stochastic model and the three yield scenarios:
```@example farmer
farmer = instantiate(farmer_model, [ξ₁,ξ₂,ξ₃])
```
Printing:
```@example farmer
print(farmer)
```
We can now optimize the model:
```@example farmer
optimize!(farmer, solver = GLPKSolverLP())
x = optimal_decision(farmer, :x)
println("Wheat: $(x[:wheat])")
println("Corn: $(x[:corn])")
println("Beets: $(x[:beets])")
println("Profit: $(optimal_value(farmer))")
```
Finally, we calculate the stochastic performance of the model:
```@example farmer
println("EVPI: $(EVPI(farmer, solver = GLPKSolverLP()))")
println("VSS: $(VSS(farmer, solver = GLPKSolverLP()))")
```

## Continuous scenario distribution

As an example, consider the following generalized stochastic program:
```math
\DeclareMathOperator*{\minimize}{minimize}
\begin{aligned}
 \minimize_{x \in \mathbb{R}} & \quad \operatorname{\mathbb{E}}_{\omega} \left[(x - \xi(\omega))^2\right] \\
\end{aligned}
```
where ``\xi(\omega)`` is exponentially distributed. We will skip the mathematical details here and just take for granted that the optimizer to the above problem is the mean of the exponential distribution. We will try to approximately solve this problem using sample average approximation. First, lets try to introduce a custom discrete scenario type that models a stochastic variable with a continuous probability distribution. Consider the following implementation:
```julia
using StochasticPrograms
using Distributions

struct DistributionScenario{D <: UnivariateDistribution} <: AbstractScenario
    probability::Probability
    distribution::D
    ξ::Float64

    function DistributionScenario(distribution::UnivariateDistribution, val::AbstractFloat)
        return new{typeof(distribution)}(Probability(pdf(distribution, val)), distribution, Float64(val))
    end
end

function StochasticPrograms.expected(scenarios::Vector{<:DistributionScenario{D}}) where D <: UnivariateDistribution
    isempty(scenarios) && return DistributionScenario(D(), 0.0)
    distribution = scenarios[1].distribution
    return ExpectedScenario(DistributionScenario(distribution, mean(distribution)))
end
```
The fallback [`probability`](@ref) method is viable as long as the scenario type contains a [`Probability`](@ref) field named `probability`. The implementation of [`expected`](@ref) is somewhat unconventional as it returns the mean of the distribution regardless of how many scenarios are given.

We can implement a sampler that generates exponentially distributed scenarios as follows:
```julia
struct ExponentialSampler <: AbstractSampler{DistributionScenario{Exponential{Float64}}}
    distribution::Exponential

    ExponentialSampler(θ::AbstractFloat) = new(Exponential(θ))
end

function (sampler::ExponentialSampler)()
    ξ = rand(sampler.distribution)
    return DistributionScenario(sampler.distribution, ξ)
end
```
Now, lets attempt to define the generalized stochastic program using the available modeling tools:
```julia
using Ipopt

sm = @stochastic_model begin
    @stage 1 begin
        @variable(model, x)
    end
    @stage 2 begin
        @decision x
        @uncertain ξ from DistributionScenario
        @variable(model, y)
        @constraint(model, y == (x - ξ)^2)
        @objective(model, Min, y)
    end
end
```
```julia
Two-Stage Stochastic Model

minimize f₀(x) + 𝔼[f(x,ξ)]
  x∈𝒳

where

f(x,ξ) = min  f(y; x, ξ)
              y ∈ 𝒴 (x, ξ)
```
The mean of the given exponential distribution is ``2.0``, which is the optimal solution to the general problem. Now, lets create a finite SAA model of 1000 exponentially distributed numbers:
```julia
sampler = ExponentialSampler(2.) # Create a sampler

saa = SAA(sm, sampler, 1000) # Sample 1000 exponentially distributed scenarios and create an SAA model
```
```julia
Stochastic program with:
 * 1 decision variable
 * 1 recourse variable
 * 1000 scenarios of type DistributionScenario
Solver is default solver
```
By the law of large numbers, we approach the generalized formulation with increasing sample size. Solving yields:
```julia
optimize!(saa, solver = IpoptSolver(print_level=0))

println("Optimal decision: $(optimal_decision(saa))")
println("Optimal value: $(optimal_value(saa))")
```
```julia
Optimal decision: [2.07583]
Optimal value: 4.00553678799426
```
Now, due to the special implementation of the [`expected`](@ref) function, it actually holds that the expected value solution solves the generalized problem. Consider:
```julia
println("EVP decision: $(EVP_decision(saa, solver = IpoptSolver(print_level=0)))")
println("VSS: $(VSS(saa, solver = IpoptSolver(print_level=0)))")
```
```julia
EVP decision: [2.0]
VSS: 0.005750340653017716
```
Accordingly, the VSS is small.
