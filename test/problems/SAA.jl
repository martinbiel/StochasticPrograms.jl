saa_model = @stochastic_model begin
    @stage 1 begin
        @decision(model, x >= 0)
    end
    @stage 2 begin
        @uncertain ξ
        @variable(model, y)
        @objective(model, Min, y)
        @constraint(model, y == x)
        @constraint(model, y >= ξ)
    end
end
