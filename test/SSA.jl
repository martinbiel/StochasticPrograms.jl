@scenario SAA = begin
    ξ::Float64
end

@sampler SAA = begin
    w::Float64

    SAA(w::AbstractFloat) = new(w)

    @sample begin
        w = sampler.w
        return SAAScenario(w*randn(), probability = rand())
    end
end

saa_model = StochasticModel((sp) -> begin
    @first_stage sp = begin
        @variable(model, x >= 0)
    end
    @second_stage sp = begin
        @decision x
        ξ = scenario.ξ
        @variable(model, y)
        @objective(model, Min, y)
        @constraint(model, y == x)
        @constraint(model, y >= ξ)
    end
end)
