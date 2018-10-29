# Problem generation #
# ========================== #
"""
    stage_one_model(stochasticprogram::JuMP.Model)

Returns a generated copy of the first stage model in `stochasticprogram`.
"""
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
"""
    stage_two_model(stochasticprogram::JuMP.Model)

Returns a generated second stage model corresponding to `scenario`, in `stochasticprogram`.
"""
function stage_two_model(stochasticprogram::JuMP.Model, scenario::AbstractScenarioData)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:stage_2) || error("Second-stage problem not defined in stochastic program. Use @second_stage when defining stochastic program. Aborting.")
    return _stage_two_model(generator(stochasticprogram,:stage_2),second_stage_data(stochasticprogram),scenario,stochasticprogram)
end
function generate_parent!(scenarioproblems::ScenarioProblems{D,SD},generator::Function,parentdata::Any) where {D,SD <: AbstractScenarioData}
    generator(parentmodel(scenarioproblems),parentdata)
    nothing
end
function generate_parent!(scenarioproblems::DScenarioProblems{D,SD},generator::Function,parentdata::Any) where {D,SD <: AbstractScenarioData}
    active_workers = Vector{Future}(undef,nworkers())
    for w in workers()
        active_workers[w-1] = remotecall((sp,generator,parentdata)->generate_parent!(fetch(sp),generator,parentdata),w,scenarioproblems[w-1],generator,parentdata)
    end
    map(wait,active_workers)
    return nothing
end
function generate_stage_one!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    if haskey(stochasticprogram.ext[:SP].problemcache,:stage_1)
        # Ensure that stage_1 points to the correct model after copying
        stochasticprogram.ext[:SP].problemcache[:stage_1] = stochasticprogram
        return nothing
    end
    has_generator(stochasticprogram,:stage_1) && has_generator(stochasticprogram,:stage_1_vars) || error("First-stage problem not defined in stochastic program. Use @first_stage when defining stochastic program. Aborting.")
    generator(stochasticprogram,:stage_1)(stochasticprogram,first_stage_data(stochasticprogram))
    generate_parent!(scenarioproblems(stochasticprogram),generator(stochasticprogram,:stage_1_vars),first_stage_data(stochasticprogram))
    stochasticprogram.ext[:SP].problemcache[:stage_1] = stochasticprogram
    return nothing
end
function generate_stage_two!(scenarioproblems::ScenarioProblems{D,SD},generator::Function) where {D,SD <: AbstractScenarioData}
    for i in nsubproblems(scenarioproblems)+1:nscenarios(scenarioproblems)
        push!(scenarioproblems.problems,_stage_two_model(generator,stage_data(scenarioproblems),scenario(scenarioproblems,i),parentmodel(scenarioproblems)))
    end
    return nothing
end
function generate_stage_two!(scenarioproblems::DScenarioProblems{D,SD},generator::Function) where {D,SD <: AbstractScenarioData}
    active_workers = Vector{Future}(undef,nworkers())
    for w in workers()
        active_workers[w-1] = remotecall((sp,generator)->generate_stage_two!(fetch(sp),generator),w,scenarioproblems[w-1],generator)
    end
    map(wait,active_workers)
    return nothing
end
function generate_stage_two!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:stage_2) || error("Second-stage problem not defined in stochastic program. Use @second_stage when defining stochastic program. Aborting.")
    if nscenarios(stochasticprogram) > 0
        p = probability(stochasticprogram)
        abs(p - 1.0) <= 1e-6 || warn("Scenario probabilities do not add up to one. The probability sum is given by $p")
    end
    generate_stage_two!(scenarioproblems(stochasticprogram),generator(stochasticprogram,:stage_2))
    return nothing
end
"""
    generate!(stochasticprogram::JuMP.Model)

Generates the `stochasticprogram` after giving model definitions with @first_stage and @second_stage. The first stage model will be generated once. Second stage models will be generated for each supplied scenario structure that has not been considered yet.
"""
function generate!(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:stage_2) || error("Second-stage problem not defined in stochastic program. Use @second_stage when defining stochastic program. Aborting.")
    generate_stage_one!(stochasticprogram)
    generate_stage_two!(scenarioproblems(stochasticprogram),generator(stochasticprogram,:stage_2))
    return stochasticprogram
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
"""
    outcome_model(stochasticprogram::JuMP.Model,
                  scenario::AbstractScenarioData,
                  x::AbstractVector)

Returns the resulting second stage model if `x` is the first stage decision in scenario `ì`, in `stochasticprogram`.
"""
function outcome_model(stochasticprogram::JuMP.Model, scenario::AbstractScenarioData, x::AbstractVector,solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    has_generator(stochasticprogram,:stage_1_vars) || error("No first-stage problem generator. Consider using @first_stage or @stage 1 when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:stage_2) || error("Second-stage problem not defined in stochastic program. Aborting.")

    return _outcome_model(generator(stochasticprogram,:stage_1_vars),generator(stochasticprogram,:stage_2),first_stage_data(stochasticprogram),second_stage_data(stochasticprogram),scenario,x,solver)
end
# ========================== #
