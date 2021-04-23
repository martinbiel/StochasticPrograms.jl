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
        @uncertain ξ[1:2]
        @recourse(model, 0.8 * ξ[i] <= y[i in 1:2] <= ξ[i])
        @objective(model, Min, dot(q, y))
        @constraint(model, T * x + W * y in MOI.Nonpositives(2))
    end
end

ξ₁ = @scenario ξ[1:2] = [6., 8.] probability = 0.5
ξ₂ = @scenario ξ[1:2] = [4., 4.] probability = 0.5

vec_infeasible_res = SPResult([27.2,41.6], Dict(1 => [4.8, 6.4], 2 => [4., 4.]), 36.4, 9.2, 27.2, Inf, 9.2, Inf)
push!(problems, (vec_infeasible, [ξ₁,ξ₂], vec_infeasible_res, "Vectorized Infeasible"))
