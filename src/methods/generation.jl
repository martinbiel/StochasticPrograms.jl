# Problem generation #
# ========================== #
function stage_one_model(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:stage_1) || error("First-stage problem not defined in stochastic program. Use @first_stage when defining stochastic program. Aborting.")
    stage_one_model = Model(solver=JuMP.UnsetSolver())
    generator(stochasticprogram,:stage_1)(stage_one_model,first_stage_data(stochasticprogram))
    return stage_one_model
end

function _stage_two_model(generator::Function,stagedata::Any,scenario::AbstractScenarioData,parent::JuMP.Model)
    stage_two_model = Model(solver=JuMP.UnsetSolver())
    generator(stage_two_model,stagedata,scenario,parent)
    return stage_two_model
end
function stage_two_model(stochasticprogram::JuMP.Model,scenario::AbstractScenarioData)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:stage_2) || error("Second-stage problem not defined in stochastic program. Use @second_stage when defining stochastic program. Aborting.")
    return _stage_two_model(generator(stochasticprogram,:stage_2),second_stage_data(stochasticprogram),scenario,stochasticprogram)
end

function generate_parent!(scenarioproblems::ScenarioProblems{D,SD},generator::Function,parentdata::Any) where {D,SD <: AbstractScenarioData}
    generator(parentmodel(scenarioproblems),parentdata)
    nothing
end
function generate_parent!(scenarioproblems::DScenarioProblems{D,SD},generator::Function,parentdata::Any) where {D,SD <: AbstractScenarioData}
    finished_workers = Vector{Future}(length(scenarioproblems))
    for p in 1:length(scenarioproblems)
        finished_workers[p] = remotecall((sp,generator,parentdata)->generate_parent!(fetch(sp),generator,parentdata),p+1,scenarioproblems[p],generator,parentdata)
    end
    map(wait,finished_workers)
    nothing
end

function generate_stage_one!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:stage_1) && has_generator(stochasticprogram,:stage_1_vars) || error("First-stage problem not defined in stochastic program. Use @first_stage when defining stochastic program. Aborting.")

    generator(stochasticprogram,:stage_1)(stochasticprogram,first_stage_data(stochasticprogram))
    generate_parent!(scenarioproblems(stochasticprogram),generator(stochasticprogram,:stage_1_vars),first_stage_data(stochasticprogram))
    nothing
end

function generate_stage_two!(scenarioproblems::ScenarioProblems{D,SD},generator::Function) where {D,SD <: AbstractScenarioData}
    for i in nscenarios(scenarioproblems)+1:length(scenarioproblems.scenariodata)
        push!(scenarioproblems.problems,_stage_two_model(generator,stage_data(scenarioproblems),scenario(scenarioproblems,i),parentmodel(scenarioproblems)))
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
    has_generator(stochasticprogram,:stage_2) || error("Second-stage problem not defined in stochastic program. Use @second_stage when defining stochastic program. Aborting.")
    generate_stage_two!(scenarioproblems(stochasticprogram),generator(stochasticprogram,:stage_2))
    nothing
end

function generate!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:stage_2) || error("Second-stage problem not defined in stochastic program. Use @second_stage when defining stochastic program. Aborting.")
    generate_stage_one!(stochasticprogram)
    generate_stage_two!(scenarioproblems(stochasticprogram),generator(stochasticprogram,:stage_2))
    nothing
end

function _outcome_model(stage_one_generator::Function,
                        stage_two_generator::Function,
                        first_stage::Any,
                        second_stage::Any,
                        scenario::AbstractScenarioData,
                        x::AbstractVector,
                        solver::MathProgBase.AbstractMathProgSolver)
    outcome_model = Model(solver = solver)
    stage_one_generator(outcome_model,first_stage)
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
    stage_two_generator(outcome_model,second_stage,scenario,outcome_model)

    return outcome_model
end
function outcome_model(stochasticprogram::JuMP.Model,scenario::AbstractScenarioData,x::AbstractVector,solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:stage_1_vars) || error("No first-stage problem generator. Consider using @first_stage or @stage 1 when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:stage_2) || error("Second-stage problem not defined in stochastic program. Aborting.")

    return _outcome_model(generator(stochasticprogram,:stage_1_vars),generator(stochasticprogram,:stage_2),first_stage_data(stochasticprogram),second_stage_data(stochasticprogram),scenario,x,solver)
end
# ========================== #
