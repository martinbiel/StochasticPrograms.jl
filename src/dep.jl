function DEP(stochasticprogram::JuMP.Model)
    haskey(stochasticprogram.ext,:SP) || error("The given model is not a stochastic program.")

    # Return possibly cached model
    cache = problemcache(stochasticprogram)
    if haskey(cache,:dep)
        return cache[:dep]
    end

    has_generator(stochasticprogram,:first_stage) || error("No first-stage problem generator. Consider using @first_stage when defining stochastic program. Aborting.")
    has_generator(stochasticprogram,:second_stage) || error("Second-stage problem not defined in stochastic program. Aborting.")

    # Define first-stage problem
    dep_model = Model()
    generator(stochasticprogram,:first_stage)(dep_model)
    dep_obj = copy(dep_model.obj)

    # Define second-stage problems, renaming variables according to scenario.
    visited_vars = collect(keys(dep_model.objDict))
    for (i,scenario) in enumerate(scenarios(stochasticprogram))
        generator(stochasticprogram,:second_stage)(dep_model,scenario,dep_model)
        append!(dep_obj,probability(stochasticprogram,i)*dep_model.obj)
        for (varkey,var) ∈ dep_model.objDict
            if varkey ∉ visited_vars
                varname = @sprintf("%s_%d",dep_model.colNames[var.col],i)
                newkey = Symbol(varname)
                dep_model.colNames[var.col] = varname
                dep_model.colNamesIJulia[var.col] = varname
                dep_model.objDict[newkey] = var
                delete!(dep_model.objDict,varkey)
                push!(visited_vars,newkey)
            end
        end
    end
    dep_model.obj = dep_obj

    # Cache dep model
    cache[:dep] = dep_model

    return dep_model
end
