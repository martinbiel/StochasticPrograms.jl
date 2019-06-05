@sampler SimpleSampler = begin
    N::StochasticPrograms.MvNormal

    SimpleSampler(μ, Σ) = new(StochasticPrograms.MvNormal(μ, Σ))

    @sample Scenario begin
        x = rand(sampler.N)
        return Scenario(q₁ = x[1], q₂ = x[2], d₁ = x[3], d₂ = x[4], probability = StochasticPrograms.pdf(sampler.N, x))
    end
end

μ = [-28, -32, 300, 300]
Σ = [2 0.5 0 0
     0.5 1 0 0
     0 0 50 20
     0 0 20 30]

sampler = SimpleSampler(μ, Σ)
