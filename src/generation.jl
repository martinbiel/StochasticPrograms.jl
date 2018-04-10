# Problem generation #
# ========================== #
function stage_one_model(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:first_stage) || error("First-stage problem not defined in stochastic program. Use @first_stage when defining stochastic program. Aborting.")
    stage_one_model = Model(solver=JuMP.UnsetSolver())
    generator(stochasticprogram,:first_stage)(stage_one_model,common(stochasticprogram))
    return stage_one_model
end

function _stage_two_model(generator::Function,common::Any,scenario::AbstractScenarioData,parent::JuMP.Model)
    stage_two_model = Model(solver=JuMP.UnsetSolver())
    generator(stage_two_model,common,scenario,parent)
    return stage_two_model
end
function stage_two_model(stochasticprogram::JuMP.Model,scenario::AbstractScenarioData)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Use @second_stage when defining stochastic program. Aborting.")
    generator(stochasticprogram,:second_stage)(stage_two_model,common(stochasticprogram),scenario,stochasticprogram)
    return _stage_two_model(generator(stochasticprogram,:second_stage),common(stochasticprogram),scenario,stochasticprogram)
end

function generate_parent!(scenarioproblems::ScenarioProblems{D,SD},generator::Function) where {D,SD <: AbstractScenarioData}
    generator(parentmodel(scenarioproblems),common(scenarioproblems))
    nothing
end
function generate_parent!(scenarioproblems::DScenarioProblems{D,SD},generator::Function) where {D,SD <: AbstractScenarioData}
    finished_workers = Vector{Future}(length(scenarioproblems))
    for p in 1:length(scenarioproblems)
        finished_workers[p] = remotecall((sp,generator)->generate_parent!(fetch(sp),generator),p+1,scenarioproblems[p],generator)
    end
    map(wait,finished_workers)
    nothing
end

function generate_stage_one!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:first_stage) && has_generator(stochasticprogram,:first_stage_vars) || error("First-stage problem not defined in stochastic program. Use @first_stage when defining stochastic program. Aborting.")

    generator(stochasticprogram,:first_stage)(stochasticprogram,common(stochasticprogram))
    generate_parent!(scenarioproblems(stochasticprogram),generator(stochasticprogram,:first_stage_vars))
    nothing
end

function generate_stage_two!(scenarioproblems::ScenarioProblems{D,SD},generator::Function) where {D,SD <: AbstractScenarioData}
    for i in nscenarios(scenarioproblems)+1:length(scenarioproblems.scenariodata)
        push!(scenarioproblems.problems,_stage_two_model(generator,common(scenarioproblems),scenario(scenarioproblems,i),parentmodel(scenarioproblems)))
    end
    nothing
end
function generate_stage_two!(scenarioproblems::DScenarioProblems{D,SD},generator::Function) where {D,SD <: AbstractScenarioData}
    finished_workers = Vector{Future}(length(scenarioproblems))
    for p in 1:length(scenarioproblems)
        finished_workers[p] = remotecall((sp,generator)->generate_stage_two!(fetch(sp),generator),p+1,scenarioproblems[p],generator)
    end
    map(wait,finished_workers)
    nothing
end
function generate_stage_two!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Use @second_stage when defining stochastic program. Aborting.")
    generate_stage_two!(scenarioproblems(stochasticprogram),generator(stochasticprogram,:second_stage))
    nothing
end

function generate!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Use @second_stage when defining stochastic program. Aborting.")
    generate_stage_one!(stochasticprogram)
    generate_stage_two!(scenarioproblems(stochasticprogram),generator(stochasticprogram,:second_stage))
    nothing
end

function _outcome_model(stage_one_generator::Function,
                        stage_two_generator::Function,
                        common::Any,
                        scenario::AbstractScenarioData,
                        x::AbstractVector,
                        solver::MathProgBase.AbstractMathProgSolver)
    outcome_model = Model(solver = solver)
    stage_one_generator(outcome_model,common)
    for obj in values(outcome_model.objDict)
        if isa(obj,JuMP.Variable)
            val = x[obj.col]
            outcome_model.colCat[obj.col] = :Fixed
            outcome_model.colVal[obj.col] = val
            outcome_model.colLower[obj.col] = val
            outcome_model.colUpper[obj.col] = val
        elseif isa(obj,JuMP.JuMPArray{JuMP.Variable})
            for var in obj.innerArray
                val = x[var.col]
                outcome_model.colCat[var.col] = :Fixed
                outcome_model.colVal[var.col] = val
                outcome_model.colLower[var.col] = val
                outcome_model.colUpper[var.col] = val
            end
        else
            continue
        end
    end
    stage_two_generator(outcome_model,common,scenario,outcome_model)

    return outcome_model
end
function outcome_model(stochasticprogram::JuMP.Model,scenario::AbstractScenarioData,x::AbstractVector,solver::MathProgBase.AbstractMathProgSolver)
    has_generator(stochasticprogram,:first_stage_vars) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    return _outcome_model(generator(stochasticprogram,:first_stage_vars),generator(stochasticprogram,:second_stage),common(stochasticprogram),scenario,x,solver)
end
# ========================== #
