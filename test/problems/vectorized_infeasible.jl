vec_infeasible = @stochastic_model begin
    @stage 1 begin
        @parameters begin
            lb = zeros(2)
            c  = [3., 2.]
        end
        @decision(model, x[i in 1:2] >= lb[i])
        @objective(model, Min, dot(c, x))
    end
    @stage 2 begin
        @parameters begin
            q = [-15., -12.]
            T = [-1. 0;
                  0  -1.]
            W = [3. 2.;
                 2. 5.]
        end
        @uncertain ξ₁ ξ₂
        ub = [ξ₁, ξ₂]
        lb = 0.8 * ub
        @variable(model, lb[i] <= y[i in 1:2] <= ub[i])
        @objective(model, Min, dot(q, y))
        @constraint(model, T * x + W * y in MOI.Nonpositives(2))
    end
end

ξ₁ = Scenario(ξ₁ = 6., ξ₂ = 8., probability = 0.5)
ξ₂ = Scenario(ξ₁ = 4., ξ₂ = 4., probability = 0.5)

vec_infeasible_res = SPResult([27.2,41.6], 36.4, 9.2, 27.2, Inf, 9.2, Inf)
push!(problems, (vec_infeasible, [ξ₁,ξ₂], vec_infeasible_res, "Infeasible"))
