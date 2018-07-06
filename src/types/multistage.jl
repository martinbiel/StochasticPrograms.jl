struct MultiStageStochasticProgramData
    first_stage::Stage
    stages::Vector{<:ScenarioProblems}
    generator::Dict{Symbol,Function}
    problemcache::Dict{Symbol,JuMP.Model}
    spsolver::SPSolver

    function (::Type{MultiStageStochasticProgramData})(nstages::Integer,::Type{SD}) where {SD <: AbstractScenarioData}
        stages = Vector{ScenarioProblems}(nstages-1)
        for i in 2:nstages
            stages[i-1] = ScenarioProblems(i,nothing,SD)
        end
        return new(Stage(1,nothing),stages,Dict{Symbol,Function}(),Dict{Symbol,JuMP.Model}(),SPSolver(JuMP.UnsetSolver()))
    end

    function (::Type{MultiStageStochasticProgramData})(stagedatas::Vector,::Type{SD}) where {SD <: AbstractScenarioData}
        isempty(stagedatas) && error("No stage data provided")
        nstages = length(stagedatas)
        stages = Vector{ScenarioProblems}(nstages-1)
        for i in 2:nstages
            stages[i-1] = ScenarioProblems(i,stagedatas[i],SD)
        end
        return new(Stage(1,stagedatas[1]),stages,Dict{Symbol,Function}(),Dict{Symbol,JuMP.Model}(),SPSolver(JuMP.UnsetSolver()))
    end
end

StochasticProgram(stagedatas::Vector; solver = JuMP.UnsetSolver()) = StochasticProgram(stagedatas,ScenarioData; solver=solver)
function StochasticProgram(stagedatas::Vector, ::Type{SD}; solver = JuMP.UnsetSolver()) where {SD <: AbstractScenarioData}
    multistage = JuMP.Model()
    multistage.ext[:MSSP] = MultiStageStochasticProgramData(stagedatas,SD)
    multistage.ext[:MSSP].spsolver.solver = solver
    # Set hooks
    JuMP.setsolvehook(multistage, _solve)
    JuMP.setprinthook(multistage, _printhook)
    return multistage
end

StochasticProgram(; nstages::Integer = 2, solver = JuMP.UnsetSolver()) = StochasticProgram(ScenarioData; nstages = nstages, solver=solver)
function StochasticProgram(::Type{SD}; nstages::Integer = 2, solver = JuMP.UnsetSolver()) where {SD <: AbstractScenarioData}
    if nstages < 2
        error("A Stochastic program should at least have two stages")
    elseif nstages == 2
        return StochasticProgram(nothing,nothing,SD; solver = solver)
    else
        multistage = JuMP.Model()
        multistage.ext[:MSSP] = MultiStageStochasticProgramData(nstages,SD)
        multistage.ext[:MSSP].spsolver.solver = solver
        # Set hooks
        JuMP.setsolvehook(multistage, _solve)
        JuMP.setprinthook(multistage, _printhook)
        return multistage
    end
end

# Setters
# ========================== #
function set_stage(multistage::JuMP.Model,stage::Integer,data)
    haskey(multistage.ext,:MSSP) || error("The given model is not a multi-stage stochastic program.")
    (stage >= 1 && stage <= nstages(multistage)) || error("Stage index outside range of multi-stage program.")
    multistage.ext[:MSSP].stages[stage].stage.data = data
    return multistage
end
# ========================== #

# Base overloads
# ========================== #
function Base.push!(multistage::JuMP.Model,stage::Integer,sdata::AbstractScenarioData)
    haskey(multistage.ext,:MSSP) || error("The given model is not a multi-stage stochastic program.")
    (stage > 1 && stage <= nstages(multistage)) || error("Stage index outside range of multi-stage program.")

    push!(multistage.stages[stage-1],sdata)
    return multistage
end
function Base.append!(multistage::JuMP.Model,stage::Integer,sdata::Vector{<:AbstractScenarioData})
    haskey(multistage.ext,:MSSP) || error("The given model is not a multi-stage stochastic program.")
    (stage > 1 && stage <= nstages(multistage)) || error("Stage index outside range of multi-stage program.")

    append!(multistage.ext[:MSSP].stages[stage-1],sdata)
    return multistage
end
# ========================== #
