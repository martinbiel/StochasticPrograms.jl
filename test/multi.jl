@everywhere begin
    struct SimpleMultiScenario <: StochasticPrograms.AbstractScenarioData
        π::Float64
        d::Float64
    end
end

s21 = SimpleMultiScenario(0.5,1.0)
s22 = SimpleMultiScenario(0.5,3.0)

s31 = SimpleMultiScenario(0.25,1.0)
s32 = SimpleMultiScenario(0.25,3.0)
s33 = SimpleMultiScenario(0.25,1.0)
s34 = SimpleMultiScenario(0.25,3.0)

sp = StochasticProgram(SimpleMultiScenario,nstages=3)

append!(sp,2,[s21,s22])
append!(sp,3,[s31,s32,s33,s34])

@stage 1 sp = begin
    @variable(model, x¹ <= 2)
    @variable(model, w¹)
    @variable(model, y¹)
    @objective(model, Min, 100*x¹ + 3*w¹ + 0.5*y¹)
    @constraint(model, x¹ + w¹ - y¹ == 1)
end

@stage 2 sp = begin
    @decision x¹ w¹ y¹
    d = scenario.d
    @variable(model, x² <= 2)
    @variable(model, w²)
    @variable(model, y²)
    @objective(model, Min, x² + 3*w² + 0.5*y²)
    @constraint(model, y¹ + x² + w² - y² == d)
end

@stage 3 sp = begin
    @decision y²
    d = scenario.d
    @variable(model, x³ <= 2)
    @variable(model, w³)
    @variable(model, y³)
    @objective(model, Min, x² + 3*w²)
    @constraint(model, y² + x³ + w³ - y³ == d)
end
