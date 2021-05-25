# Examples

## Farmer problem

The following defines the well-known "Farmer problem", first outlined in [Introduction to Stochastic Programming](https://link.springer.com/book/10.1007%2F978-1-4614-0237-4), in StochasticPrograms. The problem revolves around a farmer who needs to decide how to partition his land to sow three different crops. The uncertainty comes from not knowing what the future yield of each crop will be. Recourse decisions involve purchasing/selling crops at the market.

```@example farmer
using StochasticPrograms
using GLPK
```
An example implementation of the farmer problem is given by:
```@example farmer
Crops = [:wheat, :corn, :beets]
@stochastic_model farmer_model begin
    @stage 1 begin
        @parameters begin
            Crops = Crops
            Cost = Dict(:wheat=>150, :corn=>230, :beets=>260)
            Budget = 500
        end
        @decision(farmer_model, x[c in Crops] >= 0)
        @objective(farmer_model, Min, sum(Cost[c]*x[c] for c in Crops))
        @constraint(farmer_model, sum(x[c] for c in Crops) <= Budget)
    end
    @stage 2 begin
        @parameters begin
            Crops = Crops
            Required = Dict(:wheat=>200, :corn=>240, :beets=>0)
            PurchasePrice = Dict(:wheat=>238, :corn=>210)
            SellPrice = Dict(:wheat=>170, :corn=>150, :beets=>36, :extra_beets=>10)
        end
        @uncertain ξ[c in Crops]
        @recourse(farmer_model, y[p in setdiff(Crops, [:beets])] >= 0)
        @recourse(farmer_model, w[s in Crops ∪ [:extra_beets]] >= 0)
        @objective(farmer_model, Min, sum(PurchasePrice[p] * y[p] for p in setdiff(Crops, [:beets]))
                   - sum(SellPrice[s] * w[s] for s in Crops ∪ [:extra_beets]))
        @constraint(farmer_model, minimum_requirement[p in setdiff(Crops, [:beets])],
            ξ[p] * x[p] + y[p] - w[p] >= Required[p])
        @constraint(farmer_model, minimum_requirement_beets,
            ξ[:beets] * x[:beets] - w[:beets] - w[:extra_beets] >= Required[:beets])
        @constraint(farmer_model, beets_quota, w[:beets] <= 6000)
    end
end
```
The three yield scenarios can be defined through:
```@example farmer
ξ₁ = @scenario ξ[c in Crops] = [3.0, 3.6, 24.0] probability = 1/3
ξ₂ = @scenario ξ[c in Crops] = [2.5, 3.0, 20.0] probability = 1/3
ξ₃ = @scenario ξ[c in Crops] = [2.0, 2.4, 16.0] probability = 1/3
```
We can now instantiate the farmer problem using the defined stochastic farmer_model and the three yield scenarios:
```@example farmer
farmer = instantiate(farmer_model, [ξ₁,ξ₂,ξ₃], optimizer = GLPK.Optimizer)
```
Printing:
```@example farmer
print(farmer)
```
We can now optimize the farmer_model:
```@example farmer
optimize!(farmer)
x = optimal_decision(farmer)
x = farmer[1,:x]
println("Wheat: $(value(x[:wheat]))")
println("Corn: $(value(x[:corn]))")
println("Beets: $(value(x[:beets]))")
println("Profit: $(objective_value(farmer))")
```
We can also check results for a specific scenario:
```@example farmer
y = farmer[2,:y]
w = farmer[2,:w]
println("Purchased wheat: $(value(y[:wheat], 1))")
println("Purchased corn: $(value(y[:corn], 1))")
println("Sold wheat: $(value(w[:wheat], 1))")
println("Sold corn: $(value(w[:corn], 1))")
println("Sold beets: $(value(w[:extra_beets], 1))")
println("Profit: $(objective_value(farmer, 1))")
```

Finally, we calculate the stochastic performance of the farmer_model:
```@example farmer
println("EVPI: $(EVPI(farmer))")
println("VSS: $(VSS(farmer))")
```

## Continuous scenario distribution

As an example, consider the following generalized stochastic program:
```math
\begin{aligned}
 \operatorname*{minimize}_{x \in \mathbb{R}} & \quad \operatorname{\mathbb{E}}_{\omega} \left[(x - \xi(\omega))^2\right] \\
\end{aligned}
```
where ``\xi(\omega)`` is exponentially distributed. We will skip the mathematical details here and just take for granted that the optimizer to the above problem is the mean of the exponential distribution. We will try to approximately solve this problem using sample average approximation. First, lets try to introduce a custom discrete scenario type that farmer_models a stochastic variable with a continuous probability distribution. Consider the following implementation:
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
Now, lets attempt to define the generalized stochastic program using the available farmer_modeling tools:
```julia
using Ipopt

sm = @stochastic begin
    @stage 1 begin
        @decision(model, x)
    end
    @stage 2 begin
        @uncertain ξ from DistributionScenario
        @objective(model, Min, (x - ξ)^2)
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
The mean of the given exponential distribution is ``2.0``, which is the optimal solution to the general problem. Now, lets create a finite sampled farmer_model of 1000 exponentially distributed numbers:
```julia
sampler = ExponentialSampler(2.) # Create a sampler

sp = instantiate(sm, sampler, 1000, optimizer = Ipopt.Optimizer) # Sample 1000 exponentially distributed scenarios and create a sampled farmer_model
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
optimize!(sp)

println("Optimal decision: $(optimal_decision(sp))")
println("Optimal value: $(objective_value(sp))")
```
```julia
Optimal decision: [2.0397762891884894]
Optimal value: 4.00553678799426
```
Now, due to the special implementation of the [`expected`](@ref) function, it actually holds that the expected value solution solves the generalized problem. Consider:
```julia
println("Expected value decision: $(expected_value_decision(sp)")
println("VSS: $(VSS(sp))")
```
```julia
EVP decision: [2.0]
VSS: 0.00022773669794418083
```
Accordingly, the VSS is small.
