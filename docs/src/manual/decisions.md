# Multi-stage decisions

StochasticPrograms provides an extended version of JuMPs API for decision variables/constraints/objectives with stage and scenario dependence. Consider the following problem:

```@example decision
using StochasticPrograms
using GLPK

ξ₁ = @scenario a = 1 probability = 0.5
ξ₂ = @scenario a = 2 probability = 0.5

sp = StochasticProgram([ξ₁,ξ₂], Deterministic())
@first_stage sp = begin
    @decision(model, x >= 2)
    @variable(model, w)
    @objective(model, Min, x)
end
@second_stage sp = begin
    @known x
    @uncertain a
    @recourse(model, y >= 1/a)
    @objective(model, Max, y)
    @constraint(model, con, a*y <= x)
end
```
A first-stage decision and a second-stage recourse decision has been identified. We include a printout of the stochastic program for reference:
```@example decision
print(sp)
```

## Decision variables

All variables annotated with either [`@decision`](@ref) or [`@recourse`](@ref) become available through the API. We can query all such variables:
```@example decision
all_decision_variables(sp)
```
stage-wise lists can also be obtained:
```@example decision
all_decision_variables(sp, 1)
```
and
```@example decision
all_decision_variables(sp, 2)
```
JuMPs `[]` syntax is available as well, with the addition that the stage must be provided as well:
```@example decision
x = sp[1,:x]
println(x)
println(typeof(x))
```
The return type is [`DecisionVariable`](@ref) a specialized `AbstractVariableRef`. For first-stage variables, the syntax is unchanged from JuMP:
```@example decision
println(name(x))
println("x has lower bound: $(has_lower_bound(x))")
println("x has upper bound: $(has_upper_bound(x))")
println("lower_bound(x) = $(lower_bound(x))")
```
If we instead query for the recourse decision ``y``:
```@example decision
y = sp[2,:y]
println(y)
println(typeof(y))
```
The same getters will error:
```julia
lower_bound(y)
```
```julia
ERROR: y is scenario dependent, consider `lower_bound(dvar, scenario_index)`.
```
As indicated by the error, ``y`` is scenario-dependent so a `scenario_index` must be provided as well:
```@example decision
println(name(y, 1))
println("y has lower bound in scenario 1: $(has_lower_bound(y, 1))")
println("y has upper bound in scenario 1: $(has_upper_bound(y, 1))")
println("lower_bound(y, 1) = lower_bound(y, 1)")

println(name(y, 2))
println("y has lower bound in scenario 2: $(has_lower_bound(y, 2))")
println("y has upper bound in scenario 2: $(has_upper_bound(y, 2))")
println("lower_bound(y, 2) = lower_bound(y, 2)")
```
The lower bound of ``y`` is as expected different in the two scenarios. Some attributes, such as the variable name, are structure dependent and may vary in a [`Vertical`](@ref) or [`Horizontal`](@ref) structure. Auxiliary variables created with the standard `@variable` are not available through this API. To access them, either annotate them with [`@decision`](@ref) (or [`@recourse`](@ref) in the final stage), or access the relevant JuMP subproblem and query the variable as usual. For example:
```@example decision
w = DEP(sp)[:w]
println(w)
println(typeof(w))
```

## Decision constraints

Constraints that include variables annotated with either [`@decision`](@ref) or [`@recourse`](@ref) can also be accessed in the extended API. Stage-wise list of all such constraints can be obtained:
```@example decision
println(list_of_constraint_types(sp, 1))
```
```@example decision
println(list_of_constraint_types(sp, 2))
```
and type-sorted constraints can be obtained through a stage-dependent variant of [`all_constraints`](@ref):
```@example decision
all_constraints(sp, 2, DecisionAffExpr{Float64}, MOI.LessThan{Float64});
```
The scenario-dependent constraint in stage 2 can also be accessed through
```@example decision
con = sp[2,:con];
println(con)
```
This returns an [`SPConstraintRef`](@ref), similar in function to [`DecisionVariable`](@ref). The constraint originates from stage-two, so most attributes are scenario-dependent:
```@example decision
println(name(con, 1))
println("RHS of con in scenario 1 = $(normalized_rhs(con, 1))")
println("Coefficient of x in scenario 1 = $(normalized_coefficient(con, x, 1))")
println("Coefficient of y in scenario 1 = $(normalized_coefficient(con, y, 1))")

println(name(con, 2))
println("RHS of con in scenario 2 = $(normalized_rhs(con, 2))")
println("Coefficient of x in scenario 2 = $(normalized_coefficient(con, x, 2))")
println("Coefficient of y in scenario 2 = $(normalized_coefficient(con, y, 2))")
```

## Decision objectives

The objective function of a stochastic program can be obtained in full or in stage and scenario-dependent chunks:
```@example decision
println("Objective in stage 1: $(objective_function(sp, 1))")
println("Objective in stage 2, scenario 1: $(objective_function(sp, 2, 1))")
println("Objective in stage 2, scenario 2: $(objective_function(sp, 2, 2))")
println("Full objective: $(objective_function(sp))")
```
and can be modified accordingly:
```@example decision
set_objective_coefficient(sp, y, 2, 1, 2.);
println("Objective in stage 2, scenario 1: $(objective_function(sp, 2, 1))")
println("Full objective: $(objective_function(sp))")
set_objective_coefficient(sp, y, 2, 1, 1.);
```
The stochastic program objective is structure dependent and will appear different if the stochastic program is instantiated with [`Vertical`](@ref) or [`Horizontal`](@ref) instead.

## Solved problem

After optimizing the stochastic program, attributes for which `is_set_by_optimize` is true can be accessed using the same scenario-dependent syntax:
```@example decision
set_optimizer(sp, GLPK.Optimizer)

optimize!(sp)

# Main result
println("Termination status: $(termination_status(sp))")
println("Objective value: $(objective_value(sp))")
println("Optimal decision: $(optimal_decision(sp))")

# First stage
println("value(x) = $(value(x))")
println("reduced_cost(x) = $(reduced_cost(x))")

# Scenario 1
# Second stage
println("value(y, 1) = $(value(y, 1))")
println("reduced_cost(y, 1) = $(reduced_cost(y, 1))")
println("dual(con, 1) = $(dual(con, 1))")
println("Objective value in scenario 1: $(objective_value(sp, 1))")
println("Optimal recourse in scenario 1: $(optimal_recourse_decision(sp, 1))")

# Scenario 2
println("value(y, 2) = $(value(y, 2))")
println("reduced_cost(y, 2) = $(reduced_cost(y, 2))")
println("dual(con, 2) = $(dual(con, 2))")
println("Objective value in scenario 2: $(objective_value(sp, 2))")
println("Optimal recourse in scenario 2: $(optimal_recourse_decision(sp, 2))")
```

As mentioned in the [Quick start](@ref), decision evaluation can be performed manually through the decision API. Consider:
```@example decision
fix(x, 3.);
```
This not only fixes ``x`` in the first-stage, but also in all occurances in subsequent stages:
```@example decision
print(sp)
```
This is more apparent in a vertical structure:
```@example decision
vertical_sp = StochasticProgram([ξ₁,ξ₂], Vertical())
@first_stage vertical_sp = begin
    @decision(model, x >= 2)
    @variable(model, w)
    @objective(model, Min, x)
end
@second_stage vertical_sp = begin
    @known x
    @uncertain a
    @recourse(model, y >= 1/a)
    @objective(model, Max, y)
    @constraint(model, con, a*y <= x)
end

x = vertical_sp[1,:x]
fix(x, 3.)

print(vertical_sp)
```
We resolve the problem to verify:
```@example decision
optimize!(sp)

# Main result
println("Termination status: $(termination_status(sp))")
println("Objective value: $(objective_value(sp))")
println("Optimal decision: $(optimal_decision(sp))")

# First stage
println("value(x) = $(value(x))")

# Scenario 1
# Second stage
println("value(y, 1) = $(value(y, 1))")
println("reduced_cost(y, 1) = $(reduced_cost(y, 1))")
println("dual(con, 1) = $(dual(con, 1))")
println("Objective value in scenario 1: $(objective_value(sp, 1))")
println("Optimal recourse in scenario 1: $(optimal_recourse_decision(sp, 1))")

# Scenario 2
println("value(y, 2) = $(value(y, 2))")
println("reduced_cost(y, 2) = $(reduced_cost(y, 2))")
println("dual(con, 2) = $(dual(con, 2))")
println("Objective value in scenario 2: $(objective_value(sp, 2))")
println("Optimal recourse in scenario 2: $(optimal_recourse_decision(sp, 2))")

# Evaluating x = 3 should give the same answer:
println("Equivalent decision evaluation: $(evaluate_decision(sp, [3.]))")
```
We can also fix the value of ``y`` in a specific scenario:
```@example decision
fix(y, 1, 2.)
optimize!(sp)

# Main result
println("Termination status: $(termination_status(sp))")
println("Objective value: $(objective_value(sp))")
println("Optimal decision: $(optimal_decision(sp))")

# First stage
println("value(x) = $(value(x))")

# Scenario 1
# Second stage
println("value(y, 1) = $(value(y, 1))")
println("Objective value in scenario 1: $(objective_value(sp, 1))")
println("Optimal recourse in scenario 1: $(optimal_recourse_decision(sp, 1))")

# Scenario 2
println("value(y, 2) = $(value(y, 2))")
println("Objective value in scenario 2: $(objective_value(sp, 2))")
println("Optimal recourse in scenario 2: $(optimal_recourse_decision(sp, 2))")

# Evaluating x = 3 should give the same answer:
println(evaluate_decision(sp, [3.]))

# Evaluating x = 3 should give the same answer:
println("Equivalent decision evaluation: $(evaluate_decision(sp, [3.]))")
```
