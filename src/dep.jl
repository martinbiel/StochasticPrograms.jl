function JuMP.prepAffObjective(model::JuMP.Model)
    objaff::AffExpr = model.obj.aff
    #assert_isfinite(objaff)
    # if !verify_ownership(model, objaff.vars)
    #     throw(VariableNotOwnedError("objective"))
    # end
    f = zeros(model.numCols)
    @inbounds for ind in 1:length(objaff.vars)
        f[objaff.vars[ind].col] += objaff.coeffs[ind]
    end

    if haskey(model.ext,:SP)
        dim = model.numCols
        for (i,subproblem) in enumerate(subproblems(model))
            subdim = subproblem.numCols
            append!(f,zeros(subdim))
            subobjaff::AffExpr = subproblem.obj.aff
            @inbounds for (j,var) in enumerate(subobjaff.vars)
                if var.m == model
                    f[var.col] += probability(model,i)*subobjaff.coeffs[j]
                else
                    f[var.col+dim] += probability(model,i)*subobjaff.coeffs[j]
                end
            end
            dim += subdim
        end
    end

    return f
end
