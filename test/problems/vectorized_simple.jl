vec_simple = @stochastic_model begin
    @stage 1 begin
        @parameters begin
            lb = [40.0, 20.0]
            c  = [100., 150.]
            A  = [1. 1.]
            b  = [120.]
        end
        @decision(model, x[i in 1:2] >= lb[i])
        @objective(model, Min, dot(c, x))
        @constraint(model, A * x - b in MOI.Nonpositives(1))
    end
    @stage 2 begin
        @parameters begin
            lb = [0., 0.]
            T  = [-60. 0.;
                  0.  -80.]
            W  = [6. 10.;
                  8. 5.]
        end
        @uncertain q₁ q₂ d₁ d₂
        ub = [d₁, d₂]
        q  = [q₁, q₂]
        @variable(model, lb[i] <= y[i in 1:2] <= ub[i])
        @objective(model, Max, dot(q, y))
        @constraint(model, T * x + W * y in MOI.Nonpositives(2))
    end
end

ξ₁ = Scenario(q₁ = 24.0, q₂ = 28.0, d₁ = 500.0, d₂ = 100.0, probability = 0.4)
ξ₂ = Scenario(q₁ = 28.0, q₂ = 32.0, d₁ = 300.0, d₂ = 300.0, probability = 0.6)

vec_simple_res = SPResult([46.67, 36.25], -855.83, -1518.75, 662.92, 286.92, -1445.92, -568.92)
push!(problems, (vec_simple, [ξ₁,ξ₂], vec_simple_res, "Simple"))
