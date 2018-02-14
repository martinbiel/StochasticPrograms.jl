function DEP(model::JuMP.Model)
    haskey(model.ext,:SP) || error("The given model is not a stochastic program.")

    cache = problemcache(model)
    if haskey(cache,:dep)
        dep = cache[:dep]
        if dep.numCols == model.numCols && length(dep.linconstr) == length(model.linconstr)
            return cache[:dep]
        end
    end

    dep_model = extract_firststage(model)

    dim = model.numCols
    for (i,subproblem) in enumerate(subproblems(model))
        subdim = subproblem.numCols
        append!(dep_model.colNames,fill(string(),subdim))
        append!(dep_model.colNamesIJulia,fill(string(),subdim))
        append!(dep_model.colLower,zeros(Float64,subdim))
        append!(dep_model.colUpper,zeros(Float64,subdim))
        append!(dep_model.colCat,fill(Symbol(),subdim))
        append!(dep_model.colVal,fill(NaN,subproblem.numCols))
        dep_model.numCols += subdim
        # Subobjective
        subobjective = copy(subproblem.obj)
        aff = subobjective.aff
        for (j,var) in enumerate(aff.vars)
            aff.vars[j] = Variable(dep_model,var.col+dim)
            aff.coeffs[j] *= probability(model,i)
            name = @sprintf("%s_%d",subproblem.colNames[var.col],i)
            dep_model.colNames[var.col+dim] = name
            dep_model.objDict[Symbol(name)] = aff.vars[j]
            dep_model.colNamesIJulia[var.col+dim] = @sprintf("%s_%d",subproblem.colNamesIJulia[var.col],i)
            dep_model.colLower[var.col+dim] = subproblem.colLower[var.col]
            dep_model.colUpper[var.col+dim] = subproblem.colUpper[var.col]
            dep_model.colCat[var.col+dim] = subproblem.colCat[var.col]
        end
        append!(dep_model.obj,subobjective)
        # Subconstraints
        for constr in subproblem.linconstr
            terms = copy(constr.terms)
            for (j,var) in enumerate(terms.vars)
                if var.m == subproblem
                    terms.vars[j] = Variable(dep_model,var.col+dim)
                    name = @sprintf("%s_%d",subproblem.colNames[var.col],i)
                    dep_model.colNames[var.col+dim] = name
                    dep_model.colNamesIJulia[var.col+dim] = @sprintf("%s_%d",subproblem.colNamesIJulia[var.col],i)
                    dep_model.objDict[Symbol(name)] = terms.vars[j]
                    dep_model.colLower[var.col+dim] = subproblem.colLower[var.col]
                    dep_model.colUpper[var.col+dim] = subproblem.colUpper[var.col]
                    dep_model.colCat[var.col+dim] = subproblem.colCat[var.col]
                    dep_model
                else
                    terms.vars[j] = Variable(dep_model,var.col)
                end
            end
            push!(dep_model.linconstr,LinearConstraint(terms,constr.lb,constr.ub))
        end

        dim += subproblem.numCols
    end

    # Cache dep model
    cache[:dep] = dep_model

    return dep_model
end
