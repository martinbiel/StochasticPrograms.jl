# SP Constructs #
# ========================== #
"""
    WS(stochasticprogram::StochasticProgram, scenario::AbstractScenarioaDta; solver = JuMP.UnsetSolver())

Generate a **wait-and-see** (`WS`) model of the `stochasticprogram`, corresponding to `scenario`.

In other words, generate the first stage and the second stage of the `stochasticprogram` as if `scenario` is known to occur. Optionally, a capable `solver` can be supplied to `WS`. Otherwise, any previously set solver will be used.

See also: [`DEP`](@ref), [`EVP`](@ref)
"""
function WS(stochasticprogram::StochasticProgram, scenario::AbstractScenarioData; solver = JuMP.UnsetSolver())
    # Use cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Abort if no solver was given
    if isa(supplied_solver, JuMP.UnsetSolver)
        error("Cannot create WS model without a solver.")
    end
    # Check that the required generators have been defined
    has_generator(stochasticprogram, :stage_1) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Aborting.")
    # Return WS model
    return _WS(generator(stochasticprogram,:stage_1), generator(stochasticprogram,:stage_2), first_stage_data(stochasticprogram), second_stage_data(stochasticprogram), scenario, internal_solver(supplied_solver))
end
function _WS(stage_one_generator::Function,
             stage_two_generator::Function,
             first_stage::Any,
             second_stage::Any,
             scenario::AbstractScenarioData,
             solver::MathProgBase.AbstractMathProgSolver)
    ws_model = Model(solver = solver)
    stage_one_generator(ws_model, first_stage)
    ws_obj = copy(ws_model.obj)
    stage_two_generator(ws_model, second_stage, scenario, ws_model)
    append!(ws_obj, ws_model.obj)
    ws_model.obj = ws_obj
    return ws_model
end
function WS_decision(stochasticprogram::StochasticProgram, scenario::AbstractScenarioData; solver = JuMP.UnsetSolver())
    # Solve WS model for supplied scenario
    ws_model = WS(stochasticprogram, scenario, solver)
    solve(ws_model)
    # Return WS decision
    decision = ws_model.colVal[1:decision_length(stochasticprogram)]
    if any(isnan.(decision))
        warn("Optimal decision not defined. Check that the EVP model was properly solved.")
    end
    return decision
end
"""
    EWS(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())

Calculate the **expected wait-and-see result** (`EWS`) of the `stochasticprogram`.

In other words, calculate the expectated result of all possible wait-and-see models, using the provided scenarios in `stochasticprogram`. Optionally, a capable `solver` can be supplied to solve the intermediate problems. Otherwise, any previously set solver will be used.

See also: [`VRP`](@ref), [`WS`](@ref)
"""
function EWS(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())
    # Use cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Abort if no solver was given
    if isa(supplied_solver, JuMP.UnsetSolver)
        error("Cannot determine EWS without a solver.")
    end
    # Solve all possible WS models and compute EWS
    return _EWS(stochasticprogram, internal_solver(supplied_solver))
end
function _EWS(stochasticprogram::StochasticProgram{D1,D2,SD,S,ScenarioProblems{D2,SD,S}},
              solver::MathProgBase.AbstractMathProgSolver) where {D1, D2, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    return sum([begin
                ws = _WS(stochasticprogram.generator[:stage_1],
                         stochasticprogram.generator[:stage_2],
                         stochasticprogram.first_stage.data,
                         stage_data(stochasticprogram.scenarioproblems),
                         scenario,
                         solver)
                solve(ws)
                probability(scenario)*getobjectivevalue(ws)
                end for scenario in scenarios(stochasticprogram.scenarioproblems)])
end
function _EWS(stochasticprogram::StochasticProgram{D1,D2,SD,S,DScenarioProblems{D2,SD,S}},
              solver::MathProgBase.AbstractMathProgSolver) where {D1, D2, SD <: AbstractScenarioData, S <: AbstractSampler{SD}}
    active_workers = Vector{Future}(undef, nworkers())
    for w in workers()
        active_workers[w-1] = remotecall((sp,stage_one_generator,stage_two_generator,first_stage,second_stage,solver)->begin
                                         scenarioproblems = fetch(sp)
                                         isempty(scenarioproblems.scenarios) && return 0.0
                                         return sum([begin
                                                     ws = _WS(stage_one_generator,
                                                              stage_two_generator,
                                                              first_stage,
                                                              second_stage,
                                                              scenario,
                                                              solver)
                                                     solve(ws)
                                                     probability(scenario)*getobjectivevalue(ws)
                                                     end for scenario in scenarioproblems.scenarios])
                                         end,
                                         w,
                                         stochasticprogram.scenarioproblems[w-1],
                                         stochasticprogram.generator[:stage_1],
                                         stochasticprogram.generator[:stage_2],
                                         stochasticprogram.first_stage.data,
                                         stage_data(stochasticprogram.scenarioproblems),
                                         solver)
    end
    map(wait, active_workers)
    return sum(fetch.(active_workers))
end
"""
    DEP(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())

Generate the **deterministically equivalent problem** (`DEP`) of the `stochasticprogram`.

In other words, generate the extended form the `stochasticprogram` as a single JuMP model. Optionally, a capable `solver` can be supplied to `DEP`. Otherwise, any previously set solver will be used.

See also: [`VRP`](@ref), [`WS`](@ref)
"""
function DEP(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())
    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:dep)
        return cache[:dep]
    end
    # Use cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Abort at this stage if no solver was given
    if isa(supplied_solver, JuMP.UnsetSolver)
        error("Cannot create new DEP model without a solver.")
    end
    # Check that the required generators have been defined
    has_generator(stochasticprogram, :stage_1) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Aborting.")
    # Define first-stage problem
    dep_model = Model(solver = internal_solver(supplied_solver))
    generator(stochasticprogram,:stage_1)(dep_model, first_stage_data(stochasticprogram))
    dep_obj = copy(dep_model.obj)
    # Define second-stage problems, renaming variables according to scenario.
    second_stage = second_stage_data(stochasticprogram)
    visited_objs = collect(keys(dep_model.objDict))
    for (i, scenario) in enumerate(scenarios(stochasticprogram))
        generator(stochasticprogram,:stage_2)(dep_model, second_stage, scenario, dep_model)
        append!(dep_obj,probability(scenario)*dep_model.obj)
        for (objkey,obj) ∈ filter(kv->kv.first ∉ visited_objs, dep_model.objDict)
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
    dep_model.obj = dep_obj
    # Cache DEP
    cache[:dep] = dep_model
    # Return DEP
    return dep_model
end
"""
    VRP(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())

Calculate the **value of the recouse problem** (`VRP`) in `stochasticprogram`.

In other words, optimize the stochastic program and return the optimal value. Optionally, supply a capable `solver` to optimize the stochastic program. Otherwise, any previously set solver will be used.

See also: [`EVPI`](@ref), [`EWS`](@ref)
"""
function VRP(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())
    # Solve DEP
    optimize!(stochasticprogram, solver=solver)
    # Return optimal value
    return optimal_value(stochasticprogram)
end
"""
    EVPI(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())

Calculate the **expected value of perfect information** (`EVPI`) of the `stochasticprogram`.

In other words, calculate the gap between `VRP` and `EWS`. Optionally, supply a capable `solver` to solve the intermediate problems. Otherwise, any previously set solver will be used.

See also: [`VRP`](@ref), [`EWS`](@ref), [`VSS`](@ref)
"""
function EVPI(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())
    # Use cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Abort if no solver was given
    if isa(supplied_solver, JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end
    # Solve DEP
    evpi = VRP(stochasticprogram, solver=supplied_solver)
    # Solve all possible WS models and calculate EVPI = VRP-EWS
    evpi -= _EWS(stochasticprogram, internal_solver(supplied_solver))
    # Return EVPI
    return evpi
end
"""
    EVP(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())

Generate the **expected value problem** (`EVP`) in `stochasticprogram`.

In other words, generate a wait-and-see model corresponding to the expected scenario over all available scenarios in `stochasticprogram`. Optionally, supply a capable `solver` to `EVP`. Otherwise, any previously set solver will be used.

See also: [`EVP_decision`](@ref), [`EEV`](@ref), [`EV`](@ref), [`WS`](@ref)
"""
function EVP(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())
    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:evp)
        return cache[:evp]
    end
    # Create EVP as a wait-and-see model of the expected scenario
    ev_model = WS(stochasticprogram, expected(stochasticprogram), solver = solver)
    # Cache EVP
    cache[:evp] = ev_model
    # Return EVP
    return ev_model
end
"""
    EVP_decision(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())

Calculate the optimizer of the `EVP` in `stochasticprogram`.

Optionally, supply a capable `solver` to solve the expected value problem. The default behaviour is to rely on any previously set solver.

See also: [`EVP`](@ref), [`EV`](@ref), [`EEV`](@ref)
"""
function EVP_decision(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())
    # Solve EVP
    evp = EVP(stochasticprogram, solver = solver)
    solve(evp)
    # Return EVP decision
    decision = evp.colVal[1:decision_length(stochasticprogram)]
    if any(isnan.(decision))
        warn("Optimal decision not defined. Check that the EVP model was properly solved.")
    end
    return decision
end
"""
    EV(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())

Calculate the optimal value of the `EVP` in `stochasticprogram`.

Optionally, supply a capable `solver` to solve the expected value problem. The default behaviour is to rely on any previously set solver.

See also: [`EVP`](@ref), [`EVP_decision`](@ref), [`EEV`](@ref)
"""
function EV(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())
    # Solve EVP model
    evp = EVP(stochasticprogram; solver = solver)
    solve(evp)
    # Return optimal value
    return getobjectivevalue(evp)
end
"""
    EEV(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())

Calculate the **expected value of using the expected value solution** (`EEV`) in `stochasticprogram`.

In other words, evaluate the `EVP` decision. Optionally, supply a capable `solver` to solve the intermediate problems. The default behaviour is to rely on any previously set solver.

See also: [`EVP`](@ref), [`EV`](@ref)
"""
function EEV(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())
    # Solve EVP model
    evp_decision = EVP_decision(stochasticprogram; solver = solver)
    # Calculate EEV by evaluating the EVP decision
    eev = evaluate_decision(stochasticprogram, evp_decision; solver = solver)
    # Return EEV
    return eev
end
"""
    VSS(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())

Calculate the **value of the stochastic solution** (`VSS`) of the `stochasticprogram`.

In other words, calculate the gap between `EEV` and `VRP`. Optionally, supply a capable `solver` to solve the intermediate problems. The default behaviour is to rely on any previously set solver.
"""
function VSS(stochasticprogram::StochasticProgram; solver = JuMP.UnsetSolver())
    # Solve EVP and determine EEV
    vss = EEV(stochasticprogram; solver = solver)
    # Calculate VSS as EEV-VRP
    vss -= VRP(stochasticprogram; solver = solver)
    # Return VSS
    return vss
end
# ========================== #
