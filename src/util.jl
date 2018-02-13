function extract_firststage(src::JuMP.Model)
    @assert haskey(src.ext,:SP) "The given model is not a stochastic program."

    # Minimal copy of firststage part of structured problem
    firststage = Model()

    # Objective
    firststage.obj = copy(src.obj, firststage)
    firststage.objSense = src.objSense

    # Constraint
    firststage.linconstr  = map(c->copy(c, firststage), src.linconstr)

    # Variables
    firststage.numCols = src.numCols
    firststage.colNames = src.colNames[:]
    firststage.colNamesIJulia = src.colNamesIJulia[:]
    firststage.colLower = src.colLower[:]
    firststage.colUpper = src.colUpper[:]
    firststage.colCat = src.colCat[:]
    firststage.colVal = src.colVal[:]

    # Variable dicts
    firststage.objDict = Dict{Symbol,Any}()
    firststage.varData = ObjectIdDict()
    for (symb,o) in src.objDict
        newo = copy(o, firststage)
        firststage.objDict[symb] = newo
        if haskey(src.varData, o)
            firststage.varData[newo] = src.varData[o]
        end
    end

    if !isempty(firststage.colNames) && firststage.colNames[1] == ""
        for varFamily in firststage.dictList
            JuMP.fill_var_names(JuMP.REPLMode,firststage.colNames,varFamily)
        end
    end

    return firststage
end

function take_ownership!(model::JuMP.Model)
    for constraint in model.linconstr
        for (i,var) in enumerate(constraint.terms.vars)
            if var.m != model
                constraint.terms.vars[i] = Variable(model,var.col)
            end
        end
    end
end
