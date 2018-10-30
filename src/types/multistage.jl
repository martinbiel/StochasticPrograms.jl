struct MultiStageStochasticProgram
    first_stage::Stage
    stages::Vector{<:ScenarioProblems}
    generator::Dict{Symbol,Function}
    problemcache::Dict{Symbol,JuMP.Model}
    spsolver::SPSolver

    function (::Type{MultiStageStochasticProgram})(nstages::Integer, ::Type{SD}) where {SD <: AbstractScenarioData}
        stages = Vector{ScenarioProblems}(nstages-1)
        for i in 2:nstages
            stages[i-1] = ScenarioProblems(i, nothing, SD)
        end
        return new(Stage(1,nothing), stages, Dict{Symbol,Function}(), Dict{Symbol,JuMP.Model}(), SPSolver(JuMP.UnsetSolver()))
    end

    function (::Type{MultiStageStochasticProgram})(stagedatas::Vector, ::Type{SD}) where {SD <: AbstractScenarioData}
        isempty(stagedatas) && error("No stage data provided")
        nstages = length(stagedatas)
        stages = Vector{ScenarioProblems}(nstages-1)
        for i in 2:nstages
            stages[i-1] = ScenarioProblems(i, stagedatas[i], SD)
        end
        return new(Stage(1,stagedatas[1]), stages, Dict{Symbol,Function}(), Dict{Symbol,JuMP.Model}(), SPSolver(JuMP.UnsetSolver()))
    end
end

StochasticProgram(stagedatas::Vector; solver = JuMP.UnsetSolver()) = StochasticProgram(stagedatas, ScenarioData; solver=solver)
function StochasticProgram(stagedatas::Vector, ::Type{SD}; solver = JuMP.UnsetSolver()) where {SD <: AbstractScenarioData}
    multistage = MultiStageStochasticProgram(stagedatas, SD)
    multistage.spsolver.solver = solver
    return multistage
end

StochasticProgram(; nstages::Integer = 2, solver = JuMP.UnsetSolver()) = StochasticProgram(ScenarioData; nstages = nstages, solver=solver)
function StochasticProgram(::Type{SD}; nstages::Integer = 2, solver = JuMP.UnsetSolver()) where {SD <: AbstractScenarioData}
    if nstages < 2
        error("A Stochastic program should at least have two stages")
    elseif nstages == 2
        return StochasticProgram(nothing, nothing, SD; solver = solver)
    else
        multistage = MultiStageStochasticProgram(nstages, SD)
        multistage.spsolver.solver = solver
        return multistage
    end
end

# Setters
# ========================== #
function set_stage(multistage::MultiStageStochasticProgram, stage::Integer, data)
    (stage >= 1 && stage <= nstages(multistage)) || error("Stage index outside range of multi-stage program.")
    multistage.stages[stage].stage.data = data
    return multistage
end
function add_scenario!(multistage::MultiStageStochasticProgram, stage::Integer, scenario::AbstractScenarioData)
    (stage > 1 && stage <= nstages(multistage)) || error("Stage index outside range of multi-stage program.")
    add_scenario!(multistage.stages[stage-1], scenario)
    return multistage
end
function add_scenarios!(multistage::MultiStageStochasticProgram, stage::Integer, scenarios::Vector{<:AbstractScenarioData})
    (stage > 1 && stage <= nstages(multistage)) || error("Stage index outside range of multi-stage program.")
    add_scenarios!(multistage.stages[stage-1], scenarios)
    return multistage
end
# ========================== #
