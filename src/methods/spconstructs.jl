# SP Constructs #
# ========================== #
"""
    WS(stochasticprogram::TwoStageStochasticProgram, scenario::AbstractScenarioaData; solver = JuMP.UnsetSolver())

Generate a **wait-and-see** (`WS`) model of the two-stage `stochasticprogram`, corresponding to `scenario`.

In other words, generate the first stage and the second stage of the `stochasticprogram` as if `scenario` is known to occur. Optionally, a capable `solver` can be supplied to `WS`. Otherwise, any previously set solver will be used.

See also: [`DEP`](@ref), [`EVP`](@ref)
"""
function WS(stochasticprogram::StochasticProgram{2}, scenario::AbstractScenario; solver::SPSolverType = JuMP.UnsetSolver())
    # Use cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Check that the required generators have been defined
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Consider @stage 2.")
    # Return WS model
    return _WS(generator(stochasticprogram,:stage_1), generator(stochasticprogram,:stage_2), stage_parameters(stochasticprogram, 1), stage_parameters(stochasticprogram, 2), scenario, internal_solver(supplied_solver))
end
function _WS(stage_one_generator::Function,
             stage_two_generator::Function,
             stage_one_params::Any,
             stage_two_params::Any,
             scenario::AbstractScenario,
             solver::MathProgBase.AbstractMathProgSolver)
    ws_model = Model(solver = solver)
    stage_one_generator(ws_model, stage_one_params)
    ws_obj = copy(ws_model.obj)
    stage_two_generator(ws_model, stage_two_params, scenario, ws_model)
    append!(ws_obj, ws_model.obj)
    ws_model.obj = ws_obj
    return ws_model
end
"""
    WS_decision(stochasticprogram::TwoStageStochasticProgram, scenario::AbstractScenario; solver = JuMP.UnsetSolver())

Calculate the optimizer of the **wait-and-see** (`WS`) model of the two-stage `stochasticprogram`, corresponding to `scenario`.

Optionally, supply a capable `solver` to solve the wait-and-see problem. The default behaviour is to rely on any previously set solver.

See also: [`WS`](@ref)
"""
function WS_decision(stochasticprogram::StochasticProgram{2}, scenario::AbstractScenario; solver::SPSolverType = JuMP.UnsetSolver())
    # Solve WS model for supplied scenario
    ws_model = WS(stochasticprogram, scenario, solver = solver)
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
function EWS(stochasticprogram::StochasticProgram{2}; solver::SPSolverType = JuMP.UnsetSolver())
    # Use cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Abort if no solver was given
    if isa(supplied_solver, JuMP.UnsetSolver)
        error("Cannot determine EWS without a solver.")
    end
    # Solve all possible WS models and compute EWS
    return _EWS(stochasticprogram, internal_solver(supplied_solver))
end
function _EWS(stochasticprogram::TwoStageStochasticProgram{S,SP}, solver::MathProgBase.AbstractMathProgSolver) where {S, SP <: ScenarioProblems}
    return sum([begin
                ws = _WS(stochasticprogram.generator[:stage_1],
                         stochasticprogram.generator[:stage_2],
                         stage_parameters(stochasticprogram, 1),
                         stage_parameters(stochasticprogram, 2),
                         scenario,
                         solver)
                solve(ws)
                probability(scenario)*getobjectivevalue(ws)
                end for scenario in scenarios(stochasticprogram.scenarioproblems)])
end
function _EWS(stochasticprogram::TwoStageStochasticProgram{S,SP}, solver::MathProgBase.AbstractMathProgSolver) where {S, SP <: DScenarioProblems}
    partial_ews = Vector{Float64}(undef, nworkers())
    @sync begin
        for (i,w) in enumerate(workers())
            @async partial_ews[i] = remotecall_fetch((sp,stage_one_generator,stage_two_generator,stage_one_params,stage_two_params,solver)->begin
                scenarioproblems = fetch(sp)
                isempty(scenarioproblems.scenarios) && return 0.0
                return sum([begin
                            ws = _WS(stage_one_generator,
                                     stage_two_generator,
                                     stage_one_params,
                                     stage_two_params,
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
                stage_parameters(stochasticprogram, 1),
                stage_parameters(stochasticprogram, 2),
                solver)
        end
    end
    return sum(partial_ews)
end
"""
    SAA(stochasticmodel::StochasticModel, sampler::AbstractSampler, n::Integer; solver = JuMP.UnsetSolver())

Generate a **sample average approximation** (`SAA`) instance of size `n` using the model stored in the two-stage `stochasticmodel`, and the provided `sampler`.

Optionally, a capable `solver` can be supplied to `SAA`. Otherwise, any previously set solver will be used.

See also: [`sample!`](@ref)
"""
function SAA(sm::StochasticModel{2}, sampler::AbstractSampler{S}, n::Integer; solver::SPSolverType = JuMP.UnsetSolver(), procs = workers(), defer = false, kw...) where S <: AbstractScenario
    # Create new stochastic program instance
    saa = StochasticProgram(parameters(sm.parameters[1]; kw...),
                            parameters(sm.parameters[2]; kw...),
                            S,
                            solver,
                            procs)
    sm.generator(saa)
    # Sample n scenarios
    add_scenarios!(saa, n, defer = defer) do
        return sample(sampler, 1/n)
    end
    # Return the SAA instance
    return saa
end
function SAA(sm::StochasticModel{2}, sampler::AbstractSampler{S}, n::Integer; solver::SPSolverType = JuMP.UnsetSolver(), procs = workers(), defer = false, kw...) where S <: Scenario
    # Create new stochastic program instance
    saa = StochasticProgram(parameters(sm.parameters[1]; kw...),
                            parameters(sm.parameters[2]; kw...),
                            typeof(sample(sampler)),
                            solver,
                            procs)
    sm.generator(saa)
    # Sample n scenarios
    add_scenarios!(saa, n, defer = defer) do
        return sample(sampler, 1/n)
    end
    # Return the SAA instance
    return saa
end
function SAA(sm::StochasticModel{2}, sampler::AbstractSampler{S}, solution::StochasticSolution; solver::SPSolverType = JuMP.UnsetSolver(), procs = workers(), defer = false, kw...) where S <: AbstractScenario
    if isa(solver, JuMP.UnsetSolver)
        error("Cannot generate SAA from stochastic solution without a solver.")
    end
    n = 16
    CI = confidence_interval(solution)
    α = 1 - confidence(CI)
    while !(confidence_interval(sm, sampler; solver = solver, N = n, M = M, confidence = 1-α) ⊆ CI)
        n = n * 2
    end
    return SAA(sm, sampler, n; solver = solver, procs = procs, defer = defer)
end
"""
    DEP(stochasticprogram::TwoStageStochasticProgram; solver = JuMP.UnsetSolver())

Generate the **deterministically equivalent problem** (`DEP`) of the two-stage `stochasticprogram`.

In other words, generate the extended form the `stochasticprogram` as a single JuMP model. Optionally, a capable `solver` can be supplied to `DEP`. Otherwise, any previously set solver will be used.

See also: [`VRP`](@ref), [`WS`](@ref)
"""
function DEP(stochasticprogram::StochasticProgram{2}; solver::SPSolverType = JuMP.UnsetSolver())
    # Use cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:dep)
        dep = cache[:dep]
        setsolver(dep, supplied_solver)
        return dep
    end
    # Check that the required generators have been defined
    has_generator(stochasticprogram, :stage_1) || error("First-stage problem not defined in stochastic program. Consider @stage 1.")
    has_generator(stochasticprogram, :stage_2) || error("Second-stage problem not defined in stochastic program. Consider @stage 2.")
    # Define first-stage problem
    dep_model = Model(solver = internal_solver(supplied_solver))
    generator(stochasticprogram,:stage_1)(dep_model, stage_parameters(stochasticprogram, 1))
    dep_obj = copy(dep_model.obj)
    # Define second-stage problems, renaming variables according to scenario.
    stage_two_params = stage_parameters(stochasticprogram, 2)
    visited_objs = collect(keys(dep_model.objDict))
    for (i, scenario) in enumerate(scenarios(stochasticprogram))
        generator(stochasticprogram,:stage_2)(dep_model, stage_two_params, scenario, dep_model)
        append!(dep_obj,probability(scenario)*dep_model.obj)
        for (objkey,obj) ∈ filter(kv->kv.first ∉ visited_objs, dep_model.objDict)
            newkey = if isa(obj,JuMP.Variable)
                varname = add_subscript(dep_model.colNames[obj.col], i)
                dep_model.colNames[obj.col] = varname
                dep_model.colNamesIJulia[obj.col] = varname
                newkey = Symbol(varname)
            elseif isa(obj,Array{JuMP.Variable})
                JuMP.fill_var_names(JuMP.REPLMode, dep_model.colNames, obj)
                arrayname = add_subscript(objkey, i)
                for var in obj
                    splitname = split(dep_model.colNames[var.col],"[")
                    varname = @sprintf("%s[%s", add_subscript(splitname[1],i), splitname[2])
                    dep_model.colNames[var.col] = varname
                    dep_model.colNamesIJulia[var.col] = varname
                end
                newkey = Symbol(arrayname)
            elseif isa(obj,JuMP.ConstraintRef)
                arrayname = add_subscript(objkey, i)
                newkey = Symbol(arrayname)
            elseif isa(obj,Array{ConstraintRef})
                arrayname = add_subscript(objkey, i)
                newkey = Symbol(arrayname)
            elseif isa(obj,JuMP.JuMPArray)
                newkey = if isa(obj,JuMP.JuMPArray{JuMP.ConstraintRef})
                    arrayname = add_subscript(objkey, i)
                    newkey = Symbol(arrayname)
                else
                    JuMP.fill_var_names(JuMP.REPLMode, dep_model.colNames, obj)
                    arrayname = add_subscript(dep_model.varData[obj].name, i)
                    newkey = Symbol(arrayname)
                    dep_model.varData[obj].name = newkey
                    for var in obj.innerArray
                        splitname = split(dep_model.colNames[var.col],"[")
                        varname = @sprintf("%s[%s", add_subscript(splitname[1],i), splitname[2])
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
function VRP(stochasticprogram::StochasticProgram; solver::SPSolverType = JuMP.UnsetSolver())
    # Solve DEP
    optimize!(stochasticprogram, solver = solver)
    # Return optimal value
    return optimal_value(stochasticprogram)
end
"""
    EVPI(stochasticprogram::TwoStageStochasticProgram; solver = JuMP.UnsetSolver())

Calculate the **expected value of perfect information** (`EVPI`) of the two-stage `stochasticprogram`.

In other words, calculate the gap between `VRP` and `EWS`. Optionally, supply a capable `solver` to solve the intermediate problems. Otherwise, any previously set solver will be used.

See also: [`VRP`](@ref), [`EWS`](@ref), [`VSS`](@ref)
"""
function EVPI(stochasticprogram::StochasticProgram{2}; solver::SPSolverType = JuMP.UnsetSolver())
    # Use cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Abort if no solver was given
    if isa(supplied_solver, JuMP.UnsetSolver)
        error("Cannot determine EVPI without a solver.")
    end
    # Calculate VRP
    vrp = VRP(stochasticprogram, solver=supplied_solver)
    # Solve all possible WS models and calculate EWS
    ews = _EWS(stochasticprogram, internal_solver(supplied_solver))
    # Return EVPI = EWS-VRP
    return abs(ews-vrp)
end
"""
    EVP(stochasticprogram::TwoStageStochasticProgram; solver = JuMP.UnsetSolver())

Generate the **expected value problem** (`EVP`) of the two-stage `stochasticprogram`.

In other words, generate a wait-and-see model corresponding to the expected scenario over all available scenarios in `stochasticprogram`. Optionally, supply a capable `solver` to `EVP`. Otherwise, any previously set solver will be used.

See also: [`EVP_decision`](@ref), [`EEV`](@ref), [`EV`](@ref), [`WS`](@ref)
"""
function EVP(stochasticprogram::StochasticProgram{2}; solver::SPSolverType = JuMP.UnsetSolver())
    # Use cached solver if available
    supplied_solver = pick_solver(stochasticprogram, solver)
    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:evp)
        evp = cache[:evp]
        setsolver(evp, supplied_solver)
        return evp
    end
    # Create EVP as a wait-and-see model of the expected scenario
    ev_model = WS(stochasticprogram, expected(stochasticprogram), solver = solver)
    # Cache EVP
    cache[:evp] = ev_model
    # Return EVP
    return ev_model
end
"""
    EVP_decision(stochasticprogram::TwoStageStochasticProgram; solver = JuMP.UnsetSolver())

Calculate the optimizer of the `EVP` of the two-stage `stochasticprogram`.

Optionally, supply a capable `solver` to solve the expected value problem. The default behaviour is to rely on any previously set solver.

See also: [`EVP`](@ref), [`EV`](@ref), [`EEV`](@ref)
"""
function EVP_decision(stochasticprogram::StochasticProgram{2}; solver::SPSolverType = JuMP.UnsetSolver())
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
    EV(stochasticprogram::TwoStageStochasticProgram; solver = JuMP.UnsetSolver())

Calculate the optimal value of the `EVP` of the two-stage `stochasticprogram`.

Optionally, supply a capable `solver` to solve the expected value problem. The default behaviour is to rely on any previously set solver.

See also: [`EVP`](@ref), [`EVP_decision`](@ref), [`EEV`](@ref)
"""
function EV(stochasticprogram::StochasticProgram{2}; solver::SPSolverType = JuMP.UnsetSolver())
    # Solve EVP model
    evp = EVP(stochasticprogram; solver = solver)
    solve(evp)
    # Return optimal value
    return getobjectivevalue(evp)
end
"""
    EEV(stochasticprogram::TwoStageStochasticProgram; solver = JuMP.UnsetSolver())

Calculate the **expected value of using the expected value solution** (`EEV`) of the two-stage `stochasticprogram`.

In other words, evaluate the `EVP` decision. Optionally, supply a capable `solver` to solve the intermediate problems. The default behaviour is to rely on any previously set solver.

See also: [`EVP`](@ref), [`EV`](@ref)
"""
function EEV(stochasticprogram::StochasticProgram{2}; solver::SPSolverType = JuMP.UnsetSolver())
    # Solve EVP model
    evp_decision = EVP_decision(stochasticprogram; solver = solver)
    # Calculate EEV by evaluating the EVP decision
    eev = evaluate_decision(stochasticprogram, evp_decision; solver = solver)
    # Return EEV
    return eev
end
"""
    VSS(stochasticprogram::TwoStageStochasticProgram; solver = JuMP.UnsetSolver())

Calculate the **value of the stochastic solution** (`VSS`) of the two-stage `stochasticprogram`.

In other words, calculate the gap between `EEV` and `VRP`. Optionally, supply a capable `solver` to solve the intermediate problems. The default behaviour is to rely on any previously set solver.
"""
function VSS(stochasticprogram::StochasticProgram{2}; solver::SPSolverType = JuMP.UnsetSolver())
    # Solve EVP and determine EEV
    eev = EEV(stochasticprogram; solver = solver)
    # Calculate VRP
    vrp = VRP(stochasticprogram; solver = solver)
    # Return VSS = VRP-EEV
    return abs(vrp-eev)
end
# ========================== #
