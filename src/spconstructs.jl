# SP Constructs #
# ========================== #
function _WS(stage_one_generator::Function,
             stage_two_generator::Function,
             common::Any,
             scenario::AbstractScenarioData,
             solver::MathProgBase.AbstractMathProgSolver)
    ws_model = Model(solver = solver)
    stage_one_generator(ws_model,common)
    ws_obj = copy(ws_model.obj)
    stage_two_generator(ws_model,common,scenario,ws_model)
    append!(ws_obj,ws_model.obj)
    ws_model.obj = ws_obj

    return ws_model
end

WS(stochasticprogram::JuMP.Model,scenario::AbstractScenarioData) = WS(stochasticprogram,scenario,JuMP.UnsetSolver())
function WS(stochasticprogram::JuMP.Model, scenario::AbstractScenarioData, solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot create WS model without a solver.")
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    return _WS(generator(stochasticprogram,:first_stage),generator(stochasticprogram,:second_stage),common(stochasticprogram),scenario,optimsolver)
end

function _EWS(stochasticprogram::StochasticProgramData{D,SD,S,ScenarioProblems{D,SD,S}},
              solver::MathProgBase.AbstractMathProgSolver) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return sum([begin
                ws = _WS(stochasticprogram.generator[:first_stage],
                         stochasticprogram.generator[:second_stage],
                         common(stochasticprogram.scenarioproblems),
                         scenario,
                         solver)
                solve(ws)
                probability(scenario)*getobjectivevalue(ws)
                end for scenario in scenarios(stochasticprogram.scenarioproblems)])
end

function _EWS(stochasticprogram::StochasticProgramData{D,SD,S,DScenarioProblems{D,SD,S}},
              solver::MathProgBase.AbstractMathProgSolver) where {D, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    finished_workers = Vector{Future}(length(stochasticprogram.scenarioproblems))
    for p in 1:length(stochasticprogram.scenarioproblems)
        finished_workers[p] = remotecall((sp,stage_one_generator,stage_two_generator,solver)->begin
                                         scenarioproblems = fetch(sp)
                                         isempty(scenarioproblems.scenariodata) && return 0.0
                                         return sum([begin
                                                     ws = _WS(stage_one_generator,
                                                              stage_two_generator,
                                                              common(scenarioproblems),
                                                              scenario,
                                                              solver)
                                                     solve(ws)
                                                     probability(scenario)*getobjectivevalue(ws)
                                                     end for scenario in scenarioproblems.scenariodata])
                                         end,
                                         p+1,
                                         stochasticprogram.scenarioproblems[p],
                                         stochasticprogram.generator[:first_stage],
                                         stochasticprogram.generator[:second_stage],
                                         solver)
    end
    map(wait,finished_workers)
    return sum(fetch.(finished_workers))
end

function EWS(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end

    # Solve all possible WS models and compute EWS
    return _EWS(stochastic(stochasticprogram),optimsolver)
end

DEP(stochasticprogram::JuMP.Model) = DEP(stochasticprogram,JuMP.UnsetSolver())
function DEP(stochasticprogram::JuMP.Model, solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:dep)
        return cache[:dep]
    end
    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end
    # Abort at this stage if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot create new DEP model without a solver.")
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    # Define first-stage problem
    dep_model = Model(solver = optimsolver)
    generator(stochasticprogram,:first_stage)(dep_model,common(stochasticprogram))
    dep_obj = copy(dep_model.obj)

    # Define second-stage problems, renaming variables according to scenario.
    visited_objs = collect(keys(dep_model.objDict))
    for (i,scenario) in enumerate(scenarios(stochasticprogram))
        generator(stochasticprogram,:second_stage)(dep_model,common(stochasticprogram),scenario,dep_model)
        append!(dep_obj,probability(scenario)*dep_model.obj)
        for (objkey,obj) ∈ dep_model.objDict
            if objkey ∉ visited_objs
                newkey = if (isa(obj,JuMP.Variable))
                    varname = @sprintf("%s_%d",dep_model.colNames[obj.col],i)
                    dep_model.colNames[obj.col] = varname
                    dep_model.colNamesIJulia[obj.col] = varname
                    newkey = Symbol(varname)
                elseif isa(obj,JuMP.ConstraintRef)
                    arrayname = @sprintf("%s_%d",objkey,i)
                    newkey = Symbol(arrayname)
                elseif isa(obj,JuMP.JuMPArray)
                    newkey = if isa(obj,JuMP.JuMPArray{JuMP.ConstraintRef})
                        arrayname = @sprintf("%s_%d",objkey,i)
                        newkey = Symbol(arrayname)
                    else
                        JuMP.fill_var_names(JuMP.REPLMode, dep_model.colNames, obj)
                        arrayname = @sprintf("%s_%d",dep_model.varData[obj].name,i)
                        newkey = Symbol(arrayname)
                        dep_model.varData[obj].name = newkey
                        for var in obj.innerArray
                            splitname = split(dep_model.colNames[var.col],"[")
                            varname = @sprintf("%s_%d[%s",splitname[1],i,splitname[2])
                            dep_model.colNames[var.col] = varname
                            dep_model.colNamesIJulia[var.col] = varname
                        end
                        newkey
                    end
                 else
                    continue
                end
                dep_model.objDict[newkey] = obj
                delete!(dep_model.objDict,objkey)
                push!(visited_objs,newkey)
            end
        end
    end
    dep_model.obj = dep_obj

    # Cache dep model
    cache[:dep] = dep_model

    return dep_model
end

function RP(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end

    # Solve EVP model
    solve(stochasticprogram)

    return getobjectivevalue(stochasticprogram)
end

function EVPI(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end

    # Solve DEP model
    solve(stochasticprogram)
    evpi = getobjectivevalue(stochasticprogram)

    # Solve all possible WS models
    evpi -= EWS(stochasticprogram)

    return evpi
end

EVP(stochasticprogram::JuMP.Model) = EVP(stochasticprogram,JuMP.UnsetSolver())
function EVP(stochasticprogram::JuMP.Model, solver::MathProgBase.AbstractMathProgSolver)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")
    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:evp)
        return cache[:evp]
    end
    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end
    # Abort at this stage if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot create new EVP model without a solver.")
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    ev_model = Model(solver = optimsolver)
    generator(stochasticprogram,:first_stage)(ev_model,common(stochasticprogram))
    ev_obj = copy(ev_model.obj)
    generator(stochasticprogram,:second_stage)(ev_model,common(stochasticprogram),expected(scenarios(stochasticprogram)),ev_model)
    append!(ev_obj,ev_model.obj)
    ev_model.obj = ev_obj

    # Cache evp model
    cache[:evp] = ev_model

    return ev_model
end

function EV(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end

    # Solve EVP model
    evp = EVP(stochasticprogram, solver)
    solve(evp)

    return getobjectivevalue(evp)
end

function EEV(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot evaluate decision without a solver.")
    end

    # Solve EVP model
    evp = EVP(stochasticprogram,optimsolver)
    solve(evp)

    eev = _eval(stochasticprogram,evp.colVal[1:stochasticprogram.numCols],optimsolver)

    return eev
end

function VSS(stochasticprogram::JuMP.Model; solver::MathProgBase.AbstractMathProgSolver = JuMP.UnsetSolver())
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Prefer cached solver if available
    optimsolver = if stochasticprogram.solver isa JuMP.UnsetSolver || !(stochasticprogram.solver isa MathProgBase.AbstractMathProgSolver)
        solver
    else
        stochasticprogram.solver
    end

    # Abort if no solver was given
    if isa(optimsolver,JuMP.UnsetSolver)
        error("Cannot evaluate decision without a solver.")
    end

    # Solve EVP and determine EEV
    vss = EEV(stochasticprogram; solver = optimsolver)

    # Solve DEP model
    solve(stochasticprogram)
    vss -= getobjectivevalue(stochasticprogram)

    return vss
end
# ========================== #
